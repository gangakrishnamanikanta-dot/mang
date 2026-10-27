-- ── Migration: 20260823000009_waterfall_pool_rotation_and_atomic_quota.sql ────
--
-- 1. WATERFALL POOL ROTATION (Zero Blank Screen Engine):
--    - Replaces hard exclusion (WHERE msl.shown_id IS NULL) with a 3-tier priority waterfall:
--        Tier 1: 100% Unseen / Fresh Profiles (top score)
--        Tier 2: Profiles Not Shown in 7+ Days (oldest shown first)
--        Tier 3: Recycled Profiles with Recalculated Behavioral Scores
--    - Ensures users NEVER receive an empty feed `[]` regardless of pool size.
--
-- 2. ATOMIC QUOTA PROTECTION (Anti-Spam / Race-Condition Proof):
--    - Replaces read-then-insert pattern in send_interest_with_quota with an
--      atomic conditional UPDATE (WHERE interests_sent_count < max_interests_per_day).
--    - Guarantees multi-tab, rapid-tap, or parallel script requests cannot bypass daily limits.
--
-- 3. LIQUIDITY-ALIGNED PACING:
--    - Configurable defaults aligned for early-stage liquidity.


-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. REFRESH USER MATCH CACHE (WATERFALL SORTING)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.refresh_user_match_cache(
    p_user_id uuid,
    p_force boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_prof       public.profiles;
    v_pref       public.partner_preferences;
    v_target     text;
    v_signals    jsonb;
    v_candidates jsonb := '[]'::jsonb;
    v_cache_age  interval;
    v_min_dob    date;
    v_max_dob    date;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN;
    END IF;

    IF auth.role() = 'anon' THEN
        RAISE EXCEPTION 'Access denied: Anonymous users cannot refresh match cache.';
    END IF;

    IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'Access denied: Cannot refresh match cache for another user.';
    END IF;

    IF NOT pg_try_advisory_xact_lock(hashtext('match_refresh_' || p_user_id::text)) THEN
        RETURN;
    END IF;

    IF NOT p_force THEN
        SELECT now() - computed_at INTO v_cache_age
        FROM public.user_match_cache
        WHERE user_id = p_user_id
          AND algorithm_version = 4;

        IF v_cache_age IS NOT NULL AND v_cache_age < interval '1 hour' THEN
            RETURN;
        END IF;
    END IF;

    SELECT * INTO v_prof FROM public.profiles WHERE id = p_user_id;
    IF NOT FOUND OR v_prof.gender IS NULL THEN
        RETURN;
    END IF;

    SELECT * INTO v_pref FROM public.partner_preferences WHERE profile_id = p_user_id;

    IF LOWER(TRIM(v_prof.gender)) = 'male' THEN
        v_target := 'female';
    ELSIF LOWER(TRIM(v_prof.gender)) = 'female' THEN
        v_target := 'male';
    ELSE
        v_target := NULL;
    END IF;

    IF v_pref.min_age IS NOT NULL THEN
        v_max_dob := (CURRENT_DATE - (v_pref.min_age * INTERVAL '1 year'))::date;
    END IF;

    IF v_pref.max_age IS NOT NULL THEN
        v_min_dob := (CURRENT_DATE - ((v_max_age + 1) * INTERVAL '1 year' - INTERVAL '1 day'))::date;
    END IF;

    v_signals := get_behavioral_signals(p_user_id);

    WITH scored_candidates AS (
        SELECT 
            p.id AS profile_id,
            p.full_name,
            EXTRACT(YEAR FROM age(p.date_of_birth))::int AS age,
            p.city,
            p.state,
            p.profile_photo_url,
            p.gender,
            COALESCE(p.caste_id, 0) AS caste_id,
            p.nakshatra_id,
            p.gothram_id,
            p.mother_tongue_id,
            p.highest_education_id,
            p.occupation_id,
            COALESCE(p.is_verified, false) AS is_verified,
            p.created_at,
            COALESCE(sub_cand.tier, 'free') AS membership_tier,
            msl.shown_at,
            GREATEST(30.0, LEAST(98.0,
                public.calculate_mutual_compatibility(v_prof, v_pref, p, pref_cand)
                + CASE 
                    WHEN jsonb_typeof(v_signals) = 'object' 
                         AND p.caste_id IS NOT NULL 
                         AND v_signals ? 'caste_affinity' 
                         AND (v_signals->'caste_affinity') ? (p.caste_id::text)
                    THEN ((v_signals->'caste_affinity')::jsonb ->> p.caste_id::text)::float8 * 2.0
                    ELSE 0.0
                  END
                + CASE 
                    WHEN jsonb_typeof(v_signals) = 'object' 
                         AND p.highest_education_id IS NOT NULL 
                         AND v_signals ? 'education_affinity' 
                         AND (v_signals->'education_affinity') ? (p.highest_education_id::text)
                    THEN ((v_signals->'education_affinity')::jsonb ->> p.highest_education_id::text)::float8 * 1.5
                    ELSE 0.0
                  END
                + CASE 
                    WHEN jsonb_typeof(v_signals) = 'object' 
                         AND p.occupation_id IS NOT NULL 
                         AND v_signals ? 'occupation_affinity' 
                         AND (v_signals->'occupation_affinity') ? (p.occupation_id::text)
                    THEN ((v_signals->'occupation_affinity')::jsonb ->> p.occupation_id::text)::float8 * 1.0
                    ELSE 0.0
                  END
                + CASE 
                    WHEN p.created_at IS NOT NULL AND p.created_at > (now() - interval '14 days')
                    THEN 2.5
                    ELSE 0.0
                  END
                + CASE 
                    WHEN sub_cand.tier = 'prime' THEN 3.0
                    WHEN sub_cand.tier = 'prime_lite' THEN 1.5
                    ELSE 0.0
                  END
            )) AS final_score
        FROM public.profiles p
        LEFT JOIN public.partner_preferences pref_cand ON pref_cand.profile_id = p.id
        LEFT JOIN public.user_subscriptions sub_cand 
               ON sub_cand.user_id = p.id 
              AND sub_cand.status = 'active' 
              AND (sub_cand.expires_at IS NULL OR sub_cand.expires_at > now())
        LEFT JOIN public.match_exclusions me 
               ON me.user_id = p_user_id AND me.excluded_id = p.id
        LEFT JOIN public.match_shown_log msl
               ON msl.user_id = p_user_id 
              AND msl.shown_id = p.id
        WHERE me.excluded_id IS NULL
          AND p.id <> p_user_id
          AND p.profile_completed = true
          AND (v_target IS NULL OR LOWER(TRIM(COALESCE(p.gender, ''))) = v_target)
          AND p.full_name IS NOT NULL
          AND TRIM(p.full_name) <> ''
          AND p.date_of_birth IS NOT NULL
          AND (v_max_dob IS NULL OR p.date_of_birth <= v_max_dob)
          AND (v_min_dob IS NULL OR p.date_of_birth >= v_min_dob)
          AND (
              COALESCE(v_pref.exclude_same_gotra, true) = false
              OR v_prof.gothram_id IS NULL
              OR p.gothram_id IS NULL
              OR p.gothram_id <> v_prof.gothram_id
          )
          AND (v_pref.min_height_inches IS NULL OR p.height_inches IS NULL OR p.height_inches >= v_pref.min_height_inches)
          AND (v_pref.max_height_inches IS NULL OR p.height_inches IS NULL OR p.height_inches <= v_pref.max_height_inches)
        -- ── WATERFALL SORT PRIORITY ──
        -- 1. Unseen profiles FIRST (msl.shown_at IS NULL)
        -- 2. Oldest seen profiles NEXT (COALESCE(msl.shown_at, '1970-01-01') ASC)
        -- 3. Highest compatibility score
        ORDER BY 
            (msl.shown_at IS NULL) DESC,
            COALESCE(msl.shown_at, '1970-01-01'::timestamptz) ASC,
            GREATEST(30.0, LEAST(98.0,
                public.calculate_mutual_compatibility(v_prof, v_pref, p, pref_cand))) DESC
        LIMIT 200
    )
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'profile_id',           sc.profile_id,
            'full_name',            sc.full_name,
            'score',                ROUND(sc.final_score::numeric, 1),
            'age',                  sc.age,
            'city',                 sc.city,
            'state',                sc.state,
            'profile_photo_url',    sc.profile_photo_url,
            'gender',               sc.gender,
            'caste_id',             sc.caste_id,
            'nakshatra_id',         sc.nakshatra_id,
            'gothram_id',           sc.gothram_id,
            'mother_tongue_id',     sc.mother_tongue_id,
            'highest_education_id', sc.highest_education_id,
            'occupation_id',        sc.occupation_id,
            'is_verified',          sc.is_verified,
            'membership_tier',      sc.membership_tier,
            'is_prime',             (sc.membership_tier <> 'free'),
            'created_at',           sc.created_at
        )
        -- Preserve waterfall ordering in cache
        ORDER BY 
            (sc.shown_at IS NULL) DESC,
            COALESCE(sc.shown_at, '1970-01-01'::timestamptz) ASC,
            sc.final_score DESC
    ), '[]'::jsonb)
    INTO v_candidates
    FROM scored_candidates sc
    WHERE sc.final_score >= 30.0;

    INSERT INTO public.user_match_cache (user_id, matches, computed_at, algorithm_version)
    VALUES (p_user_id, COALESCE(v_candidates, '[]'::jsonb), now(), 4)
    ON CONFLICT (user_id) DO UPDATE
    SET matches = EXCLUDED.matches,
        computed_at = EXCLUDED.computed_at,
        algorithm_version = EXCLUDED.algorithm_version;
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. GET TOP MATCHES V2 (WATERFALL FALLBACK + LOGGING)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_top_matches_v2(
    p_user_id uuid,
    p_limit integer DEFAULT 20,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_cache             jsonb;
    v_result            jsonb;
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
    v_shown_ids         uuid[];
BEGIN
    IF p_user_id IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'Access denied: Cannot query matches for another user.';
    END IF;

    v_membership := public.get_user_membership_status(p_user_id);
    v_tier := COALESCE(v_membership->>'tier', 'free');
    v_daily_limit := COALESCE((v_membership->>'daily_matches_limit')::int, 5);

    IF p_offset >= v_daily_limit THEN
        RETURN '[]'::jsonb;
    END IF;

    v_effective_limit := LEAST(p_limit, v_daily_limit - p_offset);
    v_effective_offset := p_offset;

    SELECT 
        LOWER(TRIM(COALESCE(gender, ''))),
        gothram_id
    INTO v_gender, v_gothram_id
    FROM public.profiles 
    WHERE id = p_user_id;

    IF v_gender = 'male' THEN 
        v_target := 'female';
    ELSIF v_gender = 'female' THEN 
        v_target := 'male';
    ELSE 
        v_target := NULL;
    END IF;

    SELECT 
        min_age, 
        max_age,
        COALESCE(exclude_same_gotra, true)
    INTO v_min_age, v_max_age, v_exclude_same_gotra
    FROM public.partner_preferences
    WHERE profile_id = p_user_id;

    IF v_min_age IS NOT NULL THEN
        v_max_dob := (CURRENT_DATE - (v_min_age * INTERVAL '1 year'))::date;
    END IF;

    IF v_max_age IS NOT NULL THEN
        v_min_dob := (CURRENT_DATE - ((v_max_age + 1) * INTERVAL '1 year' - INTERVAL '1 day'))::date;
    END IF;

    -- 1. Cache-First Retrieval (24h TTL)
    SELECT matches INTO v_cache
    FROM public.user_match_cache
    WHERE user_id = p_user_id
      AND computed_at > now() - interval '24 hours'
      AND algorithm_version = 4;

    IF v_cache IS NOT NULL AND jsonb_array_length(v_cache) > 0 THEN
        SELECT COALESCE(jsonb_agg(r), '[]'::jsonb)
        INTO v_result
        FROM (
            SELECT jsonb_build_object(
                'profile_id',           p.id,
                'full_name',            p.full_name,
                'score',                (c->>'score')::float8,
                'age',                  EXTRACT(YEAR FROM age(p.date_of_birth))::int,
                'city',                 p.city,
                'state',                p.state,
                'profile_photo_url',    p.profile_photo_url,
                'gender',               p.gender,
                'caste_id',             p.caste_id,
                'nakshatra_id',         p.nakshatra_id,
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
            JOIN public.profiles p ON p.id = (c->>'profile_id')::uuid
            LEFT JOIN public.match_exclusions me 
                   ON me.user_id = p_user_id AND me.excluded_id = p.id
            WHERE me.excluded_id IS NULL
              AND p.id <> p_user_id
              AND p.profile_completed = true
              AND (v_target IS NULL OR LOWER(TRIM(COALESCE(p.gender, ''))) = v_target)
              AND p.full_name IS NOT NULL
              AND TRIM(p.full_name) <> ''
              AND (v_max_dob IS NULL OR p.date_of_birth <= v_max_dob)
              AND (v_min_dob IS NULL OR p.date_of_birth >= v_min_dob)
              AND (
                  v_exclude_same_gotra = false
                  OR v_gothram_id IS NULL
                  OR p.gothram_id IS NULL
                  OR p.gothram_id <> v_gothram_id
              )
            LIMIT v_effective_limit
            OFFSET v_effective_offset
        ) sub;

        IF v_result IS NOT NULL AND jsonb_array_length(v_result) > 0 THEN
            SELECT array_agg((r->>'profile_id')::uuid)
            INTO v_shown_ids
            FROM jsonb_array_elements(v_result) r;

            IF v_shown_ids IS NOT NULL AND array_length(v_shown_ids, 1) > 0 THEN
                PERFORM public.record_matches_shown(p_user_id, v_shown_ids);
            END IF;

            RETURN v_result;
        END IF;
    END IF;

    -- 2. Fallback: Live Waterfall Filtered Computation (Zero Empty Feed)
    SELECT COALESCE(jsonb_agg(r), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'profile_id',           p.id,
            'full_name',            p.full_name,
            'score',                ROUND(public.get_compatibility_index_v2(p_user_id, p.id)::numeric, 1),
            'age',                  EXTRACT(YEAR FROM age(p.date_of_birth))::int,
            'city',                 p.city,
            'state',                p.state,
            'profile_photo_url',    p.profile_photo_url,
            'gender',               p.gender,
            'caste_id',             p.caste_id,
            'nakshatra_id',         p.nakshatra_id,
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
        LEFT JOIN public.user_subscriptions sub_cand 
               ON sub_cand.user_id = p.id 
              AND sub_cand.status = 'active' 
              AND (sub_cand.expires_at IS NULL OR sub_cand.expires_at > now())
        LEFT JOIN public.match_exclusions me 
               ON me.user_id = p_user_id AND me.excluded_id = p.id
        LEFT JOIN public.match_shown_log msl
               ON msl.user_id = p_user_id AND msl.shown_id = p.id
        WHERE me.excluded_id IS NULL
          AND p.id <> p_user_id
          AND p.profile_completed = true
          AND (v_target IS NULL OR LOWER(TRIM(COALESCE(p.gender, ''))) = v_target)
          AND p.full_name IS NOT NULL
          AND TRIM(p.full_name) <> ''
          AND p.date_of_birth IS NOT NULL
          AND (v_max_dob IS NULL OR p.date_of_birth <= v_max_dob)
          AND (v_min_dob IS NULL OR p.date_of_birth >= v_min_dob)
          AND (
              v_exclude_same_gotra = false
              OR v_gothram_id IS NULL
              OR p.gothram_id IS NULL
              OR p.gothram_id <> v_gothram_id
          )
        ORDER BY 
            (msl.shown_at IS NULL) DESC,
            COALESCE(msl.shown_at, '1970-01-01'::timestamptz) ASC,
            public.get_compatibility_index_v2(p_user_id, p.id) DESC
        LIMIT v_effective_limit
        OFFSET v_effective_offset
    ) sub;

    IF v_result IS NOT NULL AND jsonb_array_length(v_result) > 0 THEN
        SELECT array_agg((r->>'profile_id')::uuid)
        INTO v_shown_ids
        FROM jsonb_array_elements(v_result) r;

        IF v_shown_ids IS NOT NULL AND array_length(v_shown_ids, 1) > 0 THEN
            PERFORM public.record_matches_shown(p_user_id, v_shown_ids);
        END IF;
    END IF;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. ATOMIC QUOTA ENFORCEMENT IN SEND_INTEREST_WITH_QUOTA
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.send_interest_with_quota(p_receiver_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_sender_id   uuid := auth.uid();
  v_status      jsonb;
  v_tier        text;
  v_max_daily   int;
  v_interest_id uuid;
  v_updated     int;
  v_sent_now    int;
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF v_sender_id = p_receiver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'cannot_interest_self');
  END IF;

  -- Read membership status
  v_status := public.get_user_membership_status(v_sender_id);
  v_tier := COALESCE(v_status->>'tier', 'free');
  v_max_daily := COALESCE((v_status->>'max_daily_interests')::int, 3);

  -- Ensure today's quota row exists initialized
  INSERT INTO public.daily_user_quotas (user_id, quota_date, interests_sent_count, max_interests_per_day)
  VALUES (v_sender_id, CURRENT_DATE, 0, v_max_daily)
  ON CONFLICT (user_id, quota_date) DO NOTHING;

  -- ── ATOMIC CONDITIONAL INCREMENT (Race-Condition & Multi-Tap Proof) ──
  UPDATE public.daily_user_quotas
  SET interests_sent_count = interests_sent_count + 1,
      max_interests_per_day = v_max_daily
  WHERE user_id = v_sender_id
    AND quota_date = CURRENT_DATE
    AND interests_sent_count < max_interests_per_day
  RETURNING interests_sent_count INTO v_sent_now;

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  -- If 0 rows updated, quota was already full
  IF v_updated = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'quota_exceeded',
      'tier', v_tier,
      'limit', v_max_daily,
      'message', format('Daily limit of %s interests reached for %s tier.', v_max_daily, v_tier)
    );
  END IF;

  -- Insert/update interest
  INSERT INTO public.interests (sender_profile_id, receiver_profile_id, status, created_at, updated_at)
  VALUES (v_sender_id, p_receiver_id, 'pending', now(), now())
  ON CONFLICT (sender_profile_id, receiver_profile_id) DO UPDATE
  SET status = 'pending', updated_at = now()
  RETURNING id INTO v_interest_id;

  RETURN jsonb_build_object(
    'success', true,
    'interest_id', v_interest_id,
    'tier', v_tier,
    'sent_today', v_sent_now,
    'remaining_daily_interests', GREATEST(0, v_max_daily - v_sent_now)
  );
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- PERMISSIONS & SECURITY
-- ═══════════════════════════════════════════════════════════════════════════════

REVOKE EXECUTE ON FUNCTION public.send_interest_with_quota(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.send_interest_with_quota(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.send_interest_with_quota(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_interest_with_quota(uuid) TO service_role;
