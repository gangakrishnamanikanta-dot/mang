-- ==============================================================================
-- Mangalasutram: 3-Tier Brahmin Recommendation Engine & On-The-Fly Fallback
-- Migration: 20261119000001_brahmin_waterfall_matching_engine.sql
-- 
-- 1. Drops ambiguous refresh_user_match_cache(uuid) overload to fix 42725 ambiguity.
-- 2. Corrects calculate_guna_milan_points parameter order (fixes inverted girl_rashi / pada).
-- 3. Implements 3-Tier Brahmin Waterfall in refresh_user_match_cache:
--    - Tier 1: Direct Partner Preference alignment (caste, age, height, mother tongue, marital status, sagotra excluded)
--    - Tier 2: High Vedic Ashta-Koota compatibility (guna_score >= 18)
--    - Tier 3: Active & verified Brahmin community discovery
--    - Cold-Start: Relaxes mandatory profile_completed block so new users receive matches immediately.
-- 4. Upgrades get_top_matches_v2 with live on-the-fly cache fallback on empty cache.
-- ==============================================================================

-- ── 1. Drop Deprecated & Ambiguous Signatures ────────────────────────────────
DROP FUNCTION IF EXISTS public.refresh_user_match_cache(uuid);
DROP FUNCTION IF EXISTS public.refresh_user_match_cache(uuid, boolean);
DROP FUNCTION IF EXISTS public.get_top_matches_v2(uuid, integer, integer);

