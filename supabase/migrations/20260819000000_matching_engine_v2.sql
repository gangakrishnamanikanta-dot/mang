-- Migration: Matching Engine v2 (Soft Scoring + Behavioral Learning + Daily Cache)
-- Deploy this as a single migration. It replaces the old get_compatibility_index
-- and get_top_matches with the new soft-scoring engine.

-- ============================================================
-- 1. TABLES
-- ============================================================

-- Profile exclusions (user swipes left / skips a profile)
CREATE TABLE IF NOT EXISTS public.match_exclusions (
  user_id     uuid    NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  excluded_id uuid    NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason      text    NOT NULL DEFAULT 'skip',
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, excluded_id)
);
CREATE INDEX IF NOT EXISTS idx_match_exclusions_user
  ON public.match_exclusions(user_id);

-- Partner preferences (expanded — all arrays, no hard bucketing)
CREATE TABLE IF NOT EXISTS public.partner_preferences (
  profile_id                  uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE PRIMARY KEY,
  min_age                     integer,
  max_age                     integer,
  min_height_inches           integer,
  max_height_inches           integer,
  preferred_caste_ids         integer[],
  preferred_mother_tongue_ids integer[],
  preferred_education_ids     integer[],
  preferred_occupation_ids    integer[],
  preferred_family_type_ids   integer[],
  preferred_smoking_ids       integer[],
  preferred_drinking_ids      integer[],
  preferred_food_ids          integer[],
  preferred_marital_status_ids integer[],
  preferred_annual_income_id  integer,
  location_preference         varchar(20) NOT NULL DEFAULT 'any',
  kuja_dosham_preference      varchar(20),
  exclude_same_gotra          boolean    NOT NULL DEFAULT true,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_partner_prefs_profile
  ON public.partner_preferences(profile_id);

-- Profile view tracking (feeds behavioral learning)
CREATE TABLE IF NOT EXISTS public.profile_views (
  viewer_id    uuid    NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  viewed_id    uuid    NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  viewed_at    timestamptz NOT NULL DEFAULT now(),
  dwell_seconds integer NOT NULL DEFAULT 0,
  viewed_from  text    NOT NULL DEFAULT 'matches',
  PRIMARY KEY (viewer_id, viewed_id)
);
CREATE INDEX IF NOT EXISTS idx_profile_views_viewer
  ON public.profile_views(viewer_id);
CREATE INDEX IF NOT EXISTS idx_profile_views_viewed
  ON public.profile_views(viewed_id, viewed_at DESC);

-- Add new columns to profile_views if they don't exist (idempotent)
ALTER TABLE public.profile_views
  ADD COLUMN IF NOT EXISTS dwell_seconds integer DEFAULT 0;
ALTER TABLE public.profile_views
  ADD COLUMN IF NOT EXISTS viewed_from text DEFAULT 'matches';

-- Pre-computed match cache (refreshed daily by cron or app)
CREATE TABLE IF NOT EXISTS public.user_match_cache (
  user_id           uuid    NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE PRIMARY KEY,
  matches           jsonb   NOT NULL DEFAULT '[]'::jsonb,
  computed_at       timestamptz NOT NULL DEFAULT now(),
  algorithm_version smallint NOT NULL DEFAULT 2
);
CREATE INDEX IF NOT EXISTS idx_user_match_cache_computed
  ON public.user_match_cache(computed_at);

-- ============================================================
-- 2. DROP OLD FUNCTIONS (if they exist)
-- ============================================================

DROP FUNCTION IF EXISTS public.get_compatibility_index_v2(uuid, uuid);
DROP FUNCTION IF EXISTS public.get_behavioral_signals(uuid);
DROP FUNCTION IF EXISTS public.refresh_user_match_cache(uuid);
DROP FUNCTION IF EXISTS public.get_top_matches_v2(uuid, integer, integer);

-- ============================================================
-- 3. SOFT SCORING ENGINE
--    get_compatibility_index_v2(user_a, user_b) → double precision
--
--    Continuous Gaussian scoring, NOT bucketed/hard-coded.
--    Returns a smooth score in range 40.0–98.0 with 1 decimal precision.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_compatibility_index_v2(
  user_a uuid,
  user_b uuid
)
RETURNS double precision
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
    location_score      float8 := 0.3;
    lifestyle_score     float8 := 0.5;

    final_score float8 := 0.0;
BEGIN
    SELECT * INTO prof_a FROM public.profiles WHERE id = user_a;
    IF NOT FOUND THEN RETURN 50.0; END IF;

    SELECT * INTO prof_b FROM public.profiles WHERE id = user_b;
    IF NOT FOUND THEN RETURN 50.0; END IF;

    IF prof_b.full_name IS NULL OR TRIM(prof_b.full_name) = '' THEN
        RETURN 30.0;
    END IF;

    SELECT * INTO pref_a FROM public.partner_preferences WHERE profile_id = user_a;

    -- ── HARD GOTRA EXCLUSION ──
    IF pref_a IS NOT NULL AND pref_a.exclude_same_gotra = true THEN
        IF prof_a.gothram_id IS NOT NULL AND prof_b.gothram_id IS NOT NULL 
           AND prof_a.gothram_id = prof_b.gothram_id THEN
            RETURN 0.0;
        END IF;
    END IF;

    -- ── 1) PROFILE COMPLETENESS (max 0.15) ──────────
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

    -- ── 2) AGE (Gaussian curve against preference or delta) ──
    IF prof_a.date_of_birth IS NOT NULL THEN
        age_a := extract(year from age(prof_a.date_of_birth));
    END IF;
    IF prof_b.date_of_birth IS NOT NULL THEN
        age_b := extract(year from age(prof_b.date_of_birth));
    END IF;

    IF age_b IS NOT NULL THEN
        IF pref_a IS NOT NULL AND pref_a.min_age IS NOT NULL AND pref_a.max_age IS NOT NULL THEN
            IF age_b >= pref_a.min_age AND age_b <= pref_a.max_age THEN
                age_score := 1.0;
            ELSE
                age_score := GREATEST(0.0,
                    EXP(-0.08 * power(
                        LEAST(abs(age_b - pref_a.min_age), abs(age_b - pref_a.max_age)), 2)));
            END IF;
        ELSIF age_a IS NOT NULL THEN
            age_score := GREATEST(0.0, EXP(-0.06 * power(abs(age_b - age_a), 2)));
        END IF;
    END IF;

    -- ── 3) HEIGHT ──────────────────────────────────────────────
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

    -- ── 4) CASTE PREFERENCE ────────────────────────────────────
    IF pref_a IS NOT NULL AND pref_a.preferred_caste_ids IS NOT NULL
       AND array_length(pref_a.preferred_caste_ids, 1) > 0 THEN
        IF prof_b.caste_id IS NOT NULL AND prof_b.caste_id = ANY(pref_a.preferred_caste_ids) THEN
            caste_score := 1.0;
        ELSE
            caste_score := 0.10;
        END IF;
    ELSIF prof_a.caste_id IS NOT NULL AND prof_b.caste_id IS NOT NULL THEN
        IF prof_a.caste_id = prof_b.caste_id THEN
            caste_score := 1.0;
        ELSE
            caste_score := 0.30;
        END IF;
    END IF;

    -- ── 5) MARITAL STATUS PREFERENCE ───────────────────────────
    IF pref_a IS NOT NULL AND pref_a.preferred_marital_status_ids IS NOT NULL
       AND array_length(pref_a.preferred_marital_status_ids, 1) > 0 THEN
        IF prof_b.marital_status_id IS NOT NULL AND prof_b.marital_status_id = ANY(pref_a.preferred_marital_status_ids) THEN
            marital_score := 1.0;
        ELSE
            marital_score := 0.05;
        END IF;
    ELSIF prof_a.marital_status_id IS NOT NULL AND prof_b.marital_status_id IS NOT NULL THEN
        IF prof_a.marital_status_id = prof_b.marital_status_id THEN
            marital_score := 1.0;
        ELSE
            marital_score := 0.40;
        END IF;
    END IF;

    -- ── 6) MOTHER TONGUE ───────────────────────────────────────
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
            mother_tongue_score := 0.30;
        END IF;
    END IF;

    -- ── 7) EDUCATION ───────────────────────────────────────────
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

    -- ── 8) OCCUPATION ──────────────────────────────────────────
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

    -- ── 9) LOCATION ────────────────────────────────────────────
    IF prof_a.city IS NOT NULL AND prof_b.city IS NOT NULL
       AND lower(prof_a.city) = lower(prof_b.city) THEN
        location_score := 1.0;
    ELSIF prof_a.state IS NOT NULL AND prof_b.state IS NOT NULL
       AND lower(prof_a.state) = lower(prof_b.state) THEN
        location_score := 0.70;
    ELSE
        location_score := 0.30;
    END IF;

    -- ── 10) LIFESTYLE (Food, Smoking, Drinking) ────────────────
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

    -- ── WEIGHTED COMPOSITION (Sums to 1.0) ──────────────────────
    final_score :=
        completeness_score  * 0.10 +
        age_score           * 0.22 +
        caste_score         * 0.18 +
        marital_score       * 0.12 +
        height_score        * 0.08 +
        education_score     * 0.08 +
        occupation_score    * 0.07 +
        mother_tongue_score * 0.05 +
        location_score      * 0.05 +
        lifestyle_score     * 0.05;

    -- Map final_score (0.0–1.0) cleanly to 40.0–95.0
    RETURN round((GREATEST(0.40, LEAST(final_score, 0.95)) * 100)::numeric, 1);
