-- Migration: Advanced Mathematical Matching Engine (Jeevansathi Scale)
-- 1. Add last_active_at to profiles if it doesn't exist
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_active_at timestamptz DEFAULT now();

-- 2. Drop the old simple matching function
DROP FUNCTION IF EXISTS get_best_matches(uuid, integer, integer);
DROP FUNCTION IF EXISTS get_top_matches(uuid, integer, integer);
DROP FUNCTION IF EXISTS refresh_user_matches(uuid);

-- 3. Create the Math-based Compatibility Engine
CREATE OR REPLACE FUNCTION get_compatibility_index(
    user_a uuid, 
    user_b uuid
) RETURNS float8
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    score_a_for_b float8 := 1.0;
    score_b_for_a float8 := 1.0;
    
    prof_a record;
    prof_b record;
    pref_a record;
    pref_b record;

    age_a integer;
    age_b integer;
    
    final_score float8 := 0;
    recency_multiplier float8 := 1.0;
    days_since_active float8;
BEGIN
    -- Fetch Profile A
    SELECT * INTO prof_a FROM public.profiles WHERE id = user_a AND profile_completed = true;
    IF NOT FOUND THEN RETURN 0; END IF;

    -- Fetch Profile B
    SELECT * INTO prof_b FROM public.profiles WHERE id = user_b AND profile_completed = true;
    IF NOT FOUND THEN RETURN 0; END IF;

    -- 1. DEALBREAKER GATES
    -- Gender: must be opposite (or matching preference if same-sex supported, assuming traditional here)
    IF prof_a.gender = prof_b.gender THEN
        RETURN 0;
    END IF;
    
    -- Exogamy: Same gotram is often a dealbreaker in traditional matches
    IF prof_a.gothram_id IS NOT NULL AND prof_b.gothram_id IS NOT NULL THEN
        IF prof_a.gothram_id = prof_b.gothram_id THEN
            RETURN 0;
        END IF;
    END IF;

    -- Fetch Preferences
    SELECT * INTO pref_a FROM public.partner_preferences WHERE profile_id = user_a;
    SELECT * INTO pref_b FROM public.partner_preferences WHERE profile_id = user_b;

    -- Calculate Ages
    age_a := extract(year from age(prof_a.date_of_birth));
    age_b := extract(year from age(prof_b.date_of_birth));

    -- 2. SCORE A for B (How much User A likes User B)
    IF pref_a IS NOT NULL THEN
        -- Age Decay (Gaussian)
        IF pref_a.min_age IS NOT NULL AND pref_a.max_age IS NOT NULL THEN
            IF age_b < pref_a.min_age THEN
                score_a_for_b := score_a_for_b * EXP(-0.1 * power(pref_a.min_age - age_b, 2));
            ELSIF age_b > pref_a.max_age THEN
                score_a_for_b := score_a_for_b * EXP(-0.1 * power(age_b - pref_a.max_age, 2));
            END IF;
        END IF;
        
        -- Height Decay
        IF pref_a.min_height_inches IS NOT NULL AND pref_a.max_height_inches IS NOT NULL THEN
            IF prof_b.height_inches < pref_a.min_height_inches THEN
                score_a_for_b := score_a_for_b * EXP(-0.2 * power(pref_a.min_height_inches - prof_b.height_inches, 2));
            ELSIF prof_b.height_inches > pref_a.max_height_inches THEN
                score_a_for_b := score_a_for_b * EXP(-0.2 * power(prof_b.height_inches - pref_a.max_height_inches, 2));
            END IF;
        END IF;
        
        -- Strict Array Matches (Marital Status, Mother Tongue, Caste)
        IF pref_a.preferred_marital_status_ids IS NOT NULL AND array_length(pref_a.preferred_marital_status_ids, 1) > 0 THEN
            IF NOT (prof_b.marital_status_id = ANY(pref_a.preferred_marital_status_ids)) THEN
                score_a_for_b := score_a_for_b * 0.1; -- Heavy penalty
            END IF;
        END IF;
        
        IF pref_a.preferred_caste_ids IS NOT NULL AND array_length(pref_a.preferred_caste_ids, 1) > 0 THEN
            IF NOT (prof_b.caste_id = ANY(pref_a.preferred_caste_ids)) THEN
                score_a_for_b := score_a_for_b * 0.2;
            END IF;
        END IF;
    END IF;

    -- 3. SCORE B for A (How much User B likes User A)
    IF pref_b IS NOT NULL THEN
        IF pref_b.min_age IS NOT NULL AND pref_b.max_age IS NOT NULL THEN
            IF age_a < pref_b.min_age THEN
                score_b_for_a := score_b_for_a * EXP(-0.1 * power(pref_b.min_age - age_a, 2));
            ELSIF age_a > pref_b.max_age THEN
                score_b_for_a := score_b_for_a * EXP(-0.1 * power(age_a - pref_b.max_age, 2));
            END IF;
        END IF;
        
        IF pref_b.min_height_inches IS NOT NULL AND pref_b.max_height_inches IS NOT NULL THEN
            IF prof_a.height_inches < pref_b.min_height_inches THEN
                score_b_for_a := score_b_for_a * EXP(-0.2 * power(pref_b.min_height_inches - prof_a.height_inches, 2));
            ELSIF prof_a.height_inches > pref_b.max_height_inches THEN
                score_b_for_a := score_b_for_a * EXP(-0.2 * power(prof_a.height_inches - pref_b.max_height_inches, 2));
            END IF;
        END IF;

        IF pref_b.preferred_marital_status_ids IS NOT NULL AND array_length(pref_b.preferred_marital_status_ids, 1) > 0 THEN
            IF NOT (prof_a.marital_status_id = ANY(pref_b.preferred_marital_status_ids)) THEN
                score_b_for_a := score_b_for_a * 0.1; 
            END IF;
        END IF;
        
        IF pref_b.preferred_caste_ids IS NOT NULL AND array_length(pref_b.preferred_caste_ids, 1) > 0 THEN
            IF NOT (prof_a.caste_id = ANY(pref_b.preferred_caste_ids)) THEN
                score_b_for_a := score_b_for_a * 0.2;
            END IF;
        END IF;
    END IF;

    -- 4. GEOMETRIC MEAN (Mutual Affinity)
    final_score := sqrt(score_a_for_b * score_b_for_a);

    -- 5. BEHAVIORAL ELO / RECENCY MULTIPLIER
    -- Punish inactive users so they don't clog up the matches feed
    IF prof_b.last_active_at IS NOT NULL THEN
        days_since_active := extract(epoch from (now() - prof_b.last_active_at)) / 86400.0;
        IF days_since_active > 14.0 THEN
            recency_multiplier := EXP(-(days_since_active - 14.0) / 30.0);
            -- Bound the multiplier so it doesn't go below 0.1
            IF recency_multiplier < 0.1 THEN recency_multiplier := 0.1; END IF;
        END IF;
    END IF;
    
    final_score := final_score * recency_multiplier;
    
    -- Scale to 0-100 integer score
    RETURN round((final_score * 100)::numeric, 2);
