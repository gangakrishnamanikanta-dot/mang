-- Migration: Allow matching and recommendations for all profiles (even if profile is not 100% completed)

-- 1. Drop and Recreate public_profiles view (Ensure minimum name & gender)
DROP VIEW IF EXISTS public.public_profiles CASCADE;

CREATE VIEW public.public_profiles
WITH (security_invoker = true) AS
SELECT
  p.id,
  p.full_name,
  p.gender,
  p.date_of_birth,
  p.height_inches,
  p.marital_status_id,
  p.mother_tongue_id,
  p.caste_id,
  p.sub_caste,
  p.gothram_id,
  p.veda_shakha_id,
  p.nakshatra_id,
  p.rashi_id,
  p.pada_id,
  p.highest_education_id,
  p.college,
  p.occupation_id,
  p.company,
  p.annual_income_id,
  p.work_location,
  p.about_me,
  p.profile_photo_url,
  p.hobbies,
  p.profile_completed,
  extract(year from age(p.date_of_birth)) as age
FROM public.profiles p
WHERE p.full_name IS NOT NULL AND TRIM(p.full_name) <> '';

-- 2. Accurate Mathematical Compatibility Engine with Completeness Weighting
CREATE OR REPLACE FUNCTION get_compatibility_index(
    user_a uuid, 
    user_b uuid
) RETURNS float8
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    prof_a record;
    prof_b record;
    pref_a record;
    pref_b record;

    age_a integer;
    age_b integer;

    completeness_score float8 := 0.30; -- Base 30%
    preference_score float8 := 0.0;
    final_score float8 := 0.0;
    
    age_match_score float8 := 0.0;
    height_match_score float8 := 0.0;
    caste_match_score float8 := 0.0;
    gothram_penalty float8 := 1.0;
BEGIN
    SELECT * INTO prof_a FROM public.profiles WHERE id = user_a;
    IF NOT FOUND THEN RETURN 50.0; END IF;

    SELECT * INTO prof_b FROM public.profiles WHERE id = user_b;
    IF NOT FOUND THEN RETURN 50.0; END IF;

    -- Profiles without basic info cannot score high
    IF prof_b.full_name IS NULL OR TRIM(prof_b.full_name) = '' THEN
        RETURN 30.0;
    END IF;

    -- 1. Profile Completeness Weighting (up to +40%)
    IF prof_b.profile_photo_url IS NOT NULL AND prof_b.profile_photo_url <> '' THEN
        completeness_score := completeness_score + 0.15;
    END IF;

    IF prof_b.highest_education_id IS NOT NULL OR prof_b.occupation_id IS NOT NULL THEN
        completeness_score := completeness_score + 0.10;
    END IF;

    IF prof_b.gothram_id IS NOT NULL OR prof_b.nakshatra_id IS NOT NULL OR prof_b.rashi_id IS NOT NULL THEN
        completeness_score := completeness_score + 0.10;
    END IF;

    IF prof_b.about_me IS NOT NULL AND LENGTH(TRIM(prof_b.about_me)) > 10 THEN
        completeness_score := completeness_score + 0.05;
    END IF;

    -- 2. Calculate Ages
    IF prof_a.date_of_birth IS NOT NULL THEN
        age_a := extract(year from age(prof_a.date_of_birth));
    END IF;
    IF prof_b.date_of_birth IS NOT NULL THEN
        age_b := extract(year from age(prof_b.date_of_birth));
    END IF;

    -- 3. Partner Preferences Evaluation (up to +30%)
    SELECT * INTO pref_a FROM public.partner_preferences WHERE profile_id = user_a;

    IF pref_a IS NOT NULL THEN
        -- Age matching
        IF age_b IS NOT NULL AND pref_a.min_age IS NOT NULL AND pref_a.max_age IS NOT NULL THEN
            IF age_b >= pref_a.min_age AND age_b <= pref_a.max_age THEN
                age_match_score := 0.15;
            ELSE
                age_match_score := 0.15 * GREATEST(0.0, EXP(-0.08 * power(LEAST(abs(age_b - pref_a.min_age), abs(age_b - pref_a.max_age)), 2)));
            END IF;
        ELSE
            age_match_score := 0.08; -- Neutral partial score
        END IF;

        -- Height matching
        IF prof_b.height_inches IS NOT NULL AND pref_a.min_height_inches IS NOT NULL AND pref_a.max_height_inches IS NOT NULL THEN
            IF prof_b.height_inches >= pref_a.min_height_inches AND prof_b.height_inches <= pref_a.max_height_inches THEN
                height_match_score := 0.08;
            ELSE
                height_match_score := 0.08 * GREATEST(0.0, EXP(-0.15 * power(LEAST(abs(prof_b.height_inches - pref_a.min_height_inches), abs(prof_b.height_inches - pref_a.max_height_inches)), 2)));
            END IF;
        ELSE
            height_match_score := 0.04;
        END IF;

        -- Caste matching
        IF pref_a.preferred_caste_ids IS NOT NULL AND array_length(pref_a.preferred_caste_ids, 1) > 0 THEN
            IF prof_b.caste_id IS NOT NULL AND prof_b.caste_id = ANY(pref_a.preferred_caste_ids) THEN
                caste_match_score := 0.07;
            ELSE
                caste_match_score := 0.02;
            END IF;
        ELSE
            caste_match_score := 0.05;
        END IF;
    ELSE
        -- Default neutral preference scores if no partner preferences configured
        age_match_score := 0.10;
        height_match_score := 0.05;
        caste_match_score := 0.05;
    END IF;

    -- Gotram Exogamy Check
    IF prof_a.gothram_id IS NOT NULL AND prof_b.gothram_id IS NOT NULL THEN
        IF prof_a.gothram_id = prof_b.gothram_id THEN
            gothram_penalty := 0.70; -- 30% reduction for Sagotra match
        END IF;
    END IF;

    -- Final composite score calculation
    final_score := (completeness_score + age_match_score + height_match_score + caste_match_score) * gothram_penalty;

    -- Scale cleanly between 40% and 98%
    RETURN round((GREATEST(0.40, LEAST(final_score, 0.98)) * 100)::numeric, 0);
