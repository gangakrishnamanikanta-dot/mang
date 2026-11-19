-- Migration: 20261119000002_notification_push_dispatch_trigger.sql
-- Description: Automatically dispatches background FCM push notifications via pg_net and send-push-notification edge function

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA net;

CREATE OR REPLACE FUNCTION public.handle_notification_push_dispatch()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_actor_name text := NULL;
BEGIN
  IF NEW.payload IS NOT NULL THEN
    IF NEW.payload ? 'sender_name' THEN
      v_actor_name := NEW.payload->>'sender_name';
    ELSIF NEW.payload ? 'viewer_name' THEN
      v_actor_name := NEW.payload->>'viewer_name';
    ELSIF NEW.payload ? 'partner_name' THEN
      v_actor_name := NEW.payload->>'partner_name';
    END IF;
  END IF;

  IF v_actor_name IS NULL AND NEW.body IS NOT NULL THEN
    v_actor_name := split_part(NEW.body, ' ', 1);
  END IF;

  PERFORM net.http_post(
    url := 'https://jvjfkufxwjcwsrzmnyry.supabase.co/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer mangalasutram_local_push_secret_2026_secure'
    ),
    body := jsonb_build_object(
      'recipient_user_id', NEW.user_id,
      'type', NEW.type,
      'actor_name', COALESCE(v_actor_name, 'A member'),
      'metadata', COALESCE(NEW.payload, '{}'::jsonb),
      'idempotency_key', 'notif_' || NEW.id::text
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Push notification dispatch failed for notification %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notification_push_dispatch ON public.notifications;

CREATE TRIGGER trg_notification_push_dispatch
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_notification_push_dispatch();

