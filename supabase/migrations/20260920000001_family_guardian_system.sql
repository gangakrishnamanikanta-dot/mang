-- =====================================================================
-- Phase 1: Family Room & Guardian System Backend 
-- Adds account_type and updates matching engines to exclude guardians
-- =====================================================================

-- 1. Add account_type to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS account_type text DEFAULT 'candidate';

-- 2. Update Public Profiles View to exclude guardians from being selected via the view
DROP VIEW IF EXISTS public.public_profiles;
CREATE VIEW public.public_profiles
WITH (security_invoker = true) AS
SELECT
  p.id,
  p.full_name,
  p.gender,
  p.date_of_birth,
  p.height_inches,
  p.marital_status_id,
  p.mother_tongue_id,
  p.caste_id,
  p.nakshatra_id,
  p.highest_education_id,
  p.college,
  p.occupation_id,
  p.company,
  p.annual_income_id,
  p.food_preference_id,
  p.kuja_dosham,
  p.profile_photo_url,
  p.profile_completed,
  p.is_verified,
  p.city,
  p.state,
  p.created_at,
  EXTRACT(YEAR FROM age(p.date_of_birth))::int AS age,
  COALESCE(p.account_type, 'candidate') AS account_type
FROM public.profiles p
WHERE p.profile_completed = true 
  AND COALESCE(p.account_type, 'candidate') = 'candidate';

REVOKE ALL PRIVILEGES ON public.public_profiles FROM anon;
REVOKE ALL PRIVILEGES ON public.public_profiles FROM authenticated;
GRANT SELECT ON public.public_profiles TO authenticated;

-- 3. Get Guardian's Active Candidate Context RPC
CREATE OR REPLACE FUNCTION public.get_guardian_active_candidate(p_guardian_id uuid)
RETURNS TABLE (
    candidate_id uuid,
    gender text,
    gothram_id int,
    nakshatra_id int,
    rashi_id int
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path TO 'public'
AS $$
    SELECT 
        p.id AS candidate_id,
        p.gender,
        p.gothram_id,
        p.nakshatra_id,
        p.rashi_id
    FROM public.family_members fm
    JOIN public.family_circles fc ON fc.id = fm.family_circle_id
    JOIN public.profiles p ON p.id = fc.candidate_id
    WHERE fm.user_id = p_guardian_id
    LIMIT 1;
$$;
GRANT EXECUTE ON FUNCTION public.get_guardian_active_candidate(uuid) TO authenticated;

-- 4. Update Matching Engines to exclude guardians
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
          AND me.id IS NULL
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
          AND me.id IS NULL
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

    -- Upsert user match cache
    INSERT INTO public.user_match_cache (user_id, matches, updated_at)
    VALUES (p_user_id, v_matches || v_fresh_matches, now())
    ON CONFLICT (user_id) 
    DO UPDATE SET 
        matches = EXCLUDED.matches,
        updated_at = now();

    RETURN jsonb_build_object(
        'status', 'refreshed',
        'count', jsonb_array_length(v_matches || v_fresh_matches)
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.search_discovery_profiles(
  p_user_id uuid,
  p_query text DEFAULT NULL,
  p_sub_caste text DEFAULT NULL,
  p_min_age int DEFAULT 18,
  p_max_age int DEFAULT 60,
  p_city text DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  full_name text,
  gender text,
  age int,
  city text,
  state text,
  sub_caste text,
  profile_photo_url text,
  is_verified boolean,
  highest_education text,
  occupation text,
  match_score int,
  caste_id int,
  gothram_id int,
  mother_tongue_id int,
  highest_education_id int,
  occupation_id int,
  date_of_birth text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_viewer_gender text;
  v_opposite_gender text;
  v_sub record;
  v_tier text := 'free';
  v_discovery_limit int := 10;
BEGIN
  -- Get viewer gender
  SELECT p.gender INTO v_viewer_gender
  FROM public.profiles p
  WHERE p.id = p_user_id;

  v_opposite_gender := CASE
    WHEN v_viewer_gender = 'male' THEN 'female'
    WHEN v_viewer_gender = 'female' THEN 'male'
    ELSE NULL
  END;

  -- Get subscription tier
  SELECT * INTO v_sub FROM public.user_subscriptions
  WHERE user_id = p_user_id AND status = 'active' AND (expires_at IS NULL OR expires_at > now())
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    v_tier := v_sub.tier;
  END IF;

  IF v_tier = 'prime' THEN
    v_discovery_limit := 500;
  ELSIF v_tier = 'prime_lite' THEN
    v_discovery_limit := 50;
  ELSE
    v_discovery_limit := 10;
  END IF;

  -- Enforce Free tier Discovery ceiling: Max 10 profiles visible
  IF v_tier = 'free' AND p_offset >= 10 THEN
    RETURN;
  END IF;

  IF v_tier = 'free' THEN
    p_limit := LEAST(p_limit, 10 - p_offset);
  ELSE
    p_limit := LEAST(p_limit, v_discovery_limit);
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.full_name,
    p.gender,
    DATE_PART('year', AGE(p.date_of_birth::date))::int AS age,
    p.city,
    p.state,
    p.sub_caste,
    p.profile_photo_url,
    p.is_verified,
    COALESCE(el.level, 'Graduate') AS highest_education,
    COALESCE(oc.occupation, 'Professional') AS occupation,
    CASE
      WHEN p.is_verified THEN 90
      ELSE 75
    END AS match_score,
    p.caste_id,
    p.gothram_id,
    p.mother_tongue_id,
    p.highest_education_id,
    p.occupation_id,
    p.date_of_birth::text,
    p.created_at
  FROM public.profiles p
  LEFT JOIN public.education_levels el ON el.id = p.highest_education_id
  LEFT JOIN public.occupations oc ON oc.id = p.occupation_id
  WHERE
    p.id != p_user_id
    AND p.profile_completed = true
    AND COALESCE(p.account_type, 'candidate') = 'candidate'
    AND p.full_name IS NOT NULL
    AND p.gender IS NOT NULL
    AND p.date_of_birth IS NOT NULL
    AND (v_opposite_gender IS NULL OR p.gender = v_opposite_gender)
    -- Search text filter
    AND (
      p_query IS NULL
      OR p.full_name ILIKE '%' || p_query || '%'
      OR p.city ILIKE '%' || p_query || '%'
      OR p.sub_caste ILIKE '%' || p_query || '%'
      OR COALESCE(oc.occupation, '') ILIKE '%' || p_query || '%'
    )
    -- Subcaste filter
    AND (p_sub_caste IS NULL OR p_sub_caste = 'All' OR p.sub_caste ILIKE '%' || p_sub_caste || '%')
    -- Age range filter
    AND (
      p_min_age IS NULL
      OR DATE_PART('year', AGE(p.date_of_birth::date))::int >= p_min_age
    )
    AND (
      p_max_age IS NULL
      OR DATE_PART('year', AGE(p.date_of_birth::date))::int <= p_max_age
    )
    -- City filter
    AND (
      p_city IS NULL
      OR p_city = ''
      OR p.city ILIKE '%' || p_city || '%'
      OR p.state ILIKE '%' || p_city || '%'
    )
    -- Exclude blocked profiles
    AND NOT EXISTS (
      SELECT 1 FROM public.user_blocks b 
      WHERE (b.blocker_id = p_user_id AND b.blocked_id = p.id)
         OR (b.blocker_id = p.id AND b.blocked_id = p_user_id)
    )
  ORDER BY p.is_verified DESC, p.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;
