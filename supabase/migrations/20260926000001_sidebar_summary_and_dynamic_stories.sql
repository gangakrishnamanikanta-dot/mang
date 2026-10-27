-- =====================================================================
-- Migration: 20260926000001_sidebar_summary_and_dynamic_stories.sql
-- 1. Adds is_hidden column to profiles for Profile Visibility (Active / Paused)
-- 2. Creates public.success_stories table for 100% Dynamic Home Carousel
-- 3. Creates public.toggle_profile_visibility RPC
-- 4. Creates public.get_sidebar_summary RPC (Single-trip Sidebar Engine)
-- =====================================================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT false;

CREATE TABLE IF NOT EXISTS public.success_stories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_names text NOT NULL,
    subtitle text NOT NULL,
    quote text NOT NULL,
    guna_score int DEFAULT 32,
    city text,
    married_date text,
    is_active boolean DEFAULT true,
    display_order int DEFAULT 1,
    created_at timestamptz DEFAULT now()
);

ALTER TABLE public.success_stories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read of active success stories" ON public.success_stories;
CREATE POLICY "Allow public read of active success stories"
    ON public.success_stories FOR SELECT
    USING (is_active = true);

INSERT INTO public.success_stories (couple_names, subtitle, quote, guna_score, city, married_date, display_order)
SELECT 'Chi. Rahul & Chi. La. Sow. Pooja', 'Married Feb 2026 • 32/36 Gunas', '“Our families connected through the Family Room and matched horoscopes instantly. Truly blessed!”', 32, 'Hyderabad', 'Feb 2026', 1
WHERE NOT EXISTS (SELECT 1 FROM public.success_stories LIMIT 1);

INSERT INTO public.success_stories (couple_names, subtitle, quote, guna_score, city, married_date, display_order)
SELECT 'Chi. Venkatesh & Chi. La. Sow. Sravani', 'Married Jan 2026 • 29/36 Gunas', '“Authentic Vedic Guna Milan and verified profiles gave our parents complete peace of mind.”', 29, 'Vijayawada', 'Jan 2026', 2
WHERE (SELECT count(*) FROM public.success_stories) < 2;

INSERT INTO public.success_stories (couple_names, subtitle, quote, guna_score, city, married_date, display_order)
SELECT 'Chi. Aditya & Chi. La. Sow. Madhuri', 'Married Dec 2025 • 34/36 Gunas', '“Found our sacred alliance within 3 weeks. The guardian proxy chat made family discussions effortless.”', 34, 'Visakhapatnam', 'Dec 2025', 3
WHERE (SELECT count(*) FROM public.success_stories) < 3;

CREATE OR REPLACE FUNCTION public.toggle_profile_visibility(p_is_hidden boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    UPDATE public.profiles
    SET is_hidden = p_is_hidden,
        updated_at = now()
    WHERE id = v_uid;

    RETURN jsonb_build_object(
        'status', 'success',
        'is_hidden', p_is_hidden
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_sidebar_summary(p_user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_uid uuid := COALESCE(p_user_id, auth.uid());
    v_prof public.profiles;
    v_invite_code text;
    v_target_uid uuid;
    v_cand_name text;
    v_guardian_role text;
    v_membership jsonb;
    v_shortlists_count int := 0;
    v_visited_count int := 0;
BEGIN
    IF v_uid IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

    SELECT * INTO v_prof FROM public.profiles WHERE id = v_uid;
    IF NOT FOUND THEN
        RETURN '{}'::jsonb;
    END IF;

    IF COALESCE(v_prof.account_type, 'candidate') = 'guardian' THEN
        SELECT fc.candidate_id, p.full_name, fc.invite_code, fm.role
        INTO v_target_uid, v_cand_name, v_invite_code, v_guardian_role
        FROM public.family_members fm
        JOIN public.family_circles fc ON fc.id = fm.family_circle_id
        JOIN public.profiles p ON p.id = fc.candidate_id
        WHERE fm.user_id = v_uid
        LIMIT 1;

        v_target_uid := COALESCE(v_target_uid, v_uid);
    ELSE
        v_target_uid := v_uid;
        SELECT invite_code INTO v_invite_code
        FROM public.family_circles
        WHERE candidate_id = v_uid
        LIMIT 1;
    END IF;

    v_membership := public.get_user_membership_status(v_target_uid);

    SELECT count(*)::int INTO v_shortlists_count
    FROM public.shortlists
    WHERE user_id = v_uid;

    SELECT count(*)::int INTO v_visited_count
    FROM public.profile_views
    WHERE viewer_id = v_uid;

    RETURN jsonb_build_object(
        'user_id', v_uid,
        'target_profile_id', v_target_uid,
        'matrimony_id', 'MS-' || UPPER(SUBSTRING(v_target_uid::text, 1, 6)),
        'full_name', COALESCE(v_prof.full_name, 'Valued Member'),
        'profile_photo_url', v_prof.profile_photo_url,
        'account_type', COALESCE(v_prof.account_type, 'candidate'),
        'is_verified', COALESCE(v_prof.is_verified, false),
        'is_hidden', COALESCE(v_prof.is_hidden, false),
        'allow_guardian_proxy_chat', COALESCE(v_prof.allow_guardian_proxy_chat, true),
        'family_invite_code', v_invite_code,
        'linked_candidate_name', v_cand_name,
        'guardian_role', v_guardian_role,
        'shortlists_count', v_shortlists_count,
        'visited_count', v_visited_count,
        'membership', v_membership
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.toggle_guardian_proxy_chat(p_allow boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    UPDATE public.profiles
    SET allow_guardian_proxy_chat = COALESCE(p_allow, true),
        updated_at = now()
    WHERE id = v_uid;

    RETURN jsonb_build_object(
        'success', true,
        'allow_guardian_proxy_chat', COALESCE(p_allow, true)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_guardian_proxy_chat(boolean) TO authenticated;