END;
$$;

-- 4. Create the new Feed Fetcher using the Engine
CREATE OR REPLACE FUNCTION get_top_matches(
    p_user_id uuid,
    p_limit integer DEFAULT 20,
    p_offset integer DEFAULT 0
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
BEGIN
    SELECT json_agg(t) INTO result
    FROM (
        SELECT 
            p.*, 
            get_compatibility_index(p_user_id, p.id) as total_score,
            json_build_object(
                'compatibility', get_compatibility_index(p_user_id, p.id)
            ) as factor_breakdown
        FROM public.profiles p
        WHERE 
            p.id != p_user_id 
            AND p.profile_completed = true
            AND p.gender != (SELECT gender FROM public.profiles WHERE id = p_user_id) -- Opposite gender
            -- Exclude already viewed or acted upon
            AND NOT EXISTS (
                SELECT 1 FROM public.match_exclusions me 
                WHERE me.user_id = p_user_id AND me.excluded_id = p.id
            )
            AND NOT EXISTS (
                SELECT 1 FROM public.interests i 
                WHERE i.sender_profile_id = p_user_id AND i.receiver_profile_id = p.id
            )
        ORDER BY total_score DESC, p.last_active_at DESC
        LIMIT p_limit
        OFFSET p_offset
    ) t;

    RETURN COALESCE(result, '[]'::json);
END;
$$;

-- 5. Stub the refresh function to just return successfully (since get_top_matches calculates on-the-fly now)
CREATE OR REPLACE FUNCTION refresh_user_matches(p_user_id uuid) 
RETURNS void 
LANGUAGE plpgsql 
SECURITY DEFINER 
AS $$
BEGIN
    -- In a massive scale app, we would materialize these scores in a table (e.g. user_match_scores)
    -- For now, get_top_matches computes dynamically. We can update last_active_at here.
    UPDATE public.profiles SET last_active_at = now() WHERE id = p_user_id;
END;
$$;
