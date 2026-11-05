-- ==============================================================================
-- Mangalasutram: Real-Time Notifications Automation Engine
-- Automatically populates `notifications` table on:
-- 1. Sacred Interest Sent (interest_received)
-- 2. Sacred Interest Accepted (interest_accepted)
-- 3. New Chat Message Received (chat_message)
-- 4. Profile Visited with 4-hour anti-spam debounce (profile_visit)
-- ==============================================================================

-- 1. Handler for Interests Lifecycle
CREATE OR REPLACE FUNCTION public.handle_interest_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_sender_name text;
  v_receiver_name text;
BEGIN
  -- Event 1: New Interest Received
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    SELECT COALESCE(NULLIF(trim(full_name), ''), 'A candidate')
    INTO v_sender_name
    FROM public.profiles
    WHERE id = NEW.sender_profile_id;

    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      body,
      payload,
      is_read,
      is_dismissed,
      created_at
    ) VALUES (
      NEW.receiver_profile_id,
      'interest_received',
      'New Sacred Interest',
      v_sender_name || ' has expressed sacred interest in your profile.',
      jsonb_build_object(
        'sender_id', NEW.sender_profile_id,
        'interest_id', NEW.id
      ),
      false,
      false,
      now()
    );

  -- Event 2: Interest Accepted (Mutual Match unlocked)
  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    SELECT COALESCE(NULLIF(trim(full_name), ''), 'A candidate')
    INTO v_receiver_name
    FROM public.profiles
    WHERE id = NEW.receiver_profile_id;

    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      body,
      payload,
      is_read,
      is_dismissed,
      created_at
    ) VALUES (
      NEW.sender_profile_id,
      'interest_accepted',
      'Sacred Interest Accepted!',
      v_receiver_name || ' has accepted your sacred interest. You may now begin conversing.',
      jsonb_build_object(
        'partner_id', NEW.receiver_profile_id,
        'interest_id', NEW.id
      ),
      false,
      false,
      now()
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_interest_notification ON public.interests;
CREATE TRIGGER trg_interest_notification
AFTER INSERT OR UPDATE ON public.interests
FOR EACH ROW
EXECUTE FUNCTION public.handle_interest_notification();

-- 2. Handler for Chat Messages
CREATE OR REPLACE FUNCTION public.handle_chat_message_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_sender_name text;
BEGIN
  -- Prevent self-notifications
  IF NEW.sender_id = NEW.receiver_id THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(NULLIF(trim(full_name), ''), 'Someone')
  INTO v_sender_name
  FROM public.profiles
  WHERE id = NEW.sender_id;

  INSERT INTO public.notifications (
    user_id,
    type,
    title,
    body,
    payload,
    is_read,
    is_dismissed,
    created_at
  ) VALUES (
    NEW.receiver_id,
    'chat_message',
    'New Message from ' || v_sender_name,
    v_sender_name || ' sent you a message.',
    jsonb_build_object(
      'conversation_id', NEW.conversation_id,
      'sender_id', NEW.sender_id
    ),
    false,
    false,
    now()
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_chat_message_notification ON public.messages;
CREATE TRIGGER trg_chat_message_notification
AFTER INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.handle_chat_message_notification();

-- 3. Handler for Profile Visits (with 4-hour anti-spam debounce)
CREATE OR REPLACE FUNCTION public.handle_profile_visit_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_viewer_name text;
  v_recent_notif_exists boolean;
BEGIN
  -- Prevent self-view notifications
  IF NEW.viewer_id = NEW.viewed_id THEN
    RETURN NEW;
  END IF;

  -- Debounce: check if a profile_visit notification from this viewer was already sent within the past 4 hours
  SELECT EXISTS (
    SELECT 1 FROM public.notifications
    WHERE user_id = NEW.viewed_id
      AND type = 'profile_visit'
      AND (payload->>'viewer_id')::uuid = NEW.viewer_id
      AND created_at >= (now() - interval '4 hours')
  ) INTO v_recent_notif_exists;

  IF NOT v_recent_notif_exists THEN
    SELECT COALESCE(NULLIF(trim(full_name), ''), 'A candidate')
    INTO v_viewer_name
    FROM public.profiles
    WHERE id = NEW.viewer_id;

    INSERT INTO public.notifications (
      user_id,
      type,
      title,
      body,
      payload,
      is_read,
      is_dismissed,
      created_at
    ) VALUES (
      NEW.viewed_id,
      'profile_visit',
      'Profile Visited',
      v_viewer_name || ' viewed your sacred profile.',
      jsonb_build_object(
        'viewer_id', NEW.viewer_id
      ),
      false,
      false,
      now()
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profile_visit_notification ON public.profile_views;
CREATE TRIGGER trg_profile_visit_notification
AFTER INSERT ON public.profile_views
FOR EACH ROW
EXECUTE FUNCTION public.handle_profile_visit_notification();
