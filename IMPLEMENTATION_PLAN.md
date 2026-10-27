# Mangalasutram — 20-Day Master Launch, QA, Security & Admin Sprint Plan

> **Updated:** 2026-09-26  
> **Current App Completion:** 90% (Core Mobile + Supabase Backend)  
> **Target:** 100% Production Launch + Full Lifecycle QA + Cyber Attack Resilience + Admin Dashboard in 20 Days

---

## 1. Executive Summary & Current Stage

### What is Already Complete (90%):
- **Authentication & Onboarding**: Email/Password, Google OAuth, Edge Function OTP Verification, 8-Step Luxury Vedic Onboarding Wizard, Multi-Photo Upload with Supabase Storage RLS.
- **Vedic Matching Engine**: Canonical Ashta-Koota (36 Guna) calculation engine, Reciprocal Compatibility scoring, 24-hour `user_match_cache`, Discovery Cohorts (`daily_recommendations`, `high_guna_milan`, `new_members`, `watched_profiles`).
- **Family Room & Guardian Proxy System**: 6-character Family Invite Code, separate Guardian login (`account_type = 'guardian'`), restricted 3-tab Guardian layout (`Matches`, `Discover`, `Chats`), Candidate `onBehalfOf` proxy feed querying, *"🏷️ Sent by Father"* proxy chat badges, Candidate Veto toggle (`allow_guardian_proxy_chat`).
- **End-to-End Encrypted (E2EE) Messaging**: Realtime WebSocket chat, deterministic room key encryption, delivery/read ticks, offline Outbox queue.
- **Subscriptions & Quotas**: Tier enforcement in PostgreSQL (`Free: 5/day`, `Prime Lite: 12/day`, `Prime VIP: 25/day`), atomic interest quota tracking.
- **5-Card Luxury Sidebar & Apple HIG Inner Screens**: Live `get_sidebar_summary`, `toggle_profile_visibility`, `toggle_guardian_proxy_chat`, `public.success_stories`, Apple HIG inset-grouped `My Biodata` with live trailing value summaries, `Partner Preferences` with automatic match cache refresh, `Saved & Visited` with `CupertinoSlidingSegmentedControl`, and `Settings & Privacy` with Incognito toggle, Contact Privacy toggles, Guardian Proxy Veto, Change Password, Help & Concierge FAQs, and Legal sheets.

---

## 2. The 20-Day Master Execution Schedule

### 📅 Phase 1: Candidate UI/UX Completion & Zero Static Data (Days 1 – 4)
- [x] **Day 1 — 5-Card Luxury Sidebar & Dynamic Home Backend** *(Completed Sep 26)*
  - **Supabase MCP Backend Work (`20260926000001_sidebar_summary_and_dynamic_stories.sql`)**:
    - Added `is_hidden BOOLEAN DEFAULT false` to `public.profiles` and filtered out hidden profiles in `get_discovery_cohorts`.
    - Created `public.get_sidebar_summary()` RPC returning live Matrimony ID (`MS-XXXX`), verification status, visibility status (`is_hidden`), family invite code (`family_link_code`), subscription tier, and daily quota in a single query.
    - Created `public.toggle_profile_visibility(p_is_hidden boolean)` and `public.toggle_guardian_proxy_chat(p_allow boolean)` RPCs.
    - Created `public.success_stories` table with RLS and seeded initial verified stories so `home_tab.dart` is 100% dynamic from Supabase.
  - **Flutter Sidebar & Inner Screens Refactor (`home_screen.dart`, `edit_profile_screen.dart`, `partner_preferences_screen.dart`, `visited_profiles_screen.dart`)**:
    - **Top Burgundy Header**: Avatar, Name, Copyable `ID: MS-XXXX` pill, Gold `Verified` badge, and full-width `Preview My Public Profile` button.
    - **Slim Temple Gold Strip**: Live `FREE PLAN • X/Y Matches Left` + `Upgrade` button.
    - **5 Spacious White Menu Cards** & Apple HIG inset-grouped inner screens (`My Biodata` with live trailing summaries, `Partner Preferences` with Burgundy sliders & cache refresh, `Family Room`, `Saved & Visited` 2-tab segmented control, `Settings & Privacy`).
  - Removed hardcoded static mock data (`_SuccessStoriesCarousel`) from `home_tab.dart` and bound to `public.success_stories`.
