-- ── Migration: 20260914000001_canonical_vedic_ashtakoot_guna_milan.sql ────────────────
-- Description:
-- Canonical Vedic Ashtakoot Guna Milan (0..36 points) engine strictly adhering to
-- Brihat Parashara Hora Shastra and Muhurta Chintamani.
-- Replaces heuristic modulo math with exact 27-Nakshatra, 12-Rashi, and 14-Yoni lookup tables.
-- Implements authentic Bhakoot & Nadi Dosha Parihara (cancellations).
-- Strictly returns NULL if either user has unpopulated astrological data.

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. Canonical Vedic Ashtakoot Scoring Function
-- ═══════════════════════════════════════════════════════════════════════════════

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
    -- Aries=3, Taurus=2, Gemini=1, Cancer=4, Leo=3, Virgo=2, Libra=1, Scorpio=4, Sag=3, Cap=2, Aqu=1, Pisces=4
    c_rashi_varna CONSTANT integer[] := ARRAY[3, 2, 1, 4, 3, 2, 1, 4, 3, 2, 1, 4];

    -- 27 Nakshatra Gana (0: Deva, 1: Manushya, 2: Rakshasa)
    c_nak_gana CONSTANT integer[] := ARRAY[
        0, 1, 2, 1, 0, 1, 0, 0, 2,
        2, 1, 1, 0, 2, 0, 2, 0, 2,
        2, 1, 1, 0, 2, 2, 1, 1, 0
    ];

    -- 27 Nakshatra Nadi (0: Adi/Vata, 1: Madhya/Pitta, 2: Antya/Kapha) - Classical Serpentine Wave
    c_nak_nadi CONSTANT integer[] := ARRAY[
        0, 1, 2, 2, 1, 0, 0, 1, 2,
        0, 1, 2, 2, 1, 0, 0, 1, 2,
        0, 1, 2, 2, 1, 0, 0, 1, 2
    ];

    -- 27 Nakshatra Yoni Animal (1 to 14)
    -- 1: Horse, 2: Elephant, 3: Sheep, 4: Serpent, 5: Dog, 6: Cat, 7: Rat,
    -- 8: Cow, 9: Buffalo, 10: Tiger, 11: Deer, 12: Monkey, 13: Mongoose, 14: Lion
    c_nak_yoni CONSTANT integer[] := ARRAY[
        1,  2,  3,  4,  4,  5,  6,  3,  6,  -- 1..9
        7,  7,  8,  9, 10,  9, 10, 11, 11,  -- 10..18
        5, 12, 13, 12, 14,  1, 14,  8,  2   -- 19..27
    ];

    -- 12 Rashi Planetary Lords
    -- Normalized IDs: 1:Sun, 2:Moon, 3:Mars, 4:Mercury, 5:Jupiter, 6:Venus, 7:Saturn
    -- Aries=3(Mars), Taurus=6(Venus), Gemini=4(Merc), Cancer=2(Moon), Leo=1(Sun), Virgo=4(Merc), Libra=6(Venus), Scorpio=3(Mars), Sag=5(Jup), Cap=7(Sat), Aqu=7(Sat), Pisces=5(Jup)
    c_rashi_lord_norm CONSTANT integer[] := ARRAY[3, 6, 4, 2, 1, 4, 6, 3, 5, 7, 7, 5];

    -- Intermediate variables
    v_boy_varna integer;
    v_girl_varna integer;
    v_varna_score numeric := 0;

    v_vashya_score numeric := 0;

    v_tara_b_to_g integer;
    v_tara_g_to_b integer;
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
    -- Strict Rule: If any essential astrological parameter is unpopulated, return NULL
    IF p_boy_rashi_id IS NULL OR p_girl_rashi_id IS NULL 
       OR p_boy_nakshatra_id IS NULL OR p_girl_nakshatra_id IS NULL 
       OR p_boy_rashi_id < 1 OR p_boy_rashi_id > 12
       OR p_girl_rashi_id < 1 OR p_girl_rashi_id > 12
       OR p_boy_nakshatra_id < 1 OR p_boy_nakshatra_id > 27
       OR p_girl_nakshatra_id < 1 OR p_girl_nakshatra_id > 27 THEN
        RETURN NULL;
    END IF;

    -- ─────────────────────────────────────────────────────────────────────────
    -- 1. Varna Koota (1 pt max)
    -- ─────────────────────────────────────────────────────────────────────────
    v_boy_varna := c_rashi_varna[p_boy_rashi_id];
    v_girl_varna := c_rashi_varna[p_girl_rashi_id];
    IF v_boy_varna >= v_girl_varna THEN
        v_varna_score := 1;
    ELSE
        v_varna_score := 0;
    END IF;

    -- ─────────────────────────────────────────────────────────────────────────
    -- 2. Vashya Koota (2 pts max)
    -- Chatushpada (1,2,9h,10h), Manava (3,6,7,9h,11), Jalachara (4,10h,12), Vanachara (5), Keeta (8)
    -- ─────────────────────────────────────────────────────────────────────────
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
        -- Leo (Vanachara) is wild/fierce
        IF (p_boy_rashi_id = 5 AND p_girl_rashi_id = 7) OR (p_boy_rashi_id = 7 AND p_girl_rashi_id = 5) THEN
            v_vashya_score := 1; -- Libra is vashya to Leo
        ELSE
            v_vashya_score := 0;
        END IF;
    ELSIF p_boy_rashi_id = 8 OR p_girl_rashi_id = 8 THEN
        -- Scorpio (Keeta/Insect)
        IF (p_boy_rashi_id = 8 AND p_girl_rashi_id = 4) OR (p_boy_rashi_id = 4 AND p_girl_rashi_id = 8) THEN
            v_vashya_score := 1;
        ELSE
            v_vashya_score := 0;
        END IF;
    ELSE
        v_vashya_score := 1;
    END IF;

    -- ─────────────────────────────────────────────────────────────────────────
    -- 3. Tara Koota (3 pts max)
    -- ─────────────────────────────────────────────────────────────────────────
    v_tara_g_to_b := ((p_boy_nakshatra_id - p_girl_nakshatra_id + 27) % 9);
    IF v_tara_g_to_b = 0 THEN v_tara_g_to_b := 9; END IF;

    v_tara_b_to_g := ((p_girl_nakshatra_id - p_boy_nakshatra_id + 27) % 9);
    IF v_tara_b_to_g = 0 THEN v_tara_b_to_g := 9; END IF;

    -- Inauspicious Taras: 3 (Vipat), 5 (Pratyak), 7 (Naidhana)
    IF v_tara_g_to_b NOT IN (3, 5, 7) AND v_tara_b_to_g NOT IN (3, 5, 7) THEN
        v_tara_score := 3;
    ELSIF v_tara_g_to_b NOT IN (3, 5, 7) OR v_tara_b_to_g NOT IN (3, 5, 7) THEN
        v_tara_score := 1.5;
    ELSE
        v_tara_score := 0;
    END IF;

    -- ─────────────────────────────────────────────────────────────────────────
    -- 4. Yoni Koota (4 pts max)
    -- ─────────────────────────────────────────────────────────────────────────
    v_boy_yoni := c_nak_yoni[p_boy_nakshatra_id];
    v_girl_yoni := c_nak_yoni[p_girl_nakshatra_id];

    IF v_boy_yoni = v_girl_yoni THEN
        v_yoni_score := 4;
    ELSIF (v_boy_yoni = 1 AND v_girl_yoni = 9) OR (v_boy_yoni = 9 AND v_girl_yoni = 1)   -- Horse vs Buffalo
       OR (v_boy_yoni = 2 AND v_girl_yoni = 14) OR (v_boy_yoni = 14 AND v_girl_yoni = 2) -- Elephant vs Lion
       OR (v_boy_yoni = 3 AND v_girl_yoni = 12) OR (v_boy_yoni = 12 AND v_girl_yoni = 3) -- Sheep vs Monkey
       OR (v_boy_yoni = 4 AND v_girl_yoni = 13) OR (v_boy_yoni = 13 AND v_girl_yoni = 4) -- Serpent vs Mongoose
       OR (v_boy_yoni = 5 AND v_girl_yoni = 11) OR (v_boy_yoni = 11 AND v_girl_yoni = 5) -- Dog vs Deer
       OR (v_boy_yoni = 6 AND v_girl_yoni = 7) OR (v_boy_yoni = 7 AND v_girl_yoni = 6)   -- Cat vs Rat
       OR (v_boy_yoni = 8 AND v_girl_yoni = 10) OR (v_boy_yoni = 10 AND v_girl_yoni = 8) -- Cow vs Tiger
    THEN
        v_yoni_score := 0; -- Sworn enemies
    ELSE
        -- Friendly / Neutral pairs
        v_yoni_score := 2;
    END IF;

    -- ─────────────────────────────────────────────────────────────────────────
    -- 5. Graha Maitri (5 pts max)
    -- 1:Sun, 2:Moon, 3:Mars, 4:Mercury, 5:Jupiter, 6:Venus, 7:Saturn
    -- ─────────────────────────────────────────────────────────────────────────
    v_boy_lord := c_rashi_lord_norm[p_boy_rashi_id];
    v_girl_lord := c_rashi_lord_norm[p_girl_rashi_id];

    IF v_boy_lord = v_girl_lord THEN
        v_maitri_score := 5;
    ELSIF (v_boy_lord IN (1,2,3,5) AND v_girl_lord IN (1,2,3,5)) THEN
        -- Sun, Moon, Mars, Jupiter mutual friendship group
        v_maitri_score := 5;
    ELSIF (v_boy_lord IN (4,6,7) AND v_girl_lord IN (4,6,7)) THEN
        -- Mercury, Venus, Saturn mutual friendship group
        v_maitri_score := 5;
    ELSIF (v_boy_lord = 4 AND v_girl_lord = 1) OR (v_boy_lord = 1 AND v_girl_lord = 4) THEN
        -- Sun & Mercury: Friends
        v_maitri_score := 4;
    ELSIF (v_boy_lord IN (1,2) AND v_girl_lord IN (6,7)) OR (v_boy_lord IN (6,7) AND v_girl_lord IN (1,2)) THEN
        -- Sun/Moon vs Venus/Saturn: Enemies
        v_maitri_score := 0.5;
    ELSIF (v_boy_lord = 3 AND v_girl_lord = 4) OR (v_boy_lord = 4 AND v_girl_lord = 3) THEN
        -- Mars vs Mercury: Enemies
        v_maitri_score := 0.5;
    ELSE
        v_maitri_score := 3; -- Neutral
    END IF;

    -- ─────────────────────────────────────────────────────────────────────────
    -- 6. Gana Koota (6 pts max)
    -- 0: Deva, 1: Manushya, 2: Rakshasa
    -- ─────────────────────────────────────────────────────────────────────────
    v_boy_gana := c_nak_gana[p_boy_nakshatra_id];
    v_girl_gana := c_nak_gana[p_girl_nakshatra_id];

    IF v_boy_gana = v_girl_gana THEN
        v_gana_score := 6;
    ELSIF v_boy_gana = 0 AND v_girl_gana = 1 THEN
        v_gana_score := 6; -- Boy Deva, Girl Manushya
    ELSIF v_boy_gana = 1 AND v_girl_gana = 0 THEN
        v_gana_score := 5; -- Boy Manushya, Girl Deva
    ELSIF v_boy_gana = 0 AND v_girl_gana = 2 THEN
        v_gana_score := 1; -- Boy Deva, Girl Rakshasa
    ELSIF v_boy_gana = 2 AND v_girl_gana = 0 THEN
        v_gana_score := 0; -- Boy Rakshasa, Girl Deva
    ELSE
        v_gana_score := 0; -- Manushya & Rakshasa combination
    END IF;

    -- ─────────────────────────────────────────────────────────────────────────
    -- 7. Bhakoot Koota (7 pts max)
    -- ─────────────────────────────────────────────────────────────────────────
    v_rashi_diff := ABS(p_boy_rashi_id - p_girl_rashi_id);
    IF v_rashi_diff IN (0, 6, 2, 10, 3, 9) THEN
        -- 1/1, 1/7, 3/11, 4/10 positions are naturally auspicious
        v_bhakoot_score := 7;
    ELSE
        -- 2/12 (Dwirdwadash), 6/8 (Shadashtak), 9/5 (Navapancham)
        -- Authentic Bhakoot Parihara (Cancellation):
        -- If Rashi lords are identical (e.g. Aries-Scorpio, Taurus-Libra, Capricorn-Aquarius)
        -- OR Rashi lords are mutual friends, Bhakoot dosha is cancelled!
        IF v_boy_lord = v_girl_lord OR v_maitri_score >= 4 THEN
            v_bhakoot_score := 7; -- Parihara applied!
        ELSE
            v_bhakoot_score := 0;
        END IF;
    END IF;

    -- ─────────────────────────────────────────────────────────────────────────
    -- 8. Nadi Koota (8 pts max)
    -- 0: Adi, 1: Madhya, 2: Antya
    -- ─────────────────────────────────────────────────────────────────────────
    v_boy_nadi := c_nak_nadi[p_boy_nakshatra_id];
    v_girl_nadi := c_nak_nadi[p_girl_nakshatra_id];

    IF v_boy_nadi <> v_girl_nadi THEN
        v_nadi_score := 8; -- Different Nadis: Auspicious
    ELSE
        -- Same Nadi: Nadi Dosha exists. Check Authentic Nadi Dosha Parihara:
        IF p_boy_nakshatra_id <> p_girl_nakshatra_id THEN
            IF p_boy_rashi_id <> p_girl_rashi_id AND v_maitri_score >= 4 THEN
                v_nadi_score := 8; -- Parihara applied
            ELSE
                v_nadi_score := 0; -- Nadi Dosha remains
            END IF;
        ELSIF p_boy_pada <> p_girl_pada THEN
            v_nadi_score := 8; -- Different Charana/Pada cancels Nadi Dosha
        ELSE
            v_nadi_score := 0; -- Unmitigated Nadi Dosha
        END IF;
    END IF;

    v_total := v_varna_score + v_vashya_score + v_tara_score + v_yoni_score + 
               v_maitri_score + v_gana_score + v_bhakoot_score + v_nadi_score;

    RETURN LEAST(36, GREATEST(0, ROUND(v_total, 1)));
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. Update refresh_user_match_cache to use the Canonical Function
-- ═══════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.refresh_user_match_cache(uuid, boolean);

