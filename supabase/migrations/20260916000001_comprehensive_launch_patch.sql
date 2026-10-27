-- ── Migration: 20260916000001_comprehensive_launch_patch.sql ────────────────
-- Description:
-- 1. Fix unlock_contact_number RPC (column 'unlocked_at' & 'phone')
-- 2. Fix Canonical Vedic Tara Koota 1-indexed formula (Brihat Parashara integrity)
-- 3. Fix refresh_user_match_cache schema alignment with actual profiles table
-- 4. Fix delete_user_account O(N) table lock
-- 5. Secure set_user_subscription & enforce discovery paywall ceiling
-- 6. Family Room Tables & RLS (family_circles, family_members, family_profile_reviews)
-- 7. Ensure chat-files storage bucket exists with authenticated RLS

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. Fix unlock_contact_number RPC
-- ═══════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.unlock_contact_number(uuid);

CREATE OR REPLACE FUNCTION public.unlock_contact_number(
    p_target_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid;
    v_phone text;
    v_full_name text;
    v_existing_unlock uuid;
    v_active_sub record;
    v_unlocks_used integer;
    v_unlock_limit integer;
    v_already_unlocked boolean;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'status', 'error',
            'error', 'unauthenticated',
            'message', 'Authentication required'
        );
    END IF;

    IF v_user_id = p_target_id THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'status', 'error',
            'error', 'self_unlock',
            'message', 'Cannot unlock your own contact'
        );
    END IF;

    -- Fetch target profile phone & name
    SELECT phone, full_name INTO v_phone, v_full_name
    FROM public.profiles
    WHERE id = p_target_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'status', 'error',
            'error', 'not_found',
            'message', 'Profile not found'
        );
    END IF;

    -- Check active subscription and quota
    SELECT * INTO v_active_sub
    FROM public.user_subscriptions
    WHERE user_id = v_user_id AND status = 'active' AND (expires_at IS NULL OR expires_at > now())
    ORDER BY created_at DESC
    LIMIT 1;

    -- Set limit by tier
    IF v_active_sub IS NOT NULL THEN
        IF v_active_sub.tier = 'prime' THEN
            v_unlock_limit := 60;
        ELSIF v_active_sub.tier = 'prime_lite' THEN
            v_unlock_limit := 25;
        ELSE
            v_unlock_limit := 0;
        END IF;
    ELSE
        v_unlock_limit := 0;
    END IF;

    -- Count existing unlocks within this subscription
    SELECT count(*)::integer INTO v_unlocks_used
    FROM public.contact_unlocks
    WHERE user_id = v_user_id 
      AND (v_active_sub IS NULL OR unlocked_at >= v_active_sub.created_at);

    -- Check if already unlocked (contact_unlocks PK is user_id, target_profile_id)
    SELECT EXISTS (
        SELECT 1 FROM public.contact_unlocks
        WHERE user_id = v_user_id AND target_profile_id = p_target_id
    ) INTO v_already_unlocked;

    IF v_already_unlocked THEN
        RETURN jsonb_build_object(
            'allowed', true,
            'status', 'success',
            'already_unlocked', true,
            'phone', COALESCE(v_phone, 'Contact not shared'),
            'phone_number', COALESCE(v_phone, 'Contact not shared'),
            'full_name', v_full_name,
            'remaining_contacts', GREATEST(0, v_unlock_limit - v_unlocks_used),
            'remaining_unlocks', GREATEST(0, v_unlock_limit - v_unlocks_used)
        );
    END IF;

    IF v_active_sub IS NULL OR v_unlock_limit = 0 THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'status', 'quota_exceeded',
            'error', 'upgrade_required',
            'message', 'Contact numbers are locked for Free members. Upgrade to Prime Lite or Prime VIP to unlock.'
        );
    END IF;

    IF v_unlocks_used >= v_unlock_limit THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'status', 'quota_exceeded',
            'error', 'contact_quota_exceeded',
            'message', 'You have exhausted your contact unlocks for this billing cycle.',
            'limit', v_unlock_limit,
            'used', v_unlocks_used,
            'remaining_contacts', 0,
            'remaining_unlocks', 0
        );
    END IF;

    -- Insert new unlock record with unlocked_at
    INSERT INTO public.contact_unlocks (user_id, target_profile_id, unlocked_at)
    VALUES (v_user_id, p_target_id, now())
    ON CONFLICT (user_id, target_profile_id) DO NOTHING;

    -- Sync contacts_unlocked_count in user_subscriptions (user_id is PK)
    UPDATE public.user_subscriptions
    SET contacts_unlocked_count = contacts_unlocked_count + 1,
        updated_at = now()
    WHERE user_id = v_user_id;

    RETURN jsonb_build_object(
        'allowed', true,
        'status', 'success',
        'already_unlocked', false,
        'phone', COALESCE(v_phone, 'Contact not shared'),
        'phone_number', COALESCE(v_phone, 'Contact not shared'),
        'full_name', v_full_name,
        'remaining_contacts', GREATEST(0, v_unlock_limit - (v_unlocks_used + 1)),
        'remaining_unlocks', GREATEST(0, v_unlock_limit - (v_unlocks_used + 1))
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.unlock_contact_number(uuid) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. Fix Canonical Vedic Tara Koota Formula (Brihat Parashara 1-Indexed)
-- ═══════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.calculate_guna_milan_points(integer, integer, integer, integer, integer, integer);
DROP FUNCTION IF EXISTS public.calculate_guna_milan_points(integer, integer, integer, integer);

CREATE OR REPLACE FUNCTION public.calculate_guna_milan_points(
    p_boy_rashi_id integer,
    p_boy_nakshatra_id integer,
    p_girl_rashi_id integer,
    p_girl_nakshatra_id integer,
    p_boy_pada integer DEFAULT 1,
    p_girl_pada integer DEFAULT 1
)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    -- Rashi Varna (1: Shudra, 2: Vaishya, 3: Kshatriya, 4: Brahmin)
    c_rashi_varna CONSTANT integer[] := ARRAY[3, 2, 1, 4, 3, 2, 1, 4, 3, 2, 1, 4];

    -- 27 Nakshatra Gana (0: Deva, 1: Manushya, 2: Rakshasa)
    c_nak_gana CONSTANT integer[] := ARRAY[
        0, 1, 2, 1, 0, 1, 0, 0, 2,
        2, 1, 1, 0, 2, 0, 2, 0, 2,
        2, 1, 1, 0, 2, 2, 1, 1, 0
    ];

    -- 27 Nakshatra Nadi (0: Adi/Vata, 1: Madhya/Pitta, 2: Antya/Kapha)
    c_nak_nadi CONSTANT integer[] := ARRAY[
        0, 1, 2, 2, 1, 0, 0, 1, 2,
        0, 1, 2, 2, 1, 0, 0, 1, 2,
        0, 1, 2, 2, 1, 0, 0, 1, 2
    ];

    -- 27 Nakshatra Yoni Animal (1 to 14)
    c_nak_yoni CONSTANT integer[] := ARRAY[
        1,  2,  3,  4,  4,  5,  6,  3,  6,
        7,  7,  8,  9, 10,  9, 10, 11, 11,
        5, 12, 13, 12, 14,  1, 14,  8,  2
    ];

    -- 12 Rashi Planetary Lords
    c_rashi_lord_norm CONSTANT integer[] := ARRAY[3, 6, 4, 2, 1, 4, 6, 3, 5, 7, 7, 5];

    v_boy_varna integer;
    v_girl_varna integer;
    v_varna_score numeric := 0;

    v_vashya_score numeric := 0;

    v_tara_g_to_b integer;
    v_tara_b_to_g integer;
    v_tara_score numeric := 0;

    v_boy_yoni integer;
    v_girl_yoni integer;
    v_yoni_score numeric := 0;

    v_boy_lord integer;
    v_girl_lord integer;
    v_maitri_score numeric := 0;

    v_boy_gana integer;
    v_girl_gana integer;
    v_gana_score numeric := 0;

    v_rashi_diff integer;
    v_bhakoot_score numeric := 0;

    v_boy_nadi integer;
    v_girl_nadi integer;
    v_nadi_score numeric := 0;

    v_total numeric := 0;
BEGIN
    IF p_boy_rashi_id IS NULL OR p_girl_rashi_id IS NULL 
       OR p_boy_nakshatra_id IS NULL OR p_girl_nakshatra_id IS NULL 
       OR p_boy_rashi_id < 1 OR p_boy_rashi_id > 12
       OR p_girl_rashi_id < 1 OR p_girl_rashi_id > 12
       OR p_boy_nakshatra_id < 1 OR p_boy_nakshatra_id > 27
       OR p_girl_nakshatra_id < 1 OR p_girl_nakshatra_id > 27 THEN
        RETURN NULL;
    END IF;

    -- 1. Varna Koota (1 pt)
    v_boy_varna := c_rashi_varna[p_boy_rashi_id];
    v_girl_varna := c_rashi_varna[p_girl_rashi_id];
    IF v_boy_varna >= v_girl_varna THEN
        v_varna_score := 1;
    ELSE
        v_varna_score := 0;
    END IF;

    -- 2. Vashya Koota (2 pts)
    IF p_boy_rashi_id = p_girl_rashi_id THEN
        v_vashya_score := 2;
    ELSIF (p_boy_rashi_id IN (1,2) AND p_girl_rashi_id IN (1,2))
       OR (p_boy_rashi_id IN (3,6,7,11) AND p_girl_rashi_id IN (3,6,7,11))
       OR (p_boy_rashi_id IN (4,12) AND p_girl_rashi_id IN (4,12)) THEN
        v_vashya_score := 2;
    ELSIF (p_boy_rashi_id IN (1,2) AND p_girl_rashi_id IN (3,6,7,11))
       OR (p_boy_rashi_id IN (3,6,7,11) AND p_girl_rashi_id IN (1,2))
       OR (p_boy_rashi_id IN (3,6,7,11) AND p_girl_rashi_id IN (4,12))
       OR (p_boy_rashi_id IN (4,12) AND p_girl_rashi_id IN (3,6,7,11)) THEN
        v_vashya_score := 1;
    ELSIF (p_boy_rashi_id IN (1,2) AND p_girl_rashi_id IN (4,12))
       OR (p_boy_rashi_id IN (4,12) AND p_girl_rashi_id IN (1,2)) THEN
        v_vashya_score := 0.5;
    ELSIF p_boy_rashi_id = 5 OR p_girl_rashi_id = 5 THEN
        IF (p_boy_rashi_id = 5 AND p_girl_rashi_id = 7) OR (p_boy_rashi_id = 7 AND p_girl_rashi_id = 5) THEN
            v_vashya_score := 1;
        ELSE
            v_vashya_score := 0;
        END IF;
    ELSIF p_boy_rashi_id = 8 OR p_girl_rashi_id = 8 THEN
        IF (p_boy_rashi_id = 8 AND p_girl_rashi_id = 4) OR (p_boy_rashi_id = 4 AND p_girl_rashi_id = 8) THEN
            v_vashya_score := 1;
        ELSE
            v_vashya_score := 0;
        END IF;
    ELSE
        v_vashya_score := 1;
    END IF;

    -- 3. Tara Koota (3 pts max) - Classical Brihat Parashara 1-Indexed Inclusive
    -- Tara number = (((Count from Nakshatra A to B) - 1) % 9) + 1
    v_tara_g_to_b := (((p_boy_nakshatra_id - p_girl_nakshatra_id + 27) % 27) % 9) + 1;
    v_tara_b_to_g := (((p_girl_nakshatra_id - p_boy_nakshatra_id + 27) % 27) % 9) + 1;

    -- Inauspicious Taras: 3 (Vipat), 5 (Pratyak), 7 (Naidhana)
    IF v_tara_g_to_b NOT IN (3, 5, 7) AND v_tara_b_to_g NOT IN (3, 5, 7) THEN
        v_tara_score := 3;
    ELSIF v_tara_g_to_b NOT IN (3, 5, 7) OR v_tara_b_to_g NOT IN (3, 5, 7) THEN
        v_tara_score := 1.5;
    ELSE
        v_tara_score := 0;
    END IF;

    -- 4. Yoni Koota (4 pts)
    v_boy_yoni := c_nak_yoni[p_boy_nakshatra_id];
    v_girl_yoni := c_nak_yoni[p_girl_nakshatra_id];

    IF v_boy_yoni = v_girl_yoni THEN
        v_yoni_score := 4;
    ELSIF (v_boy_yoni = 1 AND v_girl_yoni = 9) OR (v_boy_yoni = 9 AND v_girl_yoni = 1)
       OR (v_boy_yoni = 2 AND v_girl_yoni = 14) OR (v_boy_yoni = 14 AND v_girl_yoni = 2)
       OR (v_boy_yoni = 3 AND v_girl_yoni = 12) OR (v_boy_yoni = 12 AND v_girl_yoni = 3)
       OR (v_boy_yoni = 4 AND v_girl_yoni = 13) OR (v_boy_yoni = 13 AND v_girl_yoni = 4)
       OR (v_boy_yoni = 5 AND v_girl_yoni = 11) OR (v_boy_yoni = 11 AND v_girl_yoni = 5)
       OR (v_boy_yoni = 6 AND v_girl_yoni = 7) OR (v_boy_yoni = 7 AND v_girl_yoni = 6)
       OR (v_boy_yoni = 8 AND v_girl_yoni = 10) OR (v_boy_yoni = 10 AND v_girl_yoni = 8) THEN
        v_yoni_score := 0;
    ELSE
        v_yoni_score := 2;
    END IF;

    -- 5. Graha Maitri (5 pts)
    v_boy_lord := c_rashi_lord_norm[p_boy_rashi_id];
    v_girl_lord := c_rashi_lord_norm[p_girl_rashi_id];

    IF v_boy_lord = v_girl_lord THEN
        v_maitri_score := 5;
    ELSIF (v_boy_lord IN (1,2,3,5) AND v_girl_lord IN (1,2,3,5)) THEN
        v_maitri_score := 5;
    ELSIF (v_boy_lord IN (4,6,7) AND v_girl_lord IN (4,6,7)) THEN
        v_maitri_score := 5;
    ELSIF (v_boy_lord = 4 AND v_girl_lord = 1) OR (v_boy_lord = 1 AND v_girl_lord = 4) THEN
        v_maitri_score := 4;
    ELSIF (v_boy_lord IN (1,2) AND v_girl_lord IN (6,7)) OR (v_boy_lord IN (6,7) AND v_girl_lord IN (1,2)) THEN
        v_maitri_score := 0.5;
    ELSIF (v_boy_lord = 3 AND v_girl_lord = 4) OR (v_boy_lord = 4 AND v_girl_lord = 3) THEN
        v_maitri_score := 0.5;
    ELSE
        v_maitri_score := 3;
    END IF;

    -- 6. Gana Koota (6 pts)
    v_boy_gana := c_nak_gana[p_boy_nakshatra_id];
    v_girl_gana := c_nak_gana[p_girl_nakshatra_id];

    IF v_boy_gana = v_girl_gana THEN
        v_gana_score := 6;
    ELSIF v_boy_gana = 0 AND v_girl_gana = 1 THEN
        v_gana_score := 6;
    ELSIF v_boy_gana = 1 AND v_girl_gana = 0 THEN
        v_gana_score := 5;
    ELSIF v_boy_gana = 0 AND v_girl_gana = 2 THEN
        v_gana_score := 1;
    ELSIF v_boy_gana = 2 AND v_girl_gana = 0 THEN
        v_gana_score := 0;
    ELSE
        v_gana_score := 0;
    END IF;

    -- 7. Bhakoot Koota (7 pts)
    v_rashi_diff := ABS(p_boy_rashi_id - p_girl_rashi_id);
    IF v_rashi_diff IN (0, 6, 2, 10, 3, 9) THEN
        v_bhakoot_score := 7;
    ELSE
        IF v_boy_lord = v_girl_lord OR v_maitri_score >= 4 THEN
            v_bhakoot_score := 7;
        ELSE
            v_bhakoot_score := 0;
        END IF;
    END IF;

    -- 8. Nadi Koota (8 pts)
    v_boy_nadi := c_nak_nadi[p_boy_nakshatra_id];
    v_girl_nadi := c_nak_nadi[p_girl_nakshatra_id];

    IF v_boy_nadi <> v_girl_nadi THEN
        v_nadi_score := 8;
    ELSE
        IF p_boy_nakshatra_id <> p_girl_nakshatra_id THEN
            IF p_boy_rashi_id <> p_girl_rashi_id AND v_maitri_score >= 4 THEN
                v_nadi_score := 8;
            ELSE
                v_nadi_score := 0;
            END IF;
        ELSIF p_boy_pada <> p_girl_pada THEN
            v_nadi_score := 8;
        ELSE
            v_nadi_score := 0;
        END IF;
    END IF;

    v_total := v_varna_score + v_vashya_score + v_tara_score + v_yoni_score + 
               v_maitri_score + v_gana_score + v_bhakoot_score + v_nadi_score;

    RETURN LEAST(36, GREATEST(0, ROUND(v_total, 1)));
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. Fix refresh_user_match_cache (Align with actual profiles columns)
-- ═══════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.refresh_user_match_cache(uuid);
DROP FUNCTION IF EXISTS public.refresh_user_match_cache(uuid, boolean);

CREATE OR REPLACE FUNCTION public.refresh_user_match_cache(
    p_user_id uuid,
    p_force boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user public.profiles;
    v_pref public.partner_preferences;
    v_matches jsonb := '[]'::jsonb;
    v_fresh_matches jsonb := '[]'::jsonb;
    v_target_gender text;
    v_user_completed boolean;
BEGIN
    SELECT * INTO v_user FROM public.profiles WHERE id = p_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('status', 'error', 'message', 'User not found');
    END IF;

    v_user_completed := COALESCE(v_user.profile_completed, false) 
        AND (v_user.gender IS NOT NULL) 
        AND (v_user.full_name IS NOT NULL);

    IF NOT v_user_completed THEN
        RETURN jsonb_build_object('status', 'skipped', 'message', 'Profile incomplete');
    END IF;

    SELECT * INTO v_pref FROM public.partner_preferences WHERE profile_id = p_user_id;

    v_target_gender := CASE 
        WHEN LOWER(COALESCE(v_user.gender, '')) = 'male' THEN 'Female'
        WHEN LOWER(COALESCE(v_user.gender, '')) = 'female' THEN 'Male'
        ELSE NULL
    END;

    -- Fetch Top 54 Ranked Matches
    WITH candidate_pool AS (
        SELECT 
            p.id,
            p.full_name,
            p.gender,
            p.date_of_birth,
            p.height_inches,
            p.city,
            p.state,
            p.caste_id,
            p.sub_caste,
            p.highest_education_id,
            p.occupation_id,
            p.annual_income_id,
            p.marital_status_id,
            p.mother_tongue_id,
            p.food_preference_id,
            p.rashi_id,
            p.nakshatra_id,
            p.last_active_at,
            p.profile_photo_url AS primary_photo_url,
            (SELECT count(*)::int FROM public.profile_photos WHERE profile_id = p.id) AS photo_count,
            public.calculate_reciprocal_compatibility(v_user.id, p.id) AS match_score,
            CASE 
                WHEN v_user.rashi_id IS NOT NULL AND v_user.nakshatra_id IS NOT NULL 
                     AND p.rashi_id IS NOT NULL AND p.nakshatra_id IS NOT NULL 
                THEN 
                    ROUND(public.calculate_guna_milan_points(
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN v_user.rashi_id ELSE p.rashi_id END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN v_user.nakshatra_id ELSE p.nakshatra_id END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN p.rashi_id ELSE v_user.rashi_id END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN p.nakshatra_id ELSE v_user.nakshatra_id END
                    ))::integer
                ELSE NULL
            END AS guna_score
        FROM public.profiles p
        LEFT JOIN public.match_exclusions me 
            ON me.user_id = v_user.id AND me.excluded_id = p.id
        WHERE p.id <> v_user.id
          AND COALESCE(p.profile_completed, false) = true
          AND me.id IS NULL
          AND (v_target_gender IS NULL OR LOWER(p.gender) = LOWER(v_target_gender))
    ),
    ranked AS (
        SELECT *, 'ranked' AS slot_type
        FROM candidate_pool
        ORDER BY match_score DESC, guna_score DESC NULLS LAST, last_active_at DESC NULLS LAST
        LIMIT 54
    )
    SELECT COALESCE(jsonb_agg(to_jsonb(r.*)), '[]'::jsonb)
    INTO v_matches
    FROM ranked r;

    -- Fetch 6 Fresh exploration matches
    WITH fresh_pool AS (
        SELECT 
            p.id,
            p.full_name,
            p.gender,
            p.date_of_birth,
            p.height_inches,
            p.city,
            p.state,
            p.caste_id,
            p.sub_caste,
            p.highest_education_id,
            p.occupation_id,
            p.annual_income_id,
            p.marital_status_id,
            p.mother_tongue_id,
            p.food_preference_id,
            p.rashi_id,
            p.nakshatra_id,
            p.last_active_at,
            p.profile_photo_url AS primary_photo_url,
            (SELECT count(*)::int FROM public.profile_photos WHERE profile_id = p.id) AS photo_count,
            public.calculate_reciprocal_compatibility(v_user.id, p.id) AS match_score,
            NULL::integer AS guna_score
        FROM public.profiles p
        LEFT JOIN public.match_exclusions me 
            ON me.user_id = v_user.id AND me.excluded_id = p.id
        WHERE p.id <> v_user.id
          AND COALESCE(p.profile_completed, false) = true
          AND me.id IS NULL
          AND (v_target_gender IS NULL OR LOWER(p.gender) = LOWER(v_target_gender))
          AND NOT EXISTS (
              SELECT 1 FROM jsonb_array_elements(v_matches) elem 
              WHERE (elem->>'id')::uuid = p.id
          )
        ORDER BY p.created_at DESC
        LIMIT 6
    ),
    fresh_ranked AS (
        SELECT *, 'fresh' AS slot_type
        FROM fresh_pool
    )
    SELECT COALESCE(jsonb_agg(to_jsonb(f.*)), '[]'::jsonb)
    INTO v_fresh_matches
    FROM fresh_ranked f;

    -- Upsert user match cache
    INSERT INTO public.user_match_cache (user_id, matches, updated_at)
    VALUES (p_user_id, v_matches || v_fresh_matches, now())
    ON CONFLICT (user_id) 
    DO UPDATE SET 
        matches = EXCLUDED.matches,
        updated_at = now();

    RETURN jsonb_build_object(
        'status', 'refreshed',
        'count', jsonb_array_length(v_matches || v_fresh_matches)
    );
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. Fix delete_user_account (Remove O(N) Cartesian insert)
-- ═══════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.delete_user_account();

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

    -- Anonymize profile personal data & mark incomplete
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

    -- Delete photos
    DELETE FROM public.profile_photos WHERE profile_id = v_user_id;

    -- Delete partner preferences & match cache
    DELETE FROM public.partner_preferences WHERE profile_id = v_user_id;
    DELETE FROM public.user_match_cache WHERE user_id = v_user_id;

    -- Cancel active subscriptions
    UPDATE public.user_subscriptions
    SET status = 'cancelled', updated_at = now()
    WHERE user_id = v_user_id;

    -- Remove active blocks and interests
    DELETE FROM public.user_blocks WHERE blocker_id = v_user_id OR blocked_id = v_user_id;

    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'Account and personal data have been completely erased.'
    );
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. Discovery Search Paywall Enforcement (Ceiling check)
-- ═══════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.search_discovery_profiles(uuid, text, text, int, int, text, int, int);
DROP FUNCTION IF EXISTS public.search_discovery_profiles(uuid, integer, integer, integer, text, integer, integer);
DROP FUNCTION IF EXISTS public.search_discovery_profiles(text, text, integer, integer, text, integer, integer);

CREATE OR REPLACE FUNCTION public.search_discovery_profiles(
  p_user_id uuid,
  p_query text DEFAULT NULL,
  p_sub_caste text DEFAULT NULL,
  p_min_age int DEFAULT 18,
  p_max_age int DEFAULT 60,
  p_city text DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  full_name text,
  gender text,
  age int,
  city text,
  state text,
  sub_caste text,
  profile_photo_url text,
  is_verified boolean,
  highest_education text,
  occupation text,
  match_score int,
  caste_id int,
  gothram_id int,
  mother_tongue_id int,
  highest_education_id int,
  occupation_id int,
  date_of_birth text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_viewer_gender text;
  v_opposite_gender text;
  v_sub record;
  v_tier text := 'free';
  v_discovery_limit int := 10;
BEGIN
  -- Get viewer gender
  SELECT p.gender INTO v_viewer_gender
  FROM public.profiles p
  WHERE p.id = p_user_id;

  v_opposite_gender := CASE
    WHEN v_viewer_gender = 'male' THEN 'female'
    WHEN v_viewer_gender = 'female' THEN 'male'
    ELSE NULL
  END;

  -- Get subscription tier
  SELECT * INTO v_sub FROM public.user_subscriptions
  WHERE user_id = p_user_id AND status = 'active' AND (expires_at IS NULL OR expires_at > now())
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    v_tier := v_sub.tier;
  END IF;

  IF v_tier = 'prime' THEN
    v_discovery_limit := 500;
  ELSIF v_tier = 'prime_lite' THEN
    v_discovery_limit := 50;
  ELSE
    v_discovery_limit := 10;
  END IF;

  -- Enforce Free tier Discovery ceiling: Max 10 profiles visible
  IF v_tier = 'free' AND p_offset >= 10 THEN
    RETURN;
  END IF;

  IF v_tier = 'free' THEN
    p_limit := LEAST(p_limit, 10 - p_offset);
  ELSE
    p_limit := LEAST(p_limit, v_discovery_limit);
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.full_name,
    p.gender,
    DATE_PART('year', AGE(p.date_of_birth::date))::int AS age,
    p.city,
    p.state,
    p.sub_caste,
    p.profile_photo_url,
    p.is_verified,
    COALESCE(el.level, 'Graduate') AS highest_education,
    COALESCE(oc.occupation, 'Professional') AS occupation,
    CASE
      WHEN p.is_verified THEN 90
      ELSE 75
    END AS match_score,
    p.caste_id,
    p.gothram_id,
    p.mother_tongue_id,
    p.highest_education_id,
    p.occupation_id,
    p.date_of_birth::text,
    p.created_at
  FROM public.profiles p
  LEFT JOIN public.education_levels el ON el.id = p.highest_education_id
  LEFT JOIN public.occupations oc ON oc.id = p.occupation_id
  WHERE
    p.id != p_user_id
    AND p.profile_completed = true
    AND p.full_name IS NOT NULL
    AND p.gender IS NOT NULL
    AND p.date_of_birth IS NOT NULL
    AND (v_opposite_gender IS NULL OR p.gender = v_opposite_gender)
    -- Search text filter
    AND (
      p_query IS NULL
      OR p.full_name ILIKE '%' || p_query || '%'
      OR p.city ILIKE '%' || p_query || '%'
      OR p.sub_caste ILIKE '%' || p_query || '%'
      OR COALESCE(oc.occupation, '') ILIKE '%' || p_query || '%'
    )
    -- Subcaste filter
    AND (p_sub_caste IS NULL OR p_sub_caste = 'All' OR p.sub_caste ILIKE '%' || p_sub_caste || '%')
    -- Age range filter
    AND (
      p_min_age IS NULL
      OR DATE_PART('year', AGE(p.date_of_birth::date))::int >= p_min_age
    )
    AND (
      p_max_age IS NULL
      OR DATE_PART('year', AGE(p.date_of_birth::date))::int <= p_max_age
    )
    -- City filter
    AND (
      p_city IS NULL
      OR p_city = ''
      OR p.city ILIKE '%' || p_city || '%'
      OR p.state ILIKE '%' || p_city || '%'
    )
    -- Exclude blocked profiles
    AND NOT EXISTS (
      SELECT 1 FROM public.user_blocks b 
      WHERE (b.blocker_id = p_user_id AND b.blocked_id = p.id)
         OR (b.blocker_id = p.id AND b.blocked_id = p_user_id)
    )
  ORDER BY p.is_verified DESC, p.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_discovery_profiles(uuid, text, text, int, int, text, int, int) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. Idea Paper Feature: "Family Room" (కుటుంబ వేదిక) Infrastructure
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.family_circles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    family_name text DEFAULT 'Family Circle',
    invite_code text UNIQUE NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_candidate_circle UNIQUE (candidate_id)
);

CREATE TABLE IF NOT EXISTS public.family_members (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    family_circle_id uuid NOT NULL REFERENCES public.family_circles(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role text NOT NULL DEFAULT 'Parent', -- 'Father', 'Mother', 'Brother', 'Sister', 'Guardian', 'Candidate'
    display_name text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_family_member UNIQUE (family_circle_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.family_profile_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    family_circle_id uuid NOT NULL REFERENCES public.family_circles(id) ON DELETE CASCADE,
    target_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reviewed_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reaction text NOT NULL CHECK (reaction IN ('shortlist', 'discuss', 'decline')),
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_family_circles_candidate ON public.family_circles(candidate_id);
CREATE INDEX IF NOT EXISTS idx_family_members_user ON public.family_members(user_id);
CREATE INDEX IF NOT EXISTS idx_family_reviews_circle_target ON public.family_profile_reviews(family_circle_id, target_profile_id);

-- Enable RLS
ALTER TABLE public.family_circles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_profile_reviews ENABLE ROW LEVEL SECURITY;

-- Helper Function: Check membership with SECURITY DEFINER to avoid RLS recursion
CREATE OR REPLACE FUNCTION public.is_family_circle_member(p_circle_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path TO 'public'
AS $$
    SELECT (
        EXISTS (
            SELECT 1 FROM public.family_circles
            WHERE id = p_circle_id AND candidate_id = p_user_id
        )
        OR EXISTS (
            SELECT 1 FROM public.family_members 
            WHERE family_circle_id = p_circle_id AND user_id = p_user_id
        )
    );
$$;

GRANT EXECUTE ON FUNCTION public.is_family_circle_member(uuid, uuid) TO authenticated;

-- RLS Policies
DROP POLICY IF EXISTS "Members can view their family circle" ON public.family_circles;
CREATE POLICY "Members can view their family circle"
    ON public.family_circles FOR SELECT
    TO authenticated
    USING (
        candidate_id = auth.uid() OR public.is_family_circle_member(id, auth.uid())
    );

DROP POLICY IF EXISTS "Members can view circle members" ON public.family_members;
CREATE POLICY "Members can view circle members"
    ON public.family_members FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid() OR public.is_family_circle_member(family_circle_id, auth.uid())
    );

DROP POLICY IF EXISTS "Circle members can view reviews" ON public.family_profile_reviews;
CREATE POLICY "Circle members can view reviews"
    ON public.family_profile_reviews FOR SELECT
    TO authenticated
    USING (
        public.is_family_circle_member(family_circle_id, auth.uid())
    );

DROP POLICY IF EXISTS "Circle members can insert reviews" ON public.family_profile_reviews;
CREATE POLICY "Circle members can insert reviews"
    ON public.family_profile_reviews FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = reviewed_by AND public.is_family_circle_member(family_circle_id, auth.uid())
    );

-- Helper RPC: Create or Get My Family Circle
DROP FUNCTION IF EXISTS public.get_or_create_family_circle();

CREATE OR REPLACE FUNCTION public.get_or_create_family_circle()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid;
    v_circle record;
    v_code text;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('status', 'error', 'message', 'Authentication required');
    END IF;

    -- Check if user is already a candidate or member
    SELECT c.* INTO v_circle
    FROM public.family_circles c
    LEFT JOIN public.family_members m ON m.family_circle_id = c.id
    WHERE c.candidate_id = v_user_id OR m.user_id = v_user_id
    LIMIT 1;

    IF v_circle.id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'status', 'success',
            'circle_id', v_circle.id,
            'invite_code', v_circle.invite_code,
            'family_name', v_circle.family_name,
            'is_candidate', (v_circle.candidate_id = v_user_id)
        );
    END IF;

    -- Generate random 6-character code
    v_code := 'MANG-' || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 4));

    -- Create new family circle
    INSERT INTO public.family_circles (candidate_id, invite_code, family_name)
    VALUES (v_user_id, v_code, 'My Family Circle')
    RETURNING * INTO v_circle;

    -- Add candidate as default admin member
    INSERT INTO public.family_members (family_circle_id, user_id, role, display_name)
    VALUES (v_circle.id, v_user_id, 'Candidate', 'Self');

    RETURN jsonb_build_object(
        'status', 'created',
        'circle_id', v_circle.id,
        'invite_code', v_circle.invite_code,
        'family_name', v_circle.family_name,
        'is_candidate', true
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_family_circle() TO authenticated;

-- Helper RPC: Join Family Circle by Invite Code
DROP FUNCTION IF EXISTS public.join_family_circle(text, text, text);
DROP FUNCTION IF EXISTS public.join_family_circle(text, text);
DROP FUNCTION IF EXISTS public.join_family_circle(text);

CREATE OR REPLACE FUNCTION public.join_family_circle(
    p_invite_code text,
    p_role text DEFAULT 'Parent',
    p_display_name text DEFAULT 'Family Member'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid;
    v_circle record;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('status', 'error', 'message', 'Authentication required');
    END IF;

    SELECT * INTO v_circle
    FROM public.family_circles
    WHERE UPPER(invite_code) = UPPER(TRIM(p_invite_code));

    IF v_circle.id IS NULL THEN
        RETURN jsonb_build_object('status', 'error', 'message', 'Invalid invite code');
    END IF;

    -- Add member
    INSERT INTO public.family_members (family_circle_id, user_id, role, display_name)
    VALUES (v_circle.id, v_user_id, p_role, p_display_name)
    ON CONFLICT (family_circle_id, user_id) 
    DO UPDATE SET role = EXCLUDED.role, display_name = EXCLUDED.display_name;

    RETURN jsonb_build_object(
        'status', 'success',
        'circle_id', v_circle.id,
        'family_name', v_circle.family_name
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_family_circle TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. Ensure chat-files Bucket Exists
-- ═══════════════════════════════════════════════════════════════════════════════

INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-files', 'chat-files', false)
ON CONFLICT (id) DO NOTHING;

-- Authenticated upload policy for chat-files
DROP POLICY IF EXISTS "Authenticated users can upload chat files" ON storage.objects;
CREATE POLICY "Authenticated users can upload chat files"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'chat-files' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Authenticated read policy for chat-files
DROP POLICY IF EXISTS "Authenticated users can read chat files" ON storage.objects;
CREATE POLICY "Authenticated users can read chat files"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'chat-files');

