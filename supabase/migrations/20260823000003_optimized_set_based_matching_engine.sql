-- ── Optimization: Set-Based Matching Engine with Score Calibration, Time-Decay & Sargable Indexing ──
--
-- WHAT THIS FIXES:
-- 1. Eliminates O(N) subquery storm (Issue #3):
--    Pure in-memory functions (calculate_one_way_score & calculate_mutual_compatibility)
--    perform mathematical scoring on record structs with ZERO database subqueries.
--
-- 2. Eliminates O(N^2) JSONB array concatenation (Issue #4):
--    A single set-based CTE with native C-level `jsonb_agg(... ORDER BY final_score DESC)`
--    aggregates matches in O(N) memory and stores them pre-sorted.
--
-- 3. Incomplete Profile Filter (Issue #5):
--    Adds `AND p.profile_completed = true` to both refresh_user_match_cache and get_top_matches_v2.
--
-- 4. Sargable Age Bounds for B-Tree Index Scans (Issue #6):
--    Precomputes v_max_dob and v_min_dob from min_age/max_age to utilize idx_profiles_matching_v5
--    and idx_profiles_dob instead of sequential scans.
--
-- 5. Transaction-Level Advisory Lock (Issue #7):
--    `pg_try_advisory_xact_lock` prevents concurrent requests for the same user from running duplicate rebuilds.
--
-- 6. Score Distribution Calibration & De-compression (Issue #8):
--    Expands compressed 50-75% score cluster into high-contrast 30-98% range so top matches stand out.
--
-- 7. Behavioral Signal Time-Decay & Dwell Time Weighting (Issue #9):
--    Single-CTE get_behavioral_signals with 23-day exponential time decay (EXP(-0.03 * days))
--    and dwell time weighting (up to 2x for intentional reads).

-- Matching Index
CREATE INDEX IF NOT EXISTS idx_profiles_matching_v5 
ON public.profiles(gender, profile_completed, date_of_birth, gothram_id);

-- 1. Time-Decayed Behavioral Signals Engine with Dwell Time Weighting (Issue #9)
CREATE OR REPLACE FUNCTION public.get_behavioral_signals(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_caste     jsonb;
  v_edu       jsonb;
  v_nakshatra jsonb;
  v_occ       jsonb;
  v_mtongue   jsonb;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN '{}'::jsonb;
  END IF;

  WITH weighted_interactions AS (
    SELECT 
      p.caste_id,
      p.highest_education_id,
      p.nakshatra_id,
      p.occupation_id,
      p.mother_tongue_id,
      (
        EXP(-0.03 * GREATEST(0.0, EXTRACT(EPOCH FROM (now() - v.viewed_at)) / 86400.0))
        * (1.0 + LEAST(1.0, COALESCE(v.dwell_seconds, 0)::float8 / 30.0))
        * CASE i.status
            WHEN 'accepted' THEN 3.0
            WHEN 'pending'  THEN 2.0
            ELSE 1.0
          END
      ) AS weight
    FROM public.profile_views v
    JOIN public.profiles p ON p.id = v.viewed_id
    LEFT JOIN public.interests i 
           ON i.sender_profile_id = p_user_id 
          AND i.receiver_profile_id = v.viewed_id
    WHERE v.viewer_id = p_user_id
      AND v.viewed_at > now() - interval '60 days'
  ),
  caste_summary AS (
    SELECT caste_id, ROUND((SUM(weight) / NULLIF(COUNT(*), 0))::numeric, 4) AS norm
    FROM weighted_interactions
    WHERE caste_id IS NOT NULL
    GROUP BY caste_id
  ),
  edu_summary AS (
    SELECT highest_education_id, ROUND((SUM(weight) / NULLIF(COUNT(*), 0))::numeric, 4) AS norm
    FROM weighted_interactions
    WHERE highest_education_id IS NOT NULL
    GROUP BY highest_education_id
  ),
  nak_summary AS (
    SELECT nakshatra_id, ROUND((SUM(weight) / NULLIF(COUNT(*), 0))::numeric, 4) AS norm
    FROM weighted_interactions
    WHERE nakshatra_id IS NOT NULL
    GROUP BY nakshatra_id
  ),
  occ_summary AS (
    SELECT occupation_id, ROUND((SUM(weight) / NULLIF(COUNT(*), 0))::numeric, 4) AS norm
    FROM weighted_interactions
    WHERE occupation_id IS NOT NULL
    GROUP BY occupation_id
  ),
  mtongue_summary AS (
    SELECT mother_tongue_id, ROUND((SUM(weight) / NULLIF(COUNT(*), 0))::numeric, 4) AS norm
    FROM weighted_interactions
    WHERE mother_tongue_id IS NOT NULL
    GROUP BY mother_tongue_id
  )
  SELECT 
    COALESCE((SELECT jsonb_object_agg(caste_id::text, norm) FROM caste_summary), '{}'::jsonb),
    COALESCE((SELECT jsonb_object_agg(highest_education_id::text, norm) FROM edu_summary), '{}'::jsonb),
    COALESCE((SELECT jsonb_object_agg(nakshatra_id::text, norm) FROM nak_summary), '{}'::jsonb),
    COALESCE((SELECT jsonb_object_agg(occupation_id::text, norm) FROM occ_summary), '{}'::jsonb),
    COALESCE((SELECT jsonb_object_agg(mother_tongue_id::text, norm) FROM mtongue_summary), '{}'::jsonb)
  INTO v_caste, v_edu, v_nakshatra, v_occ, v_mtongue;

  RETURN jsonb_build_object(
    'caste_affinity',      COALESCE(v_caste, '{}'::jsonb),
    'education_affinity',  COALESCE(v_edu, '{}'::jsonb),
    'nakshatra_affinity',  COALESCE(v_nakshatra, '{}'::jsonb),
    'occupation_affinity', COALESCE(v_occ, '{}'::jsonb),
    'tongue_affinity',     COALESCE(v_mtongue, '{}'::jsonb)
  );
END;
$$;

-- 2. Pure In-Memory Record Scoring Function (Zero Queries)
CREATE OR REPLACE FUNCTION public.calculate_one_way_score(
  prof_a public.profiles,
  pref_a public.partner_preferences,
  prof_b public.profiles
)
RETURNS double precision
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    age_a integer;
    age_b integer;

    completeness_score  float8 := 0.20;
    age_score           float8 := 0.5;
    height_score        float8 := 0.5;
    caste_score         float8 := 0.5;
    mother_tongue_score float8 := 0.5;
    education_score     float8 := 0.5;
    occupation_score    float8 := 0.5;
    marital_score       float8 := 0.5;
    kuja_score          float8 := 0.5;
    income_score        float8 := 0.5;
    location_score      float8 := 0.3;
    lifestyle_score     float8 := 0.5;

    final_score float8 := 0.0;
BEGIN
    IF prof_a IS NULL OR prof_b IS NULL THEN
        RETURN 0.0;
    END IF;

    IF prof_b.full_name IS NULL OR TRIM(prof_b.full_name) = '' THEN
        RETURN 0.0;
    END IF;

    -- ── 1) HARD GOTRA EXCLUSION (DEALBREAKER FOR BRAHMINS) ──
    IF pref_a IS NOT NULL AND pref_a.exclude_same_gotra = true THEN
        IF prof_a.gothram_id IS NOT NULL AND prof_b.gothram_id IS NOT NULL 
           AND prof_a.gothram_id = prof_b.gothram_id THEN
            RETURN 0.0;
        END IF;
    END IF;

    -- ── 2) AGE PREFERENCE (INDEPENDENT SAFE BOUNDS & SMOOTH FALLBACK) ──
    IF prof_a.date_of_birth IS NOT NULL THEN
        age_a := extract(year from age(prof_a.date_of_birth));
    END IF;
    IF prof_b.date_of_birth IS NOT NULL THEN
        age_b := extract(year from age(prof_b.date_of_birth));
    END IF;

    IF age_b IS NOT NULL THEN
        IF pref_a IS NOT NULL AND (pref_a.min_age IS NOT NULL OR pref_a.max_age IS NOT NULL) THEN
            IF pref_a.min_age IS NOT NULL AND age_b < pref_a.min_age THEN
                RETURN 0.0;
            END IF;
            IF pref_a.max_age IS NOT NULL AND age_b > pref_a.max_age THEN
                RETURN 0.0;
            END IF;

            age_score := 1.0;
        ELSIF age_a IS NOT NULL THEN
            age_score := GREATEST(0.20, EXP(-0.03 * power(abs(age_b - age_a), 2)));
        ELSE
            age_score := 0.60;
        END IF;
    ELSE
        RETURN 0.0;
    END IF;

    -- ── 3) CASTE PREFERENCE ──
    IF pref_a IS NOT NULL AND pref_a.preferred_caste_ids IS NOT NULL
       AND array_length(pref_a.preferred_caste_ids, 1) > 0 THEN
        IF prof_b.caste_id IS NOT NULL AND prof_b.caste_id = ANY(pref_a.preferred_caste_ids) THEN
            caste_score := 1.0;
        ELSE
            caste_score := 0.15;
        END IF;
    ELSIF prof_a.caste_id IS NOT NULL AND prof_b.caste_id IS NOT NULL THEN
        IF prof_a.caste_id = prof_b.caste_id THEN
            caste_score := 1.0;
        ELSE
            caste_score := 0.40;
        END IF;
    END IF;

    -- ── 4) MARITAL STATUS PREFERENCE ──
    IF pref_a IS NOT NULL AND pref_a.preferred_marital_status_ids IS NOT NULL
       AND array_length(pref_a.preferred_marital_status_ids, 1) > 0 THEN
        IF prof_b.marital_status_id IS NOT NULL AND prof_b.marital_status_id = ANY(pref_a.preferred_marital_status_ids) THEN
            marital_score := 1.0;
        ELSE
            marital_score := 0.15;
        END IF;
    ELSIF prof_a.marital_status_id IS NOT NULL AND prof_b.marital_status_id IS NOT NULL THEN
        IF prof_a.marital_status_id = prof_b.marital_status_id THEN
            marital_score := 1.0;
        ELSE
            marital_score := 0.50;
        END IF;
    END IF;

    -- ── 5) PROFILE COMPLETENESS ──
    completeness_score := 0.05;
    IF prof_b.profile_photo_url IS NOT NULL AND prof_b.profile_photo_url <> '' THEN
        completeness_score := completeness_score + 0.05;
    END IF;
    IF prof_b.highest_education_id IS NOT NULL THEN
        completeness_score := completeness_score + 0.02;
    END IF;
    IF prof_b.occupation_id IS NOT NULL THEN
        completeness_score := completeness_score + 0.02;
    END IF;
    IF prof_b.about_me IS NOT NULL AND LENGTH(TRIM(prof_b.about_me)) > 10 THEN
        completeness_score := completeness_score + 0.01;
    END IF;

    -- ── 6) HEIGHT ──
    IF prof_b.height_inches IS NOT NULL THEN
        IF pref_a IS NOT NULL AND pref_a.min_height_inches IS NOT NULL AND pref_a.max_height_inches IS NOT NULL THEN
            IF prof_b.height_inches >= pref_a.min_height_inches
               AND prof_b.height_inches <= pref_a.max_height_inches THEN
                height_score := 1.0;
            ELSE
                height_score := GREATEST(0.1,
                    EXP(-0.12 * power(
                        LEAST(abs(prof_b.height_inches - pref_a.min_height_inches),
                              abs(prof_b.height_inches - pref_a.max_height_inches)), 2)));
            END IF;
        END IF;
    END IF;

    -- ── 7) KUJA DOSHAM ──
    IF pref_a IS NOT NULL AND pref_a.kuja_dosham_preference IS NOT NULL THEN
        IF pref_a.kuja_dosham_preference = 'Yes' THEN
            IF prof_b.kuja_dosham IS NOT NULL AND lower(prof_b.kuja_dosham) = 'yes' THEN
                kuja_score := 1.0;
            ELSE
                kuja_score := 0.20;
            END IF;
        ELSIF pref_a.kuja_dosham_preference = 'No' THEN
            IF prof_b.kuja_dosham IS NOT NULL AND lower(prof_b.kuja_dosham) = 'no' THEN
                kuja_score := 1.0;
            ELSE
                kuja_score := 0.25;
            END IF;
        ELSE
            kuja_score := 0.70;
        END IF;
    ELSE
        kuja_score := 0.60;
    END IF;

    -- ── 8) ANNUAL INCOME (HANDLES 'PREFER NOT TO SAY' = ID 12) ──
    IF pref_a IS NOT NULL AND pref_a.preferred_annual_income_id IS NOT NULL AND pref_a.preferred_annual_income_id <> 12 THEN
        IF prof_b.annual_income_id IS NOT NULL AND prof_b.annual_income_id <> 12 THEN
            IF prof_b.annual_income_id >= pref_a.preferred_annual_income_id THEN
                income_score := 1.0;
            ELSIF prof_b.annual_income_id = (pref_a.preferred_annual_income_id - 1) THEN
                income_score := 0.60;
            ELSE
                income_score := 0.30;
            END IF;
        ELSE
            income_score := 0.40;
        END IF;
    ELSE
        income_score := 0.60;
    END IF;

    -- ── 9) MOTHER TONGUE ──
    IF pref_a IS NOT NULL AND pref_a.preferred_mother_tongue_ids IS NOT NULL
       AND array_length(pref_a.preferred_mother_tongue_ids, 1) > 0 THEN
        IF prof_b.mother_tongue_id IS NOT NULL AND prof_b.mother_tongue_id = ANY(pref_a.preferred_mother_tongue_ids) THEN
            mother_tongue_score := 1.0;
        ELSE
            mother_tongue_score := 0.20;
        END IF;
    ELSIF prof_a.mother_tongue_id IS NOT NULL AND prof_b.mother_tongue_id IS NOT NULL THEN
        IF prof_a.mother_tongue_id = prof_b.mother_tongue_id THEN
            mother_tongue_score := 1.0;
        ELSE
            mother_tongue_score := 0.40;
        END IF;
    END IF;

    -- ── 10) EDUCATION ──
    IF pref_a IS NOT NULL AND pref_a.preferred_education_ids IS NOT NULL
       AND array_length(pref_a.preferred_education_ids, 1) > 0 THEN
        IF prof_b.highest_education_id IS NOT NULL AND prof_b.highest_education_id = ANY(pref_a.preferred_education_ids) THEN
            education_score := 1.0;
        ELSE
            education_score := 0.30;
        END IF;
    ELSIF prof_a.highest_education_id IS NOT NULL AND prof_b.highest_education_id IS NOT NULL THEN
        IF prof_a.highest_education_id = prof_b.highest_education_id THEN
            education_score := 1.0;
        ELSE
            education_score := 0.50;
        END IF;
    END IF;

    -- ── 11) OCCUPATION ──
    IF pref_a IS NOT NULL AND pref_a.preferred_occupation_ids IS NOT NULL
       AND array_length(pref_a.preferred_occupation_ids, 1) > 0 THEN
        IF prof_b.occupation_id IS NOT NULL AND prof_b.occupation_id = ANY(pref_a.preferred_occupation_ids) THEN
            occupation_score := 1.0;
        ELSE
            occupation_score := 0.25;
        END IF;
    ELSIF prof_a.occupation_id IS NOT NULL AND prof_b.occupation_id IS NOT NULL THEN
        IF prof_a.occupation_id = prof_b.occupation_id THEN
            occupation_score := 1.0;
        ELSE
            occupation_score := 0.40;
        END IF;
    END IF;

    -- ── 12) LOCATION ──
    IF prof_a.city IS NOT NULL AND prof_b.city IS NOT NULL
       AND lower(prof_a.city) = lower(prof_b.city) THEN
        location_score := 1.0;
    ELSIF prof_a.state IS NOT NULL AND prof_b.state IS NOT NULL
       AND lower(prof_a.state) = lower(prof_b.state) THEN
        location_score := 0.70;
    ELSE
        location_score := 0.30;
    END IF;

    -- ── 13) LIFESTYLE ──
    lifestyle_score := 0.50;
    IF pref_a IS NOT NULL AND pref_a.preferred_food_ids IS NOT NULL AND array_length(pref_a.preferred_food_ids, 1) > 0 THEN
        IF prof_b.food_preference_id IS NOT NULL AND prof_b.food_preference_id = ANY(pref_a.preferred_food_ids) THEN
            lifestyle_score := lifestyle_score + 0.20;
        ELSE
            lifestyle_score := lifestyle_score - 0.15;
        END IF;
    ELSIF prof_a.food_preference_id IS NOT NULL AND prof_b.food_preference_id IS NOT NULL THEN
        IF prof_a.food_preference_id = prof_b.food_preference_id THEN
            lifestyle_score := lifestyle_score + 0.15;
        END IF;
    END IF;
    lifestyle_score := GREATEST(0.1, LEAST(1.0, lifestyle_score));

    -- ── WEIGHTED COMPOSITION ──
    final_score :=
        completeness_score  * 0.08 +
        age_score           * 0.20 +
        caste_score         * 0.16 +
        marital_score       * 0.10 +
        kuja_score          * 0.08 +
        income_score        * 0.08 +
        height_score        * 0.08 +
        education_score     * 0.07 +
        occupation_score    * 0.06 +
        mother_tongue_score * 0.04 +
        location_score      * 0.03 +
        lifestyle_score     * 0.02;

    RETURN GREATEST(0.10, LEAST(final_score, 1.0));
