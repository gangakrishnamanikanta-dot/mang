-- =====================================================================
-- Unified Proxy Chat: Guardians Chatting on Behalf of Candidate
-- =====================================================================

-- 1. Add proxy tracking columns to the main 1-on-1 messages table
ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS proxy_sender_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS proxy_sender_role text;

-- 2. Create a secure RPC for guardians to send messages on behalf of their candidate
CREATE OR REPLACE FUNCTION public.send_proxy_message(
  p_conversation_id uuid,
  p_receiver_id uuid,
  p_content text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_guardian_id uuid;
  v_candidate_id uuid;
  v_guardian_role text;
  v_msg_id uuid;
BEGIN
  v_guardian_id := auth.uid();
  IF v_guardian_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Verify the guardian is part of a family circle, and get the candidate_id and role
  SELECT fc.candidate_id, fm.role 
  INTO v_candidate_id, v_guardian_role
  FROM public.family_members fm
  JOIN public.family_circles fc ON fc.id = fm.family_circle_id
  WHERE fm.user_id = v_guardian_id AND fm.role <> 'Candidate'
  LIMIT 1;

  IF v_candidate_id IS NULL THEN
    RAISE EXCEPTION 'Access denied: You are not a registered guardian.';
  END IF;

  -- Ensure the conversation belongs to the candidate
  IF NOT EXISTS (
    SELECT 1 FROM public.conversations 
    WHERE id = p_conversation_id AND (user1_id = v_candidate_id OR user2_id = v_candidate_id)
  ) THEN
    RAISE EXCEPTION 'Access denied: Conversation does not belong to candidate.';
  END IF;

  -- Insert the message using the candidate as the sender, but tagging the proxy
  INSERT INTO public.messages (
    conversation_id, sender_id, receiver_id, content, proxy_sender_id, proxy_sender_role
  ) VALUES (
    p_conversation_id, v_candidate_id, p_receiver_id, p_content, v_guardian_id, v_guardian_role
  ) RETURNING id INTO v_msg_id;

  RETURN v_msg_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.send_proxy_message(uuid, uuid, text) TO authenticated;