- [x] **Day 2 — Settings & Privacy Controls** *(Completed Sep 26)*
  - Added in-app **Change Password** modal sheet (`_ChangePasswordSheet`).
  - Added **Pause / Hide Profile (Incognito Mode)** `CupertinoSwitch` (`is_hidden`), **Hide Mobile**, **Hide Email**, and **Display Horoscope Publicly** toggles in `SettingsScreen`.
  - Wired **Allow Parents to Chat on My Behalf (Candidate Veto)** `CupertinoSwitch` (`toggle_guardian_proxy_chat`) into `SettingsScreen`.
- [x] **Day 3 — Store Compliance, Legal & Support Pages** *(Completed Sep 26)*
  - Wired **Terms of Service** and **Privacy Policy** Apple HIG modal sheets in `SettingsScreen`.
  - Built **Help & Vedic Concierge** sheet (FAQs + one-tap support email copy).
- [x] **Day 4 — Unified Biodata & Partner Preferences Live DB Verification** *(Completed Sep 27)*
  - Rebuilt `public.public_profiles` view (`20260927000003_biodata_public_view_and_matching_sync.sql`) to project all 55+ public Biodata columns while excluding `phone` and `email`, and added `trg_sync_profile_pada` to keep `pada` and `pada_id` synchronized.
  - Upgraded all 7 Biodata Edit sections (`edit_basic_info_screen.dart`, `edit_religion_screen.dart`, `edit_education_screen.dart`, `edit_family_screen.dart`, `edit_lifestyle_screen.dart`, `edit_location_screen.dart`, `edit_photos_screen.dart`) and `partner_preferences_screen.dart` for 100% field parity with Onboarding and `ProfileDetailScreen`, cached lookup selectors, and `FocusScope.of(context).unfocus()`.
  - Wired `ProfileService.saveProfile`, `updateProfileFields`, and `savePartnerPreferences` to automatically invalidate `HomeService` caches, invoke `refresh_user_match_cache`, and notify listeners.
  - Verified live under `SET LOCAL ROLE authenticated` across all 58 eligible female candidates that changing Partner Preferences dynamically shifts compatibility scores (`61.4%` avg broad vs `58.2%` avg strict) and re-ranks top matches (`Swati Dwivedi 86.8%` ➔ `Ananya Sharma 88.45%`).

---

### 📅 Phase 2: End-to-End Lifecycle Functional Testing (Days 5 – 9)
*Every single flow tested from cold start with zero mock data:*

- [ ] **Day 5 — Auth & Onboarding Lifecycle**
  - Test New Candidate Signup ➔ Email OTP Verification ➔ 8-Step Vedic Wizard ➔ Photo Upload.
  - Test New Guardian Signup ➔ Email OTP Verification ➔ Family Code Link ➔ Restricted 3-Tab Home.
  - Test Forgot Password ➔ Reset Password ➔ Login.
- [ ] **Day 6 — Matching & Discovery Engine**
  - Verify Candidate and Guardian receive the **exact same profiles in the exact same order** from `user_match_cache`.
  - Test all 6 Sort/Filter Chips (`Best Match`, `Online Now`, `High Guna`, `Near You`, `Newly Joined`, `Not Contacted`).
  - Test `DiscoverTab` multi-facet filters (Age, Height, Caste, Gothram exclusion, Education, State/City).
  - Verify Daily Limit Paywall Card triggers accurately at tier ceiling (`5` for Free, `12` for Lite, `25` for VIP).
- [ ] **Day 7 — Interests, Shortlists & Horoscope Requests**
  - Test Sending Interest (atomic quota deduction).
  - Test Receiving Interest (Accept ➔ unlocks chat; Decline ➔ removes from active queue).
  - Test Shortlisting / Bookmarking and Horoscope Request flows.
