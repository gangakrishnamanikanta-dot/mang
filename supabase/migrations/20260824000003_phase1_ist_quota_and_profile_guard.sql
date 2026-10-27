-- ── Migration: 20260824000003_phase1_ist_quota_and_profile_guard.sql ─────────
--
-- PHASE 1 FIXES:
-- 1. IST (Asia/Kolkata) daily quota reset instead of UTC midnight
-- 2. Strict profile completion guard in search_discovery_profiles
-- 3. Fix send_interest_with_quota to use IST date for quota check
--

-- ── 1. Fix daily_user_quotas to use IST date ──────────────────────────────────
-- Add a helper function for consistent IST date
CREATE OR REPLACE FUNCTION public.ist_today()
RETURNS date
LANGUAGE sql
STABLE
AS $$
  SELECT (now() AT TIME ZONE 'Asia/Kolkata')::date;
$$;

-- ── 2. Fix get_user_membership_status to use IST quota_date ──────────────────
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
  v_today date := public.ist_today();
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

  -- ✅ Use IST today instead of UTC CURRENT_DATE
  SELECT * INTO v_quota FROM public.daily_user_quotas
  WHERE user_id = p_user_id AND quota_date = v_today;

  IF FOUND THEN
    v_sent_today := v_quota.interests_sent_count;
  ELSE
    INSERT INTO public.daily_user_quotas (user_id, quota_date, interests_sent_count, max_interests_per_day)
    VALUES (p_user_id, v_today, 0, v_max_daily)
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

-- ── 3. Fix send_interest_with_quota to use IST date ──────────────────────────
CREATE OR REPLACE FUNCTION public.send_interest_with_quota(p_receiver_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_sender_id uuid;
  v_quota record;
  v_sub record;
  v_tier text := 'free';
  v_max_daily int := 3;
  v_today date := public.ist_today();
  v_existing_interest uuid;
BEGIN
  v_sender_id := auth.uid();
  IF v_sender_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF v_sender_id = p_receiver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'self_interest',
      'message', 'You cannot send interest to yourself.');
  END IF;

  -- Check subscription tier
  SELECT * INTO v_sub FROM public.user_subscriptions
  WHERE user_id = v_sender_id AND (expires_at IS NULL OR expires_at > now());
  IF FOUND THEN
    v_tier := v_sub.tier;
  END IF;

  IF v_tier = 'prime' THEN
    v_max_daily := 30;
  ELSIF v_tier = 'prime_lite' THEN
    v_max_daily := 15;
  ELSE
    v_max_daily := 3;
  END IF;

  -- ✅ Use IST date for quota check and insert
  SELECT * INTO v_quota FROM public.daily_user_quotas
  WHERE user_id = v_sender_id AND quota_date = v_today;

  IF NOT FOUND THEN
    INSERT INTO public.daily_user_quotas (user_id, quota_date, interests_sent_count, max_interests_per_day)
    VALUES (v_sender_id, v_today, 0, v_max_daily)
    ON CONFLICT (user_id, quota_date) DO NOTHING;
    SELECT * INTO v_quota FROM public.daily_user_quotas
    WHERE user_id = v_sender_id AND quota_date = v_today;
  END IF;

  IF v_quota.interests_sent_count >= v_max_daily THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'quota_exceeded',
      'tier', v_tier,
      'limit', v_max_daily,
      'message', 'Daily interest limit reached. Upgrade to Prime for more.'
    );
  END IF;

  -- Check for duplicate interest
  SELECT id INTO v_existing_interest
  FROM public.interests
  WHERE sender_profile_id = v_sender_id AND receiver_profile_id = p_receiver_id
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'duplicate',
      'message', 'You have already sent an interest to this profile.');
  END IF;

  -- Insert the interest
  INSERT INTO public.interests (sender_profile_id, receiver_profile_id, status)
  VALUES (v_sender_id, p_receiver_id, 'pending');

  -- Increment quota counter atomically
  UPDATE public.daily_user_quotas
  SET interests_sent_count = interests_sent_count + 1
  WHERE user_id = v_sender_id AND quota_date = v_today;

  RETURN jsonb_build_object('success', true, 'message', 'Interest sent successfully.');
END;
$$;

-- ── 4. Fix search_discovery_profiles with strict profile completion guard ─────
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
  WHERE user_id = p_user_id AND (expires_at IS NULL OR expires_at > now());

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

  -- Apply user's p_limit but cap by tier
  p_limit := LEAST(p_limit, v_discovery_limit);

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
    -- ✅ STRICT profile completion guard - no half-baked profiles in discovery
    p.id != p_user_id
    AND p.full_name IS NOT NULL
    AND p.gender IS NOT NULL
    AND p.date_of_birth IS NOT NULL
    AND p.city IS NOT NULL
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
    AND (p_sub_caste IS NULL OR p.sub_caste ILIKE '%' || p_sub_caste || '%')
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
      OR p.city ILIKE '%' || p_city || '%'
      OR p.state ILIKE '%' || p_city || '%'
    )
  ORDER BY p.is_verified DESC, p.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.ist_today() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_membership_status(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_interest_with_quota(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_discovery_profiles(uuid, text, text, int, int, text, int, int) TO authenticated;
