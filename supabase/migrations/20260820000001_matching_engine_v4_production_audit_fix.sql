-- ============================================================================
-- Migration: 20260820000001_matching_engine_v4_production_audit_fix.sql
-- Description: Complete, Standalone Hardened Production Matching Engine (Version 4.1)
-- Contains full definitions for:
--  1. Sanitized public_profiles view (safe display columns only, anon revoked)
--  2. get_behavioral_signals (VOLATILE, 5-dimension behavioral affinity tracking)
--  3. get_one_way_score (VOLATILE, 13-attribute Gaussian scoring, safe bounds, ID 12 income guard)
--  4. get_compatibility_index_v2 (VOLATILE, Two-Sided 60/40 mutual compatibility)
--  5. refresh_user_match_cache (v4 Precomputation engine with auth guards & join filters)
--  6. get_top_matches_v2 (v4 Cache-first retrieval + bounded candidate CTE pre-filter for live fallback)
--  7. Composite, Functional & Relational Indexes (interests, profiles, match_exclusions)
--  8. Security Hardening: Revoke anon on otps & public_profiles, Caller Authorization Guards
--  9. Removal of dangerous cascade triggers (trg_invalidate_cache_on_profile_change)
-- ============================================================================

-- ── 1. COMPOSITE, FUNCTIONAL & RELATIONAL INDEXES ────────────────────────────

CREATE TABLE IF NOT EXISTS public.match_exclusions (
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  excluded_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason      text NOT NULL DEFAULT 'skip',
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, excluded_id)
);

CREATE TABLE IF NOT EXISTS public.user_match_cache (
  user_id           uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE PRIMARY KEY,
  matches           jsonb NOT NULL DEFAULT '[]'::jsonb,
  computed_at       timestamptz NOT NULL DEFAULT now(),
  algorithm_version smallint NOT NULL DEFAULT 4
);

