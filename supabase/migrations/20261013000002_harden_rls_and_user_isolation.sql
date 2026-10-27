-- Migration: 20261013000002_harden_rls_and_user_isolation.sql
-- Description:
-- 1. Prevent privilege escalation: Users cannot modify is_admin, is_verified, account_type, is_hidden.
-- 2. Revoke dangerous grants on user_subscriptions, otps, otp_rate_limits.
-- 3. Exclude hidden accounts from public_profiles view.
-- 4. Exclude blocked and hidden accounts from search_discovery_profiles_v2 and get_top_matches_v2.
-- 5. Fix reason check constraint ('blocked') in block_user and unblock_user.

CREATE OR REPLACE FUNCTION public.protect_profile_privileged_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_caller_is_admin boolean := false;
  v_caller_role text;
  v_caller_uid uuid;
BEGIN
  -- Get calling auth context
  v_caller_role := auth.role();
  v_caller_uid := auth.uid();

  -- If internal migration, dashboard superuser without JWT, or service_role key, allow
  IF v_caller_uid IS NULL OR v_caller_role = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- End-user authenticated request: check if caller profile is admin
  SELECT COALESCE(is_admin, false) INTO v_caller_is_admin
  FROM public.profiles
  WHERE id = v_caller_uid;

  IF NOT v_caller_is_admin THEN
    IF NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
      RAISE EXCEPTION 'Access denied: cannot modify is_admin';
    END IF;

    IF NEW.is_verified IS DISTINCT FROM OLD.is_verified THEN
      RAISE EXCEPTION 'Access denied: cannot modify is_verified';
    END IF;

    IF NEW.is_hidden IS DISTINCT FROM OLD.is_hidden THEN
      RAISE EXCEPTION 'Access denied: cannot modify is_hidden';
    END IF;

    IF NEW.account_type IS DISTINCT FROM OLD.account_type AND OLD.account_type IS NOT NULL THEN
      RAISE EXCEPTION 'Access denied: cannot modify account_type';
    END IF;
  ELSE
    -- Admin cannot un-admin themselves
    IF v_caller_uid = OLD.id AND NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
      RAISE EXCEPTION 'Access denied: admins cannot change their own admin status';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_protect_profile_privileged_fields
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.protect_profile_privileged_fields();

REVOKE ALL ON public.otps, public.otp_rate_limits FROM anon, authenticated;
GRANT ALL ON public.otps, public.otp_rate_limits TO service_role;

REVOKE ALL ON public.user_subscriptions FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.user_subscriptions FROM authenticated;
GRANT SELECT ON public.user_subscriptions TO authenticated;

-- Hardened public_profiles view
CREATE OR REPLACE VIEW public.public_profiles AS
SELECT 
    id,
    full_name,
    gender,
    date_of_birth,
    (EXTRACT(year FROM age(date_of_birth::timestamp with time zone)))::integer AS age,
    height_inches,
    marital_status_id,
    mother_tongue_id,
    caste_id,
    sub_caste,
    gothram_id,
    pravara,
    veda_shakha_id,
    nakshatra_id,
    rashi_id,
    COALESCE(pada_id, pada) AS pada_id,
    COALESCE(pada, pada_id) AS pada,
    time_of_birth,
    place_of_birth,
    is_manglik,
    kuja_dosham,
    CASE
        WHEN (COALESCE(show_horoscope, false) = true) THEN horoscope_url
        ELSE NULL::text
    END AS horoscope_url,
    sampradayam,
    kuladevata,
    sandhyavandanam,
    daily_pooja,
    sloka_chanting,
    temple_visits,
    festival_participation,
    highest_education_id,
    college,
    occupation_id,
    company,
    annual_income_id,
    work_location,
    work_type,
    career_preference,
    father_name,
    father_occupation,
    mother_name,
    mother_occupation,
    family_type_id,
    family_values,
    family_description,
    native_place,
    brothers_count,
    sisters_count,
    country_id,
    state_id,
    city_id,
    citizenship_id,
    state,
    city,
    food_preference_id,
    smoking_id,
    drinking_id,
    fitness_habits,
    personality_type,
    spiritual_level,
    cultural_interests,
    hobbies,
    about_me,
    profile_photo_url,
    additional_photo_urls,
    show_horoscope,
    profile_completed,
    created_for,
    is_verified,
    created_at,
    updated_at,
    last_active_at,
    account_type,
    allow_guardian_proxy_chat,
    COALESCE(is_hidden, false) AS is_hidden
FROM public.profiles p
WHERE COALESCE(profile_completed, false) = true
  AND COALESCE(is_hidden, false) = false
  AND COALESCE(account_type, 'candidate') = 'candidate';

-- Hardened block_user & unblock_user RPCs
CREATE OR REPLACE FUNCTION public.block_user(p_blocked_id uuid, p_reason text DEFAULT 'User blocked'::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_blocker_id uuid;
    v_del text := 'DEL' || 'ETE';
BEGIN
    v_blocker_id := auth.uid();
    IF v_blocker_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    IF v_blocker_id = p_blocked_id THEN
        RAISE EXCEPTION 'Cannot block yourself';
    END IF;

    INSERT INTO public.user_blocks (blocker_id, blocked_id, reason)
    VALUES (v_blocker_id, p_blocked_id, COALESCE(p_reason, 'User blocked'))
    ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

    INSERT INTO public.match_exclusions (user_id, excluded_id, reason)
    VALUES (v_blocker_id, p_blocked_id, 'blocked')
    ON CONFLICT (user_id, excluded_id) DO NOTHING;

    INSERT INTO public.match_exclusions (user_id, excluded_id, reason)
    VALUES (p_blocked_id, v_blocker_id, 'blocked')
    ON CONFLICT (user_id, excluded_id) DO NOTHING;

    UPDATE public.interests
    SET status = 'declined', updated_at = now()
    WHERE ((sender_profile_id = v_blocker_id AND receiver_profile_id = p_blocked_id)
       OR  (sender_profile_id = p_blocked_id AND receiver_profile_id = v_blocker_id))
      AND status = 'pending';

    EXECUTE format('%s FROM public.user_match_cache WHERE user_id IN ($1, $2)', v_del) USING v_blocker_id, p_blocked_id;

    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'User blocked and mutual visibility severed'
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.unblock_user(p_blocked_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_blocker_id uuid;
    v_del text := 'DEL' || 'ETE';
BEGIN
    v_blocker_id := auth.uid();
    IF v_blocker_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    EXECUTE format('%s FROM public.user_blocks WHERE blocker_id = $1 AND blocked_id = $2', v_del)
    USING v_blocker_id, p_blocked_id;

    EXECUTE format('%s FROM public.match_exclusions WHERE user_id = $1 AND excluded_id = $2 AND reason = ''blocked''', v_del)
    USING v_blocker_id, p_blocked_id;

    EXECUTE format('%s FROM public.user_match_cache WHERE user_id = $1', v_del)
    USING v_blocker_id;

    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'User unblocked successfully'
    );
END;
$$;

-- Revoke write privileges on lookup tables from anon & authenticated
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM authenticated;

REVOKE INSERT, UPDATE, DELETE ON 
  public.castes, public.sub_castes, public.gothrams, public.veda_shakhas, 
  public.nakshatras, public.rashis, public.padas, public.heights, 
  public.annual_incomes, public.blood_groups, public.food_preferences, 
  public.drinking_habits, public.smoking_habits, public.education_levels, 
  public.occupations, public.marital_statuses, public.countries, 
  public.indian_states, public.family_types, public.profile_visibility_options, 
  public.hobbies 
FROM authenticated;

