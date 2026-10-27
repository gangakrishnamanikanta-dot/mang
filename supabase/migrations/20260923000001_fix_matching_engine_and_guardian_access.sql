-- =====================================================================
-- Migration: 20260923000001_fix_matching_engine_and_guardian_access.sql
-- Fixes:
-- 1. calculate_reciprocal_compatibility: checks profile_id instead of non-existent id
-- 2. refresh_user_match_cache: fixes me.id -> me.excluded_id, inserts into computed_at
-- 3. get_top_matches_v2: permits candidate AND candidate's authorized family guardians
-- =====================================================================

-- ── 1. Fix calculate_reciprocal_compatibility ────────────────────────
CREATE OR REPLACE FUNCTION public.calculate_reciprocal_compatibility(
    p_user      public.profiles,
    p_user_pref public.partner_preferences,
    p_cand      public.profiles,
    p_cand_pref public.partner_preferences
)
RETURNS float8
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_forward_score float8 := 20.0;
    v_reverse_score float8 := 20.0;
    v_final_score   float8;
    v_cand_age      integer;
    v_user_age      integer;
    v_hours_since_active float8;
    v_guna_points   integer := 0;
BEGIN
    IF p_cand.date_of_birth IS NOT NULL THEN
        v_cand_age := EXTRACT(YEAR FROM age(p_cand.date_of_birth::date))::integer;
    END IF;
    IF p_user.date_of_birth IS NOT NULL THEN
        v_user_age := EXTRACT(YEAR FROM age(p_user.date_of_birth::date))::integer;
    END IF;

    -- Sagotra Check (Same Gothram exclusion for Vedic traditions)
    IF p_user.gothram_id IS NOT NULL AND p_cand.gothram_id IS NOT NULL AND p_user.gothram_id = p_cand.gothram_id THEN
        v_forward_score := v_forward_score - 15.0;
    END IF;

    -- Forward score: User evaluating Candidate (Max 70 pts)
    IF p_user_pref.profile_id IS NOT NULL THEN
        -- Age alignment (15 pts)
        IF p_user_pref.min_age IS NOT NULL AND v_cand_age IS NOT NULL THEN
            IF v_cand_age >= p_user_pref.min_age AND (p_user_pref.max_age IS NULL OR v_cand_age <= p_user_pref.max_age) THEN
                v_forward_score := v_forward_score + 15.0;
            END IF;
        END IF;
        -- Caste alignment (20 pts)
        IF p_user_pref.preferred_caste_ids IS NOT NULL AND p_cand.caste_id IS NOT NULL THEN
            IF p_cand.caste_id = ANY(p_user_pref.preferred_caste_ids) THEN
                v_forward_score := v_forward_score + 20.0;
            END IF;
        END IF;
        -- Mother Tongue alignment (10 pts)
        IF p_user_pref.preferred_mother_tongue_ids IS NOT NULL AND p_cand.mother_tongue_id IS NOT NULL THEN
            IF p_cand.mother_tongue_id = ANY(p_user_pref.preferred_mother_tongue_ids) THEN
                v_forward_score := v_forward_score + 10.0;
            END IF;
        END IF;
        -- Location / State alignment (12 pts)
        IF p_user.state IS NOT NULL AND p_cand.state IS NOT NULL AND LOWER(TRIM(p_user.state)) = LOWER(TRIM(p_cand.state)) THEN
            v_forward_score := v_forward_score + 8.0;
            IF p_user.city IS NOT NULL AND p_cand.city IS NOT NULL AND LOWER(TRIM(p_user.city)) = LOWER(TRIM(p_cand.city)) THEN
                v_forward_score := v_forward_score + 4.0;
            END IF;
        END IF;
        -- Education alignment (8 pts)
        IF p_user_pref.preferred_education_ids IS NOT NULL AND p_cand.highest_education_id IS NOT NULL THEN
            IF p_cand.highest_education_id = ANY(p_user_pref.preferred_education_ids) THEN
                v_forward_score := v_forward_score + 8.0;
            END IF;
        END IF;
    ELSE
        IF p_user.caste_id IS NOT NULL AND p_cand.caste_id = p_user.caste_id THEN
            v_forward_score := v_forward_score + 25.0;
        END IF;
        IF p_user.state IS NOT NULL AND p_cand.state IS NOT NULL AND LOWER(TRIM(p_user.state)) = LOWER(TRIM(p_cand.state)) THEN
            v_forward_score := v_forward_score + 15.0;
        END IF;
    END IF;

    -- Reverse score: Candidate evaluating User (Max 70 pts)
    IF p_cand_pref.profile_id IS NOT NULL THEN
        IF p_cand_pref.min_age IS NOT NULL AND v_user_age IS NOT NULL THEN
            IF v_user_age >= p_cand_pref.min_age AND (p_cand_pref.max_age IS NULL OR v_user_age <= p_cand_pref.max_age) THEN
                v_reverse_score := v_reverse_score + 15.0;
            END IF;
        END IF;
        IF p_cand_pref.preferred_caste_ids IS NOT NULL AND p_user.caste_id IS NOT NULL THEN
            IF p_user.caste_id = ANY(p_cand_pref.preferred_caste_ids) THEN
                v_reverse_score := v_reverse_score + 20.0;
            END IF;
        END IF;
        IF p_cand_pref.preferred_mother_tongue_ids IS NOT NULL AND p_user.mother_tongue_id IS NOT NULL THEN
            IF p_user.mother_tongue_id = ANY(p_cand_pref.preferred_mother_tongue_ids) THEN
                v_reverse_score := v_reverse_score + 10.0;
            END IF;
        END IF;
        IF p_cand_pref.min_height_inches IS NOT NULL AND p_user.height_inches IS NOT NULL THEN
            IF p_user.height_inches >= p_cand_pref.min_height_inches AND (p_cand_pref.max_height_inches IS NULL OR p_user.height_inches <= p_cand_pref.max_height_inches) THEN
                v_reverse_score := v_reverse_score + 10.0;
            END IF;
        END IF;
    ELSE
        v_reverse_score := v_forward_score;
    END IF;

    -- Base Reciprocal Preference Match (55% forward, 45% reverse)
    v_final_score := (v_forward_score * 0.55) + (v_reverse_score * 0.45);

    -- Vedic Guna Milan Integration (Strict & Canonical)
    IF p_user.rashi_id IS NOT NULL AND p_cand.rashi_id IS NOT NULL 
       AND p_user.nakshatra_id IS NOT NULL AND p_cand.nakshatra_id IS NOT NULL THEN
        IF LOWER(TRIM(COALESCE(p_user.gender, 'male'))) = 'male' THEN
            v_guna_points := public.calculate_guna_milan_points(p_user.rashi_id, p_user.nakshatra_id, p_cand.rashi_id, p_cand.nakshatra_id);
        ELSE
            v_guna_points := public.calculate_guna_milan_points(p_cand.rashi_id, p_cand.nakshatra_id, p_user.rashi_id, p_user.nakshatra_id);
        END IF;

        IF v_guna_points IS NOT NULL THEN
            IF v_guna_points >= 28 THEN
                v_final_score := v_final_score + 8.0;
            ELSIF v_guna_points >= 18 THEN
                v_final_score := v_final_score + 4.0;
            ELSIF v_guna_points > 0 AND v_guna_points < 14 THEN
                v_final_score := v_final_score - 8.0;
            END IF;
        END IF;
    END IF;

    -- Activity Boost / Decay
    IF p_cand.updated_at IS NOT NULL THEN
        v_hours_since_active := EXTRACT(EPOCH FROM (now() - p_cand.updated_at)) / 3600.0;
        IF v_hours_since_active < 1.0 THEN
            v_final_score := v_final_score + 5.0;
        ELSIF v_hours_since_active < 24.0 THEN
            v_final_score := v_final_score + 3.0;
        ELSIF v_hours_since_active > 336.0 THEN
            v_final_score := v_final_score - 10.0;
        END IF;
    END IF;

    IF COALESCE(p_cand.is_verified, false) THEN
        v_final_score := v_final_score + 2.0;
    END IF;

    IF p_cand.profile_photo_url IS NOT NULL AND TRIM(p_cand.profile_photo_url) <> '' THEN
        v_final_score := v_final_score + 3.0;
    END IF;

    RETURN LEAST(98.0, GREATEST(35.0, v_final_score));
