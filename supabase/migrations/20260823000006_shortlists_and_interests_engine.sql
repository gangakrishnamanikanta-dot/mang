-- ── Migration: Shortlists & Interests Engine ────────────────────────────────
--
-- Provides atomic, secure RPCs for:
-- 1. toggle_shortlist: idempotent add/remove bookmark
-- 2. get_my_shortlists: populated query with safe profile details + match score
-- 3. respond_to_interest: secure interest accept/decline + auto-conversation unlock
-- 4. cancel_sent_interest: secure interest withdraw/cancel

-- 1. Toggle Shortlist RPC
CREATE OR REPLACE FUNCTION public.toggle_shortlist(p_target_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_exists boolean;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
    END IF;

    IF v_user_id = p_target_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'cannot_shortlist_self');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.shortlists 
        WHERE user_id = v_user_id AND profile_id = p_target_id
    ) INTO v_exists;

    IF v_exists THEN
        DELETE FROM public.shortlists 
        WHERE user_id = v_user_id AND profile_id = p_target_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'is_shortlisted', false,
            'profile_id', p_target_id
        );
    ELSE
        INSERT INTO public.shortlists (user_id, profile_id, created_at)
        VALUES (v_user_id, p_target_id, now())
        ON CONFLICT (user_id, profile_id) DO NOTHING;

        RETURN jsonb_build_object(
            'success', true,
            'is_shortlisted', true,
            'profile_id', p_target_id
        );
    END IF;
END;
$$;

-- 2. Get Populated Shortlists RPC
CREATE OR REPLACE FUNCTION public.get_my_shortlists(
    p_limit integer DEFAULT 20,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_result jsonb;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    SELECT COALESCE(jsonb_agg(r ORDER BY r.shortlisted_at DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT 
            p.id,
            p.full_name,
            p.gender,
            p.date_of_birth,
            p.city,
            p.state,
            p.profile_photo_url,
            p.occupation_id,
            p.highest_education_id,
            p.caste_id,
            p.gothram_id,
            p.mother_tongue_id,
            p.is_verified,
            p.created_at,
            s.created_at AS shortlisted_at,
            EXTRACT(year FROM age(p.date_of_birth))::int AS age,
            COALESCE(
                (
                    SELECT (m->>'score')::float8
                    FROM public.user_match_cache c,
                         jsonb_array_elements(c.matches) m
                    WHERE c.user_id = v_user_id
                      AND m->>'profile_id' = p.id::text
                    LIMIT 1
                ),
                ROUND(public.get_compatibility_index_v2(v_user_id, p.id)::numeric, 1)
            ) AS match_score
        FROM public.shortlists s
        JOIN public.profiles p ON p.id = s.profile_id
        WHERE s.user_id = v_user_id
          AND p.full_name IS NOT NULL
          AND TRIM(p.full_name) <> ''
        ORDER BY s.created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    ) r;

    RETURN v_result;
END;
$$;

-- 3. Respond to Interest RPC
CREATE OR REPLACE FUNCTION public.respond_to_interest(
    p_interest_id uuid,
    p_action text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_interest record;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
    END IF;

    IF p_action NOT IN ('accepted', 'declined') THEN
        RETURN jsonb_build_object('success', false, 'error', 'invalid_action');
    END IF;

    SELECT * INTO v_interest 
    FROM public.interests 
    WHERE id = p_interest_id AND receiver_profile_id = v_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'interest_not_found_or_unauthorized');
    END IF;

    UPDATE public.interests
    SET status = p_action,
        updated_at = now()
    WHERE id = p_interest_id;

    -- If accepted, automatically initialize active conversation between the two users
    IF p_action = 'accepted' THEN
        INSERT INTO public.conversations (
            user1_id, user2_id, last_message, last_message_time, created_at, updated_at
        ) VALUES (
            LEAST(v_interest.sender_profile_id, v_interest.receiver_profile_id),
            GREATEST(v_interest.sender_profile_id, v_interest.receiver_profile_id),
            'Interest accepted! You can now start messaging.',
            now(),
            now(),
            now()
        )
        ON CONFLICT (LEAST(user1_id, user2_id), GREATEST(user1_id, user2_id)) DO UPDATE
        SET updated_at = now();
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'interest_id', p_interest_id,
        'status', p_action
    );
END;
$$;

-- 4. Cancel Sent Interest RPC
CREATE OR REPLACE FUNCTION public.cancel_sent_interest(p_interest_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
    END IF;

    DELETE FROM public.interests
    WHERE id = p_interest_id AND sender_profile_id = v_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'interest_not_found_or_unauthorized');
    END IF;

    RETURN jsonb_build_object('success', true, 'interest_id', p_interest_id);
END;
$$;

-- Permissions
GRANT EXECUTE ON FUNCTION public.toggle_shortlist(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_shortlists(integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_interest(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_sent_interest(uuid) TO authenticated;
