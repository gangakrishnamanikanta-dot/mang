-- ============================================================================
-- Migration: 20260927000003_biodata_public_view_and_matching_sync.sql
-- Purpose:
--   1. Expand public.public_profiles view to include all non-sensitive Biodata
--      columns while keeping phone and email strictly excluded.
--   2. Keep profiles.pada and profiles.pada_id synchronized automatically via trigger.
--   3. Upgrade calculate_reciprocal_compatibility to evaluate full Partner Preferences.
-- ============================================================================

-- 1. Synchronize pada and pada_id on public.profiles
UPDATE public.profiles
SET pada_id = COALESCE(pada_id, pada, 1),
    pada = COALESCE(pada_id, pada, 1)
WHERE pada_id IS DISTINCT FROM pada;

CREATE OR REPLACE FUNCTION public.sync_profile_pada_columns()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.pada_id IS DISTINCT FROM OLD.pada_id AND NEW.pada_id IS NOT NULL THEN
    NEW.pada := NEW.pada_id;
  ELSIF NEW.pada IS DISTINCT FROM OLD.pada AND NEW.pada IS NOT NULL THEN
    NEW.pada_id := NEW.pada;
  ELSIF NEW.pada_id IS NOT NULL AND NEW.pada IS NULL THEN
    NEW.pada := NEW.pada_id;
  ELSIF NEW.pada IS NOT NULL AND NEW.pada_id IS NULL THEN
    NEW.pada_id := NEW.pada;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_profile_pada ON public.profiles;
CREATE TRIGGER trg_sync_profile_pada
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.sync_profile_pada_columns();

-- 2. Rebuild public.public_profiles view with all public Biodata columns
DROP VIEW IF EXISTS public.public_profiles;
CREATE VIEW public.public_profiles AS
SELECT
    p.id,
    p.full_name,
    p.gender,
    p.date_of_birth,
    EXTRACT(year FROM age(p.date_of_birth::timestamp with time zone))::integer AS age,
    p.height_inches,
    p.marital_status_id,
    p.mother_tongue_id,
    p.caste_id,
    p.sub_caste,
    p.gothram_id,
    p.pravara,
    p.veda_shakha_id,
    p.nakshatra_id,
    p.rashi_id,
    COALESCE(p.pada_id, p.pada) AS pada_id,
    COALESCE(p.pada, p.pada_id) AS pada,
    p.time_of_birth,
    p.place_of_birth,
    p.is_manglik,
    p.kuja_dosham,
    CASE WHEN COALESCE(p.show_horoscope, false) = true THEN p.horoscope_url ELSE NULL END AS horoscope_url,
    p.sampradayam,
    p.kuladevata,
    p.sandhyavandanam,
    p.daily_pooja,
    p.sloka_chanting,
    p.temple_visits,
    p.festival_participation,
    p.highest_education_id,
    p.college,
    p.occupation_id,
    p.company,
    p.annual_income_id,
    p.work_location,
    p.work_type,
    p.career_preference,
    p.father_name,
    p.father_occupation,
    p.mother_name,
    p.mother_occupation,
    p.family_type_id,
    p.family_values,
    p.family_description,
    p.native_place,
    p.brothers_count,
    p.sisters_count,
    p.country_id,
    p.state_id,
    p.city_id,
    p.citizenship_id,
    p.state,
    p.city,
    p.food_preference_id,
    p.smoking_id,
    p.drinking_id,
    p.fitness_habits,
    p.personality_type,
    p.spiritual_level,
    p.cultural_interests,
    p.hobbies,
    p.about_me,
    p.profile_photo_url,
    p.additional_photo_urls,
    p.show_horoscope,
    p.profile_completed,
    p.created_for,
    p.is_verified,
    p.created_at,
    p.updated_at,
    p.last_active_at,
    p.account_type,
    p.allow_guardian_proxy_chat,
    COALESCE(p.is_hidden, false) AS is_hidden
FROM public.profiles p
WHERE COALESCE(p.profile_completed, false) = true
  AND COALESCE(p.account_type, 'candidate') = 'candidate';

GRANT SELECT ON public.public_profiles TO anon, authenticated;

-- 3. Upgrade calculate_reciprocal_compatibility to evaluate full Partner Preferences
CREATE OR REPLACE FUNCTION public.calculate_reciprocal_compatibility(
    p_user public.profiles,
    p_user_pref public.partner_preferences,
    p_cand public.profiles,
    p_cand_pref public.partner_preferences
)
RETURNS double precision
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public'
AS $$
DECLARE
    v_forward_score float8 := 20.0;
    v_reverse_score float8 := 20.0;
    v_final_score   float8;
    v_cand_age      integer;
    v_user_age      integer;
    v_hours_since_active float8;
    v_guna_points   integer := 0;
