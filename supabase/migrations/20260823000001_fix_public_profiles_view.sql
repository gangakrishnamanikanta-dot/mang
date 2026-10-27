-- ── Fix #12 (revised): public_profiles — safe column set, correct grants ──────
--
-- WHAT THIS FIXES:
--   1. Sensitive columns removed from the view:
--      sub_caste, gothram_id, about_me, family_description, sampradayam,
--      kuladevata, family_values, hobbies, native_place, work_location,
--      work_type, sandhyavandanam, daily_pooja, sloka_chanting,
--      temple_visits, festival_participation, career_preference,
--      fitness_habits, personality_type, spiritual_level, cultural_interests,
--      family_type_id, brothers_count, sisters_count, smoking_id, drinking_id,
--      citizenship_id, city_id, state_id, country_id, veda_shakha_id, pada_id,
--      rashi_id, native_place.
--   2. anon role: all privileges revoked.
--   3. authenticated role: SELECT only. No INSERT/UPDATE/DELETE/TRUNCATE.
--   4. OTP cleanup trigger dropped (caused full-table DELETE on every insert).
--
-- COLUMNS KEPT (safe display-only fields for profile cards):
--   id, full_name, gender, date_of_birth, height_inches, marital_status_id,
--   mother_tongue_id, caste_id, nakshatra_id, highest_education_id, college,
--   occupation_id, company, annual_income_id, food_preference_id, kuja_dosham,
--   profile_photo_url, profile_completed, is_verified, city, state,
--   created_at, age (computed)

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
  p.nakshatra_id,
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
  EXTRACT(YEAR FROM age(p.date_of_birth))::int AS age
FROM public.profiles p
WHERE p.profile_completed = true;

-- anon: no access at all
REVOKE ALL PRIVILEGES ON public.public_profiles FROM anon;

-- authenticated: SELECT only, no writes
REVOKE ALL PRIVILEGES ON public.public_profiles FROM authenticated;
GRANT SELECT ON public.public_profiles TO authenticated;

-- Fix #3: Drop OTP full-table-DELETE trigger (blocks inserts under load)
DROP TRIGGER IF EXISTS trg_cleanup_otp_rate_limits ON public.otp_rate_limits;
