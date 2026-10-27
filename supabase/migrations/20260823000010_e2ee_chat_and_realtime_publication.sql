-- ── Migration: 20260823000010_e2ee_chat_and_realtime_publication.sql ──────────
--
-- 1. E2EE Public Key Registry:
--    - Stores public X25519 identity keys for client-side envelope encryption.
--    - Private keys are NEVER stored on the server.
--
-- 2. Realtime Publication Setup:
--    - Adds `messages` and `conversations` to `supabase_realtime` publication.
--
-- 3. Interest-Status Gated RLS on Messages:
--    - Only allows message INSERT if mutual interest status is 'accepted' or unlocked.
--
-- 4. Atomic Read-Receipt RPC:
--    - Single-transaction mark_conversation_read that updates messages and resets unread counters.


-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. E2EE PUBLIC KEY REGISTRY
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.user_encryption_keys (
    user_id         uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    public_key      text NOT NULL,              -- Base64 encoded X25519 public key
    key_version     integer NOT NULL DEFAULT 1,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_encryption_keys ENABLE ROW LEVEL SECURITY;

-- Any authenticated user can read public keys (needed for ECDH shared secret derivation)
CREATE POLICY "Public keys are readable by authenticated users"
    ON public.user_encryption_keys FOR SELECT
    TO authenticated
    USING (true);

-- Users can only insert/update their own public key
CREATE POLICY "Users can manage their own public key"
    ON public.user_encryption_keys FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.set_user_public_key(p_public_key text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
    END IF;

    IF p_public_key IS NULL OR TRIM(p_public_key) = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'invalid_public_key');
    END IF;

    INSERT INTO public.user_encryption_keys (user_id, public_key, updated_at)
    VALUES (v_user_id, p_public_key, now())
    ON CONFLICT (user_id) DO UPDATE
    SET public_key = EXCLUDED.public_key,
        updated_at = now();

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'public_key', p_public_key
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_public_key(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_key text;
BEGIN
    SELECT public_key INTO v_key
    FROM public.user_encryption_keys
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'key_not_found');
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', p_user_id,
        'public_key', v_key
    );
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. MESSAGES TABLE SCHEMA HARDENING & RLS GATING
-- ═══════════════════════════════════════════════════════════════════════════════

-- Ensure columns exist for E2EE payload
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS nonce text DEFAULT '';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS sender_public_key text DEFAULT '';

-- RLS: Only allow message inserts if interest status is 'accepted' between the two parties
DROP POLICY IF EXISTS "Users can insert their own messages" ON public.messages;
CREATE POLICY "Users can insert their own messages with accepted interest"
    ON public.messages FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = sender_id
        AND EXISTS (
            SELECT 1 FROM public.interests i
            WHERE (
                (i.sender_profile_id = auth.uid() AND i.receiver_profile_id = receiver_id)
                OR
                (i.sender_profile_id = receiver_id AND i.receiver_profile_id = auth.uid())
            )
            AND i.status = 'accepted'
        )
    );


-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. ATOMIC READ-RECEIPT RPC
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.mark_conversation_read(p_conversation_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_conv record;
    v_marked_count int := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
    END IF;

    -- Verify user is a participant
    SELECT * INTO v_conv
    FROM public.conversations
    WHERE id = p_conversation_id 
      AND (user1_id = v_user_id OR user2_id = v_user_id);

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'conversation_not_found');
    END IF;

    -- Batch update all unread messages where caller is the receiver
    UPDATE public.messages
    SET is_read = true
    WHERE conversation_id = p_conversation_id
      AND receiver_id = v_user_id
      AND is_read = false;

    GET DIAGNOSTICS v_marked_count = ROW_COUNT;

    -- Reset unread counter for caller atomically
    IF v_conv.user1_id = v_user_id THEN
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
$$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. REALTIME PUBLICATION CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
    -- Add messages and conversations to supabase_realtime if not already present
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'conversations'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        NULL; -- Ignore if publication already configured
END $$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. PERMISSIONS & SECURITY
-- ═══════════════════════════════════════════════════════════════════════════════

REVOKE EXECUTE ON FUNCTION public.set_user_public_key(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_user_public_key(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_conversation_read(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.set_user_public_key(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_user_public_key(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mark_conversation_read(uuid) TO authenticated, service_role;

GRANT SELECT, INSERT, UPDATE ON public.user_encryption_keys TO authenticated;
GRANT ALL ON public.user_encryption_keys TO service_role;
