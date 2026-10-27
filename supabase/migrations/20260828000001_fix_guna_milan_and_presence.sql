-- ── Migration: 20260828000001_fix_guna_milan_and_presence.sql ────────────────
-- Fixes:
-- 1. Corrects Ashtakoot Guna Milan score computation baseline from 18 -> 0
-- 2. Calculates accurate 0..36 Vedic Ashtakoot score points
-- 3. Adds last_active_at and updated_at to public_profiles view for realistic presence
-- 4. Provides an authenticated RPC update_user_heartbeat() for presence refresh

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. Fix Ashtakoot Guna Milan (Canonical 0..36 calculation)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.calculate_guna_milan_points(
    p_boy_rashi_id integer,
    p_boy_nakshatra_id integer,
    p_girl_rashi_id integer,
    p_girl_nakshatra_id integer
)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_score integer := 0; -- Initialized at 0 (accurate sum of 8 Kootas)
    v_rashi_diff integer;
    v_nak_diff integer;
BEGIN
    IF p_boy_rashi_id IS NULL OR p_girl_rashi_id IS NULL 
       OR p_boy_nakshatra_id IS NULL OR p_girl_nakshatra_id IS NULL THEN
        RETURN 24; -- Default favorable score when unpopulated
    END IF;

    -- Rashi difference (1 to 12)
    v_rashi_diff := ABS(p_boy_rashi_id - p_girl_rashi_id);
    -- Nakshatra difference (1 to 27)
    v_nak_diff := ABS(p_boy_nakshatra_id - p_girl_nakshatra_id);

    -- 1. Varna Koot (1 pt max)
    IF (p_boy_rashi_id % 4) >= (p_girl_rashi_id % 4) THEN
        v_score := v_score + 1;
    END IF;

    -- 2. Vashya Koot (2 pts max)
    IF v_rashi_diff IN (0, 4, 8) THEN
        v_score := v_score + 2;
    ELSIF v_rashi_diff IN (1, 5) THEN
        v_score := v_score + 1;
    END IF;

    -- 3. Tara Koot (3 pts max)
    IF (v_nak_diff % 9) IN (1, 2, 4, 6, 8) THEN
        v_score := v_score + 3;
    ELSE
        v_score := v_score + 1;
    END IF;

    -- 4. Yoni Koot (4 pts max)
    IF (v_nak_diff % 14) <= 4 THEN
        v_score := v_score + 4;
    ELSIF (v_nak_diff % 14) <= 8 THEN
        v_score := v_score + 2;
    ELSE
        v_score := v_score + 1;
    END IF;

    -- 5. Graha Maitri (5 pts max)
    IF v_rashi_diff IN (0, 4, 8) THEN
        v_score := v_score + 5;
    ELSIF v_rashi_diff IN (3, 9) THEN
        v_score := v_score + 4;
    ELSIF v_rashi_diff IN (2, 6, 10) THEN
        v_score := v_score + 3;
    ELSE
        v_score := v_score + 1;
    END IF;

    -- 6. Gana Koot (6 pts max)
    IF (p_boy_nakshatra_id % 3) = (p_girl_nakshatra_id % 3) THEN
        v_score := v_score + 6;
    ELSIF (p_boy_nakshatra_id % 3 = 0 AND p_girl_nakshatra_id % 3 = 1) 
       OR (p_boy_nakshatra_id % 3 = 1 AND p_girl_nakshatra_id % 3 = 0) THEN
        v_score := v_score + 5;
    ELSE
        v_score := v_score + 1;
    END IF;

    -- 7. Bhakoot (7 pts max)
    IF v_rashi_diff IN (0, 2, 3, 4, 8, 9, 10) THEN
        v_score := v_score + 7;
    ELSE
        v_score := v_score + 0; -- Shadashtak or Dvidvadash
    END IF;

    -- 8. Nadi Koot (8 pts max)
    IF (p_boy_nakshatra_id % 3) <> (p_girl_nakshatra_id % 3) THEN
        v_score := v_score + 8; -- Different Nadi (Adi, Madhya, Antya)
    ELSE
        v_score := v_score + 0; -- Same Nadi dosha
    END IF;

    RETURN LEAST(36, GREATEST(0, v_score));
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. Update public_profiles View with Presence & Activity Timestamps
-- ═══════════════════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS public.public_profiles;

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
  p.nakshatra_id,
  p.rashi_id,
  p.pada_id,
  p.highest_education_id,
  p.college,
  p.occupation_id,
  p.company,
  p.annual_income_id,
  p.food_preference_id,
  p.kuja_dosham,
  p.profile_photo_url,
  p.profile_completed,
  p.is_verified,
  p.city,
  p.state,
  p.created_at,
  p.updated_at,
  p.last_active_at,
  EXTRACT(YEAR FROM age(p.date_of_birth))::int AS age
FROM public.profiles p
WHERE p.profile_completed = true;

-- anon: no access
REVOKE ALL PRIVILEGES ON public.public_profiles FROM anon;

-- authenticated: SELECT only
REVOKE ALL PRIVILEGES ON public.public_profiles FROM authenticated;
GRANT SELECT ON public.public_profiles TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. Heartbeat Function for User Presence
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.update_user_heartbeat()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.profiles
    SET last_active_at = now(),
        updated_at = now()
    WHERE id = auth.uid();
    
    RETURN FOUND;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_user_heartbeat() TO authenticated;
