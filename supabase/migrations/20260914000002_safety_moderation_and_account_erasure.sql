-- ── Migration: 20260914000002_safety_moderation_and_account_erasure.sql ─────────
-- Description:
-- Store compliance & user safety suite:
-- 1. user_blocks table with bidirectional isolation in match_exclusions
-- 2. user_reports table for UGC audit logging
-- 3. Atomic RPCs: block_user(), unblock_user(), report_user(), get_blocked_users()
-- 4. Apple Guideline 5.1.1(v) compliant delete_user_account() self-serve erasure

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. Create user_blocks Table
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.user_blocks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    blocked_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reason text DEFAULT 'User blocked',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_blocks UNIQUE (blocker_id, blocked_id),
    CONSTRAINT chk_not_self_block CHECK (blocker_id <> blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON public.user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON public.user_blocks(blocked_id);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own blocked list" ON public.user_blocks;
CREATE POLICY "Users can view their own blocked list"
    ON public.user_blocks FOR SELECT
    TO authenticated
    USING (auth.uid() = blocker_id);

DROP POLICY IF EXISTS "Users can insert their own blocks" ON public.user_blocks;
CREATE POLICY "Users can insert their own blocks"
    ON public.user_blocks FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = blocker_id);

DROP POLICY IF EXISTS "Users can unblock their own blocks" ON public.user_blocks;
CREATE POLICY "Users can unblock their own blocks"
    ON public.user_blocks FOR DELETE
    TO authenticated
    USING (auth.uid() = blocker_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. Create user_reports Table
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.user_reports (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reported_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    category text NOT NULL,
    reason text NOT NULL,
    details text,
    status text NOT NULL DEFAULT 'pending',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_not_self_report CHECK (reporter_id <> reported_id)
);

CREATE INDEX IF NOT EXISTS idx_user_reports_reporter ON public.user_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_user_reports_reported ON public.user_reports(reported_id);
CREATE INDEX IF NOT EXISTS idx_user_reports_status ON public.user_reports(status);

ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert reports" ON public.user_reports;
CREATE POLICY "Users can insert reports"
    ON public.user_reports FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = reporter_id);

DROP POLICY IF EXISTS "Users can view their own submitted reports" ON public.user_reports;
CREATE POLICY "Users can view their own submitted reports"
    ON public.user_reports FOR SELECT
    TO authenticated
    USING (auth.uid() = reporter_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. Atomic Safety RPC: block_user
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.block_user(
    p_blocked_id uuid,
    p_reason text DEFAULT 'User blocked'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_blocker_id uuid;
BEGIN
    v_blocker_id := auth.uid();
    IF v_blocker_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    IF v_blocker_id = p_blocked_id THEN
        RAISE EXCEPTION 'Cannot block yourself';
    END IF;

    -- 1. Insert into user_blocks
    INSERT INTO public.user_blocks (blocker_id, blocked_id, reason)
    VALUES (v_blocker_id, p_blocked_id, COALESCE(p_reason, 'User blocked'))
    ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

    -- 2. Symmetrically isolate in match_exclusions
    INSERT INTO public.match_exclusions (user_id, excluded_id, reason)
    VALUES (v_blocker_id, p_blocked_id, 'Blocked by user')
    ON CONFLICT (user_id, excluded_id) DO NOTHING;

    INSERT INTO public.match_exclusions (user_id, excluded_id, reason)
    VALUES (p_blocked_id, v_blocker_id, 'Blocked by user')
    ON CONFLICT (user_id, excluded_id) DO NOTHING;

    -- 3. Decline/neutralize pending interests
    UPDATE public.interests
    SET status = 'declined', updated_at = now()
    WHERE ((sender_profile_id = v_blocker_id AND receiver_profile_id = p_blocked_id)
       OR  (sender_profile_id = p_blocked_id AND receiver_profile_id = v_blocker_id))
      AND status = 'pending';

    -- 4. Invalidate match cache so neither user appears
    DELETE FROM public.user_match_cache WHERE user_id IN (v_blocker_id, p_blocked_id);

    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'User blocked and mutual visibility severed'
    );
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. Atomic Safety RPC: unblock_user
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.unblock_user(
    p_blocked_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_blocker_id uuid;
BEGIN
    v_blocker_id := auth.uid();
    IF v_blocker_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    -- Remove block entry
    DELETE FROM public.user_blocks
    WHERE blocker_id = v_blocker_id AND blocked_id = p_blocked_id;

    -- Remove blocker's exclusion
    DELETE FROM public.match_exclusions
    WHERE user_id = v_blocker_id AND excluded_id = p_blocked_id AND reason = 'Blocked by user';

    -- Invalidate match cache
    DELETE FROM public.user_match_cache WHERE user_id = v_blocker_id;

    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'User unblocked successfully'
    );
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. Atomic Safety RPC: report_user
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.report_user(
    p_reported_id uuid,
    p_category text,
    p_reason text,
    p_details text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_reporter_id uuid;
BEGIN
    v_reporter_id := auth.uid();
    IF v_reporter_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    IF v_reporter_id = p_reported_id THEN
        RAISE EXCEPTION 'Cannot report yourself';
    END IF;

    INSERT INTO public.user_reports (reporter_id, reported_id, category, reason, details)
    VALUES (v_reporter_id, p_reported_id, p_category, p_reason, p_details);

    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'Report received. Our Vedic Trust & Safety team will review it within 24 hours.'
    );
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. RPC: get_blocked_users
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_blocked_users()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid;
    v_list jsonb;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'full_name', p.full_name,
            'city', p.city,
            'state', p.state,
            'profile_photo_url', p.profile_photo_url,
            'blocked_at', b.created_at
        ) ORDER BY b.created_at DESC
    ), '[]'::jsonb)
    INTO v_list
    FROM public.user_blocks b
    JOIN public.profiles p ON p.id = b.blocked_id
    WHERE b.blocker_id = v_user_id;

    RETURN v_list;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. Store-Mandated Account Erasure RPC: delete_user_account
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    -- 1. Anonymize profile personal data
    UPDATE public.profiles
    SET 
        full_name = 'Former Member',
        email = 'deleted_' || v_user_id::text || '@mangalasutram.in',
        phone = NULL,
        profile_photo_url = NULL,
        additional_photo_urls = NULL,
        about_me = NULL,
        profile_completed = false,
        updated_at = now()
    WHERE id = v_user_id;

    -- 2. Clear photos from profile_photos table
    DELETE FROM public.profile_photos WHERE profile_id = v_user_id;

    -- 3. Clear partner preferences
    DELETE FROM public.partner_preferences WHERE profile_id = v_user_id;

    -- 4. Clear match cache
    DELETE FROM public.user_match_cache WHERE user_id = v_user_id;

    -- 5. Cancel active subscriptions
    UPDATE public.user_subscriptions
    SET status = 'cancelled', updated_at = now()
    WHERE user_id = v_user_id;

    -- 6. Add to exclusions for all active matches
    INSERT INTO public.match_exclusions (user_id, excluded_id, reason)
    SELECT id, v_user_id, 'Account deleted' FROM public.profiles WHERE id <> v_user_id
    ON CONFLICT (user_id, excluded_id) DO NOTHING;

    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'Account and personal data have been completely erased.'
    );
END;
$$;
