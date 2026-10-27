-- ── Migration: 20260922000002_guardian_advanced_controls.sql ──────────

-- 1. Add Veto Power to Candidate Profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS allow_guardian_proxy_chat BOOLEAN DEFAULT true;

-- 2. Add 'request_connect' to family reviews constraint
ALTER TABLE public.family_profile_reviews DROP CONSTRAINT IF EXISTS family_profile_reviews_reaction_check;
ALTER TABLE public.family_profile_reviews ADD CONSTRAINT family_profile_reviews_reaction_check CHECK (reaction IN ('shortlist', 'discuss', 'decline', 'request_connect'));

-- 3. Enforce Veto Power in send_proxy_message RPC
CREATE OR REPLACE FUNCTION public.send_proxy_message(
    p_conversation_id uuid,
    p_receiver_id uuid,
    p_content text,
    p_sender_role text,
    p_on_behalf_of uuid
)
RETURNS public.messages
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_message public.messages;
    v_allow_proxy boolean;
BEGIN
    -- Enforce Veto Power
    SELECT allow_guardian_proxy_chat INTO v_allow_proxy FROM public.profiles WHERE id = p_on_behalf_of;
    IF COALESCE(v_allow_proxy, true) = false THEN
        RAISE EXCEPTION 'Candidate has disabled proxy chatting for guardians.';
    END IF;

    INSERT INTO public.messages (
        conversation_id,
        sender_id,
        receiver_id,
        content,
        proxy_sender_id,
        proxy_sender_role
    ) VALUES (
        p_conversation_id,
        p_on_behalf_of,
        p_receiver_id,
        p_content,
        auth.uid(),
        p_sender_role
    ) RETURNING * INTO v_message;
    
    RETURN v_message;
END;
$$;
