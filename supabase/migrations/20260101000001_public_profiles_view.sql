create or replace view public.public_profiles
with (security_invoker = true) as
select
  p.id,
  p.full_name,
  p.gender,
  p.date_of_birth,
  p.height_inches,
  p.marital_status_id,
  p.mother_tongue_id,
  p.caste_id,
  p.sub_caste,
  p.gothram_id,
  p.veda_shakha_id,
  p.nakshatra_id,
  p.rashi_id,
  p.pada_id,
  p.highest_education_id,
  p.college,
  p.occupation_id,
  p.company,
  p.annual_income_id,
  p.work_location,
  p.about_me,
  p.profile_photo_url,
  p.hobbies,
  p.profile_completed,
  extract(year from age(p.date_of_birth)) as age
from public.profiles p
where p.profile_completed = true;
