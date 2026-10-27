-- ── Migration: 20260823000008_audit_fixes_engine_hardening.sql ──────────────
--
-- AUDIT FIX 1: Scoring Config Table + Auto-Tuning Sweep
--   - Replaces hardcoded sigmoid constants with a configurable scoring_config table.
--   - Adds auto_tune_sigmoid_params() function for monthly normalization sweeps.
--
-- AUDIT FIX 2: Negative Behavioral Signals
--   - Profiles viewed for ≥5s WITHOUT sending an interest now receive a
--     0.3x weight penalty (weak negative) instead of a 1.0x neutral boost.
--   - Prevents confirmation bias feedback loops.
--
-- AUDIT FIX 3: Pool Rotation (7-Day Cooldown)
--   - Creates match_shown_log table (separate from profile_views which caps at 10).
--   - Candidates shown to a user are excluded for 7 days, then re-enter the pool
--     with refreshed scores. Prevents VIP pool exhaustion.
--
-- AUDIT FIX 5: Cache Builder LIMIT 200 → O(N log K)
--   - Adds LIMIT 200 to the scored_candidates CTE in refresh_user_match_cache.
--   - PostgreSQL's planner uses a top-K heapsort for O(N log K) instead of O(N log N).


-- ═══════════════════════════════════════════════════════════════════════════════
-- FIX 1: SCORING CONFIG TABLE
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.scoring_config (
    key         text PRIMARY KEY,
    value       double precision NOT NULL,
    description text,
    updated_at  timestamptz DEFAULT now()
);

-- RLS: only service_role can write; authenticated can read
ALTER TABLE public.scoring_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "scoring_config_read_all" ON public.scoring_config
    FOR SELECT USING (true);

CREATE POLICY "scoring_config_write_service" ON public.scoring_config
    FOR ALL USING (auth.role() = 'service_role');

-- Seed default sigmoid parameters
INSERT INTO public.scoring_config (key, value, description) VALUES
    ('sigmoid_midpoint',  52.0,  'Center of the sigmoid score distribution curve'),
    ('sigmoid_steepness', 0.10,  'Steepness of the sigmoid mapping function'),
    ('sigmoid_floor',     30.0,  'Minimum calibrated score output'),
    ('sigmoid_ceiling',   98.0,  'Maximum calibrated score output')
ON CONFLICT (key) DO NOTHING;

-- Auto-Tuning Sweep Function (call via pg_cron monthly or manually)
CREATE OR REPLACE FUNCTION public.auto_tune_sigmoid_params()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_avg_raw     float8;
    v_stddev_raw  float8;
    v_sample_size int;
    v_old_midpoint float8;
    v_new_midpoint float8;
