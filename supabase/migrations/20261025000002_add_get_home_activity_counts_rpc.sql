-- ── Migration: 20261025000002_add_get_home_activity_counts_rpc.sql ────────────────
-- Returns live matrimonial engagement metrics (views on profile, pending incoming interests, shortlists).
-- Supports both candidate and guardian accounts seamlessly.

CREATE OR REPLACE FUNCTION public.get_home_activity_counts(p_user_id uuid DEFAULT auth.uid())
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := COALESCE(p_user_id, auth.uid());
    v_target_uid uuid := v_uid;
    v_account_type text;
    v_views_count int := 0;
    v_pending_interests_count int := 0;
    v_shortlists_count int := 0;
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object(
            'profile_views_count', 0,
            'pending_interests_count', 0,
            'shortlists_count', 0
        );
    END IF;

    -- If guardian, resolve active candidate
    SELECT account_type INTO v_account_type FROM public.profiles WHERE id = v_uid;
    IF v_account_type = 'guardian' THEN
        SELECT fc.candidate_id INTO v_target_uid
        FROM public.family_members fm
        JOIN public.family_circles fc ON fc.id = fm.family_circle_id
        WHERE fm.user_id = v_uid
        LIMIT 1;
        v_target_uid := COALESCE(v_target_uid, v_uid);
    END IF;

    -- 1. Profiles who visited this user's biodata
    SELECT count(*)::int INTO v_views_count
    FROM public.profile_views
    WHERE viewed_id = v_target_uid;

    -- 2. Pending incoming interests received
    SELECT count(*)::int INTO v_pending_interests_count
    FROM public.interests
    WHERE receiver_profile_id = v_target_uid AND status = 'pending';

    -- 3. Shortlists count
    SELECT count(*)::int INTO v_shortlists_count
    FROM public.shortlists
    WHERE user_id = v_target_uid;

    RETURN jsonb_build_object(
        'profile_views_count', v_views_count,
        'pending_interests_count', v_pending_interests_count,
        'shortlists_count', v_shortlists_count
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_home_activity_counts(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_home_activity_counts(uuid) TO service_role;
