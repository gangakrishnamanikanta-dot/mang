-- =============================================================================
-- Migration: 20260927000001_fix_family_and_proxy_chat_e2e.sql
-- Purpose:
--   1. Helper function get_guardian_candidate_id(uuid) for RLS & RPCs
--   2. Update conversations RLS policies so Guardians can view/update their Candidate's threads
--   3. Update get_or_create_conversation, mark_conversation_read, mark_messages_delivered for Guardians
--   4. Update get_guardian_active_candidate to include allow_guardian_proxy_chat
--   5. Unify send_proxy_message with E2EE nonce support + strict Candidate Veto enforcement
--   6. Enable Realtime on family_messages & family_profile_reviews + system welcome message on join
-- =============================================================================

-- 1. Helper function to resolve a Guardian's linked Candidate ID
CREATE OR REPLACE FUNCTION public.get_guardian_candidate_id(p_user_id uuid DEFAULT auth.uid())
RETURNS uuid
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT fc.candidate_id
  FROM public.family_members fm
  JOIN public.family_circles fc ON fc.id = fm.family_circle_id
  WHERE fm.user_id = p_user_id
    AND fm.role <> 'Candidate'
  LIMIT 1;
$$;

-- 2. Update conversations RLS policies so linked Guardians can view & update their Candidate's conversations
DROP POLICY IF EXISTS "Users can view their own conversations" ON public.conversations;
CREATE POLICY "Users can view their own conversations"
ON public.conversations
FOR SELECT
USING (
  auth.uid() = user1_id
  OR auth.uid() = user2_id
  OR public.get_guardian_candidate_id(auth.uid()) IN (user1_id, user2_id)
);

DROP POLICY IF EXISTS "Users can update conversations they participate in" ON public.conversations;
CREATE POLICY "Users can update conversations they participate in"
ON public.conversations
FOR UPDATE
USING (
  auth.uid() = user1_id
  OR auth.uid() = user2_id
  OR public.get_guardian_candidate_id(auth.uid()) IN (user1_id, user2_id)
);