CREATE INDEX IF NOT EXISTS idx_profiles_matching_v4 ON public.profiles(gender, full_name, date_of_birth, gothram_id);
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON public.profiles(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_dob ON public.profiles(date_of_birth);
CREATE INDEX IF NOT EXISTS idx_profiles_height ON public.profiles(height_inches);
CREATE INDEX IF NOT EXISTS idx_match_exclusions_user ON public.match_exclusions(user_id);
CREATE INDEX IF NOT EXISTS idx_match_exclusions_pair ON public.match_exclusions(user_id, excluded_id);
CREATE INDEX IF NOT EXISTS idx_match_exclusions_excluded ON public.match_exclusions(excluded_id);
CREATE INDEX IF NOT EXISTS idx_user_match_cache_v4 ON public.user_match_cache(user_id, computed_at DESC) WHERE algorithm_version = 4;
CREATE INDEX IF NOT EXISTS idx_interests_sender_receiver ON public.interests(sender_profile_id, receiver_profile_id);
CREATE INDEX IF NOT EXISTS idx_interests_receiver_sender ON public.interests(receiver_profile_id, sender_profile_id);

-- ── 2. DEDUPLICATED RLS SECURITY POLICIES & PERMISSIONS ──────────────────────

ALTER TABLE public.match_exclusions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "me_select_own" ON public.match_exclusions;
DROP POLICY IF EXISTS "me_insert_own" ON public.match_exclusions;
DROP POLICY IF EXISTS "me_delete_own" ON public.match_exclusions;
DROP POLICY IF EXISTS "public_read_match_exclusions" ON public.match_exclusions;
DROP POLICY IF EXISTS "Public can view exclusions" ON public.match_exclusions;
DROP POLICY IF EXISTS "Users can view own exclusions" ON public.match_exclusions;
DROP POLICY IF EXISTS "Users can insert own exclusions" ON public.match_exclusions;
DROP POLICY IF EXISTS "Users can delete own exclusions" ON public.match_exclusions;

CREATE POLICY "Users can view own exclusions"
  ON public.match_exclusions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own exclusions"
  ON public.match_exclusions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own exclusions"
  ON public.match_exclusions FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Security hardening against data exposure
REVOKE ALL ON public.otps FROM anon, authenticated;

DROP VIEW IF EXISTS public.public_profiles CASCADE;
CREATE VIEW public.public_profiles AS
SELECT 
    id,
    full_name,
    gender,
    date_of_birth,
    height_inches,
    marital_status_id,
    mother_tongue_id,
    caste_id,
    sub_caste,
    gothram_id,
    veda_shakha_id,
    nakshatra_id,
    rashi_id,
    pada_id,
    highest_education_id,
    college,
    occupation_id,
    company,
    annual_income_id,
    city,
    state,
    about_me,
    profile_photo_url,
    hobbies,
    is_verified,
    profile_completed,
    created_at,
    updated_at,
    EXTRACT(year FROM age(date_of_birth::timestamptz))::int AS age
FROM public.profiles
WHERE full_name IS NOT NULL AND TRIM(full_name) <> '';

REVOKE ALL ON public.public_profiles FROM anon;
GRANT SELECT ON public.public_profiles TO authenticated;

-- ── 3. CLEANUP ALL LEGACY DEAD FUNCTIONS & DANGEROUS TRIGGERS ────────────────

DROP TRIGGER IF EXISTS trg_invalidate_cache_on_profile_change ON public.profiles;
DROP FUNCTION IF EXISTS public.trigger_invalidate_cache_on_profile_change();

DROP FUNCTION IF EXISTS public.get_top_matches(uuid, integer, integer);
DROP FUNCTION IF EXISTS public.get_top_matches(uuid);
DROP FUNCTION IF EXISTS public.compute_match_score(uuid, uuid);
DROP FUNCTION IF EXISTS public.refresh_user_matches(uuid);
DROP FUNCTION IF EXISTS public.get_compatibility_index(uuid, uuid);

-- ── 4. VOLATILE BEHAVIORAL SIGNALS ENGINE ───────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_behavioral_signals(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_signals   jsonb := '{}'::jsonb;
  v_caste     jsonb;
  v_edu       jsonb;
  v_nakshatra jsonb;
  v_occ       jsonb;
  v_mtongue   jsonb;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN '{}'::jsonb;
  END IF;

  -- Caste affinity
  SELECT jsonb_object_agg(caste_id::text, ROUND(norm::numeric, 4))
    INTO v_caste
  FROM (
    SELECT p.caste_id,
           SUM(
             COALESCE(
               (SELECT MAX(
                 CASE status
                   WHEN 'accepted' THEN 3.0
                   WHEN 'pending'  THEN 1.0
                   ELSE 0.5
                 END
               ) FROM interests i
               WHERE i.sender_profile_id = p_user_id
                 AND i.receiver_profile_id = v.viewed_id),
               0.5
             )
           ) / NULLIF(COUNT(*), 0) as norm
    FROM profile_views v
    JOIN profiles p ON p.id = v.viewed_id
    WHERE v.viewer_id = p_user_id
      AND p.caste_id IS NOT NULL
    GROUP BY p.caste_id
  ) sub;
  v_caste := COALESCE(v_caste, '{}'::jsonb);

  -- Education affinity
  SELECT jsonb_object_agg(edu_id::text, ROUND(norm::numeric, 4))
    INTO v_edu
  FROM (
    SELECT p.highest_education_id as edu_id,
           SUM(
             COALESCE(
               (SELECT MAX(
                 CASE status
                   WHEN 'accepted' THEN 3.0
                   WHEN 'pending'  THEN 1.0
                   ELSE 0.5
                 END
               ) FROM interests i
               WHERE i.sender_profile_id = p_user_id
                 AND i.receiver_profile_id = v.viewed_id),
               0.5
             )
           ) / NULLIF(COUNT(*), 0) as norm
    FROM profile_views v
    JOIN profiles p ON p.id = v.viewed_id
    WHERE v.viewer_id = p_user_id
      AND p.highest_education_id IS NOT NULL
    GROUP BY p.highest_education_id
  ) sub;
  v_edu := COALESCE(v_edu, '{}'::jsonb);

  -- Nakshatra affinity
  SELECT jsonb_object_agg(nak_id::text, ROUND(norm::numeric, 4))
    INTO v_nakshatra
  FROM (
    SELECT p.nakshatra_id as nak_id,
           SUM(
             COALESCE(
               (SELECT MAX(
                 CASE status
                   WHEN 'accepted' THEN 3.0
                   WHEN 'pending'  THEN 1.0
                   ELSE 0.5
                 END
               ) FROM interests i
               WHERE i.sender_profile_id = p_user_id
                 AND i.receiver_profile_id = v.viewed_id),
               0.5
             )
           ) / NULLIF(COUNT(*), 0) as norm
    FROM profile_views v
    JOIN profiles p ON p.id = v.viewed_id
    WHERE v.viewer_id = p_user_id
      AND p.nakshatra_id IS NOT NULL
    GROUP BY p.nakshatra_id
  ) sub;
  v_nakshatra := COALESCE(v_nakshatra, '{}'::jsonb);

  -- Occupation affinity
  SELECT jsonb_object_agg(occ_id::text, ROUND(norm::numeric, 4))
    INTO v_occ
  FROM (
    SELECT p.occupation_id as occ_id,
           SUM(
             COALESCE(
               (SELECT MAX(
                 CASE status
                   WHEN 'accepted' THEN 3.0
                   WHEN 'pending'  THEN 1.0
                   ELSE 0.5
                 END
               ) FROM interests i
               WHERE i.sender_profile_id = p_user_id
                 AND i.receiver_profile_id = v.viewed_id),
               0.5
             )
           ) / NULLIF(COUNT(*), 0) as norm
    FROM profile_views v
    JOIN profiles p ON p.id = v.viewed_id
    WHERE v.viewer_id = p_user_id
      AND p.occupation_id IS NOT NULL
    GROUP BY p.occupation_id
  ) sub;
  v_occ := COALESCE(v_occ, '{}'::jsonb);

  -- Mother tongue affinity
  SELECT jsonb_object_agg(mt_id::text, ROUND(norm::numeric, 4))
    INTO v_mtongue
  FROM (
    SELECT p.mother_tongue_id as mt_id,
           SUM(
             COALESCE(
               (SELECT MAX(
                 CASE status
                   WHEN 'accepted' THEN 3.0
                   WHEN 'pending'  THEN 1.0
                   ELSE 0.5
                 END
               ) FROM interests i
               WHERE i.sender_profile_id = p_user_id
                 AND i.receiver_profile_id = v.viewed_id),
               0.5
             )
           ) / NULLIF(COUNT(*), 0) as norm
    FROM profile_views v
    JOIN profiles p ON p.id = v.viewed_id
    WHERE v.viewer_id = p_user_id
      AND p.mother_tongue_id IS NOT NULL
    GROUP BY p.mother_tongue_id
  ) sub;
  v_mtongue := COALESCE(v_mtongue, '{}'::jsonb);

  v_signals := jsonb_build_object(
    'caste_affinity',         v_caste,
    'education_affinity',     v_edu,
    'nakshatra_affinity',     v_nakshatra,
    'occupation_affinity',    v_occ,
    'mother_tongue_affinity', v_mtongue
  );

  RETURN v_signals;
END;
$$;

-- ── 5. VOLATILE ONE-WAY 13-ATTRIBUTE SCORING FUNCTION ───────────────────────

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
    prof_a record;
    prof_b record;
    pref_a record;

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
    IF user_a IS NULL OR user_b IS NULL THEN
        RETURN 0.0;
    END IF;

    SELECT * INTO prof_a FROM public.profiles WHERE id = user_a;
    IF NOT FOUND THEN RETURN 0.0; END IF;

    SELECT * INTO prof_b FROM public.profiles WHERE id = user_b;
    IF NOT FOUND THEN RETURN 0.0; END IF;

    IF prof_b.full_name IS NULL OR TRIM(prof_b.full_name) = '' THEN
        RETURN 0.0;
    END IF;

    SELECT * INTO pref_a FROM public.partner_preferences WHERE profile_id = user_a;

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

-- ── 6. VOLATILE TWO-SIDED COMPATIBILITY INDEX (60/40 MUTUAL RECIPROCITY) ─────

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
    score_a_to_b float8;
    score_b_to_a float8;
    mutual_score float8;
BEGIN
    IF user_a IS NULL OR user_b IS NULL THEN
        RETURN 0.0;
    END IF;

    score_a_to_b := public.get_one_way_score(user_a, user_b);
    IF score_a_to_b <= 0.20 THEN
        RETURN 0.0;
    END IF;

    score_b_to_a := public.get_one_way_score(user_b, user_a);
    IF score_b_to_a <= 0.20 THEN
        RETURN 0.0;
    END IF;

    mutual_score := (0.60 * score_a_to_b) + (0.40 * score_b_to_a);
    RETURN round((GREATEST(0.40, LEAST(mutual_score, 0.96)) * 100)::numeric, 1);
END;
$$;

-- ── 7. CACHE REFRESH ENGINE (VERSION 4) ──────────────────────────────────────

CREATE OR REPLACE FUNCTION public.refresh_user_match_cache(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_gender     text;
    v_target     text;
    v_user_dob   date;
    v_user_age   int;
    v_gothram_id int;
    v_min_age    int;
    v_max_age    int;
    v_min_height int;
    v_max_height int;
    v_exclude_same_gotra boolean;
    v_row        record;
    v_score      float8;
    v_signals    jsonb;
    v_candidates jsonb := '[]'::jsonb;
    v_match      jsonb;
    v_cand_age   int;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN;
    END IF;

    -- SECURITY GUARD: Ensure caller is authorized or called internally
    IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'Access denied: Cannot refresh match cache for another user.';
    END IF;

    SELECT 
        LOWER(TRIM(COALESCE(gender, ''))),
        date_of_birth,
        EXTRACT(YEAR FROM age(date_of_birth))::int,
        gothram_id
    INTO v_gender, v_user_dob, v_user_age, v_gothram_id
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
        min_height_inches, 
        max_height_inches, 
        COALESCE(exclude_same_gotra, true)
    INTO v_min_age, v_max_age, v_min_height, v_max_height, v_exclude_same_gotra
    FROM public.partner_preferences
    WHERE profile_id = p_user_id;

    v_signals := get_behavioral_signals(p_user_id);

    FOR v_row IN
        SELECT p.*
        FROM public.profiles p
        LEFT JOIN public.match_exclusions me 
               ON me.user_id = p_user_id AND me.excluded_id = p.id
        WHERE me.excluded_id IS NULL
          AND p.id <> p_user_id
          AND (v_target IS NULL OR LOWER(TRIM(COALESCE(p.gender, ''))) = v_target)
          AND p.full_name IS NOT NULL
          AND TRIM(p.full_name) <> ''
          AND p.date_of_birth IS NOT NULL
          AND (v_min_age IS NULL OR EXTRACT(YEAR FROM age(p.date_of_birth))::int >= v_min_age)
          AND (v_max_age IS NULL OR EXTRACT(YEAR FROM age(p.date_of_birth))::int <= v_max_age)
          AND (
              NOT v_exclude_same_gotra
              OR v_gothram_id IS NULL
              OR p.gothram_id IS NULL
              OR p.gothram_id <> v_gothram_id
          )
          AND (v_min_height IS NULL OR p.height_inches IS NULL OR p.height_inches >= v_min_height)
          AND (v_max_height IS NULL OR p.height_inches IS NULL OR p.height_inches <= v_max_height)
    LOOP
        v_cand_age := EXTRACT(YEAR FROM age(v_row.date_of_birth))::int;
        v_score := get_compatibility_index_v2(p_user_id, v_row.id);

        IF v_score < 30.0 THEN
            CONTINUE;
        END IF;

        IF jsonb_typeof(v_signals) = 'object' THEN
            IF v_row.caste_id IS NOT NULL
               AND v_signals ? 'caste_affinity'
               AND (v_signals->'caste_affinity') ? (v_row.caste_id::text) THEN
                v_score := v_score + ((v_signals->'caste_affinity')::jsonb ->> v_row.caste_id::text)::float8 * 1.5;
            END IF;
            IF v_row.highest_education_id IS NOT NULL
               AND v_signals ? 'education_affinity'
               AND (v_signals->'education_affinity') ? (v_row.highest_education_id::text) THEN
                v_score := v_score + ((v_signals->'education_affinity')::jsonb ->> v_row.highest_education_id::text)::float8 * 1.5;
            END IF;
            IF v_row.occupation_id IS NOT NULL
               AND v_signals ? 'occupation_affinity'
               AND (v_signals->'occupation_affinity') ? (v_row.occupation_id::text) THEN
                v_score := v_score + ((v_signals->'occupation_affinity')::jsonb ->> v_row.occupation_id::text)::float8 * 1.0;
            END IF;
        END IF;

        IF v_row.created_at IS NOT NULL AND v_row.created_at > (now() - interval '14 days') THEN
            v_score := v_score + 3.0;
        END IF;

        v_score := GREATEST(40.0, LEAST(96.0, v_score));

        v_match := jsonb_build_object(
            'profile_id',           v_row.id,
            'full_name',            v_row.full_name,
            'score',                ROUND(v_score::numeric, 1),
            'age',                  v_cand_age,
            'city',                 v_row.city,
            'state',                v_row.state,
            'profile_photo_url',    v_row.profile_photo_url,
            'gender',               v_row.gender,
            'caste_id',             COALESCE(v_row.caste_id, 0),
            'nakshatra_id',         v_row.nakshatra_id,
            'gothram_id',           v_row.gothram_id,
            'mother_tongue_id',     v_row.mother_tongue_id,
            'highest_education_id', v_row.highest_education_id,
            'occupation_id',        v_row.occupation_id,
            'is_verified',          COALESCE(v_row.is_verified, false),
            'created_at',           v_row.created_at
        );

        v_candidates := v_candidates || v_match;
    END LOOP;

    INSERT INTO public.user_match_cache (user_id, matches, computed_at, algorithm_version)
    VALUES (p_user_id, COALESCE(v_candidates, '[]'::jsonb), now(), 4)
    ON CONFLICT (user_id) DO UPDATE
    SET matches = EXCLUDED.matches,
        computed_at = EXCLUDED.computed_at,
        algorithm_version = EXCLUDED.algorithm_version;
END;
$$;

-- ── 8. RETRIEVAL & HARD FILTERING RPC (VERSION 4) ───────────────────────────

CREATE OR REPLACE FUNCTION public.get_top_matches_v2(p_user_id uuid, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_cache   jsonb;
    v_result  jsonb;
    v_gender  text;
    v_target  text;
    v_user_age int;
    v_min_age int;
    v_max_age int;
    v_gothram_id int;
    v_exclude_same_gotra boolean;
BEGIN
    -- NULL & AUTH GUARD
    IF p_user_id IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'Access denied: Cannot query matches for another user.';
    END IF;

    SELECT 
        LOWER(TRIM(COALESCE(gender, ''))),
        EXTRACT(YEAR FROM age(date_of_birth))::int,
        gothram_id
    INTO v_gender, v_user_age, v_gothram_id
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
                'created_at',           p.created_at
            ) as r
            FROM jsonb_array_elements(v_cache) c
            JOIN public.profiles p ON p.id = (c->>'profile_id')::uuid
            LEFT JOIN public.match_exclusions me 
                   ON me.user_id = p_user_id AND me.excluded_id = p.id
            WHERE me.excluded_id IS NULL
              AND p.date_of_birth IS NOT NULL
              AND (v_min_age IS NULL OR EXTRACT(YEAR FROM age(p.date_of_birth))::int >= v_min_age)
              AND (v_max_age IS NULL OR EXTRACT(YEAR FROM age(p.date_of_birth))::int <= v_max_age)
              AND (
                  NOT v_exclude_same_gotra
                  OR v_gothram_id IS NULL
                  OR p.gothram_id IS NULL
                  OR p.gothram_id <> v_gothram_id
              )
            ORDER BY (c->>'score')::float8 DESC
            LIMIT p_limit OFFSET p_offset
        ) t;
        
        IF v_result IS NOT NULL AND jsonb_array_length(v_result) > 0 THEN
            RETURN v_result;
        END IF;
    END IF;

    -- 2. Live Fallback with Bounded Candidate CTE (Caps mutual scoring to top candidates)
    WITH candidates AS (
        SELECT p.id, p.full_name, p.city, p.state, p.profile_photo_url,
               p.gender, p.caste_id, p.nakshatra_id, p.gothram_id,
               p.mother_tongue_id, p.highest_education_id, p.occupation_id,
               COALESCE(p.is_verified, false) AS is_verified,
               p.created_at,
               EXTRACT(YEAR FROM age(p.date_of_birth))::int AS age
        FROM public.profiles p
        LEFT JOIN public.match_exclusions me 
               ON me.user_id = p_user_id AND me.excluded_id = p.id
        WHERE me.excluded_id IS NULL
          AND p.id <> p_user_id
          AND (v_target IS NULL OR LOWER(TRIM(COALESCE(p.gender,''))) = v_target)
          AND p.full_name IS NOT NULL
          AND TRIM(p.full_name) <> ''
          AND p.date_of_birth IS NOT NULL
          AND (v_min_age IS NULL OR EXTRACT(YEAR FROM age(p.date_of_birth))::int >= v_min_age)
          AND (v_max_age IS NULL OR EXTRACT(YEAR FROM age(p.date_of_birth))::int <= v_max_age)
          AND (
              NOT v_exclude_same_gotra
              OR v_gothram_id IS NULL
              OR p.gothram_id IS NULL
              OR p.gothram_id <> v_gothram_id
          )
        ORDER BY p.created_at DESC
        LIMIT 150
    )
    SELECT COALESCE(jsonb_agg(r ORDER BY (r->>'score')::float8 DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'profile_id',           c.id,
            'full_name',            c.full_name,
            'score',                ROUND(get_compatibility_index_v2(p_user_id, c.id)::numeric, 1),
            'age',                  c.age,
            'city',                 c.city,
            'state',                c.state,
            'profile_photo_url',    c.profile_photo_url,
            'gender',               c.gender,
            'caste_id',             c.caste_id,
            'nakshatra_id',         c.nakshatra_id,
            'gothram_id',           c.gothram_id,
            'mother_tongue_id',     c.mother_tongue_id,
            'highest_education_id', c.highest_education_id,
            'occupation_id',        c.occupation_id,
            'is_verified',          c.is_verified,
            'created_at',           c.created_at
        ) as r
        FROM candidates c
        ORDER BY get_compatibility_index_v2(p_user_id, c.id) DESC
        LIMIT p_limit OFFSET p_offset
    ) ranked;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;
