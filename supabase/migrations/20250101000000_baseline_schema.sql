-- ============================================================
-- Mangalasutram: Baseline Schema
-- Pre-migration foundation tables
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Table: public.mother_tongues
CREATE TABLE IF NOT EXISTS public.mother_tongues (
  id SERIAL PRIMARY KEY,
  language TEXT NOT NULL,
  sort_order INT4 DEFAULT 0
);

-- Table: public.marital_statuses
CREATE TABLE IF NOT EXISTS public.marital_statuses (
  id SERIAL PRIMARY KEY,
  status TEXT NOT NULL,
  sort_order INT4 DEFAULT 0
);

-- Table: public.castes
CREATE TABLE IF NOT EXISTS public.castes (
  id SERIAL PRIMARY KEY,
  caste TEXT NOT NULL,
  primary_region TEXT,
  sort_order INT4 DEFAULT 0
);

-- Table: public.sub_castes
CREATE TABLE IF NOT EXISTS public.sub_castes (
  id SERIAL PRIMARY KEY,
  caste_id INT4 NOT NULL,
  sub_caste TEXT NOT NULL,
  sort_order INT4 DEFAULT 0
);

-- Table: public.gothrams
CREATE TABLE IF NOT EXISTS public.gothrams (
  id SERIAL PRIMARY KEY,
  gothram TEXT NOT NULL,
  veda TEXT,
  sort_order INT4 DEFAULT 0
);

-- Table: public.veda_shakhas
CREATE TABLE IF NOT EXISTS public.veda_shakhas (
  id SERIAL PRIMARY KEY,
  shakha TEXT NOT NULL,
  veda TEXT,
  sort_order INT4 DEFAULT 0
);

-- Table: public.nakshatras
CREATE TABLE IF NOT EXISTS public.nakshatras (
  id SERIAL PRIMARY KEY,
  nakshatra TEXT NOT NULL,
  rashi TEXT,
  pada_count INT4 DEFAULT 4,
  sort_order INT4 DEFAULT 0
);

-- Table: public.rashis
CREATE TABLE IF NOT EXISTS public.rashis (
  id SERIAL PRIMARY KEY,
  rashi TEXT NOT NULL,
  sanskrit TEXT,
  element TEXT,
  lord TEXT,
  sort_order INT4 DEFAULT 0
);

-- Table: public.padas
CREATE TABLE IF NOT EXISTS public.padas (
  id SERIAL PRIMARY KEY,
  pada TEXT NOT NULL,
  sort_order INT4 DEFAULT 0
);

-- Table: public.heights
CREATE TABLE IF NOT EXISTS public.heights (
  id SERIAL PRIMARY KEY,
  display TEXT NOT NULL,
  inches INT4 NOT NULL
);

-- Table: public.education_levels
CREATE TABLE IF NOT EXISTS public.education_levels (
  id SERIAL PRIMARY KEY,
  level TEXT NOT NULL,
  sort_order INT4 DEFAULT 0
);

-- Table: public.occupations
CREATE TABLE IF NOT EXISTS public.occupations (
  id SERIAL PRIMARY KEY,
  occupation TEXT NOT NULL,
  sort_order INT4 DEFAULT 0
);

-- Table: public.annual_incomes
CREATE TABLE IF NOT EXISTS public.annual_incomes (
  id SERIAL PRIMARY KEY,
  label TEXT NOT NULL,
  min_amount INT8,
  max_amount INT8,
  sort_order INT4 DEFAULT 0
);

-- Table: public.family_types
CREATE TABLE IF NOT EXISTS public.family_types (
  id SERIAL PRIMARY KEY,
  type TEXT NOT NULL,
  sort_order INT4 DEFAULT 0
);

-- Table: public.food_preferences
CREATE TABLE IF NOT EXISTS public.food_preferences (
  id SERIAL PRIMARY KEY,
  preference TEXT NOT NULL,
  sort_order INT4 DEFAULT 0
);