-- 3. Update get_or_create_conversation to resolve Guardian's linked candidate_id
CREATE OR REPLACE FUNCTION public.get_or_create_conversation(p_other_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id uuid := auth.uid();
    v_effective_id uuid;
    v_conv_id uuid;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_effective_id := COALESCE(public.get_guardian_candidate_id(v_caller_id), v_caller_id);

    IF v_effective_id = p_other_user_id THEN
        RAISE EXCEPTION 'Cannot create conversation with yourself';
    END IF;

    SELECT id INTO v_conv_id
    FROM public.conversations
    WHERE (user1_id = v_effective_id AND user2_id = p_other_user_id)
       OR (user1_id = p_other_user_id AND user2_id = v_effective_id)
    LIMIT 1;

    IF v_conv_id IS NOT NULL THEN
        RETURN v_conv_id;
    END IF;

    INSERT INTO public.conversations (user1_id, user2_id)
    VALUES (v_effective_id, p_other_user_id)
    RETURNING id INTO v_conv_id;

    RETURN v_conv_id;
END;
$function$;

-- 4. Update mark_conversation_read and mark_messages_delivered to support Guardians
CREATE OR REPLACE FUNCTION public.mark_conversation_read(p_conversation_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id uuid := auth.uid();
    v_effective_id uuid;
    v_conv record;
    v_marked_count int := 0;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
    END IF;

    v_effective_id := COALESCE(public.get_guardian_candidate_id(v_caller_id), v_caller_id);

    SELECT * INTO v_conv
    FROM public.conversations
    WHERE id = p_conversation_id 
      AND (user1_id = v_effective_id OR user2_id = v_effective_id);

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'conversation_not_found');
    END IF;

    UPDATE public.messages
    SET is_read = true
    WHERE conversation_id = p_conversation_id
      AND receiver_id = v_effective_id
      AND is_read = false;

    GET DIAGNOSTICS v_marked_count = ROW_COUNT;

    IF v_conv.user1_id = v_effective_id THEN
        UPDATE public.conversations
        SET user1_unread_count = 0
        WHERE id = p_conversation_id;
    ELSE
        UPDATE public.conversations
        SET user2_unread_count = 0
        WHERE id = p_conversation_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'conversation_id', p_conversation_id,
        'messages_marked_read', v_marked_count
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.mark_messages_delivered(p_conversation_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id uuid := auth.uid();
    v_effective_id uuid;
    v_marked_count int := 0;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
    END IF;

    v_effective_id := COALESCE(public.get_guardian_candidate_id(v_caller_id), v_caller_id);

    IF NOT EXISTS (
        SELECT 1 FROM public.conversations
        WHERE id = p_conversation_id 
          AND (user1_id = v_effective_id OR user2_id = v_effective_id)
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'conversation_not_found');
    END IF;

    UPDATE public.messages
    SET is_delivered = true,
        delivered_at = now()
    WHERE conversation_id = p_conversation_id
      AND receiver_id = v_effective_id
      AND is_delivered = false;

    GET DIAGNOSTICS v_marked_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'conversation_id', p_conversation_id,
        'messages_marked_delivered', v_marked_count
    );
END;
$function$;

-- 5. Update get_guardian_active_candidate to include allow_guardian_proxy_chat
DROP FUNCTION IF EXISTS public.get_guardian_active_candidate(uuid);
CREATE OR REPLACE FUNCTION public.get_guardian_active_candidate(p_guardian_id uuid DEFAULT auth.uid())
RETURNS TABLE(
    candidate_id uuid,
    candidate_name text,
    gender text,
    caste_id integer,
    sub_caste text,
    gothram_id integer,
    nakshatra_id integer,
    rashi_id integer,
    photo_url text,
    circle_id uuid,
    guardian_role text,
    allow_guardian_proxy_chat boolean
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        p.id AS candidate_id,
        p.full_name AS candidate_name,
        p.gender,
        p.caste_id,
        p.sub_caste,
        p.gothram_id,
        p.nakshatra_id,
        p.rashi_id,
        p.profile_photo_url AS photo_url,
        fc.id AS circle_id,
        fm.role AS guardian_role,
        COALESCE(p.allow_guardian_proxy_chat, true) AS allow_guardian_proxy_chat
    FROM public.family_members fm
    JOIN public.family_circles fc ON fc.id = fm.family_circle_id
    JOIN public.profiles p ON p.id = fc.candidate_id
    WHERE fm.user_id = p_guardian_id
      AND fm.role <> 'Candidate'
    LIMIT 1;
END;
$function$;

-- 6. Replace send_proxy_message overloads with a single unified function supporting E2EE nonce + Veto check
DROP FUNCTION IF EXISTS public.send_proxy_message(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.send_proxy_message(uuid, uuid, text, text, uuid);
DROP FUNCTION IF EXISTS public.send_proxy_message(uuid, uuid, text, text, text, uuid);

CREATE OR REPLACE FUNCTION public.send_proxy_message(
    p_conversation_id uuid,
    p_receiver_id uuid,
    p_content text,
    p_nonce text DEFAULT ''::text,
    p_sender_role text DEFAULT NULL::text,
    p_on_behalf_of uuid DEFAULT NULL::uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_guardian_id uuid := auth.uid();
    v_candidate_id uuid;
    v_guardian_role text;
    v_allow_proxy boolean;
    v_msg_id uuid;
BEGIN
    IF v_guardian_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT fc.candidate_id, fm.role
    INTO v_candidate_id, v_guardian_role
    FROM public.family_members fm
    JOIN public.family_circles fc ON fc.id = fm.family_circle_id
    WHERE fm.user_id = v_guardian_id
      AND fm.role <> 'Candidate'
      AND (p_on_behalf_of IS NULL OR fc.candidate_id = p_on_behalf_of)
    LIMIT 1;

    IF v_candidate_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: You are not a registered guardian.';
    END IF;

    SELECT COALESCE(allow_guardian_proxy_chat, true)
    INTO v_allow_proxy
    FROM public.profiles
    WHERE id = v_candidate_id;

    IF v_allow_proxy = false THEN
        RAISE EXCEPTION 'Candidate has disabled guardian proxy messaging.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.conversations
        WHERE id = p_conversation_id
          AND (user1_id = v_candidate_id OR user2_id = v_candidate_id)
    ) THEN
        RAISE EXCEPTION 'Access denied: Conversation does not belong to candidate.';
    END IF;

    INSERT INTO public.messages (
        conversation_id,
        sender_id,
        receiver_id,
        content,
        nonce,
        proxy_sender_id,
        proxy_sender_role,
        on_behalf_of,
        is_delivered,
        is_read
    ) VALUES (
        p_conversation_id,
        v_candidate_id,
        p_receiver_id,
        p_content,
        COALESCE(p_nonce, ''),
        v_guardian_id,
        COALESCE(NULLIF(TRIM(p_sender_role), ''), v_guardian_role),
        v_candidate_id,
        false,
        false
    ) RETURNING id INTO v_msg_id;

    RETURN v_msg_id;
END;
$function$;

-- 7. Realtime publication & welcome system message on join_family_circle
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'family_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.family_messages;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'family_profile_reviews'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.family_profile_reviews;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.join_family_circle(
    p_invite_code text,
    p_role text DEFAULT 'Parent'::text,
    p_display_name text DEFAULT 'Family Member'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_user_id uuid;
    v_circle record;
    v_guardian_count int;
    v_already_member boolean;
    v_valid_roles text[] := ARRAY['Father', 'Mother', 'Brother', 'Sister', 'Relative', 'Guardian', 'Parent'];
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('status', 'error', 'message', 'Authentication required');
    END IF;

    IF NOT (p_role = ANY(v_valid_roles)) THEN
        RETURN jsonb_build_object('status', 'error', 'message', 'Invalid guardian role specified');
    END IF;

    SELECT * INTO v_circle
    FROM public.family_circles
    WHERE UPPER(invite_code) = UPPER(TRIM(p_invite_code));

    IF v_circle.id IS NULL THEN
        RETURN jsonb_build_object('status', 'error', 'message', 'Invalid invite code');
    END IF;

    IF v_circle.candidate_id = v_user_id THEN
        RETURN jsonb_build_object('status', 'error', 'message', 'Candidate cannot join their own circle as guardian');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.family_members
        WHERE family_circle_id = v_circle.id AND user_id = v_user_id
    ) INTO v_already_member;

    SELECT count(*) INTO v_guardian_count
    FROM public.family_members
    WHERE family_circle_id = v_circle.id
      AND role <> 'Candidate'
      AND user_id <> v_user_id;

    IF v_guardian_count >= 2 THEN
        RETURN jsonb_build_object(
            'status', 'error', 
            'message', 'This candidate profile already has the maximum of 2 connected guardian accounts.'
        );
    END IF;

    UPDATE public.profiles
    SET account_type = 'guardian'
    WHERE id = v_user_id;

    INSERT INTO public.family_members (family_circle_id, user_id, role, display_name)
    VALUES (v_circle.id, v_user_id, p_role, p_display_name)
    ON CONFLICT (family_circle_id, user_id) 
    DO UPDATE SET role = EXCLUDED.role, display_name = EXCLUDED.display_name;

    IF NOT v_already_member THEN
        INSERT INTO public.family_messages (
            family_circle_id,
            sender_id,
            sender_name,
            sender_role,
            message_type,
            content
        ) VALUES (
            v_circle.id,
            v_user_id,
            COALESCE(NULLIF(TRIM(p_display_name), ''), p_role),
            p_role,
            'system',
            '🪔 ' || COALESCE(NULLIF(TRIM(p_display_name), ''), p_role) || ' (' || p_role || ') joined the Sacred Family Room.'
        );
    END IF;

    RETURN jsonb_build_object(
        'status', 'success',
        'circle_id', v_circle.id,
        'family_name', v_circle.family_name,
        'candidate_id', v_circle.candidate_id
    );
END;
$function$;
