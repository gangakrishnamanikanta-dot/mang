-- ── Migration: 20260824000001_chat_delivery_ticks.sql ──────────────────────────
--
-- WhatsApp-Grade 3-Tier Message Delivery Architecture:
-- 1. Adds `is_delivered` and `delivered_at` columns to `public.messages`.
-- 2. Creates atomic `mark_messages_delivered` RPC allowing recipient's device 
--    to acknowledge delivery receipt via WebSocket.
-- 3. Locks execution permissions to authenticated users only.

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. ADD DELIVERY TIMESTAMP COLUMNS
-- ═══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_delivered boolean NOT NULL DEFAULT false;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS delivered_at timestamptz;

-- Create partial index for ultra-fast un-delivered message lookups
CREATE INDEX IF NOT EXISTS idx_messages_undelivered 
    ON public.messages(conversation_id, receiver_id) 
    WHERE is_delivered = false;


-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. ATOMIC DELIVERY ACKNOWLEDGMENT RPC
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.mark_messages_delivered(p_conversation_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_marked_count int := 0;
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

    -- Batch update all un-delivered messages where caller is the receiver
    UPDATE public.messages
    SET is_delivered = true,
        delivered_at = now()
    WHERE conversation_id = p_conversation_id
      AND receiver_id = v_user_id
      AND is_delivered = false;

    GET DIAGNOSTICS v_marked_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'conversation_id', p_conversation_id,
        'messages_marked_delivered', v_marked_count
    );
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. PERMISSIONS
-- ═══════════════════════════════════════════════════════════════════════════════

REVOKE EXECUTE ON FUNCTION public.mark_messages_delivered(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_messages_delivered(uuid) TO authenticated, service_role;
