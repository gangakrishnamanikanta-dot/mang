-- ── Migration: 20260823000007_tier_quotas_and_monetization_engine.sql ──────────
--
-- Real-World Matrimony Commercial Pacing & Monetization Engine:
-- 1. Daily Match Recommendations: Free (5/day), Prime Lite (12/day), Prime VIP (25/day)
-- 2. Daily Interest Quotas: Free (3/day), Prime Lite (15/day), Prime VIP (30/day)
-- 3. Contact Unlocks: Free (0), Prime Lite (20), Prime VIP (50)
-- 4. "Who Viewed You" Paywall: Blurs photos & masks names for Free members, full reveal for Prime
-- 5. Discovery Search Limits: Free (10 results), Prime Lite (50 results), Prime VIP (Unlimited)

-- ── 1. UPDATE MEMBERSHIP STATUS RPC ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_user_membership_status(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_sub record;
  v_quota record;
  v_tier text := 'free';
  v_max_daily int := 3;
  v_sent_today int := 0;
  v_contacts_used int := 0;
  v_contacts_limit int := 0;
  v_daily_matches_limit int := 5;
  v_discovery_limit int := 10;
BEGIN
  SELECT * INTO v_sub FROM public.user_subscriptions WHERE user_id = p_user_id;
  IF FOUND THEN
    IF v_sub.expires_at IS NULL OR v_sub.expires_at > now() THEN
      v_tier := v_sub.tier;
      v_contacts_used := v_sub.contacts_unlocked_count;
      v_contacts_limit := v_sub.contacts_unlocked_limit;
    ELSE
      v_tier := 'free';
    END IF;
  END IF;

  IF v_tier = 'prime' THEN
    v_max_daily := 30;
    IF v_contacts_limit = 0 THEN v_contacts_limit := 50; END IF;
    v_daily_matches_limit := 25;
    v_discovery_limit := 500;
  ELSIF v_tier = 'prime_lite' THEN
    v_max_daily := 15;
    IF v_contacts_limit = 0 THEN v_contacts_limit := 20; END IF;
    v_daily_matches_limit := 12;
    v_discovery_limit := 50;
  ELSE
    v_tier := 'free';
    v_max_daily := 3;
    v_contacts_limit := 0;
    v_daily_matches_limit := 5;
    v_discovery_limit := 10;
  END IF;

  SELECT * INTO v_quota FROM public.daily_user_quotas 
  WHERE user_id = p_user_id AND quota_date = CURRENT_DATE;

  IF FOUND THEN
    v_sent_today := v_quota.interests_sent_count;
  ELSE
    INSERT INTO public.daily_user_quotas (user_id, quota_date, interests_sent_count, max_interests_per_day)
    VALUES (p_user_id, CURRENT_DATE, 0, v_max_daily)
    ON CONFLICT (user_id, quota_date) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'tier', v_tier,
    'interests_sent_today', v_sent_today,
    'max_daily_interests', v_max_daily,
    'remaining_daily_interests', GREATEST(0, v_max_daily - v_sent_today),
    'contacts_unlocked_count', v_contacts_used,
    'contacts_unlocked_limit', v_contacts_limit,
    'remaining_contacts', GREATEST(0, v_contacts_limit - v_contacts_used),
    'daily_matches_limit', v_daily_matches_limit,
    'discovery_limit', v_discovery_limit,
    'expires_at', v_sub.expires_at
  );
END;
$$;