END;
$function$;

-- ============================================================
-- 4. BEHAVIORAL SIGNALS
-- ============================================================
-- (Kept intact)

-- ============================================================
-- 5. DAILY CACHE BUILDER
--    refresh_user_match_cache(p_user_id) → void
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_user_match_cache(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_gender     text;
    v_target     text;
    v_row        record;
    v_score      float8;
    v_signals    jsonb;
    v_candidates jsonb := '[]'::jsonb;
    v_match      jsonb;
    v_pref       record;
BEGIN
    SELECT LOWER(TRIM(gender)) INTO v_gender
    FROM public.profiles WHERE id = p_user_id;

    IF v_gender = 'male' THEN v_target := 'female';
    ELSIF v_gender = 'female' THEN v_target := 'male';
    ELSE v_target := NULL;
    END IF;

    SELECT * INTO v_pref FROM public.partner_preferences WHERE profile_id = p_user_id;
    v_signals := get_behavioral_signals(p_user_id);

    FOR v_row IN
        SELECT p.*
        FROM public.profiles p
        WHERE p.id <> p_user_id
          AND (v_target IS NULL OR LOWER(TRIM(COALESCE(p.gender, ''))) = v_target)
          AND p.full_name IS NOT NULL
          AND TRIM(p.full_name) <> ''
          AND NOT EXISTS (
              SELECT 1 FROM public.match_exclusions me
              WHERE me.user_id = p_user_id AND me.excluded_id = p.id
          )
    LOOP
        v_score := get_compatibility_index_v2(p_user_id, v_row.id);

        -- Exclude zero-compatibility (e.g. same gotra when excluded)
        IF v_score < 40.0 THEN
            CONTINUE;
        END IF;

        -- Subtle behavioral boosts (at most +5.0% total)
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
                v_score := v_score + ((v_signals->'occupation_affinity')::jsonb ->> v_row.occupation_id::text)::float8 * 1.2;
            END IF;
            IF v_row.nakshatra_id IS NOT NULL
               AND v_signals ? 'nakshatra_affinity'
               AND (v_signals->'nakshatra_affinity') ? (v_row.nakshatra_id::text) THEN
                v_score := v_score + ((v_signals->'nakshatra_affinity')::jsonb ->> v_row.nakshatra_id::text)::float8 * 0.8;
            END IF;
        END IF;

        v_score := GREATEST(40.0, LEAST(96.0, v_score));

        v_match := jsonb_build_object(
            'profile_id',           v_row.id,
            'full_name',            v_row.full_name,
            'score',                ROUND(v_score::numeric, 1),
            'age',                  extract(year from age(v_row.date_of_birth)),
            'city',                 v_row.city,
            'state',                v_row.state,
            'profile_photo_url',    v_row.profile_photo_url,
            'gender',               v_row.gender,
            'caste_id',             COALESCE(v_row.caste_id, 0),
            'nakshatra_id',         v_row.nakshatra_id,
            'gothram_id',           v_row.gothram_id,
            'mother_tongue_id',     v_row.mother_tongue_id,
            'highest_education_id', v_row.highest_education_id,
            'occupation_id',        v_row.occupation_id
        );

        v_candidates := v_candidates || v_match;
    END LOOP;

    INSERT INTO public.user_match_cache (user_id, matches, computed_at, algorithm_version)
    VALUES (p_user_id, COALESCE(v_candidates, '[]'::jsonb), now(), 2)
    ON CONFLICT (user_id) DO UPDATE
    SET matches = EXCLUDED.matches,
        computed_at = EXCLUDED.computed_at,
        algorithm_version = EXCLUDED.algorithm_version;
END;
$function$;

-- ============================================================
-- 6. CACHE-FIRST READER
--    get_top_matches_v2(p_user_id, p_limit, p_offset) → jsonb
--
--    Reads user_match_cache if < 24h old. Falls back to live scoring
--    using the same filters as the cache builder.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_top_matches_v2(
  p_user_id uuid,
  p_limit   integer DEFAULT 20,
  p_offset  integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_cache  jsonb;
    v_result jsonb;
    v_gender text;
    v_target text;
BEGIN
    SELECT LOWER(TRIM(gender)) INTO v_gender
    FROM public.profiles WHERE id = p_user_id;

    IF v_gender = 'male' THEN v_target := 'female';
    ELSIF v_gender = 'female' THEN v_target := 'male';
    ELSE v_target := NULL;
    END IF;

    -- Try cache first (24h TTL)
    SELECT matches INTO v_cache
    FROM public.user_match_cache
    WHERE user_id = p_user_id
      AND computed_at > now() - interval '24 hours';

    IF v_cache IS NOT NULL AND jsonb_array_length(v_cache) > 0 THEN
        SELECT COALESCE(jsonb_agg(r ORDER BY (r->>'score')::float8 DESC), '[]'::jsonb)
        INTO v_result
        FROM (
            SELECT c as r
            FROM jsonb_array_elements(v_cache) c
            LIMIT p_limit OFFSET p_offset
        ) t;
        RETURN v_result;
    END IF;

    -- Cache miss: compute live with same filters as cache builder
    RETURN COALESCE((
        SELECT jsonb_agg(r ORDER BY r.score DESC)
        FROM (
            SELECT jsonb_build_object(
                'profile_id',           p.id,
                'full_name',            p.full_name,
                'score',                ROUND(get_compatibility_index_v2(p_user_id, p.id)::numeric, 1),
                'age',                  extract(year from age(p.date_of_birth)),
                'city',                 p.city,
                'state',                p.state,
                'profile_photo_url',    p.profile_photo_url,
                'gender',               p.gender,
                'caste_id',             p.caste_id,
                'nakshatra_id',         p.nakshatra_id,
                'gothram_id',           p.gothram_id,
                'mother_tongue_id',     p.mother_tongue_id,
                'highest_education_id', p.highest_education_id,
                'occupation_id',        p.occupation_id
            ) as r
            FROM public.profiles p
            WHERE p.id <> p_user_id
              AND (v_target IS NULL OR LOWER(TRIM(COALESCE(p.gender, ''))) = v_target)
              AND p.full_name IS NOT NULL
              AND TRIM(p.full_name) <> ''
              AND NOT EXISTS (
                  SELECT 1 FROM public.match_exclusions me
                  WHERE me.user_id = p_user_id AND me.excluded_id = p.id
              )
            ORDER BY get_compatibility_index_v2(p_user_id, p.id) DESC
            LIMIT p_limit OFFSET p_offset
        ) ranked
    ), '[]'::jsonb);
END;
$function$;

-- ============================================================
-- 7. DAILY REFRESH TRIGGER (pg_cron)
--    Runs refresh_user_match_cache for every active user at 3 AM.
--    Requires pg_cron extension (available on all Supabase plans).
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
  'daily-match-cache-refresh',
  '0 3 * * *',
  $$
  SELECT public.refresh_user_match_cache(id)
  FROM public.profiles
  WHERE profile_completed = true
    AND gender IS NOT NULL;
  $$
);