BEGIN
    -- Compute raw score statistics from the match cache
    -- Extract scores from JSONB arrays across all cached users
    SELECT
        AVG(score_val),
        STDDEV(score_val),
        COUNT(*)::int
    INTO v_avg_raw, v_stddev_raw, v_sample_size
    FROM (
        SELECT (m->>'score')::float8 AS score_val
        FROM public.user_match_cache c,
             jsonb_array_elements(c.matches) m
        WHERE c.computed_at > now() - interval '30 days'
          AND c.algorithm_version = 4
        LIMIT 50000  -- cap sample to avoid scanning millions
    ) raw_scores;

    -- Guard: need at least 500 data points for meaningful statistics
    IF v_sample_size < 500 THEN
        RETURN jsonb_build_object(
            'success', false,
            'reason', 'insufficient_data',
            'sample_size', COALESCE(v_sample_size, 0)
        );
    END IF;

    -- Read current midpoint
    SELECT value INTO v_old_midpoint 
    FROM public.scoring_config WHERE key = 'sigmoid_midpoint';

    -- New midpoint = weighted blend (70% current avg, 30% old midpoint)
    -- This prevents wild swings from a single batch
    v_new_midpoint := ROUND((0.70 * v_avg_raw + 0.30 * COALESCE(v_old_midpoint, 52.0))::numeric, 2);

    -- Clamp to reasonable bounds [35.0 .. 70.0]
    v_new_midpoint := GREATEST(35.0, LEAST(70.0, v_new_midpoint));

    -- Update the config
    UPDATE public.scoring_config 
    SET value = v_new_midpoint, updated_at = now()
    WHERE key = 'sigmoid_midpoint';

    RETURN jsonb_build_object(
        'success', true,
        'old_midpoint', v_old_midpoint,
        'new_midpoint', v_new_midpoint,
        'avg_raw_score', ROUND(v_avg_raw::numeric, 2),
        'stddev_raw_score', ROUND(COALESCE(v_stddev_raw, 0)::numeric, 2),
        'sample_size', v_sample_size
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.auto_tune_sigmoid_params() TO service_role;


-- ═══════════════════════════════════════════════════════════════════════════════
-- FIX 1 (cont): UPDATE calculate_mutual_compatibility TO USE scoring_config
-- ═══════════════════════════════════════════════════════════════════════════════

-- Change from IMMUTABLE → STABLE because it now reads from scoring_config table
CREATE OR REPLACE FUNCTION public.calculate_mutual_compatibility(
  prof_a public.profiles,
  pref_a public.partner_preferences,
  prof_b public.profiles,
  pref_b public.partner_preferences
)
RETURNS double precision
LANGUAGE plpgsql
STABLE  -- was IMMUTABLE, now reads config table
AS $$
DECLARE
    score_a_to_b float8;
    score_b_to_a float8;
    mutual_score float8;
    calibrated_score float8;
    -- Sigmoid parameters from config table (with hardcoded fallbacks)
    v_midpoint  float8;
    v_steepness float8;
    v_floor     float8;
    v_ceiling   float8;
    v_range     float8;
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

    -- Read sigmoid params from config (with hardcoded fallbacks for safety)
    SELECT COALESCE(
        (SELECT value FROM public.scoring_config WHERE key = 'sigmoid_midpoint'), 52.0
    ) INTO v_midpoint;
    SELECT COALESCE(
        (SELECT value FROM public.scoring_config WHERE key = 'sigmoid_steepness'), 0.10
    ) INTO v_steepness;
    SELECT COALESCE(
        (SELECT value FROM public.scoring_config WHERE key = 'sigmoid_floor'), 30.0
    ) INTO v_floor;
    SELECT COALESCE(
        (SELECT value FROM public.scoring_config WHERE key = 'sigmoid_ceiling'), 98.0
    ) INTO v_ceiling;

    v_range := v_ceiling - v_floor;

    -- Configurable Sigmoid Calibration:
    -- Maps raw mutual_score (0.0–1.0 scale, expressed as 0–100) into [floor..ceiling]
    calibrated_score := v_floor + (v_range / (1.0 + EXP(-1.0 * v_steepness * ((mutual_score * 100.0) - v_midpoint))));

    RETURN round(GREATEST(v_floor, LEAST(calibrated_score, v_ceiling))::numeric, 1);
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- FIX 2: NEGATIVE BEHAVIORAL SIGNALS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Updated behavioral signals engine:
-- - Dwell ≥ 5s + interest sent → strong positive (2.0x – 3.0x, unchanged)
-- - Dwell ≥ 5s + NO interest → weak NEGATIVE (0.3x penalty)
-- - Dwell < 5s → neutral (1.0x, unchanged)

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
        -- ── INTEREST SIGNAL (unchanged for positive cases) ──
        * CASE 
            WHEN i.status = 'accepted' THEN 3.0
            WHEN i.status = 'pending'  THEN 2.0
            -- ── FIX 2: NEGATIVE SIGNAL ──
            -- Dwell ≥ 5s but NO interest sent → weak negative (confirmation bias breaker)
            WHEN i.id IS NULL AND COALESCE(v.dwell_seconds, 0) >= 5 THEN 0.3
            -- Dwell < 5s, no interest → neutral (just browsing, not a signal)
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


-- ═══════════════════════════════════════════════════════════════════════════════
-- FIX 3: POOL ROTATION (7-DAY COOLDOWN)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Separate log table from profile_views (which caps at 10 and overwrites).
-- This is an append-only log of which candidates were shown in match results.
CREATE TABLE IF NOT EXISTS public.match_shown_log (
    user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    shown_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    shown_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, shown_id)
);

-- Index for the 7-day cooldown lookup
CREATE INDEX IF NOT EXISTS idx_match_shown_log_cooldown
    ON public.match_shown_log (user_id, shown_at DESC);