-- Table: public.smoking_habits
CREATE TABLE IF NOT EXISTS public.smoking_habits (
  id SERIAL PRIMARY KEY,
  habit TEXT NOT NULL,
  sort_order INT4 DEFAULT 0
);

-- Table: public.drinking_habits
CREATE TABLE IF NOT EXISTS public.drinking_habits (
  id SERIAL PRIMARY KEY,
  habit TEXT NOT NULL,
  sort_order INT4 DEFAULT 0
);

-- Table: public.hobbies
CREATE TABLE IF NOT EXISTS public.hobbies (
  id SERIAL PRIMARY KEY,
  hobby TEXT NOT NULL,
  sort_order INT4 DEFAULT 0
);

-- Table: public.profile_visibility_options
CREATE TABLE IF NOT EXISTS public.profile_visibility_options (
  id SERIAL PRIMARY KEY,
  option TEXT NOT NULL,
  sort_order INT4 DEFAULT 0
);

-- Table: public.countries
CREATE TABLE IF NOT EXISTS public.countries (
  id SERIAL PRIMARY KEY,
  country TEXT NOT NULL,
  sort_order INT4 DEFAULT 0
);

-- Table: public.indian_states
CREATE TABLE IF NOT EXISTS public.indian_states (
  id SERIAL PRIMARY KEY,
  state TEXT NOT NULL,
  sort_order INT4 DEFAULT 0
);

-- Table: public.blood_groups
CREATE TABLE IF NOT EXISTS public.blood_groups (
  id SERIAL PRIMARY KEY,
  blood_group TEXT NOT NULL,
  sort_order INT4 DEFAULT 0
);

-- Table: public.profiles
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY,
  phone TEXT,
  email TEXT,
  full_name TEXT CHECK (char_length(full_name) <= 100),
  gender TEXT CHECK (gender = ANY (ARRAY['Male'::text, 'Female'::text])),
  date_of_birth DATE,
  height_inches INT4,
  marital_status_id INT4,
  mother_tongue_id INT4,
  caste_id INT4,
  sub_caste TEXT,
  gothram_id INT4,
  pravara TEXT,
  veda_shakha_id INT4,
  nakshatra_id INT4,
  rashi_id INT4,
  pada_id INT4,
  horoscope_url TEXT,
  highest_education_id INT4,
  college TEXT CHECK (char_length(college) <= 150),
  occupation_id INT4,
  company TEXT CHECK (char_length(company) <= 150),
  annual_income_id INT4,
  work_location TEXT,
  father_name TEXT,
  father_occupation TEXT,
  mother_name TEXT,
  mother_occupation TEXT,
  family_type_id INT4,
  native_place TEXT CHECK (char_length(native_place) <= 150),
  brothers_count INT4 DEFAULT 0,
  sisters_count INT4 DEFAULT 0,
  food_preference_id INT4,
  smoking_id INT4,
  drinking_id INT4,
  hobbies JSONB DEFAULT '[]'::jsonb,
  about_me TEXT CHECK (char_length(about_me) <= 1000),
  profile_photo_url TEXT,
  additional_photo_urls JSONB DEFAULT '[]'::jsonb,
  hide_mobile BOOL DEFAULT true,
  hide_email BOOL DEFAULT true,
  show_horoscope BOOL DEFAULT false,
  profile_visibility_id INT4,
  terms_accepted BOOL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  created_for TEXT,
  welcome_email_sent BOOL DEFAULT false,
  country_id INT4,
  state_id INT4,
  city_id INT4,
  citizenship_id INT4,
  state TEXT CHECK (char_length(state) <= 100),
  city TEXT CHECK (char_length(city) <= 100),
  is_verified BOOL NOT NULL DEFAULT false,
  kuja_dosham VARCHAR,
  profile_completed BOOL DEFAULT false,
  last_active_at TIMESTAMPTZ DEFAULT now(),
  sampradayam TEXT,
  kuladevata TEXT,
  sandhyavandanam TEXT,
  daily_pooja TEXT,
  sloka_chanting TEXT,
  temple_visits TEXT,
  festival_participation TEXT,
  work_type TEXT,
  career_preference TEXT,
  fitness_habits TEXT,
  personality_type TEXT,
  spiritual_level TEXT,
  cultural_interests JSONB DEFAULT '[]'::jsonb,
  family_values TEXT,
  family_description TEXT,
  is_admin BOOL DEFAULT false,
  time_of_birth TEXT,
  place_of_birth TEXT,
  pada INT4 DEFAULT 1,
  is_manglik BOOL DEFAULT false,
  account_type TEXT NOT NULL DEFAULT 'candidate'::text CHECK (account_type = ANY (ARRAY['candidate'::text, 'guardian'::text])),
  allow_guardian_proxy_chat BOOL DEFAULT true,
  is_hidden BOOL DEFAULT false,
  is_suspended BOOL DEFAULT false,
  suspended_at TIMESTAMPTZ,
  suspension_reason TEXT
);

