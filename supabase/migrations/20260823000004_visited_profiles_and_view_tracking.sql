-- ── Visited Profiles & Capped View Tracking ─────────────────────────────────
--
-- Functions supporting:
-- 1. record_profile_view_capped: records dwell_seconds and keeps the 10 most recent views per user.
-- 2. get_visited_profiles_with_score: returns visited profiles with cached/calculated match scores.

CREATE OR REPLACE FUNCTION public.record_profile_view_capped(
  p_viewer_id uuid,
  p_viewed_id uuid,
  p_dwell_seconds integer DEFAULT 0,
  p_viewed_from text DEFAULT 'matches'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Insert or update view timestamp and dwell time
  INSERT INTO public.profile_views (viewer_id, viewed_id, viewed_at, dwell_seconds, viewed_from)
  VALUES (p_viewer_id, p_viewed_id, now(), p_dwell_seconds, p_viewed_from)
  ON CONFLICT (viewer_id, viewed_id) DO UPDATE
  SET viewed_at = EXCLUDED.viewed_at,
      dwell_seconds = GREATEST(public.profile_views.dwell_seconds, EXCLUDED.dwell_seconds),
      viewed_from = EXCLUDED.viewed_from;

  -- Maintain only the 10 most recently viewed profiles for this viewer
  DELETE FROM public.profile_views
  WHERE viewer_id = p_viewer_id
    AND viewed_id NOT IN (
      SELECT viewed_id FROM public.profile_views
      WHERE viewer_id = p_viewer_id
      ORDER BY viewed_at DESC
      LIMIT 10
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_visited_profiles_with_score(
  p_viewer_id uuid,
  p_limit integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(r ORDER BY r.viewed_at DESC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT 
      p.id,
      p.full_name,
      p.gender,
      p.date_of_birth,
      p.city,
      p.state,
      p.profile_photo_url,
      p.occupation_id,
      p.highest_education_id,
      p.caste_id,
      p.gothram_id,
      p.is_verified,
      p.created_at,
      p.updated_at,
      v.viewed_at,
      v.dwell_seconds,
      EXTRACT(year FROM age(p.date_of_birth)) AS age,
      COALESCE(
        -- Check if score exists in precomputed match cache first
        (
          SELECT (m->>'score')::float8
          FROM public.user_match_cache c,
               jsonb_array_elements(c.matches) m
          WHERE c.user_id = p_viewer_id
            AND m->>'profile_id' = p.id::text
          LIMIT 1
        ),
        -- Fallback to live compatibility calculation
        public.get_compatibility_index_v2(p_viewer_id, p.id)
      ) AS match_score
    FROM public.profile_views v
    JOIN public.profiles p ON p.id = v.viewed_id
    WHERE v.viewer_id = p_viewer_id
      AND p.full_name IS NOT NULL
      AND TRIM(p.full_name) <> ''
    ORDER BY v.viewed_at DESC
    LIMIT p_limit
  ) r;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_profile_view_capped(uuid, uuid, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_visited_profiles_with_score(uuid, integer) TO authenticated;
