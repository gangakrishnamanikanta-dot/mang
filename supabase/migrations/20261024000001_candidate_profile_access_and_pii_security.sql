-- ── Migration: 20261024000001_candidate_profile_access_and_pii_security.sql ────────────────
-- Description:
-- Industry-standard Zero-Trust candidate profile access architecture.
-- 1. Updates public_profiles view as a secure, sanitized public projection (security_invoker = false).
--    Exposes complete non-PII matrimonial biodata (Vedic, Gothram, Nakshatra, Rashi, Education, Career, Family, Photos).
--    Strictly omits sensitive PII (phone, email, admin status, suspension details).
--    Enforces candidate-only, non-hidden, non-suspended, completed profile filtering.
-- 2. Grants SELECT on public_profiles exclusively to authenticated users (revokes anon).
-- 3. Provides public.is_profile_publicly_visible() helper function.
-- 4. Permits authenticated users to view candidate partner preferences for active completed candidates.
-- 5. Keeps underlying public.profiles RLS strictly locked down (auth.uid() = id), sealing raw table access.

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. Public Profiles Projection View
-- ═══════════════════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS public.public_profiles;

CREATE VIEW public.public_profiles
WITH (security_invoker = false) AS
SELECT
    p.id,
    p.full_name,
    p.gender,
    p.date_of_birth,
    EXTRACT(year FROM age(p.date_of_birth::timestamp with time zone))::integer AS age,
    p.height_inches,
    p.marital_status_id,
    p.mother_tongue_id,
    p.caste_id,
    p.sub_caste,
    p.gothram_id,
    p.pravara,
    p.veda_shakha_id,
    p.nakshatra_id,
    p.rashi_id,
    COALESCE(p.pada_id, p.pada) AS pada_id,
    COALESCE(p.pada, p.pada_id) AS pada,
    p.time_of_birth,
    p.place_of_birth,
    p.is_manglik,
    p.kuja_dosham,
    CASE
        WHEN COALESCE(p.show_horoscope, false) = true THEN p.horoscope_url
        ELSE NULL::text
    END AS horoscope_url,
    p.sampradayam,
    p.kuladevata,
    p.sandhyavandanam,
    p.daily_pooja,
    p.sloka_chanting,
    p.temple_visits,
    p.festival_participation,
    p.highest_education_id,
    p.college,
    p.occupation_id,
    p.company,
    p.annual_income_id,
    p.work_location,
    p.work_type,
    p.career_preference,
    p.father_name,
    p.father_occupation,
    p.mother_name,
    p.mother_occupation,
    p.family_type_id,
    p.family_values,
    p.family_description,
    p.native_place,
    p.brothers_count,
    p.sisters_count,
    p.country_id,
    p.state_id,
    p.city_id,
    p.citizenship_id,
    p.state,
    p.city,
    p.food_preference_id,
    p.smoking_id,
    p.drinking_id,
    p.fitness_habits,
    p.personality_type,
    p.spiritual_level,
    p.cultural_interests,
    p.hobbies,
    p.about_me,
    p.profile_photo_url,
    p.additional_photo_urls,
    p.show_horoscope,
    p.profile_completed,
    p.created_for,
    p.is_verified,
    p.created_at,
    p.updated_at,
    p.last_active_at,
    p.account_type,
    p.allow_guardian_proxy_chat,
    COALESCE(p.is_hidden, false) AS is_hidden
FROM public.profiles p
WHERE COALESCE(p.profile_completed, false) = true
  AND COALESCE(p.is_hidden, false) = false
  AND COALESCE(p.is_suspended, false) = false
  AND COALESCE(p.account_type, 'candidate'::text) = 'candidate'::text;

REVOKE ALL PRIVILEGES ON public.public_profiles FROM anon;
REVOKE ALL PRIVILEGES ON public.public_profiles FROM authenticated;
GRANT SELECT ON public.public_profiles TO authenticated;
GRANT SELECT ON public.public_profiles TO service_role;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. Helper Function for Checking Public Profile Visibility
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.is_profile_publicly_visible(p_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = p_id
      AND COALESCE(profile_completed, false) = true
      AND COALESCE(is_hidden, false) = false
      AND COALESCE(is_suspended, false) = false
      AND COALESCE(account_type, 'candidate'::text) = 'candidate'::text
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_profile_publicly_visible(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_profile_publicly_visible(uuid) TO service_role;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. Partner Preferences Visibility Policy
-- ═══════════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "view_candidate_partner_preferences" ON public.partner_preferences;

CREATE POLICY "view_candidate_partner_preferences"
ON public.partner_preferences
FOR SELECT
TO authenticated
USING (
    auth.uid() = profile_id OR public.is_profile_publicly_visible(profile_id)
);