END;
$$;

-- 3. Update get_top_matches (Filters out empty/unnamed ghost accounts and strictly requires opposite gender)
CREATE OR REPLACE FUNCTION get_top_matches(
    p_user_id uuid,
    p_limit integer DEFAULT 20,
    p_offset integer DEFAULT 0
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_gender text;
    v_target_gender text;
    result json;
BEGIN
    -- Fetch the user's gender
    SELECT LOWER(TRIM(gender)) INTO v_user_gender 
    FROM public.profiles 
    WHERE id = p_user_id;

    IF v_user_gender = 'male' THEN
        v_target_gender := 'female';
    ELSIF v_user_gender = 'female' THEN
        v_target_gender := 'male';
    ELSE
        v_target_gender := NULL;
    END IF;

    SELECT json_agg(t) INTO result
    FROM (
        SELECT 
            p.*, 
            COALESCE(get_compatibility_index(p_user_id, p.id), 50.0)::int as total_score,
            json_build_object(
                'compatibility', COALESCE(get_compatibility_index(p_user_id, p.id), 50.0)::int
            ) as factor_breakdown
        FROM public.profiles p
        WHERE 
            p.id <> p_user_id 
            -- STRICT: Must have a real name (no empty ghost accounts)
            AND p.full_name IS NOT NULL 
            AND TRIM(p.full_name) <> ''
            -- STRICT: Opposite gender only
            AND (
                v_target_gender IS NULL 
                OR LOWER(TRIM(COALESCE(p.gender, ''))) = v_target_gender
            )
            -- Exclude skipped/blocked
            AND NOT EXISTS (
                SELECT 1 FROM public.match_exclusions me 
                WHERE me.user_id = p_user_id AND me.excluded_id = p.id
            )
            AND NOT EXISTS (
                SELECT 1 FROM public.interests i 
                WHERE i.sender_profile_id = p_user_id AND i.receiver_profile_id = p.id
            )
        ORDER BY total_score DESC, p.created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    ) t;

    RETURN COALESCE(result, '[]'::json);
END;
$$;