-- ── 2. Canonical 3-Tier Brahmin Recommendation Engine ────────────────────────
CREATE OR REPLACE FUNCTION public.refresh_user_match_cache(
    p_user_id uuid,
    p_force boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id uuid;
    v_is_authorized boolean := false;
    v_user public.profiles;
    v_pref public.partner_preferences;
    v_target_gender text;
    v_user_age integer;
    v_tier1_matches jsonb := '[]'::jsonb;
    v_tier2_matches jsonb := '[]'::jsonb;
    v_tier3_matches jsonb := '[]'::jsonb;
    v_all_matches   jsonb := '[]'::jsonb;
    v_tier1_ids     uuid[] := ARRAY[]::uuid[];
    v_tier2_ids     uuid[] := ARRAY[]::uuid[];
BEGIN
    v_caller_id := auth.uid();

    -- Authorization check (caller must be owner, authorized guardian, admin, or background service_role)
    IF v_caller_id IS NOT NULL AND v_caller_id <> p_user_id THEN
        SELECT EXISTS (
            SELECT 1 FROM public.profiles WHERE id = v_caller_id AND is_admin = true
        ) INTO v_is_authorized;

        IF NOT v_is_authorized THEN
            SELECT EXISTS (
                SELECT 1 FROM public.family_members fm
                JOIN public.family_circles fc ON fc.id = fm.family_circle_id
                WHERE fm.user_id = v_caller_id
                  AND fm.role <> 'Candidate'
                  AND fc.candidate_id = p_user_id
            ) INTO v_is_authorized;
        END IF;

        IF NOT v_is_authorized THEN
            RAISE EXCEPTION 'Access denied';
        END IF;
    END IF;

    -- Fetch user profile
    SELECT * INTO v_user FROM public.profiles WHERE id = p_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('status', 'error', 'message', 'User not found');
    END IF;

    -- Cold-start check: only require gender to be known. Do NOT hard-block if profile_completed is false.
    IF v_user.gender IS NULL OR TRIM(v_user.gender) = '' THEN
        RETURN jsonb_build_object('status', 'skipped', 'message', 'Gender required for matching');
    END IF;

    -- Fetch partner preferences (if any)
    SELECT * INTO v_pref FROM public.partner_preferences WHERE profile_id = p_user_id;

    v_target_gender := CASE
        WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN 'Female'
        WHEN LOWER(TRIM(v_user.gender)) = 'female' THEN 'Male'
        ELSE NULL
    END;

    IF v_user.date_of_birth IS NOT NULL THEN
        v_user_age := EXTRACT(YEAR FROM age(v_user.date_of_birth::date))::integer;
    END IF;

    -- ═════════════════════════════════════════════════════════════════════════
    -- TIER 1: Direct Partner Preference Matches (Up to 30 candidates)
    -- ═════════════════════════════════════════════════════════════════════════
    WITH eligible_candidates AS (
        SELECT
            p.id,
            p.id AS profile_id,
            p.full_name,
            p.gender,
            p.date_of_birth,
            CASE
                WHEN p.date_of_birth IS NOT NULL THEN
                    EXTRACT(YEAR FROM age(p.date_of_birth::date))::integer
                ELSE NULL
            END AS age,
            p.height_inches,
            p.city,
            p.state,
            p.country_id,
            p.native_place,
            p.caste_id,
            p.sub_caste,
            p.gothram_id,
            p.highest_education_id,
            p.college,
            p.occupation_id,
            p.company,
            p.work_location,
            p.annual_income_id,
            p.marital_status_id,
            p.mother_tongue_id,
            p.food_preference_id,
            p.family_type_id,
            p.rashi_id,
            p.nakshatra_id,
            COALESCE(p.pada_id, p.pada, 1) AS pada_id,
            p.kuja_dosham,
            p.about_me,
            COALESCE(p.is_verified, false) AS is_verified,
            p.last_active_at,
            p.profile_photo_url,
            p.profile_photo_url AS primary_photo_url,
            p.additional_photo_urls,
            p.created_at,
            p.updated_at,
            (p.last_active_at IS NOT NULL AND p.last_active_at >= (now() - interval '15 minutes')) AS is_online,
            CASE
                WHEN p.last_active_at IS NULL THEN 'Recently'
                WHEN p.last_active_at >= (now() - interval '5 minutes') THEN 'Active now'
                WHEN p.last_active_at >= (now() - interval '60 minutes') THEN 
                    EXTRACT(MINUTE FROM (now() - p.last_active_at))::text || 'm ago'
                WHEN p.last_active_at >= (now() - interval '24 hours') THEN 
                    EXTRACT(HOUR FROM (now() - p.last_active_at))::text || 'h ago'
                ELSE 'Active recently'
            END AS last_active_label,
            (SELECT count(*)::int FROM public.profile_photos WHERE profile_id = p.id) AS photo_count,
            ROUND(public.calculate_reciprocal_compatibility(v_user.id, p.id)::numeric, 1)::double precision AS match_score,
            CASE
                WHEN v_user.nakshatra_id IS NOT NULL AND p.nakshatra_id IS NOT NULL
                     AND v_user.rashi_id IS NOT NULL AND p.rashi_id IS NOT NULL
                     AND (COALESCE(v_pref.exclude_same_gotra, true) IS NOT TRUE 
                          OR v_user.gothram_id IS NULL OR p.gothram_id IS NULL 
                          OR v_user.gothram_id <> p.gothram_id)
                THEN
                    ROUND(public.calculate_guna_milan_points(
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN v_user.rashi_id ELSE p.rashi_id END,
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN v_user.nakshatra_id ELSE p.nakshatra_id END,
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN p.rashi_id ELSE v_user.rashi_id END,
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN p.nakshatra_id ELSE v_user.nakshatra_id END,
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN COALESCE(v_user.pada_id, v_user.pada, 1) ELSE COALESCE(p.pada_id, p.pada, 1) END,
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN COALESCE(p.pada_id, p.pada, 1) ELSE COALESCE(v_user.pada_id, v_user.pada, 1) END
                    ))::integer
                ELSE NULL
            END AS guna_score
        FROM public.profiles p
        WHERE p.id <> v_user.id
          AND COALESCE(p.is_hidden, false) = false
          AND COALESCE(p.account_type, 'candidate') = 'candidate'
          AND (v_target_gender IS NULL OR LOWER(TRIM(p.gender)) = LOWER(TRIM(v_target_gender)))
          -- Strict Sagotra Exclusion for Brahmin tradition
          AND (COALESCE(v_pref.exclude_same_gotra, true) IS NOT TRUE 
               OR v_user.gothram_id IS NULL OR p.gothram_id IS NULL 
               OR v_user.gothram_id <> p.gothram_id)
          -- Exclude blocked users
          AND NOT EXISTS (
              SELECT 1 FROM public.user_blocks ub
              WHERE (ub.blocker_id = v_user.id AND ub.blocked_id = p.id)
                 OR (ub.blocker_id = p.id AND ub.blocked_id = v_user.id)
          )
          -- Exclude rejected/passed profiles
          AND NOT EXISTS (
              SELECT 1 FROM public.match_exclusions me
              WHERE me.user_id = v_user.id AND me.excluded_id = p.id
          )
    ),
    tier1_ranked AS (
        SELECT ec.*, 'tier1_preference' AS slot_type
        FROM eligible_candidates ec
        WHERE (
            v_pref.profile_id IS NULL OR (
                (v_pref.min_age IS NULL OR ec.age IS NULL OR ec.age >= v_pref.min_age)
                AND (v_pref.max_age IS NULL OR ec.age IS NULL OR ec.age <= v_pref.max_age)
                AND (v_pref.min_height_inches IS NULL OR ec.height_inches IS NULL OR ec.height_inches >= v_pref.min_height_inches)
                AND (v_pref.max_height_inches IS NULL OR ec.height_inches IS NULL OR ec.height_inches <= v_pref.max_height_inches)
                AND (v_pref.preferred_caste_ids IS NULL OR array_length(v_pref.preferred_caste_ids, 1) IS NULL OR ec.caste_id = ANY(v_pref.preferred_caste_ids))
                AND (v_pref.preferred_mother_tongue_ids IS NULL OR array_length(v_pref.preferred_mother_tongue_ids, 1) IS NULL OR ec.mother_tongue_id = ANY(v_pref.preferred_mother_tongue_ids))
                AND (v_pref.preferred_marital_status_ids IS NULL OR array_length(v_pref.preferred_marital_status_ids, 1) IS NULL OR ec.marital_status_id = ANY(v_pref.preferred_marital_status_ids))
            )
        )
        ORDER BY
            ec.match_score DESC,
            ec.guna_score DESC NULLS LAST,
            ec.is_verified DESC,
            ec.last_active_at DESC NULLS LAST
        LIMIT 30
    )
    SELECT
        COALESCE(jsonb_agg(to_jsonb(r.*)), '[]'::jsonb),
        COALESCE(array_agg(r.id), ARRAY[]::uuid[])
    INTO v_tier1_matches, v_tier1_ids
    FROM tier1_ranked r;

    -- ═════════════════════════════════════════════════════════════════════════
    -- TIER 2: High Vedic Ashta-Koota Compatibility (Up to 20 candidates, guna >= 18)
    -- ═════════════════════════════════════════════════════════════════════════
    WITH eligible_candidates AS (
        SELECT
            p.id,
            p.id AS profile_id,
            p.full_name,
            p.gender,
            p.date_of_birth,
            CASE
                WHEN p.date_of_birth IS NOT NULL THEN
                    EXTRACT(YEAR FROM age(p.date_of_birth::date))::integer
                ELSE NULL
            END AS age,
            p.height_inches,
            p.city,
            p.state,
            p.country_id,
            p.native_place,
            p.caste_id,
            p.sub_caste,
            p.gothram_id,
            p.highest_education_id,
            p.college,
            p.occupation_id,
            p.company,
            p.work_location,
            p.annual_income_id,
            p.marital_status_id,
            p.mother_tongue_id,
            p.food_preference_id,
            p.family_type_id,
            p.rashi_id,
            p.nakshatra_id,
            COALESCE(p.pada_id, p.pada, 1) AS pada_id,
            p.kuja_dosham,
            p.about_me,
            COALESCE(p.is_verified, false) AS is_verified,
            p.last_active_at,
            p.profile_photo_url,
            p.profile_photo_url AS primary_photo_url,
            p.additional_photo_urls,
            p.created_at,
            p.updated_at,
            (p.last_active_at IS NOT NULL AND p.last_active_at >= (now() - interval '15 minutes')) AS is_online,
            CASE
                WHEN p.last_active_at IS NULL THEN 'Recently'
                WHEN p.last_active_at >= (now() - interval '5 minutes') THEN 'Active now'
                WHEN p.last_active_at >= (now() - interval '60 minutes') THEN 
                    EXTRACT(MINUTE FROM (now() - p.last_active_at))::text || 'm ago'
                WHEN p.last_active_at >= (now() - interval '24 hours') THEN 
                    EXTRACT(HOUR FROM (now() - p.last_active_at))::text || 'h ago'
                ELSE 'Active recently'
            END AS last_active_label,
            (SELECT count(*)::int FROM public.profile_photos WHERE profile_id = p.id) AS photo_count,
            ROUND(public.calculate_reciprocal_compatibility(v_user.id, p.id)::numeric, 1)::double precision AS match_score,
            CASE
                WHEN v_user.nakshatra_id IS NOT NULL AND p.nakshatra_id IS NOT NULL
                     AND v_user.rashi_id IS NOT NULL AND p.rashi_id IS NOT NULL
                     AND (COALESCE(v_pref.exclude_same_gotra, true) IS NOT TRUE 
                          OR v_user.gothram_id IS NULL OR p.gothram_id IS NULL 
                          OR v_user.gothram_id <> p.gothram_id)
                THEN
                    ROUND(public.calculate_guna_milan_points(
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN v_user.rashi_id ELSE p.rashi_id END,
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN v_user.nakshatra_id ELSE p.nakshatra_id END,
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN p.rashi_id ELSE v_user.rashi_id END,
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN p.nakshatra_id ELSE v_user.nakshatra_id END,
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN COALESCE(v_user.pada_id, v_user.pada, 1) ELSE COALESCE(p.pada_id, p.pada, 1) END,
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN COALESCE(p.pada_id, p.pada, 1) ELSE COALESCE(v_user.pada_id, v_user.pada, 1) END
                    ))::integer
                ELSE NULL
            END AS guna_score
        FROM public.profiles p
        WHERE p.id <> v_user.id
          AND p.id <> ALL(v_tier1_ids)
          AND COALESCE(p.is_hidden, false) = false
          AND COALESCE(p.account_type, 'candidate') = 'candidate'
          AND (v_target_gender IS NULL OR LOWER(TRIM(p.gender)) = LOWER(TRIM(v_target_gender)))
          AND (COALESCE(v_pref.exclude_same_gotra, true) IS NOT TRUE 
               OR v_user.gothram_id IS NULL OR p.gothram_id IS NULL 
               OR v_user.gothram_id <> p.gothram_id)
          AND NOT EXISTS (
              SELECT 1 FROM public.user_blocks ub
              WHERE (ub.blocker_id = v_user.id AND ub.blocked_id = p.id)
                 OR (ub.blocker_id = p.id AND ub.blocked_id = v_user.id)
          )
          AND NOT EXISTS (
              SELECT 1 FROM public.match_exclusions me
              WHERE me.user_id = v_user.id AND me.excluded_id = p.id
          )
    ),
    tier2_ranked AS (
        SELECT ec.*, 'tier2_vedic' AS slot_type
        FROM eligible_candidates ec
        WHERE ec.guna_score IS NOT NULL AND ec.guna_score >= 18
        ORDER BY
            ec.guna_score DESC,
            ec.match_score DESC,
            ec.is_verified DESC,
            ec.last_active_at DESC NULLS LAST
        LIMIT 20
    )
    SELECT
        COALESCE(jsonb_agg(to_jsonb(r.*)), '[]'::jsonb),
        COALESCE(array_agg(r.id), ARRAY[]::uuid[])
    INTO v_tier2_matches, v_tier2_ids
    FROM tier2_ranked r;

    -- ═════════════════════════════════════════════════════════════════════════
    -- TIER 3: Active & Verified Brahmin Community Discovery (Up to 10 candidates)
    -- ═════════════════════════════════════════════════════════════════════════
    WITH eligible_candidates AS (
        SELECT
            p.id,
            p.id AS profile_id,
            p.full_name,
            p.gender,
            p.date_of_birth,
            CASE
                WHEN p.date_of_birth IS NOT NULL THEN
                    EXTRACT(YEAR FROM age(p.date_of_birth::date))::integer
                ELSE NULL
            END AS age,
            p.height_inches,
            p.city,
            p.state,
            p.country_id,
            p.native_place,
            p.caste_id,
            p.sub_caste,
            p.gothram_id,
            p.highest_education_id,
            p.college,
            p.occupation_id,
            p.company,
            p.work_location,
            p.annual_income_id,
            p.marital_status_id,
            p.mother_tongue_id,
            p.food_preference_id,
            p.family_type_id,
            p.rashi_id,
            p.nakshatra_id,
            COALESCE(p.pada_id, p.pada, 1) AS pada_id,
            p.kuja_dosham,
            p.about_me,
            COALESCE(p.is_verified, false) AS is_verified,
            p.last_active_at,
            p.profile_photo_url,
            p.profile_photo_url AS primary_photo_url,
            p.additional_photo_urls,
            p.created_at,
            p.updated_at,
            (p.last_active_at IS NOT NULL AND p.last_active_at >= (now() - interval '15 minutes')) AS is_online,
            CASE
                WHEN p.last_active_at IS NULL THEN 'Recently'
                WHEN p.last_active_at >= (now() - interval '5 minutes') THEN 'Active now'
                WHEN p.last_active_at >= (now() - interval '60 minutes') THEN 
                    EXTRACT(MINUTE FROM (now() - p.last_active_at))::text || 'm ago'
                WHEN p.last_active_at >= (now() - interval '24 hours') THEN 
                    EXTRACT(HOUR FROM (now() - p.last_active_at))::text || 'h ago'
                ELSE 'Active recently'
            END AS last_active_label,
            (SELECT count(*)::int FROM public.profile_photos WHERE profile_id = p.id) AS photo_count,
            ROUND(public.calculate_reciprocal_compatibility(v_user.id, p.id)::numeric, 1)::double precision AS match_score,
            CASE
                WHEN v_user.nakshatra_id IS NOT NULL AND p.nakshatra_id IS NOT NULL
                     AND v_user.rashi_id IS NOT NULL AND p.rashi_id IS NOT NULL
                     AND (COALESCE(v_pref.exclude_same_gotra, true) IS NOT TRUE 
                          OR v_user.gothram_id IS NULL OR p.gothram_id IS NULL 
                          OR v_user.gothram_id <> p.gothram_id)
                THEN
                    ROUND(public.calculate_guna_milan_points(
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN v_user.rashi_id ELSE p.rashi_id END,
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN v_user.nakshatra_id ELSE p.nakshatra_id END,
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN p.rashi_id ELSE v_user.rashi_id END,
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN p.nakshatra_id ELSE v_user.nakshatra_id END,
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN COALESCE(v_user.pada_id, v_user.pada, 1) ELSE COALESCE(p.pada_id, p.pada, 1) END,
                        CASE WHEN LOWER(TRIM(v_user.gender)) = 'male' THEN COALESCE(p.pada_id, p.pada, 1) ELSE COALESCE(v_user.pada_id, v_user.pada, 1) END
                    ))::integer
                ELSE NULL
            END AS guna_score
        FROM public.profiles p
        WHERE p.id <> v_user.id
          AND p.id <> ALL(v_tier1_ids || v_tier2_ids)
          AND COALESCE(p.is_hidden, false) = false
          AND COALESCE(p.account_type, 'candidate') = 'candidate'
          AND (v_target_gender IS NULL OR LOWER(TRIM(p.gender)) = LOWER(TRIM(v_target_gender)))
          AND (COALESCE(v_pref.exclude_same_gotra, true) IS NOT TRUE 
               OR v_user.gothram_id IS NULL OR p.gothram_id IS NULL 
               OR v_user.gothram_id <> p.gothram_id)
          AND NOT EXISTS (
              SELECT 1 FROM public.user_blocks ub
              WHERE (ub.blocker_id = v_user.id AND ub.blocked_id = p.id)
                 OR (ub.blocker_id = p.id AND ub.blocked_id = v_user.id)
          )
          AND NOT EXISTS (
              SELECT 1 FROM public.match_exclusions me
              WHERE me.user_id = v_user.id AND me.excluded_id = p.id
          )
    ),
    tier3_ranked AS (
        SELECT ec.*, 'tier3_discovery' AS slot_type
        FROM eligible_candidates ec
        ORDER BY
            ec.is_verified DESC,
            (ec.profile_photo_url IS NOT NULL AND TRIM(ec.profile_photo_url) <> '') DESC,
            ec.match_score DESC,
            ec.last_active_at DESC NULLS LAST,
            ec.created_at DESC
        LIMIT 10
    )
    SELECT
        COALESCE(jsonb_agg(to_jsonb(r.*)), '[]'::jsonb)
    INTO v_tier3_matches
    FROM tier3_ranked r;

    -- Concatenate all tiers: Tier 1 -> Tier 2 -> Tier 3
    v_all_matches := v_tier1_matches || v_tier2_matches || v_tier3_matches;

    -- Atomic Upsert into user_match_cache
    INSERT INTO public.user_match_cache (user_id, matches, computed_at, algorithm_version)
    VALUES (p_user_id, v_all_matches, now(), 6)
    ON CONFLICT (user_id)
    DO UPDATE SET
        matches = EXCLUDED.matches,
        computed_at = now(),
        algorithm_version = 6;

    RETURN jsonb_build_object(
        'status', 'refreshed',
        'count', jsonb_array_length(v_all_matches),
        'tier1_count', jsonb_array_length(v_tier1_matches),
        'tier2_count', jsonb_array_length(v_tier2_matches),
        'tier3_count', jsonb_array_length(v_tier3_matches)
    );
END;
$function$;

-- ── 3. High-Performance get_top_matches_v2 with On-The-Fly Fallback ───────────
CREATE OR REPLACE FUNCTION public.get_top_matches_v2(
    p_user_id uuid,
    p_limit integer DEFAULT 25,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id uuid;
    v_is_authorized boolean := false;
    v_cached jsonb;
    v_result jsonb;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    -- Verify authorization: Caller must be owner, authorized guardian, or admin
    IF p_user_id <> v_caller_id THEN
        SELECT EXISTS (
            SELECT 1 FROM public.profiles WHERE id = v_caller_id AND is_admin = true
        ) INTO v_is_authorized;

        IF NOT v_is_authorized THEN
            SELECT EXISTS (
                SELECT 1 FROM public.family_members fm
                JOIN public.family_circles fc ON fc.id = fm.family_circle_id
                WHERE fm.user_id = v_caller_id
                  AND fm.role <> 'Candidate'
                  AND fc.candidate_id = p_user_id
            ) INTO v_is_authorized;
        END IF;

        IF NOT v_is_authorized THEN
            RAISE EXCEPTION 'Access denied';
        END IF;
    END IF;

    IF public.is_user_suspended(p_user_id) THEN
        RAISE EXCEPTION 'Access denied: account suspended';
    END IF;

    -- 1. Try reading from cache
    SELECT matches INTO v_cached
    FROM public.user_match_cache
    WHERE user_id = p_user_id;

    -- 2. On-the-fly Fallback: If cache is empty or missing, compute immediately!
    IF v_cached IS NULL OR jsonb_array_length(v_cached) = 0 THEN
        PERFORM public.refresh_user_match_cache(p_user_id, true);

        SELECT matches INTO v_cached
        FROM public.user_match_cache
        WHERE user_id = p_user_id;
    END IF;

    -- 3. Slice according to limit & offset
    IF v_cached IS NOT NULL AND jsonb_array_length(v_cached) > 0 THEN
        SELECT jsonb_agg(m) INTO v_result
        FROM (
            SELECT m
            FROM jsonb_array_elements(v_cached) WITH ORDINALITY AS arr(m, ord)
            ORDER BY ord
            LIMIT p_limit OFFSET p_offset
        ) sub;
        RETURN COALESCE(v_result, '[]'::jsonb);
    END IF;

    RETURN '[]'::jsonb;
END;
$function$;

-- ── 4. Explicit Permissions & Revocations ────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.refresh_user_match_cache(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_top_matches_v2(uuid, integer, integer) TO authenticated;

REVOKE ALL ON FUNCTION public.refresh_user_match_cache(uuid, boolean) FROM anon, public;
REVOKE ALL ON FUNCTION public.get_top_matches_v2(uuid, integer, integer) FROM anon, public;

