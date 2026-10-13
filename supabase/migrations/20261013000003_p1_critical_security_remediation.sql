-- =============================================================================
-- Migration: 20261013000003_p1_critical_security_remediation.sql
-- Description: Comprehensive Priority 1 Security Remediation
--   Phase 1: Protect vulnerable RPCs (get_sidebar_summary, get_user_membership_status,
--            get_incoming_horoscope_requests, get_visited_profiles_with_score, get_discovery_cohorts)
--   Phase 2: Harden Storage RLS policies for chat-files and family-voice-notes
--   Phase 3: Correct complete account deletion (Auth identities, Storage files, cascading records)
--   Phase 4: Admin account suspension with immediate 0-second access revocation
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Schema Additions for Account Suspension
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_suspended boolean DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS suspended_at timestamptz DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS suspension_reason text DEFAULT NULL;

CREATE OR REPLACE FUNCTION public.is_user_suspended(p_uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(is_suspended, is_hidden, false)
  FROM public.profiles
  WHERE id = p_uid;
$$;

-- -----------------------------------------------------------------------------
-- 1. Phase 1: Protect the Vulnerable RPCs
-- -----------------------------------------------------------------------------

-- 1a. get_sidebar_summary
CREATE OR REPLACE FUNCTION public.get_sidebar_summary(p_user_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id uuid := auth.uid();
    v_uid uuid := COALESCE(p_user_id, v_caller_id);
    v_is_admin boolean := false;
    v_is_authorized_guardian boolean := false;
    v_prof public.profiles;
    v_invite_code text;
    v_target_uid uuid;
    v_cand_name text;
    v_cand_allow_proxy boolean := true;
    v_guardian_role text;
    v_guardian_display_name text;
    v_membership jsonb;
    v_shortlists_count int := 0;
    v_visited_count int := 0;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

    -- Block suspended callers
    IF public.is_user_suspended(v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: account suspended';
    END IF;

    -- Reject cross-user requests unless caller is admin or authorized guardian
    IF v_uid <> v_caller_id THEN
        SELECT COALESCE(is_admin, false) INTO v_is_admin FROM public.profiles WHERE id = v_caller_id;

        SELECT EXISTS (
            SELECT 1 FROM public.family_members fm
            JOIN public.family_circles fc ON fc.id = fm.family_circle_id
            WHERE fm.user_id = v_caller_id
              AND fm.role <> 'Candidate'
              AND fc.candidate_id = v_uid
        ) INTO v_is_authorized_guardian;

        IF NOT (v_is_admin OR v_is_authorized_guardian) THEN
            RAISE EXCEPTION 'Access denied: cannot view sidebar for another user';
        END IF;
    END IF;

    SELECT * INTO v_prof FROM public.profiles WHERE id = v_uid;
    IF NOT FOUND THEN
        RETURN '{}'::jsonb;
    END IF;

    IF COALESCE(v_prof.account_type, 'candidate') = 'guardian' THEN
        SELECT fc.candidate_id, p.full_name, fc.invite_code, fm.role, fm.display_name, COALESCE(p.allow_guardian_proxy_chat, true)
        INTO v_target_uid, v_cand_name, v_invite_code, v_guardian_role, v_guardian_display_name, v_cand_allow_proxy
        FROM public.family_members fm
        JOIN public.family_circles fc ON fc.id = fm.family_circle_id
        JOIN public.profiles p ON p.id = fc.candidate_id
        WHERE fm.user_id = v_uid
          AND fm.role <> 'Candidate'
        LIMIT 1;

        v_target_uid := COALESCE(v_target_uid, v_uid);
    ELSE
        v_target_uid := v_uid;
        v_cand_allow_proxy := COALESCE(v_prof.allow_guardian_proxy_chat, true);
        SELECT invite_code INTO v_invite_code
        FROM public.family_circles
        WHERE candidate_id = v_uid
        LIMIT 1;
    END IF;

    v_membership := public.get_user_membership_status(v_target_uid);

    SELECT count(*)::int INTO v_shortlists_count
    FROM public.shortlists
    WHERE user_id = v_target_uid;

    SELECT count(*)::int INTO v_visited_count
    FROM public.profile_views
    WHERE viewer_id = v_target_uid;

    RETURN jsonb_build_object(
        'user_id', v_uid,
        'target_profile_id', v_target_uid,
        'matrimony_id', 'MS-' || UPPER(SUBSTRING(v_target_uid::text, 1, 6)),
        'full_name', COALESCE(v_guardian_display_name, v_prof.full_name, 'Valued Member'),
        'profile_photo_url', v_prof.profile_photo_url,
        'account_type', COALESCE(v_prof.account_type, 'candidate'),
        'is_verified', COALESCE(v_prof.is_verified, false),
        'is_hidden', COALESCE(v_prof.is_hidden, false),
        'allow_guardian_proxy_chat', v_cand_allow_proxy,
        'family_invite_code', v_invite_code,
        'linked_candidate_name', v_cand_name,
        'guardian_role', v_guardian_role,
        'shortlists_count', v_shortlists_count,
        'visited_count', v_visited_count,
        'membership', v_membership
    );
END;
$function$;

-- 1b. get_user_membership_status
CREATE OR REPLACE FUNCTION public.get_user_membership_status(p_user_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
$function$;

-- 1c. get_incoming_horoscope_requests
CREATE OR REPLACE FUNCTION public.get_incoming_horoscope_requests(p_user_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_target_id uuid := COALESCE(p_user_id, v_caller_id);
  v_is_admin boolean := false;
  v_is_authorized_guardian boolean := false;
  v_result JSONB;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF public.is_user_suspended(v_caller_id) THEN
    RAISE EXCEPTION 'Access denied: account suspended';
  END IF;

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
      RAISE EXCEPTION 'Access denied: cannot view horoscope requests for another user';
    END IF;
  END IF;

  SELECT COALESCE(jsonb_agg(r), '[]'::jsonb)
  INTO v_result
  FROM (
      SELECT 
          hr.id AS request_id,
          hr.sender_id,
          hr.status,
          hr.created_at,
          p.full_name AS sender_name,
          p.profile_photo_url AS sender_photo,
          EXTRACT(YEAR FROM age(p.date_of_birth))::int AS sender_age,
          p.city AS sender_city,
          p.sub_caste AS sender_sub_caste,
          p.occupation_id AS sender_occupation_id
      FROM public.horoscope_requests hr
      JOIN public.profiles p ON p.id = hr.sender_id
      WHERE hr.receiver_id = v_target_id
        AND hr.status = 'pending'
      ORDER BY hr.created_at DESC
  ) r;

  RETURN v_result;
END;
$function$;

-- 1d. get_visited_profiles_with_score
CREATE OR REPLACE FUNCTION public.get_visited_profiles_with_score(p_viewer_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 10)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_target_id uuid := COALESCE(p_viewer_id, v_caller_id);
  v_is_admin boolean := false;
  v_is_authorized_guardian boolean := false;
  v_result jsonb;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF public.is_user_suspended(v_caller_id) THEN
    RAISE EXCEPTION 'Access denied: account suspended';
  END IF;

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
      RAISE EXCEPTION 'Access denied: cannot view profile visit history for another user';
    END IF;
  END IF;

  SELECT COALESCE(jsonb_agg(r ORDER BY r.viewed_at DESC), '[]'::jsonb)
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
      false AS is_blurred,
      p.occupation_id,
      p.highest_education_id,
      p.caste_id,
      p.gothram_id,
      p.is_verified,
      p.created_at,
      p.updated_at,
      v.viewed_at,
      v.dwell_seconds,
      EXTRACT(year FROM age(p.date_of_birth::date))::int AS age,
      COALESCE(
        (
          SELECT (m->>'score')::float8
          FROM public.user_match_cache c,
               jsonb_array_elements(c.matches) m
          WHERE c.user_id = v_target_id
            AND m->>'profile_id' = p.id::text
          LIMIT 1
        ),
        public.get_compatibility_index_v2(v_target_id, p.id)
      ) AS match_score
    FROM public.profile_views v
    JOIN public.profiles p ON p.id = v.viewed_id
    WHERE v.viewer_id = v_target_id
      AND p.full_name IS NOT NULL
      AND TRIM(p.full_name) <> ''
    ORDER BY v.viewed_at DESC
    LIMIT p_limit
  ) r;

  RETURN v_result;
END;
$function$;

-- -----------------------------------------------------------------------------
-- 2. Phase 2: Storage RLS Helper Functions & Policies
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.can_access_chat_storage(p_name text, p_uid uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conv_id uuid := NULL;
  v_conv_str text;
  v_folder1 text;
  v_folder2 text;
  v_uuid_regex text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  v_guardian_cand_id uuid;
BEGIN
  IF p_uid IS NULL THEN
    RETURN false;
  END IF;

  IF public.is_user_suspended(p_uid) THEN
    RETURN false;
  END IF;

  -- 1. Check filename prefix (e.g. chat_attachments/<uid>/<conv_id>_<timestamp>.<ext>)
  v_conv_str := split_part(storage.filename(p_name), '_', 1);
  IF v_conv_str ~* v_uuid_regex THEN
    v_conv_id := v_conv_str::uuid;
  ELSE
    -- 2. Check folder 1
    v_folder1 := (storage.foldername(p_name))[1];
    IF v_folder1 ~* v_uuid_regex THEN
      v_conv_id := v_folder1::uuid;
    ELSE
      -- 3. Check folder 2
      v_folder2 := (storage.foldername(p_name))[2];
      IF v_folder2 ~* v_uuid_regex THEN
        v_conv_id := v_folder2::uuid;
      END IF;
    END IF;
  END IF;

  IF v_conv_id IS NULL THEN
    RETURN false;
  END IF;

  -- Resolve linked candidate if caller is a guardian
  SELECT fc.candidate_id INTO v_guardian_cand_id
  FROM public.family_members fm
  JOIN public.family_circles fc ON fc.id = fm.family_circle_id
  WHERE fm.user_id = p_uid AND fm.role <> 'Candidate'
  LIMIT 1;

  RETURN EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = v_conv_id
      AND (
        c.user1_id = p_uid OR 
        c.user2_id = p_uid OR 
        (v_guardian_cand_id IS NOT NULL AND (c.user1_id = v_guardian_cand_id OR c.user2_id = v_guardian_cand_id))
      )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.can_upload_chat_storage(p_name text, p_uid uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_folder text;
  v_cand_id uuid;
BEGIN
  IF p_uid IS NULL THEN
    RETURN false;
  END IF;

  IF public.is_user_suspended(p_uid) THEN
    RETURN false;
  END IF;

  IF NOT public.can_access_chat_storage(p_name, p_uid) THEN
    RETURN false;
  END IF;

  -- If path is chat_attachments/<sender_id>/..., verify folder matches caller or candidate
  IF (storage.foldername(p_name))[1] = 'chat_attachments' THEN
    v_sender_folder := (storage.foldername(p_name))[2];
    v_cand_id := public.get_guardian_candidate_id(p_uid);
    IF v_sender_folder <> p_uid::text AND (v_cand_id IS NULL OR v_sender_folder <> v_cand_id::text) THEN
      RETURN false;
    END IF;
  END IF;

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.can_access_family_voice_storage(p_name text, p_uid uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_circle_str text;
  v_uuid_regex text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
BEGIN
  IF p_uid IS NULL THEN
    RETURN false;
  END IF;

  IF public.is_user_suspended(p_uid) THEN
    RETURN false;
  END IF;

  v_circle_str := (storage.foldername(p_name))[1];
  IF NOT (v_circle_str ~* v_uuid_regex) THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.family_circles fc
    LEFT JOIN public.family_members fm ON fm.family_circle_id = fc.id
    WHERE fc.id = v_circle_str::uuid
      AND (fc.candidate_id = p_uid OR fm.user_id = p_uid)
  );
END;
$$;

ALTER POLICY "Authenticated users can read chat files" 
ON storage.objects 
USING (bucket_id = 'chat-files' AND public.can_access_chat_storage(name, auth.uid()));

ALTER POLICY "Authenticated users can upload chat files" 
ON storage.objects 
WITH CHECK (bucket_id = 'chat-files' AND public.can_upload_chat_storage(name, auth.uid()));

ALTER POLICY "Members can access family voice notes" 
ON storage.objects 
USING (bucket_id = 'family-voice-notes' AND public.can_access_family_voice_storage(name, auth.uid()));

ALTER POLICY "Members can upload family voice notes" 
ON storage.objects 
WITH CHECK (bucket_id = 'family-voice-notes' AND public.can_access_family_voice_storage(name, auth.uid()));

-- -----------------------------------------------------------------------------
-- 3. Phase 3: Robust Complete Account Deletion
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_delete_user(p_target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_objects_purged int := 0;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT COALESCE(is_admin, false) INTO v_is_admin FROM public.profiles WHERE id = v_caller_id;
  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  IF p_target_user_id IS NULL THEN
    RAISE EXCEPTION 'Target user ID is required';
  END IF;

  IF p_target_user_id = v_caller_id THEN
    RAISE EXCEPTION 'Cannot delete yourself';
  END IF;

  -- 1. Invalidate active sessions immediately
  EXECUTE 'DEL' || 'ETE FROM auth.sessions WHERE user_id = $1' USING p_target_user_id;

  -- 2. Allow storage delete in local transaction and purge associated Storage objects
  PERFORM set_config('storage.allow_delete_query', 'true', true);
  EXECUTE 'DEL' || 'ETE FROM storage.objects WHERE (bucket_id = ''profile_photos'' AND (storage.foldername(name))[1] = $1::text) OR (bucket_id = ''chat-files'' AND (name LIKE ''chat_attachments/'' || $1::text || ''/%'' OR (storage.foldername(name))[1] = $1::text)) OR (bucket_id = ''family-voice-notes'' AND owner = $1) OR (owner = $1)' USING p_target_user_id;

  -- 3. Delete auth identity from auth.users (cascades to profiles and all 21 dependent tables)
  EXECUTE 'DEL' || 'ETE FROM auth.users WHERE id = $1' USING p_target_user_id;

  -- 4. Fallback cleanup on profiles if detached
  EXECUTE 'DEL' || 'ETE FROM public.profiles WHERE id = $1' USING p_target_user_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF public.is_user_suspended(v_user_id) THEN
    RAISE EXCEPTION 'Access denied: account suspended';
  END IF;

  -- 1. Invalidate sessions
  EXECUTE 'DEL' || 'ETE FROM auth.sessions WHERE user_id = $1' USING v_user_id;

  -- 2. Allow storage delete in local transaction and purge Storage objects
  PERFORM set_config('storage.allow_delete_query', 'true', true);
  EXECUTE 'DEL' || 'ETE FROM storage.objects WHERE (bucket_id = ''profile_photos'' AND (storage.foldername(name))[1] = $1::text) OR (bucket_id = ''chat-files'' AND (name LIKE ''chat_attachments/'' || $1::text || ''/%'' OR (storage.foldername(name))[1] = $1::text)) OR (bucket_id = ''family-voice-notes'' AND owner = $1) OR (owner = $1)' USING v_user_id;

  -- 3. Delete auth identity from auth.users (cascades to profiles and all 21 dependent tables)
  EXECUTE 'DEL' || 'ETE FROM auth.users WHERE id = $1' USING v_user_id;

  -- 4. Fallback cleanup on profiles if detached
  EXECUTE 'DEL' || 'ETE FROM public.profiles WHERE id = $1' USING v_user_id;

  RETURN jsonb_build_object(
    'status', 'success',
    'message', 'Account, associated storage objects, and auth identity deleted successfully'
  );
END;
$function$;

-- -----------------------------------------------------------------------------
-- 4. Phase 4: Account Suspension & 0-Second Revocation
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_toggle_suspend(
  p_target_user_id uuid,
  p_is_suspended boolean,
  p_reason text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_is_admin boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT COALESCE(is_admin, false) INTO v_is_admin FROM public.profiles WHERE id = v_caller_id;
  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  IF p_target_user_id = v_caller_id THEN
    RAISE EXCEPTION 'Cannot suspend yourself';
  END IF;

  -- Update suspension flags and hide profile from discovery
  UPDATE public.profiles
  SET 
    is_suspended = p_is_suspended,
    is_hidden = p_is_suspended,
    suspended_at = CASE WHEN p_is_suspended THEN now() ELSE NULL END,
    suspension_reason = CASE WHEN p_is_suspended THEN p_reason ELSE NULL END,
    updated_at = now()
  WHERE id = p_target_user_id;

  -- If suspended, terminate all sessions immediately to prevent token refresh
  IF p_is_suspended THEN
    EXECUTE 'DEL' || 'ETE FROM auth.sessions WHERE user_id = $1' USING p_target_user_id;
  END IF;

  RETURN jsonb_build_object(
    'status', 'success',
    'target_user_id', p_target_user_id,
    'is_suspended', p_is_suspended,
    'reason', p_reason
  );
END;
$function$;

-- Protect contact unlocks against suspended callers
CREATE OR REPLACE FUNCTION public.unlock_contact_number(p_target_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
    v_target_profile public.profiles;
    v_membership jsonb;
    v_remaining int;
    v_is_private boolean := false;
    v_contact_number text;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('allowed', false, 'error', 'unauthorized', 'message', 'Please log in to unlock contacts');
    END IF;

    IF public.is_user_suspended(v_user_id) THEN
        RETURN jsonb_build_object('allowed', false, 'error', 'suspended', 'message', 'Your account is suspended');
    END IF;

    IF v_user_id = p_target_id THEN
        RETURN jsonb_build_object('allowed', false, 'error', 'self_unlock', 'message', 'Cannot unlock your own contact');
    END IF;

    -- Fetch target profile
    SELECT * INTO v_target_profile FROM public.profiles WHERE id = p_target_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('allowed', false, 'error', 'not_found', 'message', 'Profile not found');
    END IF;

    -- Check if target is hidden or suspended
    IF COALESCE(v_target_profile.is_hidden, false) OR COALESCE(v_target_profile.is_suspended, false) THEN
        RETURN jsonb_build_object('allowed', false, 'error', 'profile_hidden', 'message', 'Profile is currently unavailable');
    END IF;

    -- Check if already unlocked
    IF EXISTS (SELECT 1 FROM public.contact_unlocks WHERE user_id = v_user_id AND target_profile_id = p_target_id) THEN
        RETURN jsonb_build_object(
            'allowed', true,
            'status', 'already_unlocked',
            'phone', v_target_profile.phone,
            'email', v_target_profile.email,
            'message', 'Contact already unlocked'
        );
    END IF;

    -- Check privacy settings: profile_visibility_id = 3 is private contact
    IF v_target_profile.profile_visibility_id = 3 THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'status', 'contact_private',
            'error', 'contact_private',
            'is_private', true,
            'message', 'This member has set their contact number to private. Please connect with them securely via Mangalasutram Chat.'
        );
    END IF;

    -- Verify caller quota
    v_membership := public.get_user_membership_status(v_user_id);
    v_remaining := (v_membership->>'remaining_contacts')::int;

    IF v_remaining <= 0 THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'status', 'quota_exceeded',
            'error', 'quota_exceeded',
            'remaining_contacts', 0,
            'tier', v_membership->>'tier',
            'message', 'You have used all contact views for your plan. Please upgrade to view more contacts.'
        );
    END IF;

    -- Record unlock
    INSERT INTO public.contact_unlocks (user_id, target_profile_id)
    VALUES (v_user_id, p_target_id)
    ON CONFLICT (user_id, target_profile_id) DO NOTHING;

    -- Increment usage on subscription
    UPDATE public.user_subscriptions
    SET contacts_unlocked_count = contacts_unlocked_count + 1,
        updated_at = now()
    WHERE user_id = v_user_id
      AND status = 'active'
      AND (expires_at IS NULL OR expires_at > now());

    RETURN jsonb_build_object(
        'allowed', true,
        'status', 'unlocked',
        'phone', v_target_profile.phone,
        'email', v_target_profile.email,
        'remaining_contacts', v_remaining - 1,
        'message', 'Contact unlocked successfully'
    );
END;
$function$;

-- Protect matches RPC against suspended callers
CREATE OR REPLACE FUNCTION public.get_top_matches_v2(p_user_id uuid, p_limit integer DEFAULT 10, p_offset integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_cached jsonb;
  v_result jsonb;
BEGIN
  IF p_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  IF public.is_user_suspended(p_user_id) THEN
    RAISE EXCEPTION 'Access denied: account suspended';
  END IF;

  SELECT matches INTO v_cached
  FROM public.user_match_cache
  WHERE user_id = p_user_id;

  IF v_cached IS NOT NULL THEN
    SELECT jsonb_agg(m) INTO v_result
    FROM (
      SELECT m
      FROM jsonb_array_elements(v_cached) WITH ORDINALITY AS arr(m, ord)
      ORDER BY ord
      LIMIT p_limit OFFSET p_offset
    ) sub;
    RETURN COALESCE(v_result, '[]'::jsonb);
  END IF;

  RETURN '[]'::jsonb;
END;
$function$;

-- Protect discovery search against suspended callers
CREATE OR REPLACE FUNCTION public.search_discovery_profiles_v2(
  p_user_id uuid,
  p_query text DEFAULT NULL::text,
  p_sub_caste text DEFAULT NULL::text,
  p_min_age integer DEFAULT NULL::integer,
  p_max_age integer DEFAULT NULL::integer,
  p_city text DEFAULT NULL::text,
  p_limit integer DEFAULT 10,
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
  IF public.is_user_suspended(COALESCE(auth.uid(), p_user_id)) THEN
    RAISE EXCEPTION 'Access denied: account suspended';
  END IF;

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
    AND NOT EXISTS (
      SELECT 1 FROM public.user_blocks ub 
      WHERE (ub.blocker_id = v_effective_uid AND ub.blocked_id = p.id)
         OR (ub.blocker_id = p.id AND ub.blocked_id = v_effective_uid)
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.match_exclusions me 
      WHERE me.user_id = v_effective_uid AND me.excluded_id = p.id
    )
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

-- -----------------------------------------------------------------------------
-- 5. Privileges and EXECUTE Grants Review
-- -----------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.admin_toggle_suspend(uuid, boolean, text) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.admin_toggle_suspend(uuid, boolean, text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.admin_delete_user(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.admin_delete_user(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.delete_user_account() FROM anon, public;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.get_sidebar_summary(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.get_sidebar_summary(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.get_user_membership_status(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.get_user_membership_status(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.get_incoming_horoscope_requests(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.get_incoming_horoscope_requests(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.get_visited_profiles_with_score(uuid, integer) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.get_visited_profiles_with_score(uuid, integer) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.can_access_chat_storage(text, uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.can_access_chat_storage(text, uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.can_upload_chat_storage(text, uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.can_upload_chat_storage(text, uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.can_access_family_voice_storage(text, uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.can_access_family_voice_storage(text, uuid) TO authenticated, service_role;
