-- =====================================================================
-- Migration: 20261014000002_notifications_and_device_tokens.sql
-- Description: Zero-Leak Notification History and Fully RPC-Mediated Device Tokens
-- Phase: Part 2, Task 2.1 — Final Realtime, Grant & Ownership Hardening
-- Author: Engineering Team
--
-- Security Rules & Design Directives:
-- 1. Table public.notifications:
--    - Ownership RLS Policy: SELECT policy strictly enforces auth.uid() = user_id.
--      (Does not filter is_dismissed in RLS, ensuring owners can always receive their
--      own UPDATE events in Realtime and audit their records).
--    - Active list queries and unread counts explicitly filter is_dismissed = false.
--    - Pagination validation: get_active_notifications() validates 1 <= limit <= 100 and offset >= 0.
--    - Realtime DELETE Leak Resolution:
--      Supabase Postgres Changes does not evaluate RLS on DELETE events (exposing IDs/data in WAL).
--      Resolved via User-Scoped Soft-Delete (is_dismissed, dismissed_at).
--      Dismissals execute as UPDATE events, where Supabase Realtime strictly enforces RLS (auth.uid() = user_id).
--      Physical DELETE is completely REVOKED from authenticated clients.
--    - Direct INSERT, UPDATE, and DELETE are completely REVOKED from authenticated clients.
--    - Clients CANNOT forge arbitrary notifications (creation restricted to service_role / backend triggers).
--    - Clients CANNOT alter notification content, recipient, payload, or type.
--    - Read and dismissal state modifications are mediated solely through secure RPCs:
--      mark_notification_as_read(), mark_all_notifications_as_read(),
--      dismiss_notification(), dismiss_all_notifications().
--    - Grants on client-specific RPCs requiring auth.uid() are granted strictly to 'authenticated',
--      avoiding contradictory service_role caller assumptions.
--    - Added to supabase_realtime publication with REPLICA IDENTITY DEFAULT.
--
-- 2. Table public.device_tokens:
--    - Complete Zero-Trust Table Isolation:
--      Flutter clients NEVER query device_tokens directly (FCM token is managed locally on device).
--      ALL table-level privileges (SELECT, INSERT, UPDATE, DELETE) are REVOKED from authenticated and anon.
--      Device registration and unregistration occur strictly via secure RPCs:
--      register_device_token() and remove_device_token().
--    - Unique constraint on fcm_token ensures 1 physical device = 1 active account.
--    - Safe device reassignment: register_device_token() rebinds token on account switch.
--    - Tokens cascade delete when auth.users account is removed.
--    - NO Realtime publication (device tokens must never leak via client websockets).
-- =====================================================================

-- ── 1. Create Notifications Table ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type          text        NOT NULL CHECK (length(type) > 0 AND length(type) <= 50 AND type ~ '^[a-z0-9_]+$'),
  title         text        NOT NULL CHECK (length(trim(title)) > 0 AND length(title) <= 200),
  body          text        NOT NULL CHECK (length(trim(body)) > 0 AND length(body) <= 1000),
  payload       jsonb       NOT NULL DEFAULT '{}'::jsonb CHECK (pg_column_size(payload) <= 8192),
  is_read       boolean     NOT NULL DEFAULT false,
  read_at       timestamptz DEFAULT NULL,
  is_dismissed  boolean     NOT NULL DEFAULT false,
  dismissed_at  timestamptz DEFAULT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Documentation
COMMENT ON TABLE public.notifications IS 'Audit-grade in-app notifications history for matrimonial alliances, astrology matches, and system alerts.';
COMMENT ON COLUMN public.notifications.type IS 'Notification category: interest_received, interest_accepted, interest_declined, chat_message, high_guna_milan, profile_visit, quota_exhausted, contact_locked, pending_reminder, family_action, promotional_offer, system.';
COMMENT ON COLUMN public.notifications.payload IS 'Non-sensitive navigation metadata (e.g. {route: "/profile", id: "..."}). Never store PII/chat text.';
COMMENT ON COLUMN public.notifications.is_dismissed IS 'Soft-delete flag ensuring client dismissals propagate via RLS-protected UPDATE events in Realtime rather than unauthenticated DELETEs.';

