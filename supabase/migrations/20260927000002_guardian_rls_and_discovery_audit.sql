-- ============================================================================
-- Migration: 20260927000002_guardian_rls_and_discovery_audit.sql
-- Purpose:
--   1. Fix search_discovery_profiles gender case mismatch ('Male'/'Female' vs 'male'/'female')
--      and replace hardcoded 90/75 score with real calculate_reciprocal_compatibility.
--   2. Allow linked Guardians via RLS to view Candidate shortlists and interests.
--   3. Update toggle_shortlist, get_my_shortlists, send_interest_with_quota, and
--      get_sidebar_summary to resolve Guardian -> Candidate ID seamlessly.
--   4. Deduplicate family_profile_reviews and add UNIQUE(family_circle_id, target_profile_id).
--   5. Ensure Guardian profile 9605e06e-a4b9-435c-b2db-9558e8b612ef has clean Father name.
-- ============================================================================

-- 1. RLS on shortlists & interests for linked Guardians
DROP POLICY IF EXISTS "Users can manage shortlists" ON public.shortlists;
CREATE POLICY "Users can manage shortlists"
ON public.shortlists
FOR ALL
TO authenticated
USING (
  auth.uid() = user_id
  OR public.get_guardian_candidate_id(auth.uid()) = user_id
)
WITH CHECK (
  auth.uid() = user_id
  OR public.get_guardian_candidate_id(auth.uid()) = user_id
);

DROP POLICY IF EXISTS "Users can view relevant interests" ON public.interests;
CREATE POLICY "Users can view relevant interests"
ON public.interests
FOR SELECT
TO public
USING (
  auth.uid() = sender_profile_id
  OR auth.uid() = receiver_profile_id
  OR public.get_guardian_candidate_id(auth.uid()) = sender_profile_id
  OR public.get_guardian_candidate_id(auth.uid()) = receiver_profile_id
);

-- 2. Update toggle_shortlist to act on Candidate profile when called by Guardian
CREATE OR REPLACE FUNCTION public.toggle_shortlist(p_target_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_caller_id uuid := auth.uid();
    v_user_id uuid;
    v_exists boolean;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
    END IF;

    v_user_id := COALESCE(public.get_guardian_candidate_id(v_caller_id), v_caller_id);

    IF v_user_id = p_target_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'cannot_shortlist_self');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.shortlists
        WHERE user_id = v_user_id AND profile_id = p_target_id
    ) INTO v_exists;

    IF v_exists THEN
        DELETE FROM public.shortlists
        WHERE user_id = v_user_id AND profile_id = p_target_id;

        RETURN jsonb_build_object(
            'success', true,
            'is_shortlisted', false,
            'profile_id', p_target_id
        );
    ELSE
        INSERT INTO public.shortlists (user_id, profile_id, created_at)
        VALUES (v_user_id, p_target_id, now())
        ON CONFLICT (user_id, profile_id) DO NOTHING;

        RETURN jsonb_build_object(
            'success', true,
            'is_shortlisted', true,
            'profile_id', p_target_id
        );
    END IF;
END;
$$;

-- 3. Update get_my_shortlists to resolve Guardian -> Candidate
CREATE OR REPLACE FUNCTION public.get_my_shortlists(p_limit integer DEFAULT 20, p_offset integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_caller_id uuid := auth.uid();
    v_user_id uuid;
    v_result jsonb;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    v_user_id := COALESCE(public.get_guardian_candidate_id(v_caller_id), v_caller_id);

    SELECT COALESCE(jsonb_agg(r ORDER BY r.shortlisted_at DESC), '[]'::jsonb)
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
            p.mother_tongue_id,
            p.is_verified,
            p.created_at,
            s.created_at AS shortlisted_at,
            EXTRACT(year FROM age(p.date_of_birth))::int AS age,
            COALESCE(
                (
                    SELECT (m->>'score')::float8
                    FROM public.user_match_cache c,
                         jsonb_array_elements(c.matches) m
                    WHERE c.user_id = v_user_id
                      AND (m->>'profile_id' = p.id::text OR m->>'id' = p.id::text)
                    LIMIT 1
                ),
                ROUND(public.calculate_reciprocal_compatibility(v_user_id, p.id)::numeric, 1)
            ) AS match_score
        FROM public.shortlists s
        JOIN public.profiles p ON p.id = s.profile_id
        WHERE s.user_id = v_user_id
          AND p.full_name IS NOT NULL
          AND TRIM(p.full_name) <> ''
        ORDER BY s.created_at DESC
        LIMIT p_limit
        OFFSET p_offset
    ) r;

    RETURN v_result;