-- ── 2. UPDATE SET USER SUBSCRIPTION RPC ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_user_subscription(
  p_user_id uuid,
  p_tier text,
  p_duration_days integer DEFAULT 90
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_limit int := 0;
BEGIN
  IF p_tier = 'prime' THEN
    v_limit := 50;
  ELSIF p_tier = 'prime_lite' THEN
    v_limit := 20;
  ELSE
    p_tier := 'free';
    v_limit := 0;
  END IF;

  INSERT INTO public.user_subscriptions (
    user_id, tier, status, start_at, expires_at, contacts_unlocked_count, contacts_unlocked_limit, updated_at
  )
  VALUES (
    p_user_id,
    p_tier,
    'active',
    now(),
    CASE WHEN p_tier = 'free' THEN NULL ELSE now() + (p_duration_days || ' days')::interval END,
    0,
    v_limit,
    now()
  )
  ON CONFLICT (user_id) DO UPDATE
  SET tier = EXCLUDED.tier,
      status = 'active',
      start_at = now(),
      expires_at = EXCLUDED.expires_at,
      contacts_unlocked_count = 0,
      contacts_unlocked_limit = EXCLUDED.contacts_unlocked_limit,
      updated_at = now();

  PERFORM public.refresh_user_match_cache(p_user_id, true);

  RETURN public.get_user_membership_status(p_user_id);
END;
$$;

-- ── 3. STRICT MATCH PACING IN GET_TOP_MATCHES_V2 ─────────────────────────────
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
BEGIN
    IF p_user_id IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'Access denied: Cannot query matches for another user.';
    END IF;

    -- TIER-BASED MATCH PACING: Free (5), Prime Lite (12), Prime VIP (25)
    v_membership := public.get_user_membership_status(p_user_id);
    v_tier := COALESCE(v_membership->>'tier', 'free');
    v_daily_limit := (v_membership->>'daily_matches_limit')::int;

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
        SELECT COALESCE(jsonb_agg(r ORDER BY (r->>'score')::float8 DESC), '[]'::jsonb)
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
            ORDER BY (c->>'score')::float8 DESC
            LIMIT v_effective_limit
            OFFSET v_effective_offset
        ) sub;

        IF v_result IS NOT NULL AND jsonb_array_length(v_result) > 0 THEN
            RETURN v_result;
        END IF;
    END IF;

    -- 2. Fallback: Live Filtered Computation
    SELECT COALESCE(jsonb_agg(r ORDER BY (r->>'score')::float8 DESC), '[]'::jsonb)
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
        ORDER BY public.get_compatibility_index_v2(p_user_id, p.id) DESC
        LIMIT v_effective_limit
        OFFSET v_effective_offset
    ) sub;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ── 4. "WHO VIEWED YOU" PAYWALL (BLURS FREE TIER) ────────────────────────────