-- Table: public.partner_preferences
CREATE TABLE IF NOT EXISTS public.partner_preferences (
  profile_id UUID PRIMARY KEY,
  min_age INT4 CHECK (min_age >= 18 AND min_age <= 80),
  max_age INT4 CHECK (max_age >= 18 AND max_age <= 80),
  min_height_inches INT4 CHECK (min_height_inches >= 48 AND min_height_inches <= 90),
  max_height_inches INT4 CHECK (max_height_inches >= 48 AND max_height_inches <= 90),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  kuja_dosham_preference VARCHAR,
  preferred_marital_status_ids INT4[],
  preferred_mother_tongue_ids INT4[],
  preferred_caste_ids INT4[],
  preferred_food_ids INT4[],
  exclude_same_gotra BOOL DEFAULT true,
  preferred_education_ids INT4[],
  preferred_occupation_ids INT4[],
  preferred_family_type_ids INT4[],
  preferred_smoking_ids INT4[],
  preferred_drinking_ids INT4[],
  location_preference VARCHAR DEFAULT 'any'::character varying,
  preferred_annual_income_id INT4,
  horoscope_matching_required TEXT DEFAULT 'Must Match'::text,
  preferred_country_ids INT4[] DEFAULT '{1}'::integer[],
  marriage_vision TEXT
);

