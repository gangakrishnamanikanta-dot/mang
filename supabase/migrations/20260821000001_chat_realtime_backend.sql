-- ============================================================================
-- Migration: 20260821000001_chat_realtime_backend.sql
-- Description: Real-time Conversations & Messaging Tables with RLS & Publication
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.conversations (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user1_id            uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    user2_id            uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    last_message        text DEFAULT '',
    last_message_time   timestamptz DEFAULT now(),
    last_sender_id      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    user1_unread_count  integer NOT NULL DEFAULT 0,
    user2_unread_count  integer NOT NULL DEFAULT 0,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_distinct_users CHECK (user1_id <> user2_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_conversations_pair 
  ON public.conversations (LEAST(user1_id, user2_id), GREATEST(user1_id, user2_id));

CREATE TABLE IF NOT EXISTS public.messages (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id     uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id           uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    receiver_id         uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content             text NOT NULL,
    is_read             boolean NOT NULL DEFAULT false,
    created_at          timestamptz NOT NULL DEFAULT now()
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_conversations_user1 ON public.conversations(user1_id, last_message_time DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_user2 ON public.conversations(user2_id, last_message_time DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conv ON public.messages(conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_unread ON public.messages(receiver_id, is_read) WHERE is_read = false;

-- RLS Policies
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own conversations" ON public.conversations;
CREATE POLICY "Users can view their own conversations"
  ON public.conversations FOR SELECT
  TO authenticated
  USING (auth.uid() = user1_id OR auth.uid() = user2_id);

DROP POLICY IF EXISTS "Users can insert conversations they participate in" ON public.conversations;
CREATE POLICY "Users can insert conversations they participate in"
  ON public.conversations FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);

DROP POLICY IF EXISTS "Users can update conversations they participate in" ON public.conversations;
CREATE POLICY "Users can update conversations they participate in"
  ON public.conversations FOR UPDATE
  TO authenticated
  USING (auth.uid() = user1_id OR auth.uid() = user2_id);

DROP POLICY IF EXISTS "Users can view messages in their conversations" ON public.messages;
CREATE POLICY "Users can view messages in their conversations"
  ON public.messages FOR SELECT
  TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users can insert their own messages" ON public.messages;
CREATE POLICY "Users can insert their own messages"
  ON public.messages FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = sender_id);

DROP POLICY IF EXISTS "Receivers can mark messages as read" ON public.messages;
CREATE POLICY "Receivers can mark messages as read"
  ON public.messages FOR UPDATE
  TO authenticated
  USING (auth.uid() = receiver_id)
  WITH CHECK (auth.uid() = receiver_id);

-- Auto-update conversation on message insert
CREATE OR REPLACE FUNCTION public.handle_new_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
    UPDATE public.conversations
    SET 
        last_message = NEW.content,
        last_message_time = NEW.created_at,
        last_sender_id = NEW.sender_id,
        user1_unread_count = CASE 
            WHEN user1_id = NEW.receiver_id THEN user1_unread_count + 1 
            ELSE user1_unread_count 
        END,
        user2_unread_count = CASE 
            WHEN user2_id = NEW.receiver_id THEN user2_unread_count + 1 
            ELSE user2_unread_count 
        END,
        updated_at = now()
    WHERE id = NEW.conversation_id;
    
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_on_new_message ON public.messages;
CREATE TRIGGER trg_on_new_message
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_message();

-- RPC to get or create conversation
CREATE OR REPLACE FUNCTION public.get_or_create_conversation(p_other_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_my_id uuid := auth.uid();
    v_conv_id uuid;
BEGIN
    IF v_my_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    
    IF v_my_id = p_other_user_id THEN
        RAISE EXCEPTION 'Cannot create conversation with yourself';
    END IF;

    SELECT id INTO v_conv_id
    FROM public.conversations
    WHERE (user1_id = v_my_id AND user2_id = p_other_user_id)
       OR (user1_id = p_other_user_id AND user2_id = v_my_id)
    LIMIT 1;

    IF v_conv_id IS NOT NULL THEN
        RETURN v_conv_id;
    END IF;

    INSERT INTO public.conversations (user1_id, user2_id)
    VALUES (v_my_id, p_other_user_id)
    RETURNING id INTO v_conv_id;

    RETURN v_conv_id;
END;
$$;
