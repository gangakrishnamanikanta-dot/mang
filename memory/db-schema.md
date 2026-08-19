---
name: db-schema
description: Profiles table has 48 columns, 27 lookup tables, ID fields are integer not string, hobbies is jsonb
metadata:
  type: reference
---

## Database Schema Notes

### profiles table (48 columns)
- `id` — integer (PK, from auth.users UUID mapped to integer or direct UUID)
- `email` — text
- `phone` — text (nullable)
- `full_name` — text (required)
- `gender` — text (nullable)
- `date_of_birth` — text (nullable)
- `height_inches` — integer (nullable)
- `marital_status_id` — integer FK
- `mother_tongue_id` — integer FK
- `caste_id` — integer FK
- `sub_caste` — text (nullable)
- `gothram_id` — integer FK
- `pravara` — text (nullable)
- `veda_shakha_id` — integer FK
- `nakshatra_id` — integer FK
- `rashi_id` — integer FK
- `pada_id` — integer FK
- `horoscope_url` — text (nullable)
- `highest_education_id` — integer FK
- `college` — text (nullable)
- `occupation_id` — integer FK
- `company` — text (nullable)
- `annual_income_id` — integer FK
- `work_location` — text (nullable)
- `father_name` — text (nullable)
- `father_occupation` — text (nullable)
- `mother_name` — text (nullable)
- `mother_occupation` — text (nullable)
- `family_type_id` — integer FK
- `native_place` — text (nullable)
- `brothers_count` — integer (nullable)
- `sisters_count` — integer (nullable)
- `state` — text (nullable)
- `city` — text (nullable)
- `food_preference_id` — integer FK
- `smoking_id` — integer FK
- `drinking_id` — integer FK
- `about_me` — text (nullable)
- `hobbies` — jsonb (nullable, stores string[])
- `profile_photo_url` — text (nullable)
- `additional_photo_urls` — jsonb (nullable, stores string[])
- `hide_mobile` — boolean (nullable)
- `hide_email` — boolean (nullable)
- `show_horoscope` — boolean (nullable)
- `profile_visibility_id` — integer FK
- `profile_completed` — boolean
- `terms_accepted` — boolean (nullable)
- `created_for` — text (nullable)
- `created_at` — timestamp
- `updated_at` — timestamp

### 27 Lookup Tables
marital_statuses, mother_tongues, castes, countries, drinking_habits, educations, annual_incomes, blood_groups, food_preferences, occupations, family_types, profile_visibilities, veda_shakhas, nakshatras, rashis, padas, gothrams, smoking_habits, and more.

### Custom OTP Table
- `otps` table needed for custom OTP (since we're not using Supabase email)
- Columns: id, email, code, purpose (signup/reset), expires_at, created_at

### handle_new_user Trigger
Auto-creates profile when auth user signs up. Inserts id, email, full_name from raw_user_meta_data.