- [ ] **Day 8 — E2EE Chat, Offline Outbox & Family Room**
  - Test real-time 1-on-1 messaging between matched candidates.
  - Test Guardian proxy messaging (*"Sent by Father"* gold badge + yellow Transparency Notice banner).
  - Test Candidate Veto toggle (disables Guardian input bar immediately when turned off).
  - Test airplane-mode offline message queuing (`OutboxService`) and automatic retry upon reconnect.
- [ ] **Day 9 — Subscriptions, Logout & Account Deletion**
  - Test Razorpay checkout / plan upgrade reflection across app.
  - Test clean Logout (wipes local memory cache, secure storage tokens, and realtime subscriptions).
  - Test 2-Step Permanent Account Erasure (verifying cascading deletion of profile, photos, chats, and auth record).

---

### 📅 Phase 3: Cyber Attack Resilience & Security Audit (Days 10 – 13)
*Defensive penetration testing against OWASP Mobile & API Top 10:*

- [ ] **Day 10 — Broken Object-Level Authorization (IDOR) & RLS Audit**
  - Attempt cross-user profile mutation (`UPDATE profiles WHERE id = '<other_user_uuid>'`).
  - Attempt unauthorized match cache reading (`get_top_matches_v2` with unlinked user UUID).
  - Attempt reading another family's `family_messages` or `family_profile_reviews`.
  - Confirm 100% rejection by PostgreSQL Row Level Security (RLS).
- [ ] **Day 11 — Authentication, OTP Brute-Force & Token Security**
  - Test OTP rate-limiting and max retry lockout on `verify-otp` Edge Function.
  - Verify expired/tampered JWT rejection on all RPC endpoints.
  - Verify `FlutterSecureStorage` AES-256 encryption on Android/iOS local storage.
- [ ] **Day 12 — SQL Injection, RPC Fuzzing & Payload Validation**
  - Fuzz all RPC parameters (`p_user_id`, `p_invite_code`, `p_content`) with SQL injection payloads, null bytes, and oversized strings.
  - Verify phone numbers and emails are never leaked in public discovery JSON responses.
- [ ] **Day 13 — Storage Bucket & E2EE Cryptographic Verification**
  - Attempt uploading non-image binaries or >5MB files to `profile_photos` bucket.
  - Attempt deleting another user's storage folder (`storage.foldername(name)[1] != auth.uid()`).
  - Verify raw `messages` table rows in Supabase contain only `e2ee:` ciphertext and never plaintext.

---

### 📅 Phase 4: Admin Dashboard Development & Testing (Days 14 – 18)
- [ ] **Day 14 — Admin Authentication & RBAC Guard**
  - Create strict `admin_users` role guard and RLS policies in Supabase.
  - Build Admin Login & Protected Route shell.
- [ ] **Day 15 — User Management & Profile Verification Queue**
  - Build table view of newly registered Candidates & Guardians.
  - Build Photo & Profile Verification approval/rejection actions (`is_verified = true`, `is_approved = true`).
- [ ] **Day 16 — Trust & Safety Moderation Desk**
  - Build Reported Profiles & Block Logs queue (`reports` and `blocks` tables).
  - Build 1-click Suspend / Ban / Unban user controls with audit logging.
- [ ] **Day 17 — Subscriptions, Quotas & Platform Analytics**
  - Build live KPI cards: Total Candidates, Active Guardians, Prime Subscribers, Daily Matches Served, Interests Sent.
  - Manual tier override tool for customer support.
- [ ] **Day 18 — Admin Security Penetration Test**
  - Verify a normal Candidate or Guardian JWT can never invoke Admin RPCs or view the Admin Dashboard.

---

### 📅 Phase 5: Final Polish, Release Build & Store Sign-Off (Days 19 – 20)
- [ ] **Day 19 — Performance & Zero-Error Lock**
  - 60fps scroll profiling, memory leak check, `flutter analyze` (0 errors, 0 warnings, 0 lints).
- [ ] **Day 20 — Production Release Packaging**
  - Signed Android App Bundle (`.aab`) & APK build, iOS release archive preparation, final pre-launch verification.
