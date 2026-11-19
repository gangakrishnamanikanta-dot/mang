-- Migration: 20261119000003_promotional_launch_tier.sql
-- Description: Provisions 60-day Promotional Prime Launch Tier (2 months free) for all existing & new users

-- 1. Grant 60-day Promotional Prime to all existing profiles without an active subscription
INSERT INTO public.user_subscriptions (
  user_id,
  tier,
  status,
  start_at,
  expires_at,
  contacts_unlocked_count,
  contacts_unlocked_limit,
  created_at,
  updated_at
)
SELECT 
  p.id AS user_id,
  'prime' AS tier,
  'active' AS status,
  now() AS start_at,
  now() + interval '60 days' AS expires_at,
  0 AS contacts_unlocked_count,
  50 AS contacts_unlocked_limit,
  now() AS created_at,
  now() AS updated_at
FROM public.profiles p
LEFT JOIN public.user_subscriptions us 
  ON us.user_id = p.id AND us.status = 'active' AND (us.expires_at IS NULL OR us.expires_at > now())
WHERE us.user_id IS NULL
ON CONFLICT (user_id) DO UPDATE SET
  tier = 'prime',
  status = 'active',
  start_at = now(),
  expires_at = now() + interval '60 days',
  contacts_unlocked_limit = GREATEST(public.user_subscriptions.contacts_unlocked_limit, 50),
  updated_at = now();

-- 2. Trigger function to automatically provision 60-day Promotional Prime on new profile creation
CREATE OR REPLACE FUNCTION public.handle_new_profile_launch_subscription()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.user_subscriptions (
    user_id,
    tier,
    status,
    start_at,
    expires_at,
    contacts_unlocked_count,
    contacts_unlocked_limit,
    created_at,
    updated_at
  ) VALUES (
    NEW.id,
    'prime',
    'active',
    now(),
    now() + interval '60 days',
    0,
    50,
    now(),
    now()
  )
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_new_profile_launch_subscription ON public.profiles;

CREATE TRIGGER trg_new_profile_launch_subscription
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_profile_launch_subscription();

-- 3. Update get_user_membership_status to auto-provision if missing
CREATE OR REPLACE FUNCTION public.get_user_membership_status(p_user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_target_id uuid := COALESCE(p_user_id, v_caller_id);
  v_is_admin boolean := false;
  v_is_authorized_guardian boolean := false;
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
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF public.is_user_suspended(v_caller_id) THEN
    RAISE EXCEPTION 'Access denied: account suspended';
  END IF;

  -- Verify authorization for cross-user requests
  IF v_target_id <> v_caller_id THEN
    SELECT COALESCE(is_admin, false) INTO v_is_admin FROM public.profiles WHERE id = v_caller_id;

    SELECT EXISTS (
      SELECT 1 FROM public.family_members fm
      JOIN public.family_circles fc ON fc.id = fm.family_circle_id
      WHERE fm.user_id = v_caller_id
        AND fm.role <> 'Candidate'
        AND fc.candidate_id = v_target_id
    ) INTO v_is_authorized_guardian;

    IF NOT (v_is_admin OR v_is_authorized_guardian) THEN
      RAISE EXCEPTION 'Access denied: cannot view membership for another user';
    END IF;
  END IF;

  SELECT * INTO v_sub
  FROM public.user_subscriptions
  WHERE user_id = v_target_id
    AND status = 'active'
  ORDER BY updated_at DESC NULLS LAST
  LIMIT 1;

  -- Auto-provision 60-day Promotional Prime launch tier if no active subscription exists
  IF NOT FOUND OR (v_sub.expires_at IS NOT NULL AND v_sub.expires_at <= now()) THEN
    INSERT INTO public.user_subscriptions (
      user_id,
      tier,
      status,
      start_at,
      expires_at,
      contacts_unlocked_count,
      contacts_unlocked_limit,
      created_at,
      updated_at
    ) VALUES (
      v_target_id,
      'prime',
      'active',
      now(),
      now() + interval '60 days',
      0,
      50,
      now(),
      now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
      tier = 'prime',
      status = 'active',
      start_at = now(),
      expires_at = now() + interval '60 days',
      contacts_unlocked_limit = 50,
      updated_at = now()
    RETURNING * INTO v_sub;
  END IF;

  IF v_sub.expires_at IS NULL OR v_sub.expires_at > now() THEN
    v_tier := v_sub.tier;
    v_contacts_used := v_sub.contacts_unlocked_count;
    v_contacts_limit := v_sub.contacts_unlocked_limit;
  ELSE
    v_tier := 'free';
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
  WHERE user_id = v_target_id AND quota_date = CURRENT_DATE;

  IF FOUND THEN
    v_sent_today := v_quota.interests_sent_count;
  ELSE
    INSERT INTO public.daily_user_quotas (user_id, quota_date, interests_sent_count, max_interests_per_day)
    VALUES (v_target_id, CURRENT_DATE, 0, v_max_daily)
    ON CONFLICT (user_id, quota_date) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'user_id', v_target_id,
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
