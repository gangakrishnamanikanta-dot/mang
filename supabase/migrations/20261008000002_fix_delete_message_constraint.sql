-- ============================================================================
-- Migration: 20261008000002_fix_delete_message_constraint.sql
-- Purpose:
--   1. Update delete_message RPC to set content = 'e2ee:deleted' so it satisfies
--      the table check constraint chk_content_encrypted (CHECK content LIKE 'e2ee:%').
--   2. Update trg_prevent_message_tampering trigger to permit the official
--      soft-delete update (content = 'e2ee:deleted', is_deleted = true).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trg_prevent_message_tampering()
RETURNS TRIGGER AS $$
BEGIN
  -- If message is being soft-deleted, allow it
  IF NEW.is_deleted = true AND (NEW.content = 'e2ee:deleted' OR NEW.content = 'This message was deleted') THEN
    RETURN NEW;
  END IF;

  IF (OLD.content IS DISTINCT FROM NEW.content)
     OR OLD.sender_id IS DISTINCT FROM NEW.sender_id
     OR OLD.receiver_id IS DISTINCT FROM NEW.receiver_id
     OR OLD.conversation_id IS DISTINCT FROM NEW.conversation_id
     OR (OLD.nonce IS DISTINCT FROM NEW.nonce AND NEW.nonce != '') THEN
    RAISE EXCEPTION 'Message core fields (content, sender, receiver, nonce, conversation) are immutable and cannot be modified';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.delete_message(p_message_id uuid, p_delete_for_everyone boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_user_id uuid := auth.uid();
    v_msg record;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
    END IF;

    SELECT * INTO v_msg
    FROM public.messages
    WHERE id = p_message_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'message_not_found');
    END IF;

    IF v_msg.sender_id != v_user_id AND v_msg.receiver_id != v_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthorized');
    END IF;

    IF p_delete_for_everyone THEN
        IF v_msg.sender_id != v_user_id THEN
            RETURN jsonb_build_object('success', false, 'error', 'only_sender_can_delete_for_everyone');
        END IF;

        IF v_msg.created_at < (now() - interval '24 hours') THEN
            RETURN jsonb_build_object('success', false, 'error', 'delete_window_expired');
        END IF;

        UPDATE public.messages
        SET is_deleted = true,
            content = 'e2ee:deleted',
            nonce = ''
        WHERE id = p_message_id;

        UPDATE public.conversations
        SET last_message = '🚫 This message was deleted'
        WHERE id = v_msg.conversation_id AND last_message_time = v_msg.created_at;

        RETURN jsonb_build_object(
            'success', true,
            'message_id', p_message_id,
            'type', 'deleted_for_everyone'
        );
    ELSE
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
$function$;
