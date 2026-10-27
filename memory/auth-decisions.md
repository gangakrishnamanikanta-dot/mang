---
name: auth-decisions
description: OTP-only auth, no magic links, email + mobile on same signup form, 60% profile completion threshold
metadata:
  type: project
---
## Authentication Decisions

### Auth Method
- **OTP only** — no magic links anywhere
- Email OTP for signup verification (sent via Resend)
- Email/password for login
- Phone OTP login standby (needs Twilio/MSG91 API key later)

### Signup Flow
1. Unified form: Email + Mobile + Password + Confirm Password
2. Email OTP verification (6-digit code via Resend)
3. 7-step Profile Builder
4. 60% completion check before Home Screen
5. Auto-create Supabase auth user (no auto-email)

### Profile Completion (60% threshold)
20 core required fields:
- full_name, gender, date_of_birth, phone, email
- marital_status_id, mother_tongue_id, caste_id
- gothram_id, veda_shakha_id, nakshatra_id, rashi_id
- highest_education_id, occupation_id, annual_income_id
- country_id, state, city
- profile_photo_url

Brahmin-specific fields (gothram, nakshatra, rashi, veda_shakha) are REQUIRED — not optional. This is a Brahmin community app.

### Custom OTP Implementation
- Custom `otps` table in DB (supabase auth.users not used for emails)
- Edge Functions: send-otp, verify-otp, send-email
- OTP expires in 10 minutes
- Resend sends the OTP email

### Edge Functions
- `send-otp` — generate + store OTP, send via Resend
- `verify-otp` — check OTP, confirm user
- `send-email` — generic email sender for all 7 email types
- Cron jobs: bi-weekly digest, monthly summary

### Password Reset
- User enters email → send-otp Edge Function sends 6-digit code
- User enters code → verify-otp confirms
- User sets new password

### Phone Login
- Standby for v2
- Needs Twilio or MSG91 API key
- UI already exists (tab in LoginScreen)