END;
$$;

-- 4. Update send_interest_with_quota to resolve Guardian -> Candidate
CREATE OR REPLACE FUNCTION public.send_interest_with_quota(p_receiver_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_caller_id uuid;
    v_sender_id uuid;
    v_quota record;
    v_sub record;
    v_tier text := 'free';
    v_max_daily int := 3;
    v_today date := public.ist_today();
    v_existing_interest uuid;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
    END IF;

    v_sender_id := COALESCE(public.get_guardian_candidate_id(v_caller_id), v_caller_id);

    IF v_sender_id = p_receiver_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'self_interest', 'message', 'You cannot send interest to yourself.');
    END IF;

    SELECT * INTO v_sub
    FROM public.user_subscriptions
    WHERE user_id = v_sender_id
      AND (expires_at IS NULL OR expires_at > now());

    IF FOUND THEN
        v_tier := v_sub.tier;
    END IF;

    IF v_tier = 'prime' THEN
        v_max_daily := 30;
    ELSIF v_tier = 'prime_lite' THEN
        v_max_daily := 15;
    ELSE
        v_max_daily := 3;
    END IF;

    SELECT * INTO v_quota
    FROM public.daily_user_quotas
    WHERE user_id = v_sender_id AND quota_date = v_today;

    IF NOT FOUND THEN
        INSERT INTO public.daily_user_quotas (user_id, quota_date, interests_sent_count, max_interests_per_day)
        VALUES (v_sender_id, v_today, 0, v_max_daily)
        ON CONFLICT (user_id, quota_date) DO NOTHING;

        SELECT * INTO v_quota
        FROM public.daily_user_quotas
        WHERE user_id = v_sender_id AND quota_date = v_today;
    END IF;

    IF v_quota.interests_sent_count >= v_max_daily THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'quota_exceeded',
            'tier', v_tier,
            'limit', v_max_daily,
            'message', 'Daily interest limit reached. Upgrade to Prime for more.'
        );
    END IF;

    SELECT id INTO v_existing_interest
    FROM public.interests
    WHERE sender_profile_id = v_sender_id AND receiver_profile_id = p_receiver_id
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'duplicate', 'message', 'You have already sent an interest to this profile.');
    END IF;

    INSERT INTO public.interests (sender_profile_id, receiver_profile_id, status)
    VALUES (v_sender_id, p_receiver_id, 'pending');

    UPDATE public.daily_user_quotas
    SET interests_sent_count = interests_sent_count + 1
    WHERE user_id = v_sender_id AND quota_date = v_today;

    RETURN jsonb_build_object('success', true, 'message', 'Interest sent successfully.');
END;
$$;

