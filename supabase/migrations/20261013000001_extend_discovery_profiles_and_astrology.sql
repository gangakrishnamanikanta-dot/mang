-- Migration: 20261013000001_extend_discovery_profiles_and_astrology.sql
-- Description: Provide rich astrology & profile fields (nakshatra_id, rashi_id, pada_id, height_inches, about_me, marital_status_id, annual_income_id) in discovery search.

CREATE OR REPLACE FUNCTION public.search_discovery_profiles_v2(
  p_user_id uuid,
  p_query text DEFAULT NULL::text,
  p_sub_caste text DEFAULT NULL::text,
  p_min_age integer DEFAULT 18,
  p_max_age integer DEFAULT 60,
  p_city text DEFAULT NULL::text,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  id uuid,
  full_name text,
  gender text,
  age integer,
  city text,
  state text,
  sub_caste text,
  profile_photo_url text,
  is_verified boolean,
  highest_education text,
  occupation text,
  match_score integer,
  caste_id integer,
  gothram_id integer,
  mother_tongue_id integer,
  highest_education_id integer,
  occupation_id integer,
  date_of_birth text,
  created_at timestamp with time zone,
  nakshatra_id integer,
  rashi_id integer,
  pada_id integer,
  height_inches integer,
  about_me text,
  marital_status_id integer,
  annual_income_id integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_effective_uid uuid;
  v_viewer_gender text;
  v_opposite_gender text;
  v_sub record;
  v_tier text := 'free';
  v_discovery_limit int := 10;
BEGIN
  v_effective_uid := COALESCE(public.get_guardian_candidate_id(p_user_id), p_user_id);

  SELECT LOWER(TRIM(COALESCE(p.gender, ''))) INTO v_viewer_gender
  FROM public.profiles p
  WHERE p.id = v_effective_uid;

  v_opposite_gender := CASE
    WHEN v_viewer_gender = 'male' THEN 'female'
    WHEN v_viewer_gender = 'female' THEN 'male'
    ELSE NULL
  END;

  SELECT * INTO v_sub FROM public.user_subscriptions
  WHERE user_id = v_effective_uid AND status = 'active' AND (expires_at IS NULL OR expires_at > now())
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
    COALESCE(p.is_verified, false) AS is_verified,
    COALESCE(el.level, 'Graduate') AS highest_education,
    COALESCE(oc.occupation, 'Professional') AS occupation,
    ROUND(public.calculate_reciprocal_compatibility(v_effective_uid, p.id)::numeric)::int AS match_score,
    p.caste_id,
    p.gothram_id,
    p.mother_tongue_id,
    p.highest_education_id,
    p.occupation_id,
    p.date_of_birth::text,
    p.created_at,
    p.nakshatra_id,
    p.rashi_id,
    p.pada_id,
    p.height_inches,
    p.about_me,
    p.marital_status_id,
    p.annual_income_id
  FROM public.profiles p
  LEFT JOIN public.education_levels el ON el.id = p.highest_education_id
  LEFT JOIN public.occupations oc ON oc.id = p.occupation_id
  WHERE
    p.id <> v_effective_uid
    AND p.profile_completed = true
    AND COALESCE(p.is_hidden, false) = false
    AND COALESCE(p.account_type, 'candidate') = 'candidate'
    AND p.full_name IS NOT NULL
    AND p.gender IS NOT NULL
    AND p.date_of_birth IS NOT NULL
    AND (v_opposite_gender IS NULL OR LOWER(TRIM(p.gender)) = v_opposite_gender)
    AND (
      p_query IS NULL
      OR p.full_name ILIKE '%' || p_query || '%'
      OR p.city ILIKE '%' || p_query || '%'
      OR p.sub_caste ILIKE '%' || p_query || '%'
      OR COALESCE(oc.occupation, '') ILIKE '%' || p_query || '%'
    )
    AND (p_sub_caste IS NULL OR p_sub_caste = 'All' OR p.sub_caste ILIKE '%' || p_sub_caste || '%')
    AND (
      p_min_age IS NULL
      OR DATE_PART('year', AGE(p.date_of_birth::date))::int >= p_min_age
    )
    AND (
      p_max_age IS NULL
      OR DATE_PART('year', AGE(p.date_of_birth::date))::int <= p_max_age
    )
    AND (
      p_city IS NULL
      OR p_city = ''
      OR p.city ILIKE '%' || p_city || '%'
      OR p.state ILIKE '%' || p_city || '%'
    )
  ORDER BY p.is_verified DESC, p.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.search_discovery_profiles_v2(uuid, text, text, integer, integer, text, integer, integer) TO authenticated, service_role, anon;
