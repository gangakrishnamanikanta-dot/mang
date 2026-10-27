-- =============================================================================
-- Migration: 20261009000001_harden_security_privacy_and_quotas.sql
-- Description:
--   1. Revoke set_user_subscription from authenticated/anon (restricted to service_role).
--   2. Harden unlock_contact_number to enforce profiles.hide_mobile privacy and FOR UPDATE quota lock.
--   3. Harden send_interest_with_quota with FOR UPDATE atomic row lock and aligned tier quotas.
--   4. Extend search_discovery_profiles to return rashi_id, nakshatra_id, pada_id, height_inches, about_me.
--   5. Drop conflicting profiles_about_me_check (<= 500) in favor of chk_about_me_len (<= 1000).
--   6. Harden delete_user_account to cascade-delete from auth.users (preventing orphaned credentials).
--   7. Revoke EXECUTE from anon on admin and internal functions.
--   8. Add covering indexes for high-frequency unindexed foreign keys.
--   9. Fix mutable search_path on functions identified by security advisor.
-- =============================================================================

-- ── 1. Revoke set_user_subscription from authenticated / anon ──────────────────
REVOKE EXECUTE ON FUNCTION public.set_user_subscription(uuid, text, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.set_user_subscription(uuid, text, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.set_user_subscription(uuid, text, integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.set_user_subscription(uuid, text, integer) TO service_role;

-- Recreate set_user_subscription with synchronized unlock limits (Prime: 60, Lite: 25, Free: 0)
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
  v_expires timestamptz;
BEGIN
  IF p_tier = 'prime' THEN
    v_limit := 60;
  ELSIF p_tier = 'prime_lite' THEN
    v_limit := 25;
  ELSE
    v_limit := 0;
  END IF;

  IF p_tier = 'free' THEN
    v_expires := NULL;
  ELSE
    v_expires := now() + (p_duration_days * INTERVAL '1 day');
  END IF;

  INSERT INTO public.user_subscriptions (
    user_id, tier, status,
    start_at, expires_at,
    contacts_unlocked_count, contacts_unlocked_limit,
    created_at, updated_at
  ) VALUES (
    p_user_id, p_tier, 'active',
    now(), v_expires,
    0, v_limit,
    now(), now()
  )
  ON CONFLICT (user_id) DO UPDATE
  SET tier = EXCLUDED.tier,
      status = 'active',
      start_at = EXCLUDED.start_at,
      expires_at = EXCLUDED.expires_at,
      contacts_unlocked_limit = EXCLUDED.contacts_unlocked_limit,
      contacts_unlocked_count = 0,
      updated_at = now();

  RETURN public.get_user_membership_status(p_user_id);
END;
$$;


-- ── 2. Harden unlock_contact_number (hide_mobile privacy & FOR UPDATE lock) ───
CREATE OR REPLACE FUNCTION public.unlock_contact_number(
    p_target_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid;
    v_phone text;
    v_full_name text;
    v_hide_mobile boolean;
    v_already_unlocked boolean;
    v_active_sub record;
    v_unlocks_used integer;
    v_unlock_limit integer;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'status', 'error',
            'error', 'unauthenticated',
            'message', 'Authentication required'
        );
    END IF;

    IF v_user_id = p_target_id THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'status', 'error',
            'error', 'self_unlock',
            'message', 'Cannot unlock your own contact'
        );
    END IF;

    -- Fetch target profile phone, name & privacy settings
    SELECT phone, full_name, COALESCE(hide_mobile, false)
    INTO v_phone, v_full_name, v_hide_mobile
    FROM public.profiles
    WHERE id = p_target_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'status', 'error',
            'error', 'not_found',
            'message', 'Profile not found'
        );
    END IF;

    -- Check if target user has explicitly hidden their mobile number
    IF v_hide_mobile IS TRUE THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'status', 'contact_private',
            'error', 'contact_private',
            'is_private', true,
            'message', 'This member has set their contact number to private. Please connect with them securely via Mangalasutram Chat.'
        );
    END IF;

    -- Check active subscription and quota with row-level lock
    SELECT * INTO v_active_sub
    FROM public.user_subscriptions
    WHERE user_id = v_user_id AND status = 'active' AND (expires_at IS NULL OR expires_at > now())
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    -- Set limit by tier
    IF v_active_sub IS NOT NULL THEN
        IF v_active_sub.tier = 'prime' THEN
            v_unlock_limit := 60;
        ELSIF v_active_sub.tier = 'prime_lite' THEN
            v_unlock_limit := 25;
        ELSE
            v_unlock_limit := 0;
        END IF;
    ELSE
        v_unlock_limit := 0;
    END IF;

    -- Count existing unlocks within this subscription
    SELECT count(*)::integer INTO v_unlocks_used
    FROM public.contact_unlocks
    WHERE user_id = v_user_id 
      AND (v_active_sub IS NULL OR unlocked_at >= v_active_sub.created_at);

    -- Check if already unlocked
    SELECT EXISTS (
        SELECT 1 FROM public.contact_unlocks
        WHERE user_id = v_user_id AND target_profile_id = p_target_id
    ) INTO v_already_unlocked;

    IF v_already_unlocked THEN
        RETURN jsonb_build_object(
            'allowed', true,
            'status', 'success',
            'already_unlocked', true,
            'phone', COALESCE(v_phone, 'Contact not shared'),
            'phone_number', COALESCE(v_phone, 'Contact not shared'),
            'full_name', v_full_name,
            'remaining_contacts', GREATEST(0, v_unlock_limit - v_unlocks_used),
            'remaining_unlocks', GREATEST(0, v_unlock_limit - v_unlocks_used)
        );
    END IF;

    IF v_active_sub IS NULL OR v_unlock_limit = 0 THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'status', 'quota_exceeded',
            'error', 'upgrade_required',
            'message', 'Contact numbers are locked for Free members. Upgrade to Prime Lite or Prime VIP to unlock.'
        );
    END IF;

    IF v_unlocks_used >= v_unlock_limit THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'status', 'quota_exceeded',
            'error', 'contact_quota_exceeded',
            'message', 'You have exhausted your contact unlocks for this billing cycle.',
            'limit', v_unlock_limit,
            'used', v_unlocks_used,
            'remaining_contacts', 0,
            'remaining_unlocks', 0
        );
    END IF;

    -- Insert new unlock record
    INSERT INTO public.contact_unlocks (user_id, target_profile_id, unlocked_at)
    VALUES (v_user_id, p_target_id, now())
    ON CONFLICT (user_id, target_profile_id) DO NOTHING;

    -- Sync contacts_unlocked_count
    UPDATE public.user_subscriptions
    SET contacts_unlocked_count = contacts_unlocked_count + 1,
        updated_at = now()
    WHERE user_id = v_user_id;

    RETURN jsonb_build_object(
        'allowed', true,
        'status', 'success',
        'already_unlocked', false,
        'phone', COALESCE(v_phone, 'Contact not shared'),
        'phone_number', COALESCE(v_phone, 'Contact not shared'),
        'full_name', v_full_name,
        'remaining_contacts', GREATEST(0, v_unlock_limit - (v_unlocks_used + 1)),
        'remaining_unlocks', GREATEST(0, v_unlock_limit - (v_unlocks_used + 1))
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.unlock_contact_number(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unlock_contact_number(uuid) TO service_role;


-- ── 3. Harden send_interest_with_quota (FOR UPDATE lock & quota alignment) ───
CREATE OR REPLACE FUNCTION public.send_interest_with_quota(p_receiver_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_caller_id uuid;
    v_sender_id uuid;
    v_quota record;
    v_sub record;
    v_tier text := 'free';
    v_max_daily int := 5;
    v_today date := public.ist_today();
    v_existing_interest uuid;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
    END IF;

    v_sender_id := COALESCE(public.get_guardian_candidate_id(v_caller_id), v_caller_id);

    IF v_sender_id = p_receiver_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'self_interest', 'message', 'You cannot send interest to yourself.');
    END IF;

    SELECT * INTO v_sub
    FROM public.user_subscriptions
    WHERE user_id = v_sender_id
      AND (expires_at IS NULL OR expires_at > now())
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND THEN
        v_tier := v_sub.tier;
    END IF;

    IF v_tier = 'prime' THEN
        v_max_daily := 30;
    ELSIF v_tier = 'prime_lite' THEN
        v_max_daily := 15;
    ELSE
        v_max_daily := 5;
    END IF;

    -- Upsert daily quota row first
    INSERT INTO public.daily_user_quotas (user_id, quota_date, interests_sent_count, max_interests_per_day)
    VALUES (v_sender_id, v_today, 0, v_max_daily)
    ON CONFLICT (user_id, quota_date) DO UPDATE
    SET max_interests_per_day = EXCLUDED.max_interests_per_day;

    -- Row lock for concurrency safety
    SELECT * INTO v_quota
    FROM public.daily_user_quotas
    WHERE user_id = v_sender_id AND quota_date = v_today
    FOR UPDATE;

    IF v_quota.interests_sent_count >= v_max_daily THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'quota_exceeded',
            'tier', v_tier,
            'limit', v_max_daily,
            'message', 'Daily interest limit reached. Upgrade to Prime for more.'
        );
    END IF;

    SELECT id INTO v_existing_interest
    FROM public.interests
    WHERE sender_profile_id = v_sender_id AND receiver_profile_id = p_receiver_id
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'duplicate', 'message', 'You have already sent an interest to this profile.');
    END IF;

    INSERT INTO public.interests (sender_profile_id, receiver_profile_id, status)
    VALUES (v_sender_id, p_receiver_id, 'pending');

    UPDATE public.daily_user_quotas
    SET interests_sent_count = interests_sent_count + 1
    WHERE user_id = v_sender_id AND quota_date = v_today;

    RETURN jsonb_build_object('success', true, 'message', 'Interest sent successfully.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_interest_with_quota(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_interest_with_quota(uuid) TO service_role;


-- ── 4. Extend search_discovery_profiles ───────────────────────────────────────
DROP FUNCTION IF EXISTS public.search_discovery_profiles(uuid, text, text, integer, integer, text, integer, integer);
DROP FUNCTION IF EXISTS public.search_discovery_profiles(uuid, text, text, int, int, text, int, int);

CREATE OR REPLACE FUNCTION public.search_discovery_profiles(
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
    rashi_id integer,
    nakshatra_id integer,
    pada_id integer,
    height_inches integer,
    about_me text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
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
    p.rashi_id,
    p.nakshatra_id,
    p.pada_id,
    p.height_inches,
    p.about_me
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
$$;

GRANT EXECUTE ON FUNCTION public.search_discovery_profiles(uuid, text, text, int, int, text, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_discovery_profiles(uuid, text, text, int, int, text, int, int) TO service_role;


-- ── 5. Harmonize about_me constraint to 1000 characters ───────────────────────
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_about_me_check;


-- ── 6. Harden delete_user_account to cascade from auth.users ─────────────────
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    -- Deleting from auth.users cascades to public.profiles and all associated records
    DELETE FROM auth.users WHERE id = v_user_id;

    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'Account and personal data have been completely erased.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO service_role;


-- ── 7. Revoke EXECUTE from anon on administrative & internal functions ────────
DO $$
DECLARE
    f record;
    v_sql text;
BEGIN
    FOR f IN 
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
          AND p.proname IN (
              'admin_delete_user',
              'admin_toggle_admin',
              'admin_toggle_verify',
              'cleanup_expired_otps',
              'get_admin_stats',
              'get_admin_users'
          )
    LOOP
        v_sql := format('REVOKE EXECUTE ON FUNCTION public.%I(%s) FROM anon;', f.proname, f.args);
        EXECUTE v_sql;
    END LOOP;
END $$;


-- ── 8. Covering Indexes for High-Frequency Foreign Keys ───────────────────────
CREATE INDEX IF NOT EXISTS idx_contact_unlocks_target_profile_id ON public.contact_unlocks(target_profile_id);
CREATE INDEX IF NOT EXISTS idx_conversations_last_sender_id ON public.conversations(last_sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON public.messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_on_behalf_of ON public.messages(on_behalf_of);
CREATE INDEX IF NOT EXISTS idx_messages_proxy_sender_id ON public.messages(proxy_sender_id);
CREATE INDEX IF NOT EXISTS idx_shortlists_profile_id ON public.shortlists(profile_id);
CREATE INDEX IF NOT EXISTS idx_family_messages_sender_id ON public.family_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_family_messages_shared_profile_id ON public.family_messages(shared_profile_id);
CREATE INDEX IF NOT EXISTS idx_family_profile_reviews_reviewed_by ON public.family_profile_reviews(reviewed_by);
CREATE INDEX IF NOT EXISTS idx_family_profile_reviews_target_profile_id ON public.family_profile_reviews(target_profile_id);

CREATE INDEX IF NOT EXISTS idx_profiles_nakshatra_id ON public.profiles(nakshatra_id);
CREATE INDEX IF NOT EXISTS idx_profiles_rashi_id ON public.profiles(rashi_id);
CREATE INDEX IF NOT EXISTS idx_profiles_pada_id ON public.profiles(pada_id);
CREATE INDEX IF NOT EXISTS idx_profiles_gothram_id ON public.profiles(gothram_id);
CREATE INDEX IF NOT EXISTS idx_profiles_caste_id ON public.profiles(caste_id);
CREATE INDEX IF NOT EXISTS idx_profiles_mother_tongue_id ON public.profiles(mother_tongue_id);
CREATE INDEX IF NOT EXISTS idx_profiles_highest_education_id ON public.profiles(highest_education_id);
CREATE INDEX IF NOT EXISTS idx_profiles_occupation_id ON public.profiles(occupation_id);
CREATE INDEX IF NOT EXISTS idx_profiles_annual_income_id ON public.profiles(annual_income_id);
CREATE INDEX IF NOT EXISTS idx_profiles_food_preference_id ON public.profiles(food_preference_id);
CREATE INDEX IF NOT EXISTS idx_profiles_marital_status_id ON public.profiles(marital_status_id);
CREATE INDEX IF NOT EXISTS idx_profiles_veda_shakha_id ON public.profiles(veda_shakha_id);


-- ── 9. Fix mutable search_path on advisor-flagged functions ──────────────────
ALTER FUNCTION public.sync_profile_pada_columns() SET search_path = 'public';
ALTER FUNCTION public.calculate_reciprocal_compatibility(uuid, uuid) SET search_path = 'public';
ALTER FUNCTION public.trg_prevent_message_tampering() SET search_path = 'public';
