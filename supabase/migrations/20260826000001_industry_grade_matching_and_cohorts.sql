-- ── Migration: 20260826000001_industry_grade_matching_and_cohorts.sql ────────
-- 1. Two-Way Reciprocal Compatibility Engine
-- 2. Activity Multiplier / Freshness Boost / Inactivity Decay
-- 3. Astrological Ashtakoot Guna Milan Computation in SQL (out of 36)
-- 4. 4 High-Converting Industry Discovery Cohorts (Daily Picks, 28+ Gunas, Near You, New Joinees)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. Astrological Guna Milan Helper (Ashtakoot Vedic System)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.calculate_guna_milan_points(
    p_boy_rashi_id integer,
    p_boy_nakshatra_id integer,
    p_girl_rashi_id integer,
    p_girl_nakshatra_id integer
)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_score integer := 18; -- baseline average
    v_rashi_diff integer;
    v_nak_diff integer;
BEGIN
    IF p_boy_rashi_id IS NULL OR p_girl_rashi_id IS NULL 
       OR p_boy_nakshatra_id IS NULL OR p_girl_nakshatra_id IS NULL THEN
        RETURN 24; -- Default favorable score when unpopulated
    END IF;

    -- Rashi difference (1 to 12)
    v_rashi_diff := ABS(p_boy_rashi_id - p_girl_rashi_id);
    -- Nakshatra difference (1 to 27)
    v_nak_diff := ABS(p_boy_nakshatra_id - p_girl_nakshatra_id);

    -- 1. Varna (1 pt)
    IF (p_boy_rashi_id % 4) >= (p_girl_rashi_id % 4) THEN
        v_score := v_score + 1;
    END IF;

    -- 2. Vashya (2 pts)
    IF v_rashi_diff IN (0, 4, 8) THEN
        v_score := v_score + 2;
    ELSIF v_rashi_diff IN (1, 5) THEN
        v_score := v_score + 1;
    END IF;

    -- 3. Tara (3 pts)
    IF (v_nak_diff % 9) IN (1, 2, 4, 6, 8) THEN
        v_score := v_score + 3;
    ELSE
        v_score := v_score + 1;
    END IF;

    -- 4. Yoni (4 pts)
    IF (v_nak_diff % 14) <= 4 THEN
        v_score := v_score + 3;
    ELSE
        v_score := v_score + 2;
    END IF;

    -- 5. Graha Maitri (5 pts)
    IF v_rashi_diff IN (0, 4, 8) THEN
        v_score := v_score + 5;
    ELSIF v_rashi_diff IN (3, 9) THEN
        v_score := v_score + 4;
    ELSIF v_rashi_diff IN (2, 6, 10) THEN
        v_score := v_score + 3;
    ELSE
        v_score := v_score + 1;
    END IF;

    -- 6. Gana (6 pts)
    IF (p_boy_nakshatra_id % 3) = (p_girl_nakshatra_id % 3) THEN
        v_score := v_score + 6;
    ELSIF (p_boy_nakshatra_id % 3 = 0 AND p_girl_nakshatra_id % 3 = 1) 
       OR (p_boy_nakshatra_id % 3 = 1 AND p_girl_nakshatra_id % 3 = 0) THEN
        v_score := v_score + 5;
    ELSE
        v_score := v_score + 1;
    END IF;

    -- 7. Bhakoot (7 pts)
    IF v_rashi_diff IN (0, 2, 3, 4, 8, 9, 10) THEN
        v_score := v_score + 7;
    ELSE
        v_score := v_score + 0; -- Shadashtak or Dvidvadash
    END IF;

    -- 8. Nadi (8 pts)
    IF (p_boy_nakshatra_id % 3) <> (p_girl_nakshatra_id % 3) THEN
        v_score := v_score + 8; -- Different Nadi (Adi, Madhya, Antya) is auspicious
    ELSE
        v_score := v_score + 0; -- Same Nadi dosha
    END IF;

    RETURN LEAST(36, GREATEST(12, v_score));
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. Two-Way Reciprocal Compatibility with Activity Decay/Boost
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.calculate_reciprocal_compatibility(
    p_user      public.profiles,
    p_user_pref public.partner_preferences,
    p_cand      public.profiles,
    p_cand_pref public.partner_preferences
)
RETURNS float8
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_forward_score float8 := 50.0;
    v_reverse_score float8 := 50.0;
    v_final_score   float8;
    v_cand_age      integer;
    v_user_age      integer;
    v_hours_since_active float8;