-- Chronological listing and pagination partial index (only active notifications)
CREATE INDEX IF NOT EXISTS idx_notifications_user_active_created
  ON public.notifications (user_id, created_at DESC)
  WHERE is_dismissed = false;

-- Fast unread badge counter partial index
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications (user_id)
  WHERE is_read = false AND is_dismissed = false;

-- Enable Row Level Security
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- ── 2. Explicit Notifications Permissions & RLS Policies ──────────────
-- Explicitly revoke all table permissions from PUBLIC, anon, and authenticated
REVOKE ALL ON TABLE public.notifications FROM PUBLIC, anon, authenticated;

-- Grant strictly SELECT to authenticated users (NO INSERT, NO UPDATE, NO DELETE)
GRANT SELECT ON TABLE public.notifications TO authenticated;
GRANT ALL ON TABLE public.notifications TO service_role;

-- Policy: Select own notifications (Pure ownership check without is_dismissed,
-- ensuring owners receive Realtime UPDATE events on dismissal and can access audit records)
DROP POLICY IF EXISTS "notifications_select_own" ON public.notifications;
CREATE POLICY "notifications_select_own"
  ON public.notifications FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- NOTE: No INSERT, UPDATE, or DELETE policies exist for 'authenticated'.
-- Direct client writes are rejected at the PostgreSQL privilege layer (42501).


-- ── 3. Notification Query, Read & Dismissal State RPCs ────────────────