END;
$$;

-- Overload for (uuid, uuid)
CREATE OR REPLACE FUNCTION public.calculate_reciprocal_compatibility(
    p_user_id uuid,
    p_cand_id uuid
)
RETURNS float8
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user public.profiles;
    v_user_pref public.partner_preferences;
    v_cand public.profiles;
    v_cand_pref public.partner_preferences;
BEGIN
    SELECT * INTO v_user FROM public.profiles WHERE id = p_user_id;
    SELECT * INTO v_user_pref FROM public.partner_preferences WHERE profile_id = p_user_id;
    SELECT * INTO v_cand FROM public.profiles WHERE id = p_cand_id;
    SELECT * INTO v_cand_pref FROM public.partner_preferences WHERE profile_id = p_cand_id;

    RETURN public.calculate_reciprocal_compatibility(v_user, v_user_pref, v_cand, v_cand_pref);
END;
$$;

-- ── 2. Fix refresh_user_match_cache ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.refresh_user_match_cache(
    p_user_id uuid,
    p_force boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user public.profiles;
    v_pref public.partner_preferences;
    v_matches jsonb := '[]'::jsonb;
    v_fresh_matches jsonb := '[]'::jsonb;
    v_target_gender text;
    v_user_completed boolean;
BEGIN
    SELECT * INTO v_user FROM public.profiles WHERE id = p_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('status', 'error', 'message', 'User not found');
    END IF;

    v_user_completed := COALESCE(v_user.profile_completed, false) 
        AND (v_user.gender IS NOT NULL) 
        AND (v_user.full_name IS NOT NULL);

    IF NOT v_user_completed THEN
        RETURN jsonb_build_object('status', 'skipped', 'message', 'Profile incomplete');
    END IF;

    SELECT * INTO v_pref FROM public.partner_preferences WHERE profile_id = p_user_id;

    v_target_gender := CASE 
        WHEN LOWER(COALESCE(v_user.gender, '')) = 'male' THEN 'Female'
        WHEN LOWER(COALESCE(v_user.gender, '')) = 'female' THEN 'Male'
        ELSE NULL
    END;

    -- Fetch Top 54 Ranked Matches
    WITH candidate_pool AS (
        SELECT 
            p.id,
            p.full_name,
            p.gender,
            p.date_of_birth,
            p.height_inches,
            p.city,
            p.state,
            p.caste_id,
            p.sub_caste,
            p.highest_education_id,
            p.occupation_id,
            p.annual_income_id,
            p.marital_status_id,
            p.mother_tongue_id,
            p.food_preference_id,
            p.rashi_id,
            p.nakshatra_id,
            p.last_active_at,
            p.profile_photo_url AS primary_photo_url,
            (SELECT count(*)::int FROM public.profile_photos WHERE profile_id = p.id) AS photo_count,
            public.calculate_reciprocal_compatibility(v_user.id, p.id) AS match_score,
            CASE 
                WHEN v_user.rashi_id IS NOT NULL AND v_user.nakshatra_id IS NOT NULL 
                     AND p.rashi_id IS NOT NULL AND p.nakshatra_id IS NOT NULL 
                THEN 
                    ROUND(public.calculate_guna_milan_points(
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN v_user.rashi_id ELSE p.rashi_id END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN v_user.nakshatra_id ELSE p.nakshatra_id END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN p.rashi_id ELSE v_user.rashi_id END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN p.nakshatra_id ELSE v_user.nakshatra_id END
                    ))::integer
                ELSE NULL
            END AS guna_score
        FROM public.profiles p
        LEFT JOIN public.match_exclusions me 
            ON me.user_id = v_user.id AND me.excluded_id = p.id
        WHERE p.id <> v_user.id
          AND COALESCE(p.profile_completed, false) = true
          AND COALESCE(p.account_type, 'candidate') = 'candidate'
          AND me.excluded_id IS NULL
          AND (v_target_gender IS NULL OR LOWER(p.gender) = LOWER(v_target_gender))
    ),
    ranked AS (
        SELECT *, 'ranked' AS slot_type
        FROM candidate_pool
        ORDER BY match_score DESC, guna_score DESC NULLS LAST, last_active_at DESC NULLS LAST
        LIMIT 54
    )
    SELECT COALESCE(jsonb_agg(to_jsonb(r.*)), '[]'::jsonb)
    INTO v_matches
    FROM ranked r;

    -- Fetch 6 Fresh exploration matches
    WITH fresh_pool AS (
        SELECT 
            p.id,
            p.full_name,
            p.gender,
            p.date_of_birth,
            p.height_inches,
            p.city,
            p.state,
            p.caste_id,
            p.sub_caste,
            p.highest_education_id,
            p.occupation_id,
            p.annual_income_id,
            p.marital_status_id,
            p.mother_tongue_id,
            p.food_preference_id,
            p.rashi_id,
            p.nakshatra_id,
            p.last_active_at,
            p.profile_photo_url AS primary_photo_url,
            (SELECT count(*)::int FROM public.profile_photos WHERE profile_id = p.id) AS photo_count,
            public.calculate_reciprocal_compatibility(v_user.id, p.id) AS match_score,
            NULL::integer AS guna_score
        FROM public.profiles p
        LEFT JOIN public.match_exclusions me 
            ON me.user_id = v_user.id AND me.excluded_id = p.id
        WHERE p.id <> v_user.id
          AND COALESCE(p.profile_completed, false) = true
          AND COALESCE(p.account_type, 'candidate') = 'candidate'
          AND me.excluded_id IS NULL
          AND (v_target_gender IS NULL OR LOWER(p.gender) = LOWER(v_target_gender))
          AND NOT EXISTS (
              SELECT 1 FROM jsonb_array_elements(v_matches) elem 
              WHERE (elem->>'id')::uuid = p.id
          )
        ORDER BY p.created_at DESC
        LIMIT 6
    ),
    fresh_ranked AS (
        SELECT *, 'fresh' AS slot_type
        FROM fresh_pool
    )
    SELECT COALESCE(jsonb_agg(to_jsonb(f.*)), '[]'::jsonb)
    INTO v_fresh_matches
    FROM fresh_ranked f;

    -- Upsert user match cache with computed_at & algorithm_version
    INSERT INTO public.user_match_cache (user_id, matches, computed_at, algorithm_version)
    VALUES (p_user_id, v_matches || v_fresh_matches, now(), 4)
    ON CONFLICT (user_id) 
    DO UPDATE SET 
        matches = EXCLUDED.matches,
        computed_at = now(),
        algorithm_version = 4;

    RETURN jsonb_build_object(
        'status', 'refreshed',
        'count', jsonb_array_length(v_matches || v_fresh_matches)
    );
END;
$$;

-- ── 3. Fix get_top_matches_v2 ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_top_matches_v2(
    p_user_id uuid,
    p_limit int DEFAULT 25,
    p_offset int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_cache             jsonb;
    v_result            jsonb;
    v_prof              public.profiles;
    v_gender            text;
    v_target            text;
    v_gothram_id        int;
    v_min_age           int;
    v_max_age           int;
    v_min_dob           date;
    v_max_dob           date;
    v_exclude_same_gotra boolean;
    v_membership        jsonb;
    v_tier              text := 'free';
    v_daily_limit       int := 5;
    v_effective_limit   int;
    v_effective_offset  int;
    v_is_guardian       boolean := false;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    -- Security Guard: Must be candidate themselves OR an authorized family guardian
    IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
        SELECT EXISTS (
            SELECT 1 
            FROM public.family_members fm
            JOIN public.family_circles fc ON fc.id = fm.family_circle_id
            WHERE fm.user_id = auth.uid() AND fc.candidate_id = p_user_id
        ) INTO v_is_guardian;

        IF NOT v_is_guardian THEN
            RAISE EXCEPTION 'Access denied';
        END IF;
    END IF;

    v_membership := public.get_user_membership_status(p_user_id);
    v_tier := COALESCE(v_membership->>'tier', 'free');
    v_daily_limit := COALESCE((v_membership->>'daily_matches_limit')::int, 5);

    IF p_offset >= v_daily_limit THEN
        RETURN '[]'::jsonb;
    END IF;

    v_effective_limit := LEAST(p_limit, v_daily_limit - p_offset);
    v_effective_offset := p_offset;

    SELECT * INTO v_prof FROM public.profiles WHERE id = p_user_id;
    v_gender := LOWER(TRIM(COALESCE(v_prof.gender,'')));
    v_gothram_id := v_prof.gothram_id;

    IF v_gender = 'male' THEN v_target := 'female';
    ELSIF v_gender = 'female' THEN v_target := 'male';
    ELSE v_target := NULL;
    END IF;

    SELECT min_age, max_age, COALESCE(exclude_same_gotra, true)
    INTO v_min_age, v_max_age, v_exclude_same_gotra
    FROM public.partner_preferences WHERE profile_id = p_user_id;

    IF v_min_age IS NOT NULL THEN
        v_max_dob := (CURRENT_DATE - (v_min_age * INTERVAL '1 year'))::date;
    END IF;
    IF v_max_age IS NOT NULL THEN
        v_min_dob := (CURRENT_DATE - ((v_max_age + 1) * INTERVAL '1 year' - INTERVAL '1 day'))::date;
    END IF;

    -- 1. Try Cache First (24h TTL, algorithm_version >= 4)
    SELECT matches INTO v_cache
    FROM public.user_match_cache
    WHERE user_id = p_user_id
      AND computed_at > now() - interval '24 hours'
      AND algorithm_version >= 4;

    IF v_cache IS NOT NULL AND jsonb_array_length(v_cache) > 0 THEN
        SELECT COALESCE(jsonb_agg(r), '[]'::jsonb)
        INTO v_result
        FROM (
            SELECT jsonb_build_object(
                'profile_id',           p.id,
                'full_name',            p.full_name,
                'score',                COALESCE((c->>'match_score')::float8, (c->>'score')::float8, 70.0),
                'guna_score',           (c->>'guna_score')::numeric,
                'age',                  EXTRACT(YEAR FROM age(p.date_of_birth))::int,
                'city',                 p.city,
                'state',                p.state,
                'profile_photo_url',    p.profile_photo_url,
                'gender',               p.gender,
                'caste_id',             p.caste_id,
                'nakshatra_id',         p.nakshatra_id,
                'rashi_id',             p.rashi_id,
                'gothram_id',           p.gothram_id,
                'mother_tongue_id',     p.mother_tongue_id,
                'highest_education_id', p.highest_education_id,
                'occupation_id',        p.occupation_id,
                'is_verified',          COALESCE(p.is_verified, false),
                'membership_tier',      COALESCE(c->>'membership_tier', 'free'),
                'is_prime',             COALESCE((c->>'is_prime')::boolean, false),
                'created_at',           p.created_at
            ) AS r
            FROM jsonb_array_elements(v_cache) c
            JOIN public.profiles p ON p.id = (c->>'id')::uuid OR p.id = (c->>'profile_id')::uuid
            LEFT JOIN public.match_exclusions me ON me.user_id = p_user_id AND me.excluded_id = p.id
            WHERE me.excluded_id IS NULL AND p.id <> p_user_id
              AND p.profile_completed = true
              AND (v_target IS NULL OR LOWER(TRIM(COALESCE(p.gender,''))) = v_target)
              AND p.full_name IS NOT NULL AND TRIM(p.full_name) <> ''
              AND (v_max_dob IS NULL OR p.date_of_birth <= v_max_dob)
              AND (v_min_dob IS NULL OR p.date_of_birth >= v_min_dob)
              AND (v_exclude_same_gotra = false OR v_gothram_id IS NULL OR p.gothram_id IS NULL OR p.gothram_id <> v_gothram_id)
            LIMIT v_effective_limit OFFSET v_effective_offset
        ) sub;

        IF v_result IS NOT NULL AND jsonb_array_length(v_result) > 0 THEN
            RETURN v_result;
        END IF;
    END IF;

    -- 2. Fallback: Live Query with Authentic Guna Score
    SELECT COALESCE(jsonb_agg(r), '[]'::jsonb) INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'profile_id',           p.id,
            'full_name',            p.full_name,
            'score',                ROUND(public.calculate_reciprocal_compatibility(p_user_id, p.id)::numeric, 1),
            'guna_score',           public.calculate_guna_milan_points(
                                        CASE WHEN LOWER(v_prof.gender) = 'male' THEN v_prof.rashi_id ELSE p.rashi_id END,
                                        CASE WHEN LOWER(v_prof.gender) = 'male' THEN v_prof.nakshatra_id ELSE p.nakshatra_id END,
                                        CASE WHEN LOWER(v_prof.gender) = 'male' THEN p.rashi_id ELSE v_prof.rashi_id END,
                                        CASE WHEN LOWER(v_prof.gender) = 'male' THEN p.nakshatra_id ELSE v_prof.nakshatra_id END,
                                        COALESCE(CASE WHEN LOWER(v_prof.gender) = 'male' THEN v_prof.pada ELSE p.pada END, 1),
                                        COALESCE(CASE WHEN LOWER(v_prof.gender) = 'male' THEN p.pada ELSE v_prof.pada END, 1)
                                    ),
            'age',                  EXTRACT(YEAR FROM age(p.date_of_birth))::int,
            'city',                 p.city,
            'state',                p.state,
            'profile_photo_url',    p.profile_photo_url,
            'gender',               p.gender,
            'caste_id',             p.caste_id,
            'nakshatra_id',         p.nakshatra_id,
            'rashi_id',             p.rashi_id,
            'gothram_id',           p.gothram_id,
            'mother_tongue_id',     p.mother_tongue_id,
            'highest_education_id', p.highest_education_id,
            'occupation_id',        p.occupation_id,
            'is_verified',          COALESCE(p.is_verified, false),
            'membership_tier',      COALESCE(sub_cand.tier, 'free'),
            'is_prime',             (sub_cand.tier IS NOT NULL AND sub_cand.tier <> 'free'),
            'created_at',           p.created_at
        ) AS r
        FROM public.profiles p
        LEFT JOIN public.user_subscriptions sub_cand ON sub_cand.user_id = p.id AND sub_cand.status = 'active'
        LEFT JOIN public.match_exclusions me ON me.user_id = p_user_id AND me.excluded_id = p.id
        WHERE me.excluded_id IS NULL AND p.id <> p_user_id
          AND p.profile_completed = true
          AND (v_target IS NULL OR LOWER(TRIM(COALESCE(p.gender,''))) = v_target)
          AND p.full_name IS NOT NULL AND TRIM(p.full_name) <> '' AND p.date_of_birth IS NOT NULL
          AND (v_max_dob IS NULL OR p.date_of_birth <= v_max_dob)
          AND (v_min_dob IS NULL OR p.date_of_birth >= v_min_dob)
          AND (v_exclude_same_gotra = false OR v_gothram_id IS NULL OR p.gothram_id IS NULL OR p.gothram_id <> v_gothram_id)
        ORDER BY public.calculate_reciprocal_compatibility(p_user_id, p.id) DESC
        LIMIT v_effective_limit OFFSET v_effective_offset
    ) sub;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;