CREATE OR REPLACE FUNCTION public.get_visited_profiles_with_score(
  p_viewer_id uuid,
  p_limit integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_result jsonb;
  v_membership jsonb;
  v_tier text := 'free';
  v_is_paid boolean := false;
BEGIN
  v_membership := public.get_user_membership_status(p_viewer_id);
  v_tier := COALESCE(v_membership->>'tier', 'free');
  v_is_paid := (v_tier IN ('prime', 'prime_lite'));

  SELECT COALESCE(jsonb_agg(r ORDER BY r.viewed_at DESC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT 
      p.id,
      CASE 
        WHEN v_is_paid THEN p.full_name 
        ELSE (SPLIT_PART(p.full_name, ' ', 1) || ' ' || SUBSTRING(SPLIT_PART(p.full_name, ' ', 2), 1, 1) || '.')
      END AS full_name,
      p.gender,
      p.date_of_birth,
      p.city,
      p.state,
      CASE 
        WHEN v_is_paid THEN p.profile_photo_url 
        ELSE NULL 
      END AS profile_photo_url,
      NOT v_is_paid AS is_blurred,
      p.occupation_id,
      p.highest_education_id,
      p.caste_id,
      p.gothram_id,
      p.is_verified,
      p.created_at,
      p.updated_at,
      v.viewed_at,
      v.dwell_seconds,
      EXTRACT(year FROM age(p.date_of_birth))::int AS age,
      COALESCE(
        (
          SELECT (m->>'score')::float8
          FROM public.user_match_cache c,
               jsonb_array_elements(c.matches) m
          WHERE c.user_id = p_viewer_id
            AND m->>'profile_id' = p.id::text
          LIMIT 1
        ),
        public.get_compatibility_index_v2(p_viewer_id, p.id)
      ) AS match_score
    FROM public.profile_views v
    JOIN public.profiles p ON p.id = v.viewed_id
    WHERE v.viewer_id = p_viewer_id
      AND p.full_name IS NOT NULL
      AND TRIM(p.full_name) <> ''
    ORDER BY v.viewed_at DESC
    LIMIT p_limit
  ) r;

  RETURN v_result;
END;
$$;

-- ── 5. DISCOVERY TIER-GATED SEARCH RPC ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.search_discovery_profiles(
    p_user_id uuid,
    p_caste_id integer DEFAULT NULL,
    p_min_age integer DEFAULT NULL,
    p_max_age integer DEFAULT NULL,
    p_city text DEFAULT NULL,
    p_limit integer DEFAULT 20,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_result            jsonb;
    v_gender            text;
    v_target            text;
    v_membership        jsonb;
    v_tier              text := 'free';
    v_disc_limit        int := 10;
    v_effective_limit   int;
    v_effective_offset  int;
    v_min_dob           date;
    v_max_dob           date;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    v_membership := public.get_user_membership_status(p_user_id);
    v_tier := COALESCE(v_membership->>'tier', 'free');
    v_disc_limit := (v_membership->>'discovery_limit')::int;

    IF p_offset >= v_disc_limit THEN
        RETURN '[]'::jsonb;
    END IF;

    v_effective_limit := LEAST(p_limit, v_disc_limit - p_offset);
    v_effective_offset := p_offset;

    SELECT LOWER(TRIM(COALESCE(gender, ''))) INTO v_gender
    FROM public.profiles 
    WHERE id = p_user_id;

    IF v_gender = 'male' THEN v_target := 'female';
    ELSIF v_gender = 'female' THEN v_target := 'male';
    ELSE v_target := NULL;
    END IF;

    IF p_min_age IS NOT NULL THEN
        v_max_dob := (CURRENT_DATE - (p_min_age * INTERVAL '1 year'))::date;
    END IF;

    IF p_max_age IS NOT NULL THEN
        v_min_dob := (CURRENT_DATE - ((p_max_age + 1) * INTERVAL '1 year' - INTERVAL '1 day'))::date;
    END IF;

    SELECT COALESCE(jsonb_agg(r ORDER BY r.match_score DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT 
            p.id,
            p.full_name,
            p.gender,
            p.date_of_birth,
            p.city,
            p.state,
            p.profile_photo_url,
            p.occupation_id,
            p.highest_education_id,
            p.caste_id,
            p.gothram_id,
            p.mother_tongue_id,
            COALESCE(p.is_verified, false) AS is_verified,
            p.created_at,
            EXTRACT(year FROM age(p.date_of_birth))::int AS age,
            COALESCE(
                (
                    SELECT (m->>'score')::float8
                    FROM public.user_match_cache c,
                         jsonb_array_elements(c.matches) m
                    WHERE c.user_id = p_user_id
                      AND m->>'profile_id' = p.id::text
                    LIMIT 1
                ),
                ROUND(public.get_compatibility_index_v2(p_user_id, p.id)::numeric, 1)
            ) AS match_score
        FROM public.profiles p
        LEFT JOIN public.match_exclusions me 
               ON me.user_id = p_user_id AND me.excluded_id = p.id
        WHERE me.excluded_id IS NULL
          AND p.id <> p_user_id
          AND p.profile_completed = true
          AND (v_target IS NULL OR LOWER(TRIM(COALESCE(p.gender, ''))) = v_target)
          AND p.full_name IS NOT NULL
          AND TRIM(p.full_name) <> ''
          AND (p_caste_id IS NULL OR p.caste_id = p_caste_id)
          AND (v_max_dob IS NULL OR p.date_of_birth <= v_max_dob)
          AND (v_min_dob IS NULL OR p.date_of_birth >= v_min_dob)
          AND (p_city IS NULL OR LOWER(p.city) LIKE ('%' || LOWER(p_city) || '%'))
        ORDER BY match_score DESC
        LIMIT v_effective_limit
        OFFSET v_effective_offset
    ) r;

    RETURN v_result;
END;
$$;

-- Permissions
GRANT EXECUTE ON FUNCTION public.get_user_membership_status(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_user_subscription(uuid, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_top_matches_v2(uuid, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_visited_profiles_with_score(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_discovery_profiles(uuid, integer, integer, integer, text, integer, integer) TO authenticated;