END;
$$;

-- 3. Calibrated High-Discrimination Mutual Scoring (Issue #8)
CREATE OR REPLACE FUNCTION public.calculate_mutual_compatibility(
  prof_a public.profiles,
  pref_a public.partner_preferences,
  prof_b public.profiles,
  pref_b public.partner_preferences
)
RETURNS double precision
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    score_a_to_b float8;
    score_b_to_a float8;
    mutual_score float8;
    calibrated_score float8;
BEGIN
    score_a_to_b := public.calculate_one_way_score(prof_a, pref_a, prof_b);
    IF score_a_to_b <= 0.15 THEN
        RETURN 0.0;
    END IF;

    score_b_to_a := public.calculate_one_way_score(prof_b, pref_b, prof_a);
    IF score_b_to_a <= 0.15 THEN
        RETURN 0.0;
    END IF;

    mutual_score := (0.60 * score_a_to_b) + (0.40 * score_b_to_a);

    -- Contrast Expansion Curve:
    -- Spreads compressed 50-75% cluster into a natural 30-98% range
    IF mutual_score >= 0.70 THEN
        calibrated_score := 75.0 + ((mutual_score - 0.70) / 0.30) * 23.0;
    ELSIF mutual_score >= 0.45 THEN
        calibrated_score := 50.0 + ((mutual_score - 0.45) / 0.25) * 25.0;
    ELSE
        calibrated_score := 30.0 + ((mutual_score - 0.15) / 0.30) * 20.0;
    END IF;

    RETURN round(GREATEST(30.0, LEAST(calibrated_score, 98.0))::numeric, 1);
END;
$$;

-- 4. Compatibility Index v2 delegating to pure calculation
CREATE OR REPLACE FUNCTION public.get_compatibility_index_v2(
  user_a uuid,
  user_b uuid
)
RETURNS double precision
LANGUAGE plpgsql
VOLATILE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    prof_a public.profiles;
    prof_b public.profiles;
    pref_a public.partner_preferences;
    pref_b public.partner_preferences;
BEGIN
    IF user_a IS NULL OR user_b IS NULL THEN
        RETURN 0.0;
    END IF;

    SELECT * INTO prof_a FROM public.profiles WHERE id = user_a;
    IF NOT FOUND THEN RETURN 0.0; END IF;

    SELECT * INTO prof_b FROM public.profiles WHERE id = user_b;
    IF NOT FOUND THEN RETURN 0.0; END IF;

    SELECT * INTO pref_a FROM public.partner_preferences WHERE profile_id = user_a;
    SELECT * INTO pref_b FROM public.partner_preferences WHERE profile_id = user_b;

    RETURN public.calculate_mutual_compatibility(prof_a, pref_a, prof_b, pref_b);
END;
$$;

-- 5. get_one_way_score delegating to pure calculation
CREATE OR REPLACE FUNCTION public.get_one_way_score(
  user_a uuid,
  user_b uuid
)
RETURNS double precision
LANGUAGE plpgsql
VOLATILE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    prof_a public.profiles;
    prof_b public.profiles;
    pref_a public.partner_preferences;
BEGIN
    IF user_a IS NULL OR user_b IS NULL THEN
        RETURN 0.0;
    END IF;

    SELECT * INTO prof_a FROM public.profiles WHERE id = user_a;
    IF NOT FOUND THEN RETURN 0.0; END IF;

    SELECT * INTO prof_b FROM public.profiles WHERE id = user_b;
    IF NOT FOUND THEN RETURN 0.0; END IF;

    SELECT * INTO pref_a FROM public.partner_preferences WHERE profile_id = user_a;

    RETURN public.calculate_one_way_score(prof_a, pref_a, prof_b);
END;
$$;

-- 6. Set-Based, Single-Pass, O(N) Cache Refresh Engine with Sargable Indexing & Advisory Lock
CREATE OR REPLACE FUNCTION public.refresh_user_match_cache(
    p_user_id uuid,
    p_force boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_prof       public.profiles;
    v_pref       public.partner_preferences;
    v_target     text;
    v_signals    jsonb;
    v_candidates jsonb := '[]'::jsonb;
    v_cache_age  interval;
    v_min_dob    date;
    v_max_dob    date;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN;
    END IF;

    -- SECURITY GUARD: Deny anonymous or cross-user requests
    IF auth.role() = 'anon' THEN
        RAISE EXCEPTION 'Access denied: Anonymous users cannot refresh match cache.';
    END IF;

    IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'Access denied: Cannot refresh match cache for another user.';
    END IF;

    -- CONCURRENCY PROTECTION: Transaction-level advisory lock per user
    IF NOT pg_try_advisory_xact_lock(hashtext('match_refresh_' || p_user_id::text)) THEN
        RETURN;
    END IF;

    -- FRESHNESS GUARD: Skip if < 1h old unless p_force = true
    IF NOT p_force THEN
        SELECT now() - computed_at INTO v_cache_age
        FROM public.user_match_cache
        WHERE user_id = p_user_id
          AND algorithm_version = 4;

        IF v_cache_age IS NOT NULL AND v_cache_age < interval '1 hour' THEN
            RETURN;
        END IF;
    END IF;

    -- Fetch user profile ONCE (1 query)
    SELECT * INTO v_prof FROM public.profiles WHERE id = p_user_id;
    IF NOT FOUND OR v_prof.gender IS NULL THEN
        RETURN;
    END IF;

    -- Fetch user partner preferences ONCE (1 query)
    SELECT * INTO v_pref FROM public.partner_preferences WHERE profile_id = p_user_id;

    IF LOWER(TRIM(v_prof.gender)) = 'male' THEN
        v_target := 'female';
    ELSIF LOWER(TRIM(v_prof.gender)) = 'female' THEN
        v_target := 'male';
    ELSE
        v_target := NULL;
    END IF;

    -- Precompute Sargable Date Bounds for Index Scans
    IF v_pref.min_age IS NOT NULL THEN
        v_max_dob := (CURRENT_DATE - (v_pref.min_age * INTERVAL '1 year'))::date;
    END IF;

    IF v_pref.max_age IS NOT NULL THEN
        v_min_dob := (CURRENT_DATE - ((v_pref.max_age + 1) * INTERVAL '1 year' - INTERVAL '1 day'))::date;
    END IF;

    v_signals := get_behavioral_signals(p_user_id);

    -- SET-BASED COMPUTATION with Prime Visibility Boost & Candidate Subscriptions
    WITH scored_candidates AS (
        SELECT 
            p.id AS profile_id,
            p.full_name,
            EXTRACT(YEAR FROM age(p.date_of_birth))::int AS age,
            p.city,
            p.state,
            p.profile_photo_url,
            p.gender,
            COALESCE(p.caste_id, 0) AS caste_id,
            p.nakshatra_id,
            p.gothram_id,
            p.mother_tongue_id,
            p.highest_education_id,
            p.occupation_id,
            COALESCE(p.is_verified, false) AS is_verified,
            p.created_at,
            COALESCE(sub_cand.tier, 'free') AS membership_tier,
            GREATEST(30.0, LEAST(98.0,
                public.calculate_mutual_compatibility(v_prof, v_pref, p, pref_cand)
                -- Behavioral Signals Affinity Boosts
                + CASE 
                    WHEN jsonb_typeof(v_signals) = 'object' 
                         AND p.caste_id IS NOT NULL 
                         AND v_signals ? 'caste_affinity' 
                         AND (v_signals->'caste_affinity') ? (p.caste_id::text)
                    THEN ((v_signals->'caste_affinity')::jsonb ->> p.caste_id::text)::float8 * 2.0
                    ELSE 0.0
                  END
                + CASE 
                    WHEN jsonb_typeof(v_signals) = 'object' 
                         AND p.highest_education_id IS NOT NULL 
                         AND v_signals ? 'education_affinity' 
                         AND (v_signals->'education_affinity') ? (p.highest_education_id::text)
                    THEN ((v_signals->'education_affinity')::jsonb ->> p.highest_education_id::text)::float8 * 1.5
                    ELSE 0.0
                  END
                + CASE 
                    WHEN jsonb_typeof(v_signals) = 'object' 
                         AND p.occupation_id IS NOT NULL 
                         AND v_signals ? 'occupation_affinity' 
                         AND (v_signals->'occupation_affinity') ? (p.occupation_id::text)
                    THEN ((v_signals->'occupation_affinity')::jsonb ->> p.occupation_id::text)::float8 * 1.0
                    ELSE 0.0
                  END
                -- New Member Boost (+2.5)
                + CASE 
                    WHEN p.created_at IS NOT NULL AND p.created_at > (now() - interval '14 days')
                    THEN 2.5
                    ELSE 0.0
                  END
                -- PRIME MEMBER VISIBILITY BOOST (Prime VIP +3.0, Prime Lite +1.5)
                + CASE 
                    WHEN sub_cand.tier = 'prime' THEN 3.0
                    WHEN sub_cand.tier = 'prime_lite' THEN 1.5
                    ELSE 0.0
                  END
            )) AS final_score
        FROM public.profiles p
        LEFT JOIN public.partner_preferences pref_cand ON pref_cand.profile_id = p.id
        LEFT JOIN public.user_subscriptions sub_cand 
               ON sub_cand.user_id = p.id 
              AND sub_cand.status = 'active' 
              AND (sub_cand.expires_at IS NULL OR sub_cand.expires_at > now())
        LEFT JOIN public.match_exclusions me 
               ON me.user_id = p_user_id AND me.excluded_id = p.id
        WHERE me.excluded_id IS NULL
          AND p.id <> p_user_id
          AND p.profile_completed = true
          AND (v_target IS NULL OR LOWER(TRIM(COALESCE(p.gender, ''))) = v_target)
          AND p.full_name IS NOT NULL
          AND TRIM(p.full_name) <> ''
          AND p.date_of_birth IS NOT NULL
          AND (v_max_dob IS NULL OR p.date_of_birth <= v_max_dob)
          AND (v_min_dob IS NULL OR p.date_of_birth >= v_min_dob)
          AND (
              COALESCE(v_pref.exclude_same_gotra, true) = false
              OR v_prof.gothram_id IS NULL
              OR p.gothram_id IS NULL
              OR p.gothram_id <> v_prof.gothram_id
          )
          AND (v_pref.min_height_inches IS NULL OR p.height_inches IS NULL OR p.height_inches >= v_pref.min_height_inches)
          AND (v_pref.max_height_inches IS NULL OR p.height_inches IS NULL OR p.height_inches <= v_pref.max_height_inches)
    )
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'profile_id',           sc.profile_id,
            'full_name',            sc.full_name,
            'score',                ROUND(sc.final_score::numeric, 1),
            'age',                  sc.age,
            'city',                 sc.city,
            'state',                sc.state,
            'profile_photo_url',    sc.profile_photo_url,
            'gender',               sc.gender,
            'caste_id',             sc.caste_id,
            'nakshatra_id',         sc.nakshatra_id,
            'gothram_id',           sc.gothram_id,
            'mother_tongue_id',     sc.mother_tongue_id,
            'highest_education_id', sc.highest_education_id,
            'occupation_id',        sc.occupation_id,
            'is_verified',          sc.is_verified,
            'membership_tier',      sc.membership_tier,
            'is_prime',             (sc.membership_tier <> 'free'),
            'created_at',           sc.created_at
        ) ORDER BY sc.final_score DESC
    ), '[]'::jsonb)
    INTO v_candidates
    FROM scored_candidates sc
    WHERE sc.final_score >= 30.0;

    INSERT INTO public.user_match_cache (user_id, matches, computed_at, algorithm_version)
    VALUES (p_user_id, COALESCE(v_candidates, '[]'::jsonb), now(), 4)
    ON CONFLICT (user_id) DO UPDATE
    SET matches = EXCLUDED.matches,
        computed_at = EXCLUDED.computed_at,
        algorithm_version = EXCLUDED.algorithm_version;
