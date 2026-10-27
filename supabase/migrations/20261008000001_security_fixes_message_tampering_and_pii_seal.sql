-- ============================================================================
-- Migration: 20261008000001_security_fixes_message_tampering_and_pii_seal.sql
-- Purpose:
--   1. Prevent message content tampering by adding a BEFORE UPDATE trigger
--      on public.messages that enforces immutability of content, sender,
--      receiver, conversation, and nonce.
--   2. Seal PII exposure on public.profiles table by dropping the overly
--      permissive "Authenticated users can view profiles" policy.
--      (Candidate browsing uses the sanitized public_profiles view;
--       contact phone reveals are governed by unlock_contact_number RPC).
--   3. Drop the duplicate older insert policy on public.messages.
-- ============================================================================

-- 1. Message Immutability Trigger
CREATE OR REPLACE FUNCTION public.trg_prevent_message_tampering()
RETURNS TRIGGER AS $$
BEGIN
  -- Allow content update ONLY if it is the official soft-delete from delete_message RPC
  IF (OLD.content IS DISTINCT FROM NEW.content AND NEW.content != 'This message was deleted')
     OR OLD.sender_id IS DISTINCT FROM NEW.sender_id
     OR OLD.receiver_id IS DISTINCT FROM NEW.receiver_id
     OR OLD.conversation_id IS DISTINCT FROM NEW.conversation_id
     OR (OLD.nonce IS DISTINCT FROM NEW.nonce AND NEW.nonce != '') THEN
    RAISE EXCEPTION 'Message core fields (content, sender, receiver, nonce, conversation) are immutable and cannot be modified';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_message_immutability ON public.messages;
CREATE TRIGGER trg_message_immutability
BEFORE UPDATE ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.trg_prevent_message_tampering();

-- 2. Seal PII on profiles table
DROP POLICY IF EXISTS "Authenticated users can view profiles" ON public.profiles;

-- Ensure "Users can view own profile" exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'profiles' AND schemaname = 'public' AND policyname = 'Users can view own profile'
  ) THEN
    CREATE POLICY "Users can view own profile" ON public.profiles
      FOR SELECT TO authenticated
      USING (auth.uid() = id);
  END IF;
END $$;

-- 3. Drop duplicate older insert policy on messages
DROP POLICY IF EXISTS "Users can insert their own messages with accepted interest" ON public.messages;