BEGIN
    IF p_cand.date_of_birth IS NOT NULL THEN
        v_cand_age := EXTRACT(YEAR FROM age(p_cand.date_of_birth::date))::integer;
    END IF;
    IF p_user.date_of_birth IS NOT NULL THEN
        v_user_age := EXTRACT(YEAR FROM age(p_user.date_of_birth::date))::integer;
    END IF;

    -- Sagotra Check (Same Gothram penalty for Vedic traditions)
    IF p_user.gothram_id IS NOT NULL AND p_cand.gothram_id IS NOT NULL AND p_user.gothram_id = p_cand.gothram_id THEN
        IF COALESCE(p_user_pref.exclude_same_gotra, true) THEN
            v_forward_score := v_forward_score - 20.0;
        END IF;
    END IF;

    -- Forward score: User evaluating Candidate
    IF p_user_pref.profile_id IS NOT NULL THEN
        -- 1. Age alignment (12 pts)
        IF p_user_pref.min_age IS NOT NULL AND v_cand_age IS NOT NULL THEN
            IF v_cand_age >= p_user_pref.min_age AND (p_user_pref.max_age IS NULL OR v_cand_age <= p_user_pref.max_age) THEN
                v_forward_score := v_forward_score + 12.0;
            END IF;
        END IF;

        -- 2. Height alignment (8 pts)
        IF p_user_pref.min_height_inches IS NOT NULL AND p_cand.height_inches IS NOT NULL THEN
            IF p_cand.height_inches >= p_user_pref.min_height_inches
               AND (p_user_pref.max_height_inches IS NULL OR p_cand.height_inches <= p_user_pref.max_height_inches) THEN
                v_forward_score := v_forward_score + 8.0;
            END IF;
        END IF;

        -- 3. Marital Status alignment (6 pts)
        IF p_user_pref.preferred_marital_status_ids IS NOT NULL AND array_length(p_user_pref.preferred_marital_status_ids, 1) > 0 THEN
            IF p_cand.marital_status_id = ANY(p_user_pref.preferred_marital_status_ids) THEN
                v_forward_score := v_forward_score + 6.0;
            END IF;
        ELSE
            v_forward_score := v_forward_score + 4.0;
        END IF;

        -- 4. Caste alignment (14 pts)
        IF p_user_pref.preferred_caste_ids IS NOT NULL AND array_length(p_user_pref.preferred_caste_ids, 1) > 0 THEN
            IF p_cand.caste_id = ANY(p_user_pref.preferred_caste_ids) THEN
                v_forward_score := v_forward_score + 14.0;
            END IF;
        ELSIF p_user.caste_id IS NOT NULL AND p_cand.caste_id = p_user.caste_id THEN
            v_forward_score := v_forward_score + 12.0;
        END IF;

        -- 5. Mother Tongue alignment (8 pts)
        IF p_user_pref.preferred_mother_tongue_ids IS NOT NULL AND array_length(p_user_pref.preferred_mother_tongue_ids, 1) > 0 THEN
            IF p_cand.mother_tongue_id = ANY(p_user_pref.preferred_mother_tongue_ids) THEN
                v_forward_score := v_forward_score + 8.0;
            END IF;
        ELSIF p_user.mother_tongue_id IS NOT NULL AND p_cand.mother_tongue_id = p_user.mother_tongue_id THEN
            v_forward_score := v_forward_score + 6.0;
        END IF;

        -- 6. Education & Occupation & Income alignment (10 pts)
        IF p_user_pref.preferred_education_ids IS NOT NULL AND array_length(p_user_pref.preferred_education_ids, 1) > 0 THEN
            IF p_cand.highest_education_id = ANY(p_user_pref.preferred_education_ids) THEN
                v_forward_score := v_forward_score + 4.0;
            END IF;
        ELSE
            v_forward_score := v_forward_score + 2.0;
        END IF;

        IF p_user_pref.preferred_occupation_ids IS NOT NULL AND array_length(p_user_pref.preferred_occupation_ids, 1) > 0 THEN
            IF p_cand.occupation_id = ANY(p_user_pref.preferred_occupation_ids) THEN
                v_forward_score := v_forward_score + 4.0;
            END IF;
        ELSE
            v_forward_score := v_forward_score + 2.0;
        END IF;

        IF p_user_pref.preferred_annual_income_id IS NOT NULL AND p_cand.annual_income_id IS NOT NULL THEN
            IF p_cand.annual_income_id >= p_user_pref.preferred_annual_income_id THEN
                v_forward_score := v_forward_score + 2.0;
            END IF;
        END IF;

        -- 7. Diet & Lifestyle alignment (6 pts)
        IF p_user_pref.preferred_food_ids IS NOT NULL AND array_length(p_user_pref.preferred_food_ids, 1) > 0 THEN
            IF p_cand.food_preference_id = ANY(p_user_pref.preferred_food_ids) THEN
                v_forward_score := v_forward_score + 4.0;
            END IF;
        END IF;
        IF p_user_pref.preferred_family_type_ids IS NOT NULL AND array_length(p_user_pref.preferred_family_type_ids, 1) > 0 THEN
            IF p_cand.family_type_id = ANY(p_user_pref.preferred_family_type_ids) THEN
                v_forward_score := v_forward_score + 2.0;
            END IF;
        END IF;

        -- 8. Location alignment (8 pts)
        IF COALESCE(p_user_pref.location_preference, 'any') = 'same_city' THEN
            IF p_user.city IS NOT NULL AND p_cand.city IS NOT NULL AND LOWER(TRIM(p_user.city)) = LOWER(TRIM(p_cand.city)) THEN
                v_forward_score := v_forward_score + 8.0;
            END IF;
        ELSIF COALESCE(p_user_pref.location_preference, 'any') = 'same_state' THEN
            IF p_user.state IS NOT NULL AND p_cand.state IS NOT NULL AND LOWER(TRIM(p_user.state)) = LOWER(TRIM(p_cand.state)) THEN
                v_forward_score := v_forward_score + 8.0;
            END IF;
        ELSE
            IF p_user.state IS NOT NULL AND p_cand.state IS NOT NULL AND LOWER(TRIM(p_user.state)) = LOWER(TRIM(p_cand.state)) THEN
                v_forward_score := v_forward_score + 5.0;
                IF p_user.city IS NOT NULL AND p_cand.city IS NOT NULL AND LOWER(TRIM(p_user.city)) = LOWER(TRIM(p_cand.city)) THEN
                    v_forward_score := v_forward_score + 3.0;
                END IF;
            END IF;
        END IF;
    ELSE
        IF p_user.caste_id IS NOT NULL AND p_cand.caste_id = p_user.caste_id THEN
            v_forward_score := v_forward_score + 25.0;
        END IF;
        IF p_user.state IS NOT NULL AND p_cand.state IS NOT NULL AND LOWER(TRIM(p_user.state)) = LOWER(TRIM(p_cand.state)) THEN
            v_forward_score := v_forward_score + 15.0;
        END IF;
    END IF;

    -- Reverse score: Candidate evaluating User
    IF p_cand_pref.profile_id IS NOT NULL THEN
        IF p_cand_pref.min_age IS NOT NULL AND v_user_age IS NOT NULL THEN
            IF v_user_age >= p_cand_pref.min_age AND (p_cand_pref.max_age IS NULL OR v_user_age <= p_cand_pref.max_age) THEN
                v_reverse_score := v_reverse_score + 15.0;
            END IF;
        END IF;
        IF p_cand_pref.preferred_caste_ids IS NOT NULL AND array_length(p_cand_pref.preferred_caste_ids, 1) > 0 AND p_user.caste_id IS NOT NULL THEN
            IF p_user.caste_id = ANY(p_cand_pref.preferred_caste_ids) THEN
                v_reverse_score := v_reverse_score + 20.0;
            END IF;
        ELSIF p_cand.caste_id IS NOT NULL AND p_user.caste_id = p_cand.caste_id THEN
            v_reverse_score := v_reverse_score + 15.0;
        END IF;
        IF p_cand_pref.preferred_mother_tongue_ids IS NOT NULL AND array_length(p_cand_pref.preferred_mother_tongue_ids, 1) > 0 AND p_user.mother_tongue_id IS NOT NULL THEN
            IF p_user.mother_tongue_id = ANY(p_cand_pref.preferred_mother_tongue_ids) THEN
                v_reverse_score := v_reverse_score + 10.0;
            END IF;
        END IF;
        IF p_cand_pref.min_height_inches IS NOT NULL AND p_user.height_inches IS NOT NULL THEN
            IF p_user.height_inches >= p_cand_pref.min_height_inches AND (p_cand_pref.max_height_inches IS NULL OR p_user.height_inches <= p_cand_pref.max_height_inches) THEN
                v_reverse_score := v_reverse_score + 10.0;
            END IF;
        END IF;
    ELSE
        v_reverse_score := v_forward_score;
    END IF;

    -- Base Reciprocal Preference Match (55% forward, 45% reverse)
    v_final_score := (v_forward_score * 0.55) + (v_reverse_score * 0.45);

    -- Vedic Guna Milan Integration (Strict & Canonical)
    IF p_user.rashi_id IS NOT NULL AND p_cand.rashi_id IS NOT NULL 
       AND p_user.nakshatra_id IS NOT NULL AND p_cand.nakshatra_id IS NOT NULL THEN
        IF LOWER(TRIM(COALESCE(p_user.gender, 'male'))) = 'male' THEN
            v_guna_points := public.calculate_guna_milan_points(
                p_user.rashi_id, p_user.nakshatra_id,
                p_cand.rashi_id, p_cand.nakshatra_id,
                COALESCE(p_user.pada_id, p_user.pada, 1),
                COALESCE(p_cand.pada_id, p_cand.pada, 1)
            );
        ELSE
            v_guna_points := public.calculate_guna_milan_points(
                p_cand.rashi_id, p_cand.nakshatra_id,
                p_user.rashi_id, p_user.nakshatra_id,
                COALESCE(p_cand.pada_id, p_cand.pada, 1),
                COALESCE(p_user.pada_id, p_user.pada, 1)
            );
        END IF;

        IF v_guna_points IS NOT NULL THEN
            IF v_guna_points >= 28 THEN
                v_final_score := v_final_score + 8.0;
            ELSIF v_guna_points >= 18 THEN
                v_final_score := v_final_score + 4.0;
            ELSIF v_guna_points > 0 AND v_guna_points < 14 THEN
                v_final_score := v_final_score - 8.0;
            END IF;
        END IF;
    END IF;

    -- Activity Boost / Decay
    IF p_cand.updated_at IS NOT NULL THEN
        v_hours_since_active := EXTRACT(EPOCH FROM (now() - p_cand.updated_at)) / 3600.0;
        IF v_hours_since_active < 1.0 THEN
            v_final_score := v_final_score + 5.0;
        ELSIF v_hours_since_active < 24.0 THEN
            v_final_score := v_final_score + 3.0;
        ELSIF v_hours_since_active > 336.0 THEN
            v_final_score := v_final_score - 10.0;
        END IF;
    END IF;

    IF COALESCE(p_cand.is_verified, false) THEN
        v_final_score := v_final_score + 2.0;
    END IF;

    IF p_cand.profile_photo_url IS NOT NULL AND TRIM(p_cand.profile_photo_url) <> '' THEN
        v_final_score := v_final_score + 3.0;
    END IF;

    RETURN LEAST(98.0, GREATEST(35.0, v_final_score));