-- RPC: Get active notifications (paginated, excluding dismissed, validated bounds)
CREATE OR REPLACE FUNCTION public.get_active_notifications(
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS SETOF public.notifications
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_limit int;
  v_offset int;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN;
  END IF;

  IF p_limit IS NOT NULL AND (p_limit < 1 OR p_limit > 100) THEN
    RAISE EXCEPTION 'Limit must be between 1 and 100';
  END IF;

  IF p_offset IS NOT NULL AND p_offset < 0 THEN
    RAISE EXCEPTION 'Offset must be non-negative';
  END IF;

  v_limit := COALESCE(p_limit, 50);
  v_offset := COALESCE(p_offset, 0);

  RETURN QUERY
  SELECT *
  FROM public.notifications
  WHERE user_id = auth.uid()
    AND is_dismissed = false
  ORDER BY created_at DESC
  LIMIT v_limit
  OFFSET v_offset;
END;
$$;

COMMENT ON FUNCTION public.get_active_notifications(int, int) IS 'Fetches paginated active notifications for the calling user with validated bounds, strictly excluding dismissed items.';
REVOKE ALL ON FUNCTION public.get_active_notifications(int, int) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_active_notifications(int, int) TO authenticated;


-- RPC: Mark a single notification as read
CREATE OR REPLACE FUNCTION public.mark_notification_as_read(p_notification_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_updated int;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.notifications
  SET 
    is_read = true,
    read_at = COALESCE(read_at, now())
  WHERE id = p_notification_id
    AND user_id = auth.uid()
    AND is_read = false
    AND is_dismissed = false;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated > 0;
END;
$$;

COMMENT ON FUNCTION public.mark_notification_as_read(uuid) IS 'Safely marks a single user-owned active notification as read.';
REVOKE ALL ON FUNCTION public.mark_notification_as_read(uuid) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.mark_notification_as_read(uuid) TO authenticated;


-- RPC: Mark all unread notifications as read
CREATE OR REPLACE FUNCTION public.mark_all_notifications_as_read()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_updated int;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.notifications
  SET 
    is_read = true,
    read_at = COALESCE(read_at, now())
  WHERE user_id = auth.uid()
    AND is_read = false
    AND is_dismissed = false;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated;
END;
$$;

COMMENT ON FUNCTION public.mark_all_notifications_as_read() IS 'Bulk marks all active unread notifications for the active user as read.';
REVOKE ALL ON FUNCTION public.mark_all_notifications_as_read() FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_as_read() TO authenticated;


-- RPC: Dismiss a single notification (soft-delete with RLS-protected Realtime broadcast)
CREATE OR REPLACE FUNCTION public.dismiss_notification(p_notification_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_dismissed int;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.notifications
  SET 
    is_dismissed = true,
    dismissed_at = now()
  WHERE id = p_notification_id
    AND user_id = auth.uid()
    AND is_dismissed = false;

  GET DIAGNOSTICS v_dismissed = ROW_COUNT;
  RETURN v_dismissed > 0;
END;
$$;

COMMENT ON FUNCTION public.dismiss_notification(uuid) IS 'Soft-deletes a notification, propagating through Realtime UPDATE without DELETE leaks.';
REVOKE ALL ON FUNCTION public.dismiss_notification(uuid) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.dismiss_notification(uuid) TO authenticated;


-- RPC: Dismiss all notifications (bulk inbox clear)
CREATE OR REPLACE FUNCTION public.dismiss_all_notifications()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_dismissed int;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.notifications
  SET 
    is_dismissed = true,
    dismissed_at = now()
  WHERE user_id = auth.uid()
    AND is_dismissed = false;

  GET DIAGNOSTICS v_dismissed = ROW_COUNT;
  RETURN v_dismissed;
END;
$$;

COMMENT ON FUNCTION public.dismiss_all_notifications() IS 'Bulk soft-deletes all notifications for the active user.';
REVOKE ALL ON FUNCTION public.dismiss_all_notifications() FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.dismiss_all_notifications() TO authenticated;


-- RPC: Get unread count
CREATE OR REPLACE FUNCTION public.get_unread_notifications_count()
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_count int;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN 0;
  END IF;

  SELECT count(*)::int INTO v_count
  FROM public.notifications
  WHERE user_id = auth.uid()
    AND is_read = false
    AND is_dismissed = false;

  RETURN COALESCE(v_count, 0);
END;
$$;

COMMENT ON FUNCTION public.get_unread_notifications_count() IS 'High-speed unread badge counter leveraging partial index.';
REVOKE ALL ON FUNCTION public.get_unread_notifications_count() FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_unread_notifications_count() TO authenticated;


-- ── 4. Create Device Tokens Table ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token    text        NOT NULL,
  platform     text        NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  device_info  jsonb       NOT NULL DEFAULT '{}'::jsonb CHECK (pg_column_size(device_info) <= 2048),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_device_tokens_fcm_token UNIQUE (fcm_token)
);

COMMENT ON TABLE public.device_tokens IS 'FCM device tokens for push notification delivery with single-device binding.';
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON public.device_tokens (user_id);
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- Permissions: Complete Zero-Trust Table Isolation
-- Flutter clients NEVER access device_tokens directly; all table-level access is revoked from clients.
REVOKE ALL ON TABLE public.device_tokens FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.device_tokens TO service_role;


-- ── 5. Device Token Registration RPCs ─────────────────────────────────

-- RPC: Register or rebind device token
CREATE OR REPLACE FUNCTION public.register_device_token(
  p_fcm_token   text,
  p_platform    text,
  p_device_info jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id    uuid;
  v_clean_tok  text;
  v_clean_plat text;
  v_token_id   uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to register device token';
  END IF;

  v_clean_tok := trim(p_fcm_token);
  -- Standard FCM registration tokens are 140-180 chars. Enforce safe bounds [32, 512] and alphanumeric/separator charset.
  IF v_clean_tok IS NULL OR length(v_clean_tok) < 32 OR length(v_clean_tok) > 512 THEN
    RAISE EXCEPTION 'Invalid FCM token string length (must be between 32 and 512 characters)';
  END IF;

  IF v_clean_tok !~ '^[A-Za-z0-9_\-:]+$' THEN
    RAISE EXCEPTION 'Invalid FCM token character set';
  END IF;

  v_clean_plat := lower(trim(p_platform));
  IF v_clean_plat NOT IN ('android', 'ios', 'web') THEN
    RAISE EXCEPTION 'Platform must be android, ios, or web';
  END IF;

  -- Reassignment / Upsert:
  -- If token exists, reassign it to the currently authenticated user and update timestamps.
  INSERT INTO public.device_tokens (
    user_id,
    fcm_token,
    platform,
    device_info,
    updated_at,
    last_seen_at
  )
  VALUES (
    v_user_id,
    v_clean_tok,
    v_clean_plat,
    COALESCE(p_device_info, '{}'::jsonb),
    now(),
    now()
  )
  ON CONFLICT (fcm_token)
  DO UPDATE SET
    user_id      = EXCLUDED.user_id,
    platform     = EXCLUDED.platform,
    device_info  = EXCLUDED.device_info,
    updated_at   = now(),
    last_seen_at = now()
  RETURNING id INTO v_token_id;

  RETURN v_token_id;
END;
$$;

COMMENT ON FUNCTION public.register_device_token(text, text, jsonb) IS 'Registers or reassigns an FCM token to the authenticated user via secure RPC.';
REVOKE ALL ON FUNCTION public.register_device_token(text, text, jsonb) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.register_device_token(text, text, jsonb) TO authenticated;


-- RPC: Remove device token on logout
CREATE OR REPLACE FUNCTION public.remove_device_token(p_fcm_token text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_deleted int;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  DELETE FROM public.device_tokens
  WHERE fcm_token = trim(p_fcm_token)
    AND user_id = auth.uid();

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted > 0;
END;
$$;

COMMENT ON FUNCTION public.remove_device_token(text) IS 'Removes an FCM device token upon user logout via secure RPC.';
REVOKE ALL ON FUNCTION public.remove_device_token(text) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.remove_device_token(text) TO authenticated;


-- ── 6. Realtime Publication Configuration ─────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END;
$$;


-- ── 7. Server-Side Push Dispatch Idempotency Store ────────────────────
CREATE TABLE IF NOT EXISTS public.push_dispatch_idempotency (
  idempotency_key text        PRIMARY KEY,
  status          text        NOT NULL CHECK (status IN ('in_flight', 'completed', 'expired_unconfirmed', 'tombstone_archived')),
  summary         jsonb       DEFAULT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  expires_at      timestamptz NOT NULL
);

COMMENT ON TABLE public.push_dispatch_idempotency IS 'Atomic deduplication store for server-side push dispatch events to prevent duplicate notifications across Edge Function isolates.';

CREATE INDEX IF NOT EXISTS idx_push_dispatch_idempotency_expires
  ON public.push_dispatch_idempotency (expires_at);

ALTER TABLE public.push_dispatch_idempotency ENABLE ROW LEVEL SECURITY;

-- Access strictly restricted to service_role (server-side only; zero client access)
REVOKE ALL ON TABLE public.push_dispatch_idempotency FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.push_dispatch_idempotency TO service_role;

-- RPC: Atomic claim for push dispatch idempotency with row-level locking
-- Note: Standard callers CANNOT bypass deduplication or force-retry.
CREATE OR REPLACE FUNCTION public.claim_push_idempotency(
  p_key text,
  p_ttl_seconds int DEFAULT 600
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_inserted record;
  v_existing record;
  v_now timestamptz := now();
  v_expires_at timestamptz := v_now + (COALESCE(p_ttl_seconds, 600) || ' seconds')::interval;
BEGIN
  IF p_key IS NULL OR length(trim(p_key)) = 0 THEN
    RAISE EXCEPTION 'Idempotency key cannot be empty';
  END IF;

  -- 1. Try atomic insert with conflict handling (fresh event)
  INSERT INTO public.push_dispatch_idempotency (
    idempotency_key,
    status,
    expires_at,
    created_at,
    updated_at
  )
  VALUES (
    trim(p_key),
    'in_flight',
    v_expires_at,
    v_now,
    v_now
  )
  ON CONFLICT (idempotency_key) DO NOTHING
  RETURNING * INTO v_inserted;

  IF v_inserted.idempotency_key IS NOT NULL THEN
    RETURN jsonb_build_object('claimed', true, 'status', 'in_flight');
  END IF;

  -- 2. Conflict occurred: Key already exists. Acquire row lock for safe evaluation
  SELECT * INTO v_existing
  FROM public.push_dispatch_idempotency
  WHERE idempotency_key = trim(p_key)
  FOR UPDATE;

  -- 3. Tombstone Terminal State: Key was already processed and archived. Replay is permanently blocked.
  IF v_existing.status = 'tombstone_archived' THEN
    RETURN jsonb_build_object(
      'claimed', false,
      'status', 'tombstone_archived'
    );
  END IF;

  -- 4. Completed State Evaluation
  IF v_existing.status = 'completed' THEN
    -- Active retention window: block duplicate and return cached summary
    IF v_now < v_existing.expires_at THEN
      RETURN jsonb_build_object(
        'claimed', false,
        'status', 'completed',
        'summary', v_existing.summary
      );
    END IF;

    -- Retention window elapsed: Transition key to tombstone_archived and purge payload summary
    UPDATE public.push_dispatch_idempotency
    SET
      status = 'tombstone_archived',
      summary = NULL,
      updated_at = v_now
    WHERE idempotency_key = trim(p_key);

    RETURN jsonb_build_object(
      'claimed', false,
      'status', 'tombstone_archived'
    );
  END IF;

  -- 5. In-Flight / Expired Claim Evaluation
  IF v_now < v_existing.expires_at THEN
    -- Active in-flight lease: worker is currently dispatching
    RETURN jsonb_build_object(
      'claimed', false,
      'status', 'in_flight'
    );
  END IF;

  -- Lease expired (previous isolate crashed or timed out after contacting FCM)
  -- Conservative policy: NEVER automatically redispatch. Mark as expired_unconfirmed.
  UPDATE public.push_dispatch_idempotency
  SET status = 'expired_unconfirmed', updated_at = v_now
  WHERE idempotency_key = trim(p_key)
    AND status = 'in_flight'
    AND expires_at <= v_now;

  RETURN jsonb_build_object(
    'claimed', false,
    'status', 'expired_unconfirmed'
  );
END;
$$;

COMMENT ON FUNCTION public.claim_push_idempotency(text, int) IS 'Atomically claims an idempotency key with row-level locking, tombstone protection, and zero client force-retry bypass.';
REVOKE ALL ON FUNCTION public.claim_push_idempotency(text, int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_push_idempotency(text, int) TO service_role;

-- RPC: Complete push dispatch idempotency
CREATE OR REPLACE FUNCTION public.complete_push_idempotency(
  p_key text,
  p_summary jsonb
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_updated int;
BEGIN
  IF p_key IS NULL OR length(trim(p_key)) = 0 THEN
    RAISE EXCEPTION 'Idempotency key cannot be empty';
  END IF;

  UPDATE public.push_dispatch_idempotency
  SET
    status = 'completed',
    summary = p_summary,
    updated_at = now()
  WHERE idempotency_key = trim(p_key)
    AND status = 'in_flight';

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated > 0;
END;
$$;

COMMENT ON FUNCTION public.complete_push_idempotency(text, jsonb) IS 'Records the completion summary for an in-flight idempotency key.';
REVOKE ALL ON FUNCTION public.complete_push_idempotency(text, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_push_idempotency(text, jsonb) TO service_role;

-- RPC: Privileged administrative recovery for ambiguous expired_unconfirmed outcomes
-- Restricted strictly to service_role; cannot be invoked by standard callers or clients.
CREATE OR REPLACE FUNCTION public.admin_recover_unconfirmed_push_idempotency(
  p_key text,
  p_ttl_seconds int DEFAULT 600
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_updated record;
  v_now timestamptz := now();
  v_expires_at timestamptz := v_now + (COALESCE(p_ttl_seconds, 600) || ' seconds')::interval;
BEGIN
  IF p_key IS NULL OR length(trim(p_key)) = 0 THEN
    RAISE EXCEPTION 'Idempotency key cannot be empty';
  END IF;

  UPDATE public.push_dispatch_idempotency
  SET
    status = 'in_flight',
    summary = NULL,
    created_at = v_now,
    updated_at = v_now,
    expires_at = v_expires_at
  WHERE idempotency_key = trim(p_key)
    AND status = 'expired_unconfirmed'
  RETURNING * INTO v_updated;

  IF v_updated.idempotency_key IS NOT NULL THEN
    RETURN jsonb_build_object('recovered', true, 'status', 'in_flight');
  END IF;

  RETURN jsonb_build_object('recovered', false, 'message', 'Key is not in expired_unconfirmed status');
END;
$$;

COMMENT ON FUNCTION public.admin_recover_unconfirmed_push_idempotency(text, int) IS 'Privileged administrative recovery RPC for expired_unconfirmed outcomes, executable exclusively by service_role.';
REVOKE ALL ON FUNCTION public.admin_recover_unconfirmed_push_idempotency(text, int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_recover_unconfirmed_push_idempotency(text, int) TO service_role;

-- RPC: Two-tier cleanup: strips payload summaries into tombstones and purges only tombstones older than 30 days
CREATE OR REPLACE FUNCTION public.cleanup_expired_push_idempotency(p_batch_size int DEFAULT 1000)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tombstoned_completed int;
  v_tombstoned_unconfirmed int;
  v_purged_old_tombstones int;
  v_batch int := COALESCE(p_batch_size, 1000);
BEGIN
  -- Tier 1A: Transition completed records past retention into tombstone_archived, stripping summary payloads
  WITH target_completed AS (
    SELECT idempotency_key
    FROM public.push_dispatch_idempotency
    WHERE status = 'completed' AND expires_at < now()
    LIMIT v_batch
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.push_dispatch_idempotency
  SET status = 'tombstone_archived', summary = NULL, updated_at = now()
  WHERE idempotency_key IN (SELECT idempotency_key FROM target_completed);
  GET DIAGNOSTICS v_tombstoned_completed = ROW_COUNT;

  -- Tier 1B: Transition expired_unconfirmed records older than 24h into tombstone_archived
  WITH target_unconfirmed AS (
    SELECT idempotency_key
    FROM public.push_dispatch_idempotency
    WHERE status = 'expired_unconfirmed' AND created_at < now() - interval '24 hours'
    LIMIT v_batch
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.push_dispatch_idempotency
  SET status = 'tombstone_archived', summary = NULL, updated_at = now()
  WHERE idempotency_key IN (SELECT idempotency_key FROM target_unconfirmed);
  GET DIAGNOSTICS v_tombstoned_unconfirmed = ROW_COUNT;

  -- Tier 2: Physically delete only tombstones older than 30 days (outside the 24h application dispatch window)
  WITH target_purge AS (
    SELECT idempotency_key
    FROM public.push_dispatch_idempotency
    WHERE status = 'tombstone_archived' AND created_at < now() - interval '30 days'
    LIMIT v_batch
    FOR UPDATE SKIP LOCKED
  )
  DELETE FROM public.push_dispatch_idempotency
  WHERE idempotency_key IN (SELECT idempotency_key FROM target_purge);
  GET DIAGNOSTICS v_purged_old_tombstones = ROW_COUNT;

  RETURN jsonb_build_object(
    'tombstoned_completed', v_tombstoned_completed,
    'tombstoned_unconfirmed', v_tombstoned_unconfirmed,
    'purged_old_tombstones', v_purged_old_tombstones
  );
END;
$$;

COMMENT ON FUNCTION public.cleanup_expired_push_idempotency(int) IS 'Two-tier cleanup: archives expired completed/unconfirmed records into tombstones without memory loss, and purges tombstones older than 30 days.';
REVOKE ALL ON FUNCTION public.cleanup_expired_push_idempotency(int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_expired_push_idempotency(int) TO service_role;