ALTER TABLE public.match_shown_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "match_shown_log_own" ON public.match_shown_log
    FOR ALL USING (auth.uid() = user_id);

-- Helper: record which candidates were shown to a user
CREATE OR REPLACE FUNCTION public.record_matches_shown(
    p_user_id uuid,
    p_shown_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
    INSERT INTO public.match_shown_log (user_id, shown_id, shown_at)
    SELECT p_user_id, unnest(p_shown_ids), now()
    ON CONFLICT (user_id, shown_id) 
    DO UPDATE SET shown_at = EXCLUDED.shown_at;
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_matches_shown(uuid, uuid[]) TO authenticated;


-- ═══════════════════════════════════════════════════════════════════════════════
-- FIX 3 + FIX 5: UPDATED refresh_user_match_cache
-- ═══════════════════════════════════════════════════════════════════════════════

-- Changes:
--   FIX 3: Adds LEFT JOIN on match_shown_log to exclude candidates shown in last 7 days
--   FIX 5: Adds ORDER BY + LIMIT 200 to scored_candidates CTE for O(N log K)

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

    -- SET-BASED COMPUTATION with Prime Visibility Boost, Behavioral Signals,
    -- Pool Rotation (FIX 3), and Top-K LIMIT (FIX 5)
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
        -- FIX 3: Pool Rotation — exclude candidates shown in last 7 days
        LEFT JOIN public.match_shown_log msl
               ON msl.user_id = p_user_id 
              AND msl.shown_id = p.id
              AND msl.shown_at > now() - interval '7 days'
        WHERE me.excluded_id IS NULL
          AND msl.shown_id IS NULL  -- FIX 3: not shown in last 7 days
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
        -- FIX 5: ORDER BY + LIMIT for top-K heapsort → O(N log K) instead of O(N log N)
        ORDER BY GREATEST(30.0, LEAST(98.0,
                public.calculate_mutual_compatibility(v_prof, v_pref, p, pref_cand))) DESC
        LIMIT 200
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


-- ═══════════════════════════════════════════════════════════════════════════════
-- FIX 3 (cont): UPDATE get_top_matches_v2 TO RECORD SHOWN CANDIDATES
-- ═══════════════════════════════════════════════════════════════════════════════

-- After returning matches, log them so the 7-day rotation works
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
    v_shown_ids         uuid[];
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
            -- FIX 3: Log shown candidates for pool rotation
            SELECT array_agg((r->>'profile_id')::uuid)
            INTO v_shown_ids
            FROM jsonb_array_elements(v_result) r;

            IF v_shown_ids IS NOT NULL AND array_length(v_shown_ids, 1) > 0 THEN
                PERFORM public.record_matches_shown(p_user_id, v_shown_ids);
            END IF;

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

    -- FIX 3: Log shown candidates for pool rotation (fallback path too)
    IF v_result IS NOT NULL AND jsonb_array_length(v_result) > 0 THEN
        SELECT array_agg((r->>'profile_id')::uuid)
        INTO v_shown_ids
        FROM jsonb_array_elements(v_result) r;

        IF v_shown_ids IS NOT NULL AND array_length(v_shown_ids, 1) > 0 THEN
            PERFORM public.record_matches_shown(p_user_id, v_shown_ids);
        END IF;
    END IF;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- PERMISSIONS
-- ═══════════════════════════════════════════════════════════════════════════════

-- scoring_config: read-only for authenticated, full access for service_role
GRANT SELECT ON public.scoring_config TO authenticated;
GRANT ALL ON public.scoring_config TO service_role;

-- match_shown_log: authenticated can read/write own rows (via RLS)
GRANT SELECT, INSERT, UPDATE ON public.match_shown_log TO authenticated;
GRANT ALL ON public.match_shown_log TO service_role;

-- Existing function permissions remain unchanged:
-- refresh_user_match_cache: authenticated + service_role (from migration 0003)
-- get_top_matches_v2: authenticated + service_role (from migration 0003)

-- Revoke anon from new functions
REVOKE ALL ON FUNCTION public.auto_tune_sigmoid_params() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.auto_tune_sigmoid_params() FROM anon;
REVOKE ALL ON FUNCTION public.record_matches_shown(uuid, uuid[]) FROM anon;