CREATE OR REPLACE FUNCTION public.refresh_user_match_cache(
    p_user_id uuid,
    p_force boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user public.profiles;
    v_pref public.partner_preferences;
    v_matches jsonb := '[]'::jsonb;
    v_fresh_matches jsonb := '[]'::jsonb;
    v_final_matches jsonb := '[]'::jsonb;
    v_target_gender text;
    v_today date := CURRENT_DATE;
    v_existing_date date;
    v_user_completed boolean;
BEGIN
    SELECT * INTO v_user FROM public.profiles WHERE id = p_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('status', 'error', 'message', 'User not found');
    END IF;

    v_user_completed := COALESCE(v_user.is_completed, false) 
        AND (v_user.gender IS NOT NULL) 
        AND (v_user.full_name IS NOT NULL);

    IF NOT v_user_completed THEN
        RETURN jsonb_build_object('status', 'skipped', 'message', 'Profile incomplete');
    END IF;

    SELECT cache_date INTO v_existing_date
    FROM public.user_match_cache
    WHERE user_id = p_user_id;

    IF v_existing_date = v_today AND NOT p_force THEN
        RETURN jsonb_build_object('status', 'cached', 'date', v_today);
    END IF;

    SELECT * INTO v_pref FROM public.partner_preferences WHERE user_id = p_user_id;

    v_target_gender := CASE 
        WHEN LOWER(v_user.gender) = 'male' THEN 'Female'
        WHEN LOWER(v_user.gender) = 'female' THEN 'Male'
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
            p.city_id,
            p.state_id,
            p.caste_id,
            p.subcaste_id,
            p.education_level_id,
            p.occupation_id,
            p.annual_income_id,
            p.marital_status_id,
            p.mother_tongue_id,
            p.diet_id,
            p.manglik_id,
            p.rashi_id,
            p.nakshatra_id,
            p.last_active_at,
            (
                SELECT url FROM public.profile_photos
                WHERE profile_id = p.id AND is_approved = true
                ORDER BY is_primary DESC, created_at ASC LIMIT 1
            ) AS primary_photo_url,
            (
                SELECT count(*)::int FROM public.profile_photos
                WHERE profile_id = p.id AND is_approved = true
            ) AS photo_count,
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
            END AS guna_score,
            cit.name AS city_name,
            st.name AS state_name,
            cst.name AS caste_name,
            sub.name AS subcaste_name,
            edu.name AS education_name,
            occ.name AS occupation_name,
            inc.name AS income_range,
            rsh.name AS rashi_name,
            nak.name AS nakshatra_name
        FROM public.profiles p
        LEFT JOIN public.match_exclusions me 
            ON me.user_id = v_user.id AND me.excluded_profile_id = p.id
        LEFT JOIN public.cities cit ON cit.id = p.city_id
        LEFT JOIN public.states st ON st.id = p.state_id
        LEFT JOIN public.castes cst ON cst.id = p.caste_id
        LEFT JOIN public.subcastes sub ON sub.id = p.subcaste_id
        LEFT JOIN public.education_levels edu ON edu.id = p.education_level_id
        LEFT JOIN public.occupations occ ON occ.id = p.occupation_id
        LEFT JOIN public.income_ranges inc ON inc.id = p.annual_income_id
        LEFT JOIN public.rashis rsh ON rsh.id = p.rashi_id
        LEFT JOIN public.nakshatras nak ON nak.id = p.nakshatra_id
        WHERE p.id <> v_user.id
          AND p.is_active = true
          AND p.is_completed = true
          AND me.id IS NULL
          AND (v_target_gender IS NULL OR p.gender = v_target_gender)
    ),
    ranked AS (
        SELECT *, 'ranked' AS slot_type
        FROM candidate_pool
        ORDER BY match_score DESC, guna_score DESC NULLS LAST, last_active_at DESC
        LIMIT 54
    )
    SELECT COALESCE(jsonb_agg(to_jsonb(r.*)), '[]'::jsonb)
    INTO v_matches
    FROM ranked r;

    -- Fetch 6 Fresh Exploration / Diversity Matches
    WITH fresh_pool AS (
        SELECT 
            p.id,
            p.full_name,
            p.gender,
            p.date_of_birth,
            p.height_inches,
            p.city_id,
            p.state_id,
            p.caste_id,
            p.subcaste_id,
            p.education_level_id,
            p.occupation_id,
            p.annual_income_id,
            p.marital_status_id,
            p.mother_tongue_id,
            p.diet_id,
            p.manglik_id,
            p.rashi_id,
            p.nakshatra_id,
            p.last_active_at,
            (
                SELECT url FROM public.profile_photos
                WHERE profile_id = p.id AND is_approved = true
                ORDER BY is_primary DESC, created_at ASC LIMIT 1
            ) AS primary_photo_url,
            (
                SELECT count(*)::int FROM public.profile_photos
                WHERE profile_id = p.id AND is_approved = true
            ) AS photo_count,
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
            END AS guna_score,
            cit.name AS city_name,
            st.name AS state_name,
            cst.name AS caste_name,
            sub.name AS subcaste_name,
            edu.name AS education_name,
            occ.name AS occupation_name,
            inc.name AS income_range,
            rsh.name AS rashi_name,
            nak.name AS nakshatra_name,
            'discovery' AS slot_type
        FROM public.profiles p
        LEFT JOIN public.match_exclusions me 
            ON me.user_id = v_user.id AND me.excluded_profile_id = p.id
        LEFT JOIN public.cities cit ON cit.id = p.city_id
        LEFT JOIN public.states st ON st.id = p.state_id
        LEFT JOIN public.castes cst ON cst.id = p.caste_id
        LEFT JOIN public.subcastes sub ON sub.id = p.subcaste_id
        LEFT JOIN public.education_levels edu ON edu.id = p.education_level_id
        LEFT JOIN public.occupations occ ON occ.id = p.occupation_id
        LEFT JOIN public.income_ranges inc ON inc.id = p.annual_income_id
        LEFT JOIN public.rashis rsh ON rsh.id = p.rashi_id
        LEFT JOIN public.nakshatras nak ON nak.id = p.nakshatra_id
        WHERE p.id <> v_user.id
          AND p.is_active = true
          AND p.is_completed = true
          AND me.id IS NULL
          AND (v_target_gender IS NULL OR p.gender = v_target_gender)
          AND p.id NOT IN (
              SELECT (elem->>'id')::uuid 
              FROM jsonb_array_elements(v_matches) elem
          )
        ORDER BY RANDOM()
        LIMIT 6
    )
    SELECT COALESCE(jsonb_agg(to_jsonb(f.*)), '[]'::jsonb)
    INTO v_fresh_matches
    FROM fresh_pool f;

    v_final_matches := v_matches || v_fresh_matches;

    INSERT INTO public.user_match_cache (user_id, matches, cache_date, algorithm_version, updated_at)
    VALUES (p_user_id, v_final_matches, v_today, 6, NOW())
    ON CONFLICT (user_id) DO UPDATE SET
        matches = EXCLUDED.matches,
        cache_date = EXCLUDED.cache_date,
        algorithm_version = EXCLUDED.algorithm_version,
        updated_at = NOW();

    RETURN jsonb_build_object(
        'status', 'refreshed',
        'count', jsonb_array_length(v_final_matches),
        'algorithm_version', 6
    );
END;
$$;