-- Table: public.education_career
CREATE TABLE IF NOT EXISTS public.education_career (
  id UUID PRIMARY KEY,
  education TEXT,
  college_university TEXT,
  profession TEXT,
  career_preference TEXT CHECK (career_preference = ANY (ARRAY['career_based'::text, 'family_balanced'::text])),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Table: public.preferences
CREATE TABLE IF NOT EXISTS public.preferences (
  id UUID PRIMARY KEY,
  looking_for_gender TEXT CHECK (looking_for_gender = ANY (ARRAY['male'::text, 'female'::text, 'other'::text])),
  age_min INT4,
  age_max INT4,
  height_min INT4,
  height_max INT4,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Table: public.traditional_details
CREATE TABLE IF NOT EXISTS public.traditional_details (
  id UUID PRIMARY KEY,
  brahmin_type TEXT,
  gothram TEXT,
  nakshatram TEXT,
  rashi TEXT,
  veda_sakha TEXT,
  pravara TEXT,
  sampradayam TEXT,
  kuladevata TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Table: public.otps
CREATE TABLE IF NOT EXISTS public.otps (
  id BIGSERIAL PRIMARY KEY,
  email TEXT NOT NULL,
  code_hash TEXT NOT NULL,
  purpose TEXT NOT NULL CHECK (purpose = ANY (ARRAY['signup'::text, 'reset_password'::text, 'verify_email'::text])),
  expires_at TIMESTAMPTZ NOT NULL,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table: public.otp_rate_limits
CREATE TABLE IF NOT EXISTS public.otp_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier TEXT NOT NULL,
  identifier_type TEXT NOT NULL,
  attempts INT4 NOT NULL DEFAULT 1,
  first_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  blocked_until TIMESTAMPTZ
);

-- Table: public.interests
CREATE TABLE IF NOT EXISTS public.interests (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  sender_profile_id UUID NOT NULL,
  receiver_profile_id UUID NOT NULL,
  status VARCHAR NOT NULL DEFAULT 'pending'::character varying CHECK (status::text = ANY (ARRAY['pending'::character varying, 'accepted'::character varying, 'declined'::character varying]::text[])),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Table: public.match_scores
CREATE TABLE IF NOT EXISTS public.match_scores (
  user_id UUID,
  candidate_id UUID,
  total_score INT2 NOT NULL CHECK (total_score >= 0 AND total_score <= 100),
  factor_breakdown JSONB NOT NULL DEFAULT '{}'::jsonb,
  algorithm_version INT2 NOT NULL DEFAULT 1,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, candidate_id)
);

-- Table: public.match_exclusions
CREATE TABLE IF NOT EXISTS public.match_exclusions (
  user_id UUID,
  excluded_id UUID,
  reason TEXT NOT NULL DEFAULT 'skip'::text CHECK (reason = ANY (ARRAY['skip'::text, 'blocked'::text, 'contacted'::text, 'not_interested'::text])),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, excluded_id)
);

-- Table: public.profile_views
CREATE TABLE IF NOT EXISTS public.profile_views (
  viewer_id UUID,
  viewed_id UUID,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  dwell_seconds INT4 DEFAULT 0,
  viewed_from TEXT DEFAULT 'matches'::text,
  PRIMARY KEY (viewer_id, viewed_id)
);

-- Table: public.user_match_sessions
CREATE TABLE IF NOT EXISTS public.user_match_sessions (
  user_id UUID PRIMARY KEY,
  last_refreshed TIMESTAMPTZ NOT NULL DEFAULT now(),
  candidates_count INT4 NOT NULL DEFAULT 0,
  algorithm_version INT2 NOT NULL DEFAULT 1
);

-- Table: public.user_match_cache
CREATE TABLE IF NOT EXISTS public.user_match_cache (
  user_id UUID PRIMARY KEY,
  matches JSONB NOT NULL DEFAULT '[]'::jsonb,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  algorithm_version INT2 NOT NULL DEFAULT 2
);

-- Table: public.shortlists
CREATE TABLE IF NOT EXISTS public.shortlists (
  user_id UUID,
  profile_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, profile_id)
);

-- Table: public.user_subscriptions
CREATE TABLE IF NOT EXISTS public.user_subscriptions (
  user_id UUID PRIMARY KEY,
  tier TEXT NOT NULL DEFAULT 'free'::text CHECK (tier = ANY (ARRAY['free'::text, 'prime_lite'::text, 'prime'::text])),
  status TEXT NOT NULL DEFAULT 'active'::text CHECK (status = ANY (ARRAY['active'::text, 'expired'::text, 'cancelled'::text])),
  start_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ,
  contacts_unlocked_count INT4 NOT NULL DEFAULT 0,
  contacts_unlocked_limit INT4 NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table: public.daily_user_quotas
CREATE TABLE IF NOT EXISTS public.daily_user_quotas (
  user_id UUID,
  quota_date DATE DEFAULT CURRENT_DATE,
  interests_sent_count INT4 NOT NULL DEFAULT 0,
  max_interests_per_day INT4 NOT NULL DEFAULT 5,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, quota_date)
);

-- Table: public.contact_unlocks
CREATE TABLE IF NOT EXISTS public.contact_unlocks (
  user_id UUID,
  target_profile_id UUID,
  unlocked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, target_profile_id)
);

-- Table: public.conversations
CREATE TABLE IF NOT EXISTS public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user1_id UUID NOT NULL,
  user2_id UUID NOT NULL,
  last_message TEXT DEFAULT ''::text,
  last_message_time TIMESTAMPTZ DEFAULT now(),
  last_sender_id UUID,
  user1_unread_count INT4 NOT NULL DEFAULT 0,
  user2_unread_count INT4 NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_message_nonce TEXT DEFAULT ''::text
);