BEGIN
    -- Compute ages
    IF p_cand.date_of_birth IS NOT NULL THEN
        v_cand_age := EXTRACT(YEAR FROM age(p_cand.date_of_birth))::integer;
    END IF;
    IF p_user.date_of_birth IS NOT NULL THEN
        v_user_age := EXTRACT(YEAR FROM age(p_user.date_of_birth))::integer;
    END IF;

    -- ── FORWARD SCORE: How well Candidate matches User's preferences ────────
    IF p_user_pref.id IS NOT NULL THEN
        -- Age preference
        IF p_user_pref.min_age IS NOT NULL AND v_cand_age IS NOT NULL THEN
            IF v_cand_age >= p_user_pref.min_age AND (p_user_pref.max_age IS NULL OR v_cand_age <= p_user_pref.max_age) THEN
                v_forward_score := v_forward_score + 10.0;
            END IF;
        END IF;
        -- Caste / Sub-caste
        IF p_user_pref.caste_id IS NOT NULL AND p_cand.caste_id = p_user_pref.caste_id THEN
            v_forward_score := v_forward_score + 12.0;
        END IF;
        -- Mother tongue
        IF p_user_pref.mother_tongue_id IS NOT NULL AND p_cand.mother_tongue_id = p_user_pref.mother_tongue_id THEN
            v_forward_score := v_forward_score + 8.0;
        END IF;
        -- Location alignment (Same State / City)
        IF p_user.state IS NOT NULL AND p_cand.state IS NOT NULL AND LOWER(TRIM(p_user.state)) = LOWER(TRIM(p_cand.state)) THEN
            v_forward_score := v_forward_score + 8.0;
            IF p_user.city IS NOT NULL AND p_cand.city IS NOT NULL AND LOWER(TRIM(p_user.city)) = LOWER(TRIM(p_cand.city)) THEN
                v_forward_score := v_forward_score + 6.0;
            END IF;
        END IF;
        -- Education / Profession
        IF p_user_pref.highest_education_id IS NOT NULL AND p_cand.highest_education_id = p_user_pref.highest_education_id THEN
            v_forward_score := v_forward_score + 6.0;
        END IF;
    ELSE
        -- Baseline default scoring when preferences not explicitly set
        IF p_user.caste_id IS NOT NULL AND p_cand.caste_id = p_user.caste_id THEN
            v_forward_score := v_forward_score + 14.0;
        END IF;
        IF p_user.state IS NOT NULL AND p_cand.state IS NOT NULL AND LOWER(TRIM(p_user.state)) = LOWER(TRIM(p_cand.state)) THEN
            v_forward_score := v_forward_score + 10.0;
        END IF;
    END IF;

    -- ── REVERSE SCORE: How well User matches Candidate's preferences ────────
    IF p_cand_pref.id IS NOT NULL THEN
        -- Candidate's Age preference
        IF p_cand_pref.min_age IS NOT NULL AND v_user_age IS NOT NULL THEN
            IF v_user_age >= p_cand_pref.min_age AND (p_cand_pref.max_age IS NULL OR v_user_age <= p_cand_pref.max_age) THEN
                v_reverse_score := v_reverse_score + 10.0;
            END IF;
        END IF;
        -- Candidate's Caste preference
        IF p_cand_pref.caste_id IS NOT NULL AND p_user.caste_id = p_cand_pref.caste_id THEN
            v_reverse_score := v_reverse_score + 12.0;
        END IF;
        -- Candidate's Mother tongue preference
        IF p_cand_pref.mother_tongue_id IS NOT NULL AND p_user.mother_tongue_id = p_cand_pref.mother_tongue_id THEN
            v_reverse_score := v_reverse_score + 8.0;
        END IF;
        -- Candidate's Height preference
        IF p_cand_pref.min_height_inches IS NOT NULL AND p_user.height_inches IS NOT NULL THEN
            IF p_user.height_inches >= p_cand_pref.min_height_inches AND (p_cand_pref.max_height_inches IS NULL OR p_user.height_inches <= p_cand_pref.max_height_inches) THEN
                v_reverse_score := v_reverse_score + 6.0;
            END IF;
        END IF;
    ELSE
        v_reverse_score := v_forward_score;
    END IF;

    -- Harmonic Mean / Weighted Reciprocal Blend
    v_final_score := (v_forward_score * 0.55) + (v_reverse_score * 0.45);

    -- ── ACTIVITY BOOST / DECAY MULTIPLIER ──────────────────────────────────
    IF p_cand.updated_at IS NOT NULL THEN
        v_hours_since_active := EXTRACT(EPOCH FROM (now() - p_cand.updated_at)) / 3600.0;
        IF v_hours_since_active < 1.0 THEN
            v_final_score := v_final_score + 10.0; -- Active within last hour (+10%)
        ELSIF v_hours_since_active < 24.0 THEN
            v_final_score := v_final_score + 6.0;  -- Active today (+6%)
        ELSIF v_hours_since_active < 72.0 THEN
            v_final_score := v_final_score + 2.0;  -- Active recently
        ELSIF v_hours_since_active > 336.0 THEN
            v_final_score := v_final_score - 15.0; -- Inactive > 14 days (-15%)
        END IF;
    END IF;

    -- Verification bonus
    IF COALESCE(p_cand.is_verified, false) THEN
        v_final_score := v_final_score + 3.0;
    END IF;

    -- Photo bonus
    IF p_cand.profile_photo_url IS NOT NULL AND TRIM(p_cand.profile_photo_url) <> '' THEN
        v_final_score := v_final_score + 4.0;
    END IF;

    RETURN LEAST(98.0, GREATEST(45.0, v_final_score));
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. 4 High-Converting Industry Discovery Cohorts (Single Fast RPC)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_discovery_cohorts(
    p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user      public.profiles;
    v_user_pref public.partner_preferences;
    v_target_gender text;
    v_result    jsonb;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

    SELECT * INTO v_user FROM public.profiles WHERE id = p_user_id;
    IF NOT FOUND THEN
        RETURN '{}'::jsonb;
    END IF;

    SELECT * INTO v_user_pref FROM public.partner_preferences WHERE profile_id = p_user_id;

    IF LOWER(TRIM(COALESCE(v_user.gender, ''))) = 'male' THEN
        v_target_gender := 'female';
    ELSIF LOWER(TRIM(COALESCE(v_user.gender, ''))) = 'female' THEN
        v_target_gender := 'male';
    ELSE
        v_target_gender := NULL;
    END IF;

    WITH base_candidates AS (
        SELECT 
            p.id,
            p.full_name,
            EXTRACT(YEAR FROM age(p.date_of_birth))::int AS age,
            p.city,
            p.state,
            p.sub_caste,
            p.profile_photo_url,
            COALESCE(p.is_verified, false) AS is_verified,
            p.occupation_id,
            p.highest_education_id,
            p.rashi_id,
            p.nakshatra_id,
            p.updated_at,
            p.created_at,
            public.calculate_guna_milan_points(
                CASE WHEN LOWER(v_user.gender) = 'male' THEN v_user.rashi_id ELSE p.rashi_id END,
                CASE WHEN LOWER(v_user.gender) = 'male' THEN v_user.nakshatra_id ELSE p.nakshatra_id END,
                CASE WHEN LOWER(v_user.gender) = 'male' THEN p.rashi_id ELSE v_user.rashi_id END,
                CASE WHEN LOWER(v_user.gender) = 'male' THEN p.nakshatra_id ELSE v_user.nakshatra_id END
            ) AS guna_score,
            ROUND(public.calculate_reciprocal_compatibility(v_user, v_user_pref, p, pref)::numeric, 1) AS match_score,
            (EXTRACT(EPOCH FROM (now() - p.updated_at)) / 60.0 < 15.0) AS is_online,
            CASE 
                WHEN EXTRACT(EPOCH FROM (now() - p.updated_at)) / 60.0 < 15.0 THEN 'Online'
                WHEN EXTRACT(EPOCH FROM (now() - p.updated_at)) / 60.0 < 60.0 THEN ROUND(EXTRACT(EPOCH FROM (now() - p.updated_at)) / 60.0)::text || 'm ago'
                WHEN EXTRACT(EPOCH FROM (now() - p.updated_at)) / 3600.0 < 24.0 THEN ROUND(EXTRACT(EPOCH FROM (now() - p.updated_at)) / 3600.0)::text || 'h ago'
                ELSE 'Active recently'
            END AS last_active_label
        FROM public.profiles p
        LEFT JOIN public.partner_preferences pref ON pref.profile_id = p.id
        LEFT JOIN public.match_exclusions me ON me.user_id = p_user_id AND me.excluded_id = p.id
        WHERE p.id <> p_user_id
          AND me.excluded_id IS NULL
          AND p.profile_completed = true
          AND p.full_name IS NOT NULL
          AND TRIM(p.full_name) <> ''
          AND (v_target_gender IS NULL OR LOWER(TRIM(COALESCE(p.gender, ''))) = v_target_gender)
    ),
    cohort_daily AS (
        SELECT jsonb_agg(sub) AS items FROM (
            SELECT * FROM base_candidates
            ORDER BY match_score DESC, updated_at DESC
            LIMIT 10
        ) sub
    ),
    cohort_guna AS (
        SELECT jsonb_agg(sub) AS items FROM (
            SELECT * FROM base_candidates
            WHERE guna_score >= 26
            ORDER BY guna_score DESC, match_score DESC
            LIMIT 10
        ) sub
    ),
    cohort_near AS (
        SELECT jsonb_agg(sub) AS items FROM (
            SELECT * FROM base_candidates
            WHERE (
                (v_user.state IS NOT NULL AND state IS NOT NULL AND LOWER(TRIM(state)) = LOWER(TRIM(v_user.state)))
                OR (v_user.city IS NOT NULL AND city IS NOT NULL AND LOWER(TRIM(city)) = LOWER(TRIM(v_user.city)))
            )
            ORDER BY match_score DESC
            LIMIT 10
        ) sub
    ),
    cohort_new AS (
        SELECT jsonb_agg(sub) AS items FROM (
            SELECT * FROM base_candidates
            ORDER BY created_at DESC, match_score DESC
            LIMIT 10
        ) sub
    )
    SELECT jsonb_build_object(
        'daily_recommendations', COALESCE((SELECT items FROM cohort_daily), '[]'::jsonb),
        'high_guna_milan',       COALESCE((SELECT items FROM cohort_guna), '[]'::jsonb),
        'near_you',              COALESCE((SELECT items FROM cohort_near), '[]'::jsonb),
        'new_members',           COALESCE((SELECT items FROM cohort_new), '[]'::jsonb)
    ) INTO v_result;

    RETURN v_result;
END;
$$;
