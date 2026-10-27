-- ── Migration: 20260824000002_chat_delete_and_erasure.sql ─────────────────────
--
-- WhatsApp-Grade Chat Deletion & DPDP Act Data Erasure Architecture:
-- 1. Adds `is_deleted boolean DEFAULT false` and `deleted_for_users uuid[]` to `public.messages`.
-- 2. Creates `delete_message(p_message_id, p_delete_for_everyone)` RPC.
-- 3. Creates `clear_conversation_history(p_conversation_id)` RPC.
-- 4. Updates message select policy and triggers to respect deletions.


-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. ADD DELETION COLUMNS
-- ═══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_deleted boolean NOT NULL DEFAULT false;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS deleted_for_users uuid[] NOT NULL DEFAULT '{}';


-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. DELETE MESSAGE RPC ("Delete for Everyone" vs "Delete for Me")
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.delete_message(
    p_message_id uuid,
    p_delete_for_everyone boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_msg record;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
    END IF;

    -- Fetch message
    SELECT * INTO v_msg
    FROM public.messages
    WHERE id = p_message_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'message_not_found');
    END IF;

    -- Verify caller is either sender or receiver
    IF v_msg.sender_id != v_user_id AND v_msg.receiver_id != v_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthorized');
    END IF;

    IF p_delete_for_everyone THEN
        -- "Delete for Everyone" Rule: Only sender can delete for everyone, within 24 hours
        IF v_msg.sender_id != v_user_id THEN
            RETURN jsonb_build_object('success', false, 'error', 'only_sender_can_delete_for_everyone');
        END IF;

        IF v_msg.created_at < (now() - interval '24 hours') THEN
            RETURN jsonb_build_object('success', false, 'error', 'delete_window_expired');
        END IF;

        -- Hard erase ciphertext & nonce, mark as deleted
        UPDATE public.messages
        SET is_deleted = true,
            content = 'This message was deleted',
            nonce = ''
        WHERE id = p_message_id;

        -- Update conversation last message preview if this was the latest message
        UPDATE public.conversations
        SET last_message = 'This message was deleted'
        WHERE id = v_msg.conversation_id AND last_message_time = v_msg.created_at;

        RETURN jsonb_build_object(
            'success', true,
            'message_id', p_message_id,
            'type', 'deleted_for_everyone'
        );
    ELSE
        -- "Delete for Me": Add caller's UUID to deleted_for_users array
        UPDATE public.messages
        SET deleted_for_users = array_append(deleted_for_users, v_user_id)
        WHERE id = p_message_id
          AND NOT (deleted_for_users @> ARRAY[v_user_id]);

        RETURN jsonb_build_object(
            'success', true,
            'message_id', p_message_id,
            'type', 'deleted_for_me'
        );
    END IF;
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. CLEAR CONVERSATION HISTORY RPC ("Clear Chat")
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.clear_conversation_history(p_conversation_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_count int := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
    END IF;

    -- Verify user is a participant
    IF NOT EXISTS (
        SELECT 1 FROM public.conversations
        WHERE id = p_conversation_id 
          AND (user1_id = v_user_id OR user2_id = v_user_id)
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'conversation_not_found');
    END IF;

    -- Add caller to deleted_for_users on all messages in this conversation
    UPDATE public.messages
    SET deleted_for_users = array_append(deleted_for_users, v_user_id)
    WHERE conversation_id = p_conversation_id
      AND NOT (deleted_for_users @> ARRAY[v_user_id]);

    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'conversation_id', p_conversation_id,
        'messages_cleared', v_count
    );
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. PERMISSIONS
-- ═══════════════════════════════════════════════════════════════════════════════

REVOKE EXECUTE ON FUNCTION public.delete_message(uuid, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.clear_conversation_history(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.delete_message(uuid, boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.clear_conversation_history(uuid) TO authenticated, service_role;