END;
$$;

-- 7. Retrieval & Hard Filtering RPC (Version 4 with Sargable DOB Indexing and Pricing Tier Gating)
CREATE OR REPLACE FUNCTION public.get_top_matches_v2(
    p_user_id uuid,
    p_limit integer DEFAULT 20,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_cache             jsonb;
    v_result            jsonb;
    v_gender            text;
    v_target            text;
    v_gothram_id        int;
    v_min_age           int;
    v_max_age           int;
    v_min_dob           date;
    v_max_dob           date;
    v_exclude_same_gotra boolean;
    v_membership        jsonb;
    v_tier              text := 'free';
    v_effective_limit   int;
    v_effective_offset  int;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'Access denied: Cannot query matches for another user.';
    END IF;

    -- TIER-BASED MATCH LIMITS ENFORCEMENT
    v_membership := public.get_user_membership_status(p_user_id);
    v_tier := COALESCE(v_membership->>'tier', 'free');

    IF v_tier = 'free' THEN
        -- Free users get capped at top 20 matches per day
        IF p_offset >= 20 THEN
            RETURN '[]'::jsonb;
        END IF;
        v_effective_limit := LEAST(p_limit, 20 - p_offset);
        v_effective_offset := p_offset;
    ELSE
        -- Prime Lite & Prime VIP get unlimited matches
        v_effective_limit := p_limit;
        v_effective_offset := p_offset;
    END IF;

    SELECT 
        LOWER(TRIM(COALESCE(gender, ''))),
        gothram_id
    INTO v_gender, v_gothram_id
    FROM public.profiles 
    WHERE id = p_user_id;

    IF v_gender = 'male' THEN 
        v_target := 'female';
    ELSIF v_gender = 'female' THEN 
        v_target := 'male';
    ELSE 
        v_target := NULL;
    END IF;

    SELECT 
        min_age, 
        max_age,
        COALESCE(exclude_same_gotra, true)
    INTO v_min_age, v_max_age, v_exclude_same_gotra
    FROM public.partner_preferences
    WHERE profile_id = p_user_id;

    IF v_min_age IS NOT NULL THEN
        v_max_dob := (CURRENT_DATE - (v_min_age * INTERVAL '1 year'))::date;
    END IF;

    IF v_max_age IS NOT NULL THEN
        v_min_dob := (CURRENT_DATE - ((v_max_age + 1) * INTERVAL '1 year' - INTERVAL '1 day'))::date;
    END IF;

    -- 1. Try Cache First (24h TTL)
    SELECT matches INTO v_cache
    FROM public.user_match_cache
    WHERE user_id = p_user_id
      AND computed_at > now() - interval '24 hours'
      AND algorithm_version = 4;

    IF v_cache IS NOT NULL AND jsonb_array_length(v_cache) > 0 THEN
        SELECT COALESCE(jsonb_agg(r ORDER BY (r->>'score')::float8 DESC), '[]'::jsonb)
        INTO v_result
        FROM (
            SELECT jsonb_build_object(
                'profile_id',           p.id,
                'full_name',            p.full_name,
                'score',                (c->>'score')::float8,
                'age',                  EXTRACT(YEAR FROM age(p.date_of_birth))::int,
                'city',                 p.city,
                'state',                p.state,
                'profile_photo_url',    p.profile_photo_url,
                'gender',               p.gender,
                'caste_id',             p.caste_id,
                'nakshatra_id',         p.nakshatra_id,
                'gothram_id',           p.gothram_id,
                'mother_tongue_id',     p.mother_tongue_id,
                'highest_education_id', p.highest_education_id,
                'occupation_id',        p.occupation_id,
                'is_verified',          COALESCE(p.is_verified, false),
                'membership_tier',      COALESCE(c->>'membership_tier', 'free'),
                'is_prime',             COALESCE((c->>'is_prime')::boolean, false),
                'created_at',           p.created_at
            ) AS r
            FROM jsonb_array_elements(v_cache) c
            JOIN public.profiles p ON p.id = (c->>'profile_id')::uuid
            LEFT JOIN public.match_exclusions me 
                   ON me.user_id = p_user_id AND me.excluded_id = p.id
            WHERE me.excluded_id IS NULL
              AND p.id <> p_user_id
              AND p.profile_completed = true
              AND (v_target IS NULL OR LOWER(TRIM(COALESCE(p.gender, ''))) = v_target)
              AND p.full_name IS NOT NULL
              AND TRIM(p.full_name) <> ''
              AND (v_max_dob IS NULL OR p.date_of_birth <= v_max_dob)
              AND (v_min_dob IS NULL OR p.date_of_birth >= v_min_dob)
              AND (
                  v_exclude_same_gotra = false
                  OR v_gothram_id IS NULL
                  OR p.gothram_id IS NULL
                  OR p.gothram_id <> v_gothram_id
              )
            ORDER BY (c->>'score')::float8 DESC
            LIMIT v_effective_limit
            OFFSET v_effective_offset
        ) sub;

        IF v_result IS NOT NULL AND jsonb_array_length(v_result) > 0 THEN
            RETURN v_result;
        END IF;
    END IF;

    -- 2. Fallback: Live Filtered Computation
    SELECT COALESCE(jsonb_agg(r ORDER BY (r->>'score')::float8 DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'profile_id',           p.id,
            'full_name',            p.full_name,
            'score',                ROUND(public.get_compatibility_index_v2(p_user_id, p.id)::numeric, 1),
            'age',                  EXTRACT(YEAR FROM age(p.date_of_birth))::int,
            'city',                 p.city,
            'state',                p.state,
            'profile_photo_url',    p.profile_photo_url,
            'gender',               p.gender,
            'caste_id',             p.caste_id,
            'nakshatra_id',         p.nakshatra_id,
            'gothram_id',           p.gothram_id,
            'mother_tongue_id',     p.mother_tongue_id,
            'highest_education_id', p.highest_education_id,
            'occupation_id',        p.occupation_id,
            'is_verified',          COALESCE(p.is_verified, false),
            'membership_tier',      COALESCE(sub_cand.tier, 'free'),
            'is_prime',             (sub_cand.tier IS NOT NULL AND sub_cand.tier <> 'free'),
            'created_at',           p.created_at
        ) AS r
        FROM public.profiles p
        LEFT JOIN public.user_subscriptions sub_cand 
               ON sub_cand.user_id = p.id 
              AND sub_cand.status = 'active' 
              AND (sub_cand.expires_at IS NULL OR sub_cand.expires_at > now())
        LEFT JOIN public.match_exclusions me 
               ON me.user_id = p_user_id AND me.excluded_id = p.id
        WHERE me.excluded_id IS NULL
          AND p.id <> p_user_id
          AND p.profile_completed = true
          AND (v_target IS NULL OR LOWER(TRIM(COALESCE(p.gender, ''))) = v_target)
          AND p.full_name IS NOT NULL
          AND TRIM(p.full_name) <> ''
          AND p.date_of_birth IS NOT NULL
          AND (v_max_dob IS NULL OR p.date_of_birth <= v_max_dob)
          AND (v_min_dob IS NULL OR p.date_of_birth >= v_min_dob)
          AND (
              v_exclude_same_gotra = false
              OR v_gothram_id IS NULL
              OR p.gothram_id IS NULL
              OR p.gothram_id <> v_gothram_id
          )
        ORDER BY public.get_compatibility_index_v2(p_user_id, p.id) DESC
        LIMIT v_effective_limit
        OFFSET v_effective_offset
    ) sub;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- Permissions
REVOKE ALL ON FUNCTION public.refresh_user_match_cache(uuid, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refresh_user_match_cache(uuid, boolean) FROM anon;
GRANT EXECUTE ON FUNCTION public.refresh_user_match_cache(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_user_match_cache(uuid, boolean) TO service_role;

