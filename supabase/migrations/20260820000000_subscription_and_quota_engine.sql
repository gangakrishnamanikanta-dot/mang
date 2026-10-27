-- ============================================================
-- Migration: 3-Tier Membership & Quota Engine (Free, Prime Lite, Prime VIP)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.user_subscriptions (
  user_id                  uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  tier                     text NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'prime_lite', 'prime')),
  status                   text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'cancelled')),
  start_at                 timestamptz NOT NULL DEFAULT now(),
  expires_at               timestamptz,
  contacts_unlocked_count  integer NOT NULL DEFAULT 0,
  contacts_unlocked_limit  integer NOT NULL DEFAULT 0,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.daily_user_quotas (
  user_id                  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  quota_date               date NOT NULL DEFAULT CURRENT_DATE,
  interests_sent_count     integer NOT NULL DEFAULT 0,
  max_interests_per_day    integer NOT NULL DEFAULT 5,
  created_at               timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, quota_date)
);

CREATE TABLE IF NOT EXISTS public.contact_unlocks (
  user_id                  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_profile_id        uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  unlocked_at              timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, target_profile_id)
);

ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_user_quotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_unlocks ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_subscriptions' AND policyname = 'Users can view own subscription') THEN
    CREATE POLICY "Users can view own subscription" ON public.user_subscriptions FOR SELECT TO authenticated USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'daily_user_quotas' AND policyname = 'Users can view own daily quota') THEN
    CREATE POLICY "Users can view own daily quota" ON public.daily_user_quotas FOR SELECT TO authenticated USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'contact_unlocks' AND policyname = 'Users can view own unlocks') THEN
    CREATE POLICY "Users can view own unlocks" ON public.contact_unlocks FOR SELECT TO authenticated USING (auth.uid() = user_id);
  END IF;
END $$;

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
  v_max_daily int := 5;
  v_sent_today int := 0;
  v_contacts_used int := 0;
  v_contacts_limit int := 0;
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
    v_max_daily := 25;
    IF v_contacts_limit = 0 THEN v_contacts_limit := 60; END IF;
  ELSIF v_tier = 'prime_lite' THEN
    v_max_daily := 15;
    IF v_contacts_limit = 0 THEN v_contacts_limit := 25; END IF;
  ELSE
    v_tier := 'free';
    v_max_daily := 5;
    v_contacts_limit := 0;
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
    'expires_at', v_sub.expires_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.send_interest_with_quota(p_receiver_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_sender_id uuid := auth.uid();
  v_status jsonb;
  v_tier text;
  v_max_daily int;
  v_sent_today int;
  v_remaining int;
  v_interest_id uuid;
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF v_sender_id = p_receiver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'cannot_interest_self');
  END IF;

  v_status := public.get_user_membership_status(v_sender_id);
  v_tier := v_status->>'tier';
  v_max_daily := (v_status->>'max_daily_interests')::int;
  v_sent_today := (v_status->>'interests_sent_today')::int;

  IF v_sent_today >= v_max_daily THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'quota_exceeded',
      'tier', v_tier,
      'limit', v_max_daily,
      'sent_today', v_sent_today,
      'message', format('Daily limit of %s interests reached for %s tier.', v_max_daily, v_tier)
    );
  END IF;

  INSERT INTO public.interests (sender_profile_id, receiver_profile_id, status, created_at, updated_at)
  VALUES (v_sender_id, p_receiver_id, 'pending', now(), now())
  ON CONFLICT (sender_profile_id, receiver_profile_id) DO UPDATE
  SET status = 'pending', updated_at = now()
  RETURNING id INTO v_interest_id;

  INSERT INTO public.daily_user_quotas (user_id, quota_date, interests_sent_count, max_interests_per_day)
  VALUES (v_sender_id, CURRENT_DATE, 1, v_max_daily)
  ON CONFLICT (user_id, quota_date) DO UPDATE
  SET interests_sent_count = public.daily_user_quotas.interests_sent_count + 1;

  v_remaining := GREATEST(0, v_max_daily - (v_sent_today + 1));

  RETURN jsonb_build_object(
    'success', true,
    'interest_id', v_interest_id,
    'tier', v_tier,
    'sent_today', v_sent_today + 1,
    'remaining_daily_interests', v_remaining
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.unlock_contact_number(p_target_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_status jsonb;
  v_tier text;
  v_used int;
  v_limit int;
  v_phone text;
  v_already_unlocked boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'error', 'unauthenticated');
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.contact_unlocks 
    WHERE user_id = v_user_id AND target_profile_id = p_target_id
  ) INTO v_already_unlocked;

  SELECT phone_number INTO v_phone FROM public.profiles WHERE id = p_target_id;

  IF v_already_unlocked THEN
    RETURN jsonb_build_object(
      'allowed', true,
      'already_unlocked', true,
      'phone_number', COALESCE(v_phone, 'Not provided'),
      'remaining_contacts', (public.get_user_membership_status(v_user_id)->>'remaining_contacts')::int
    );
  END IF;

  v_status := public.get_user_membership_status(v_user_id);
  v_tier := v_status->>'tier';
  v_used := (v_status->>'contacts_unlocked_count')::int;
  v_limit := (v_status->>'contacts_unlocked_limit')::int;

  IF v_tier = 'free' OR v_limit = 0 THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'error', 'upgrade_required',
      'tier', v_tier,
      'message', 'Contact numbers are locked for Free members. Upgrade to Prime Lite or Prime VIP to unlock.'
    );
  END IF;

  IF v_used >= v_limit THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'error', 'contact_quota_exceeded',
      'tier', v_tier,
      'limit', v_limit,
      'message', format('You have used all %s contact unlocks for this billing cycle.', v_limit)
    );
  END IF;

  INSERT INTO public.contact_unlocks (user_id, target_profile_id, unlocked_at)
  VALUES (v_user_id, p_target_id, now())
  ON CONFLICT DO NOTHING;

  UPDATE public.user_subscriptions
  SET contacts_unlocked_count = contacts_unlocked_count + 1,
      updated_at = now()
  WHERE user_id = v_user_id;

  RETURN jsonb_build_object(
    'allowed', true,
    'already_unlocked', false,
    'phone_number', COALESCE(v_phone, 'Not provided'),
    'remaining_contacts', GREATEST(0, v_limit - (v_used + 1))
  );
END;
$$;

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
    v_limit := 60;
  ELSIF p_tier = 'prime_lite' THEN
    v_limit := 25;
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

  PERFORM public.refresh_user_match_cache(p_user_id);

  RETURN public.get_user_membership_status(p_user_id);
END;
$$;
