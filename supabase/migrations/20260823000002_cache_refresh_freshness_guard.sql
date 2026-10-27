-- Fix: Add freshness guard & security hardening to refresh_user_match_cache
--
-- 1. Security Hardening:
--    - Revoke EXECUTE from PUBLIC and anon.
--    - Block anonymous requests explicitly (auth.role() = 'anon').
--    - Prevent authenticated users from refreshing caches for other users (auth.uid() <> p_user_id).
--
-- 2. Freshness Guard with Force Override:
--    - Added `p_force boolean DEFAULT false`.
--    - If p_force = false and cache is < 1 hour old, skip execution.
--    - If p_force = true (user changes partner preferences, or manual pull-to-refresh), bypass freshness guard and force cache recomputation.

DROP FUNCTION IF EXISTS public.refresh_user_match_cache(uuid);
DROP FUNCTION IF EXISTS public.refresh_user_match_cache(uuid, boolean);

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
    v_cache_age  interval;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN;
    END IF;

    -- SECURITY GUARD:
    -- 1. Deny unauthenticated anonymous requests
    IF auth.role() = 'anon' THEN
        RAISE EXCEPTION 'Access denied: Anonymous users cannot refresh match cache.';
    END IF;

    -- 2. Prevent users from refreshing cache for other users
    IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'Access denied: Cannot refresh match cache for another user.';
    END IF;

    -- FRESHNESS GUARD: skip rebuild if cache is less than 1 hour old UNLESS p_force is true
    IF NOT p_force THEN
        SELECT now() - computed_at INTO v_cache_age
        FROM public.user_match_cache
        WHERE user_id = p_user_id
          AND algorithm_version = 4;

        IF v_cache_age IS NOT NULL AND v_cache_age < interval '1 hour' THEN
            RETURN;
        END IF;
    END IF;

    SELECT
        LOWER(TRIM(COALESCE(gender, ''))),
        date_of_birth,
        EXTRACT(YEAR FROM age(date_of_birth))::int,
        gothram_id
    INTO v_gender, v_user_dob, v_user_age, v_gothram_id
    FROM public.profiles
    WHERE id = p_user_id;

    IF NOT FOUND OR v_gender IS NULL THEN
        RETURN;
    END IF;

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

-- Permissions
REVOKE ALL ON FUNCTION public.refresh_user_match_cache(uuid, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refresh_user_match_cache(uuid, boolean) FROM anon;
GRANT EXECUTE ON FUNCTION public.refresh_user_match_cache(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_user_match_cache(uuid, boolean) TO service_role;