-- 5. Fix search_discovery_profiles gender case matching & real compatibility score
CREATE OR REPLACE FUNCTION public.search_discovery_profiles(
    p_user_id uuid,
    p_query text DEFAULT NULL::text,
    p_sub_caste text DEFAULT NULL::text,
    p_min_age integer DEFAULT 18,
    p_max_age integer DEFAULT 60,
    p_city text DEFAULT NULL::text,
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS TABLE(
    id uuid,
    full_name text,
    gender text,
    age integer,
    city text,
    state text,
    sub_caste text,
    profile_photo_url text,
    is_verified boolean,
    highest_education text,
    occupation text,
    match_score integer,
    caste_id integer,
    gothram_id integer,
    mother_tongue_id integer,
    highest_education_id integer,
    occupation_id integer,
    date_of_birth text,
    created_at timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_effective_uid uuid;
  v_viewer_gender text;
  v_opposite_gender text;
  v_sub record;
  v_tier text := 'free';
  v_discovery_limit int := 10;
BEGIN
  v_effective_uid := COALESCE(public.get_guardian_candidate_id(p_user_id), p_user_id);

  SELECT LOWER(TRIM(COALESCE(p.gender, ''))) INTO v_viewer_gender
  FROM public.profiles p
  WHERE p.id = v_effective_uid;

  v_opposite_gender := CASE
    WHEN v_viewer_gender = 'male' THEN 'female'
    WHEN v_viewer_gender = 'female' THEN 'male'
    ELSE NULL
  END;

  SELECT * INTO v_sub FROM public.user_subscriptions
  WHERE user_id = v_effective_uid AND status = 'active' AND (expires_at IS NULL OR expires_at > now())
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    v_tier := v_sub.tier;
  END IF;

  IF v_tier = 'prime' THEN
    v_discovery_limit := 500;
  ELSIF v_tier = 'prime_lite' THEN
    v_discovery_limit := 50;
  ELSE
    v_discovery_limit := 10;
  END IF;

  IF v_tier = 'free' AND p_offset >= 10 THEN
    RETURN;
  END IF;

  IF v_tier = 'free' THEN
    p_limit := LEAST(p_limit, 10 - p_offset);
  ELSE
    p_limit := LEAST(p_limit, v_discovery_limit);
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.full_name,
    p.gender,
    DATE_PART('year', AGE(p.date_of_birth::date))::int AS age,
    p.city,
    p.state,
    p.sub_caste,
    p.profile_photo_url,
    COALESCE(p.is_verified, false) AS is_verified,
    COALESCE(el.level, 'Graduate') AS highest_education,
    COALESCE(oc.occupation, 'Professional') AS occupation,
    ROUND(public.calculate_reciprocal_compatibility(v_effective_uid, p.id)::numeric)::int AS match_score,
    p.caste_id,
    p.gothram_id,
    p.mother_tongue_id,
    p.highest_education_id,
    p.occupation_id,
    p.date_of_birth::text,
    p.created_at
  FROM public.profiles p
  LEFT JOIN public.education_levels el ON el.id = p.highest_education_id
  LEFT JOIN public.occupations oc ON oc.id = p.occupation_id
  WHERE
    p.id <> v_effective_uid
    AND p.profile_completed = true
    AND COALESCE(p.is_hidden, false) = false
    AND COALESCE(p.account_type, 'candidate') = 'candidate'
    AND p.full_name IS NOT NULL
    AND p.gender IS NOT NULL
    AND p.date_of_birth IS NOT NULL
    AND (v_opposite_gender IS NULL OR LOWER(TRIM(p.gender)) = v_opposite_gender)
    AND (
      p_query IS NULL
      OR p.full_name ILIKE '%' || p_query || '%'
      OR p.city ILIKE '%' || p_query || '%'
      OR p.sub_caste ILIKE '%' || p_query || '%'
      OR COALESCE(oc.occupation, '') ILIKE '%' || p_query || '%'
    )
    AND (p_sub_caste IS NULL OR p_sub_caste = 'All' OR p.sub_caste ILIKE '%' || p_sub_caste || '%')
    AND (
      p_min_age IS NULL
      OR DATE_PART('year', AGE(p.date_of_birth::date))::int >= p_min_age
    )
    AND (
      p_max_age IS NULL
      OR DATE_PART('year', AGE(p.date_of_birth::date))::int <= p_max_age
    )
    AND (
      p_city IS NULL
      OR p_city = ''
      OR p.city ILIKE '%' || p_city || '%'
      OR p.state ILIKE '%' || p_city || '%'
    )
  ORDER BY p.is_verified DESC, p.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- 6. Update get_sidebar_summary to count shortlists/views for v_target_uid and return candidate's proxy setting
CREATE OR REPLACE FUNCTION public.get_sidebar_summary(p_user_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_uid uuid := COALESCE(p_user_id, auth.uid());
    v_prof public.profiles;
    v_invite_code text;
    v_target_uid uuid;
    v_cand_name text;
    v_cand_allow_proxy boolean := true;
    v_guardian_role text;
    v_guardian_display_name text;
    v_membership jsonb;
    v_shortlists_count int := 0;
    v_visited_count int := 0;
BEGIN
    IF v_uid IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

    SELECT * INTO v_prof FROM public.profiles WHERE id = v_uid;
    IF NOT FOUND THEN
        RETURN '{}'::jsonb;
    END IF;

    IF COALESCE(v_prof.account_type, 'candidate') = 'guardian' THEN
        SELECT fc.candidate_id, p.full_name, fc.invite_code, fm.role, fm.display_name, COALESCE(p.allow_guardian_proxy_chat, true)
        INTO v_target_uid, v_cand_name, v_invite_code, v_guardian_role, v_guardian_display_name, v_cand_allow_proxy
        FROM public.family_members fm
        JOIN public.family_circles fc ON fc.id = fm.family_circle_id
        JOIN public.profiles p ON p.id = fc.candidate_id
        WHERE fm.user_id = v_uid
          AND fm.role <> 'Candidate'
        LIMIT 1;

        v_target_uid := COALESCE(v_target_uid, v_uid);
    ELSE
        v_target_uid := v_uid;
        v_cand_allow_proxy := COALESCE(v_prof.allow_guardian_proxy_chat, true);
        SELECT invite_code INTO v_invite_code
        FROM public.family_circles
        WHERE candidate_id = v_uid
        LIMIT 1;
    END IF;

    v_membership := public.get_user_membership_status(v_target_uid);

    SELECT count(*)::int INTO v_shortlists_count
    FROM public.shortlists
    WHERE user_id = v_target_uid;

    SELECT count(*)::int INTO v_visited_count
    FROM public.profile_views
    WHERE viewer_id = v_target_uid;

    RETURN jsonb_build_object(
        'user_id', v_uid,
        'target_profile_id', v_target_uid,
        'matrimony_id', 'MS-' || UPPER(SUBSTRING(v_target_uid::text, 1, 6)),
        'full_name', COALESCE(v_guardian_display_name, v_prof.full_name, 'Valued Member'),
        'profile_photo_url', v_prof.profile_photo_url,
        'account_type', COALESCE(v_prof.account_type, 'candidate'),
        'is_verified', COALESCE(v_prof.is_verified, false),
        'is_hidden', COALESCE(v_prof.is_hidden, false),
        'allow_guardian_proxy_chat', v_cand_allow_proxy,
        'family_invite_code', v_invite_code,
        'linked_candidate_name', v_cand_name,
        'guardian_role', v_guardian_role,
        'shortlists_count', v_shortlists_count,
        'visited_count', v_visited_count,
        'membership', v_membership
    );
END;
$$;

-- 7. Deduplicate family_profile_reviews and enforce UNIQUE(family_circle_id, target_profile_id)
DELETE FROM public.family_profile_reviews a
USING public.family_profile_reviews b
WHERE a.family_circle_id = b.family_circle_id
  AND a.target_profile_id = b.target_profile_id
  AND a.created_at < b.created_at;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'family_profile_reviews_circle_target_unique'
  ) THEN
    ALTER TABLE public.family_profile_reviews
      ADD CONSTRAINT family_profile_reviews_circle_target_unique
      UNIQUE (family_circle_id, target_profile_id);
  END IF;
END $$;

-- 8. Ensure Guardian account 9605e06e-a4b9-435c-b2db-9558e8b612ef has distinct Father name
UPDATE public.profiles
SET full_name = 'Vukanti Ramesh'
WHERE id = '9605e06e-a4b9-435c-b2db-9558e8b612ef';