-- Table: public.messages
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL,
  sender_id UUID NOT NULL,
  receiver_id UUID NOT NULL,
  content TEXT NOT NULL CHECK (content ~~ 'e2ee:%'::text),
  is_read BOOL NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  nonce TEXT DEFAULT ''::text,
  sender_public_key TEXT DEFAULT ''::text,
  is_delivered BOOL NOT NULL DEFAULT false,
  delivered_at TIMESTAMPTZ,
  is_deleted BOOL NOT NULL DEFAULT false,
  deleted_for_users UUID[] NOT NULL DEFAULT '{}'::uuid[],
  sender_role TEXT DEFAULT 'Candidate'::text,
  on_behalf_of UUID,
  proxy_sender_id UUID,
  proxy_sender_role TEXT
);

-- Table: public.scoring_config
CREATE TABLE IF NOT EXISTS public.scoring_config (
  key TEXT PRIMARY KEY,
  value FLOAT8 NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Table: public.match_shown_log
CREATE TABLE IF NOT EXISTS public.match_shown_log (
  user_id UUID,
  shown_id UUID,
  shown_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, shown_id)
);

-- Table: public.user_encryption_keys
CREATE TABLE IF NOT EXISTS public.user_encryption_keys (
  user_id UUID PRIMARY KEY,
  public_key TEXT NOT NULL,
  key_version INT4 NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table: public.horoscope_requests
CREATE TABLE IF NOT EXISTS public.horoscope_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL,
  receiver_id UUID NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'::text,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table: public.user_blocks
CREATE TABLE IF NOT EXISTS public.user_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL,
  blocked_id UUID NOT NULL,
  reason TEXT DEFAULT 'User blocked'::text,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table: public.user_reports
CREATE TABLE IF NOT EXISTS public.user_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL,
  reported_id UUID NOT NULL,
  category TEXT NOT NULL,
  reason TEXT NOT NULL,
  details TEXT,
  status TEXT NOT NULL DEFAULT 'pending'::text,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table: public.family_circles
CREATE TABLE IF NOT EXISTS public.family_circles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id UUID NOT NULL,
  family_name TEXT DEFAULT 'Family Circle'::text,
  invite_code TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table: public.family_members
CREATE TABLE IF NOT EXISTS public.family_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_circle_id UUID NOT NULL,
  user_id UUID NOT NULL,
  role TEXT NOT NULL DEFAULT 'Parent'::text,
  display_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table: public.family_profile_reviews
CREATE TABLE IF NOT EXISTS public.family_profile_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_circle_id UUID NOT NULL,
  target_profile_id UUID NOT NULL,
  reviewed_by UUID NOT NULL,
  reaction TEXT NOT NULL CHECK (reaction = ANY (ARRAY['shortlist'::text, 'discuss'::text, 'decline'::text, 'request_connect'::text])),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  voice_note_url TEXT
);

-- Table: public.family_messages
CREATE TABLE IF NOT EXISTS public.family_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_circle_id UUID NOT NULL,
  sender_id UUID NOT NULL,
  sender_name TEXT NOT NULL DEFAULT 'Member'::text,
  sender_role TEXT NOT NULL DEFAULT 'Member'::text,
  message_type TEXT NOT NULL DEFAULT 'text'::text CHECK (message_type = ANY (ARRAY['text'::text, 'shared_profile'::text, 'audio'::text, 'system'::text])),
  content TEXT,
  media_url TEXT,
  shared_profile_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table: public.profile_photos
CREATE TABLE IF NOT EXISTS public.profile_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL,
  url TEXT NOT NULL,
  is_approved BOOL DEFAULT false,
  is_primary BOOL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Table: public.success_stories
CREATE TABLE IF NOT EXISTS public.success_stories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_names TEXT NOT NULL,
  subtitle TEXT NOT NULL,
  quote TEXT NOT NULL,
  guna_score INT4 DEFAULT 32,
  city TEXT,
  married_date TEXT,
  is_active BOOL DEFAULT true,
  display_order INT4 DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now()
);