END;
$$;

CREATE OR REPLACE FUNCTION public.calculate_reciprocal_compatibility(
    p_user public.profiles,
    p_cand public.profiles,
    p_user_pref public.partner_preferences,
    p_cand_pref public.partner_preferences
)
RETURNS double precision
LANGUAGE plpgsql
IMMUTABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
    RETURN public.calculate_reciprocal_compatibility(p_user, p_user_pref, p_cand, p_cand_pref);
END;
$$;

-- 4. Upgrade refresh_user_match_cache so cached JSONB matches include full biodata & 6-arg Guna Milan
CREATE OR REPLACE FUNCTION public.refresh_user_match_cache(p_user_id uuid, p_force boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
            p.country_id,
            p.native_place,
            p.caste_id,
            p.sub_caste,
            p.gothram_id,
            p.highest_education_id,
            p.college,
            p.occupation_id,
            p.company,
            p.work_location,
            p.annual_income_id,
            p.marital_status_id,
            p.mother_tongue_id,
            p.food_preference_id,
            p.family_type_id,
            p.rashi_id,
            p.nakshatra_id,
            COALESCE(p.pada_id, p.pada) AS pada_id,
            p.kuja_dosham,
            p.about_me,
            p.is_verified,
            p.last_active_at,
            p.profile_photo_url,
            p.profile_photo_url AS primary_photo_url,
            p.additional_photo_urls,
            (SELECT count(*)::int FROM public.profile_photos WHERE profile_id = p.id) AS photo_count,
            public.calculate_reciprocal_compatibility(v_user.id, p.id) AS match_score,
            CASE
                WHEN v_user.nakshatra_id IS NOT NULL AND p.nakshatra_id IS NOT NULL
                     AND (v_pref.exclude_same_gotra IS NOT TRUE OR v_user.gothram_id IS NULL OR p.gothram_id IS NULL OR v_user.gothram_id <> p.gothram_id)
                THEN
                    ROUND(public.calculate_guna_milan_points(
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN v_user.rashi_id ELSE p.rashi_id END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN v_user.nakshatra_id ELSE p.nakshatra_id END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN COALESCE(v_user.pada_id, v_user.pada, 1) ELSE COALESCE(p.pada_id, p.pada, 1) END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN p.rashi_id ELSE v_user.rashi_id END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN p.nakshatra_id ELSE v_user.nakshatra_id END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN COALESCE(p.pada_id, p.pada, 1) ELSE COALESCE(v_user.pada_id, v_user.pada, 1) END
                    ))::integer
                ELSE NULL
            END AS guna_score
        FROM public.profiles p
        LEFT JOIN public.match_exclusions me
            ON me.user_id = v_user.id AND me.excluded_id = p.id
        WHERE p.id <> v_user.id
          AND COALESCE(p.profile_completed, false) = true
          AND COALESCE(p.is_hidden, false) = false
          AND COALESCE(p.account_type, 'candidate') = 'candidate'
          AND me.excluded_id IS NULL
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
            p.country_id,
            p.native_place,
            p.caste_id,
            p.sub_caste,
            p.gothram_id,
            p.highest_education_id,
            p.college,
            p.occupation_id,
            p.company,
            p.work_location,
            p.annual_income_id,
            p.marital_status_id,
            p.mother_tongue_id,
            p.food_preference_id,
            p.family_type_id,
            p.rashi_id,
            p.nakshatra_id,
            COALESCE(p.pada_id, p.pada) AS pada_id,
            p.kuja_dosham,
            p.about_me,
            p.is_verified,
            p.last_active_at,
            p.profile_photo_url,
            p.profile_photo_url AS primary_photo_url,
            p.additional_photo_urls,
            (SELECT count(*)::int FROM public.profile_photos WHERE profile_id = p.id) AS photo_count,
            public.calculate_reciprocal_compatibility(v_user.id, p.id) AS match_score,
            CASE
                WHEN v_user.nakshatra_id IS NOT NULL AND p.nakshatra_id IS NOT NULL
                     AND (v_pref.exclude_same_gotra IS NOT TRUE OR v_user.gothram_id IS NULL OR p.gothram_id IS NULL OR v_user.gothram_id <> p.gothram_id)
                THEN
                    ROUND(public.calculate_guna_milan_points(
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN v_user.rashi_id ELSE p.rashi_id END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN v_user.nakshatra_id ELSE p.nakshatra_id END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN COALESCE(v_user.pada_id, v_user.pada, 1) ELSE COALESCE(p.pada_id, p.pada, 1) END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN p.rashi_id ELSE v_user.rashi_id END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN p.nakshatra_id ELSE v_user.nakshatra_id END,
                        CASE WHEN LOWER(v_user.gender) = 'male' THEN COALESCE(p.pada_id, p.pada, 1) ELSE COALESCE(v_user.pada_id, v_user.pada, 1) END
                    ))::integer
                ELSE NULL
            END AS guna_score
        FROM public.profiles p
        LEFT JOIN public.match_exclusions me
            ON me.user_id = v_user.id AND me.excluded_id = p.id
        WHERE p.id <> v_user.id
          AND COALESCE(p.profile_completed, false) = true
          AND COALESCE(p.is_hidden, false) = false
          AND COALESCE(p.account_type, 'candidate') = 'candidate'
          AND me.excluded_id IS NULL
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

    -- Upsert user match cache with computed_at & algorithm_version
    INSERT INTO public.user_match_cache (user_id, matches, computed_at, algorithm_version)
    VALUES (p_user_id, v_matches || v_fresh_matches, now(), 5)
    ON CONFLICT (user_id)
    DO UPDATE SET
        matches = EXCLUDED.matches,
        computed_at = now(),
        algorithm_version = 5;

    RETURN jsonb_build_object(
        'status', 'refreshed',
        'count', jsonb_array_length(v_matches || v_fresh_matches)
    );
END;
$function$;

