# 🕉️ Mangalasutram — Master Execution Plan
### Single Source of Truth | Quality First | No Shortcuts

> **Standard**: JeevaSathi features × Instagram polish × WhatsApp security  
> **Rule**: Complete one module fully before moving to the next.  
> **Tracking**: See `PROGRESS.md` for what's done.

---

## 🏭 THE 9-STAGE QUALITY GATE
### Every single feature — no exceptions — passes all 9 stages before being marked ✅

| Stage | Name | What Happens |
|-------|------|-------------|
| **Stage 1** | 🔨 **BUILD** | Write complete code — UI + logic + service calls. Not partial. Not "we'll fix later." |
| **Stage 2** | 🔎 **CODE REVIEW** | Critically re-read every line written. Check for edge cases, dead code, hardcoded values, missing null checks. |
| **Stage 3** | 📊 **STATIC ANALYSIS** | `flutter analyze` → must show **zero issues, zero warnings, zero lints**. No exceptions. |
| **Stage 4** | 🧪 **UNIT + INTEGRATION TESTS** | Write tests for all business logic. Test full flows (e.g. signup → profile row in DB). Run `flutter test` — all pass. |
| **Stage 5** | 🛡️ **SECURITY CHECK** | RLS enforced? JWT in SecureStorage? No secrets in code? No cross-user data leak? Inputs validated? Brute force blocked? |
| **Stage 6** | 🗄️ **DB CHECK** | Data saved correctly after flow? Constraints enforced? Edge cases handled (duplicate, null, expired)? Test via Postman/Node against live Supabase. |
| **Stage 7** | 📱 **DEVICE TEST** | Run on real device. Happy path + all error paths. Small screen (no overflow). Slow network (graceful). |
| **Stage 8** | 👤 **UAT** | **You (client) test it.** You approve it. You sign off. Only then it is locked. |
| **Stage 9** | 🚀 **STAGING → PRODUCTION** | Deploy to staging Supabase branch first. Smoke test. Watch logs for 30 min. Then push to production. Rollback script ready. |

### Post-Deploy (after Stage 9)
- Monitor Sentry + Supabase logs for 24h
- Run regression test — confirm previous features still work
- Mark ✅ in `PROGRESS.md` with date and notes
- **Lock it. Never touch it again unless a bug is found.**

---


## CURRENT APP STATE (Baseline — Aug 31, 2026)

### ✅ Already Exists (needs polish/hardening, not rebuild)
- Auth screens: login, signup, OTP, forgot password, reset password, splash
- Onboarding: all 8 steps (basic info, traditional/astrology, education, family, lifestyle, location, preferences, review)
- Home: home_tab, home_screen, visited_profiles_screen, home_service
- Matching: matches_tab, match_action_buttons, match_badge
- Discovery: discover_tab (partial)
- Interests: interests_tab, interest_service
- Messaging: chat_conversation_screen, inbox_tab, chat_service, E2EE crypto service, outbox_service
- Profile: profile_detail_screen, edit_profile_screen, all edit section screens, partner_preferences_screen, profile_service
- Subscription: plans_screen, premium_tab, settings_screen, subscription_service, contact_unlock_dialog, quota_exhausted_sheet, prime_verified_badge
- Shared: profile_card, lookup_service, all luxury widgets
- Core: theme, DI, models (Profile, MatchResult, Interest, LookupOption, PartnerPreference)
- Backend: Matching engine (quota-enforced), Guna Milan engine, E2EE chat, subscription system, quota walls

### ❌ Missing / Not Built Yet
- Guna Milan breakdown screen (8 kootas + verdict)
- Who Viewed Me screen
- Shortlists screen
- Block / Report flow (UI + backend)
- Push Notifications (FCM + APNs)
- Payment Gateway (Razorpay)
- Ghost Mode toggle
- Account deletion (2-step, Apple mandatory)
- Privacy Policy + Terms & Conditions screens
- Notification preferences + in-app notification center
- Biometric auth
- Certificate pinning
- Rate limiting middleware
- ML event logging table
- CI/CD pipeline

---

## PHASE 1 — Auth & Onboarding (Polish & Harden)

### 1.1 Splash Screen
- [ ] Animated Mandala logo on cream background
- [ ] Auto-navigate: session valid → Home, else → Login
- [ ] Biometric auth prompt if enabled
- [ ] Handle token expiry gracefully (auto-refresh or redirect)

### 1.2 Login Screen
- [ ] Email + password login working
- [ ] Google Sign-In (OAuth) working
- [ ] Show/hide password toggle
- [ ] Input validation (empty, invalid email)
- [ ] Rate limit UI feedback ("Too many attempts. Try in 30s")
- [ ] Loading state on button (no double-tap)
- [ ] Keyboard does not jump or overlap inputs

### 1.3 OTP Verification
- [ ] 6-box OTP, auto-focus and auto-advance
- [ ] Resend OTP with 60s countdown timer
- [ ] Auto-verify on 6th digit entered
- [ ] Wrong OTP error (clear message, don't clear all boxes)

### 1.4 Signup Screen
- [ ] Full name, email, phone, password, confirm password
- [ ] Password strength indicator
- [ ] T&C + Privacy Policy checkbox (required, links open legal screens)
- [ ] Age 18+ declaration

### 1.5 Forgot / Reset Password
- [ ] Email link flow end-to-end working
- [ ] Deep link handling for reset
- [ ] Success state shown after reset

### 1.6 Onboarding Step 1 — Basic Info
- [ ] Full name, DOB (LuxuryDatePicker), gender (card), height
- [ ] All fields validated before Next
- [ ] No keyboard jump

### 1.7 Onboarding Step 2 — Traditional / Astrology
- [ ] Religion, caste, sub-caste, gothram (DB dropdowns)
- [ ] Nakshatra, Rashi, Pada (DB dropdowns)
- [ ] Manglik toggle (Yes/No/Partial)
- [ ] Time of birth (LuxuryTimePicker), place of birth
- [ ] "Skip astrology" option

### 1.8 Onboarding Step 3 — Education & Career
- [ ] Highest education, field of study, college name
- [ ] Employment status, occupation (DB), employer, income range

### 1.9 Onboarding Step 4 — Family
- [ ] Family type, values, status
- [ ] No. of siblings, parents' occupations
- [ ] Mother tongue (DB dropdown)
- [ ] Spacious layout — zero cramping

### 1.10 Onboarding Step 5 — Lifestyle
- [ ] Diet, smoking, drinking toggles
- [ ] Hobbies (multi-select chips)
- [ ] Exercise, daily routine

### 1.11 Onboarding Step 6 — Location
- [ ] Country, state, city (cascading DB dropdowns)
- [ ] Residential status

### 1.12 Onboarding Step 7 — Partner Preferences
- [ ] Age range slider, height range slider
- [ ] Preferred castes (multi-select)
- [ ] Education, income, location preferences
- [ ] Exclude same gotra toggle

### 1.13 Onboarding Step 8 — Review & Complete
- [ ] Summary of all data, section by section
- [ ] Edit icon on each section
- [ ] Profile photo upload (min 1, max 6)
- [ ] Profile completion % bar
- [ ] "Complete Profile" CTA

### 1.14 Photo Upload
- [ ] Gallery or camera picker
- [ ] Square crop with preview
- [ ] Stored in Supabase Storage as signed URL (not public)
- [ ] Server-side type + size validation
- [ ] Reorder photos drag-and-drop

---

## PHASE 2 — Home Feed

### 2.1 Home Tab Layout
- [ ] Warm cream background, Playfair Display headings
- [ ] Section: "Today's Picks" (quota-limited)
- [ ] Section: "High Guna Matches" (≥28/36)
- [ ] Section: "New Members" (last 7 days)
- [ ] Section: "Recently Active" (last 48h)
- [ ] Section: "Who Viewed You" (blurred free / revealed prime)
- [ ] Pull-to-refresh
- [ ] Skeleton loaders (not spinners)
- [ ] Graceful empty states for every section

### 2.2 Profile Card Widget
- [ ] Photo, name, age, city
- [ ] Compatibility score badge
- [ ] Guna score badge (if available)
- [ ] Verified tick, Prime badge
- [ ] Quick actions: Heart, Bookmark, Skip
- [ ] Tap → Profile Detail
- [ ] Photo blur on Who Viewed You for free tier

### 2.3 Quota Exhausted State
- [ ] After 5 profiles (free): elegant upgrade prompt
- [ ] "Upgrade to Prime for 25 daily picks" CTA

---

## PHASE 3 — Matching & Guna Milan

### 3.1 Matches Tab
- [ ] Full quota-limited match list
- [ ] Sort: by score / age / Guna
- [ ] Filter chips: All / High Guna / Verified / Prime
- [ ] Load more pagination (offset-based)
- [ ] Empty state when quota exhausted

### 3.2 Profile Detail Screen
- [ ] Hero photo carousel (multiple photos + page dots)
- [ ] Name, age, city — large, clear
- [ ] Compatibility score ring (animated)
- [ ] **Guna Milan card** — total/36, tappable → breakdown
- [ ] About / Bio section
- [ ] All info sections: Basic, Astrology, Education, Family, Lifestyle, Location, Preferences
- [ ] Action bar: Send Interest | Shortlist | Message | More (⋯)
- [ ] More menu: Block, Report, Share
- [ ] Contact info (blurred free / unlock prime)
- [ ] Record profile view silently on screen open

### 3.3 Guna Milan Breakdown Screen ⭐ (Key Differentiator)
- [ ] 8-koota table:
  - Varna (1), Vashya (2), Tara (3), Yoni (4)
  - Graha Maitri (5), Gana (6), Bhakoot (7), Nadi (8)
- [ ] Each row: name | score | max | result (✅/❌/⚠️)
- [ ] Total score with color band: <18 red | 18-24 yellow | 24-32 green | 32+ gold
- [ ] Verdict: Anukool / Madhyam / Uttam / Param Uttam
- [ ] Dosha alerts: Nadi Dosha, Mangal Dosha, Bhakoot Dosha
- [ ] Expandable "What does this mean?" for each koota
- [ ] Null state: "Add astrology details to see Guna report"

---

## PHASE 4 — Discovery & Search

### 4.1 Discover Tab
- [ ] Search bar with debounced name search
- [ ] Filter panel (bottom sheet) with all filters:
  - Age range, height range, religion, caste, education, income
  - Location (state/city), Manglik preference, mother tongue, diet
  - Verified only toggle, Prime only toggle
- [ ] Results grid (2-col) or list toggle
- [ ] Result count displayed
- [ ] Sort: Relevance / Newest / Last Active
- [ ] Discovery limit per plan enforced (10/50/unlimited)
- [ ] Upgrade prompt at limit

### 4.2 Search
- [ ] Search by name, instant results
- [ ] Recent searches stored locally

---

## PHASE 5 — Interests

### 5.1 Interests Tab
- [ ] Sub-tabs: Received | Sent | Accepted
- [ ] Each card: photo, name, age, city, timestamp
- [ ] Received: Accept / Decline with confirmation
- [ ] Sent: status badge (Pending/Accepted/Declined)
- [ ] Accepted: "Start Chat" button
- [ ] Daily quota shown: "3/15 sent today"
- [ ] Quota exhausted state with upgrade CTA

### 5.2 Send Interest Flow
- [ ] Confirmation bottom sheet
- [ ] Success animation (heart burst)
- [ ] Error: quota exceeded / already sent / blocked

### 5.3 Interest Notifications
- [ ] Push notification on receive
- [ ] Push notification on accept
- [ ] In-app tab badge

---

## PHASE 6 — Shortlists

### 6.1 Shortlists Screen
- [ ] Grid/list of shortlisted profiles
- [ ] Sorted by most recent
- [ ] Swipe or long-press to remove
- [ ] Empty state with CTA

### 6.2 Who Shortlisted Me
- [ ] Prime users see list of who shortlisted them
- [ ] Free users see blurred + count + upgrade CTA

---

## PHASE 7 — Messaging / Chat

### 7.1 Inbox Tab
- [ ] Threads sorted by latest message
- [ ] Row: avatar, name, last message, timestamp, unread badge
- [ ] Swipe to delete (with confirmation)
- [ ] Empty state: "Accept an interest to chat"

### 7.2 Chat Conversation Screen
- [ ] Bubble UI: sent (right/burgundy), received (left/cream)
- [ ] E2EE lock icon + "End-to-end encrypted" label in header
- [ ] Delivery ticks: ✓ sent / ✓✓ delivered / ✓✓ (blue) read
- [ ] Timestamps grouped by day
- [ ] Text, image, voice message support
- [ ] Emoji picker
- [ ] Reply to message (swipe right on bubble)
- [ ] Long-press menu: Copy | Delete for me | Delete for everyone | Report
- [ ] Typing indicator
- [ ] Online / last seen in header
- [ ] Block / Report from ⋯ menu

### 7.3 Chat Security
- [ ] Signed URLs for shared images
- [ ] No screenshot notification (Android)
- [ ] Auto-delete option (24h / 7d / 30d)
- [ ] Messages deleted for both users if requested

---

## PHASE 8 — Push Notifications

### 8.1 FCM + APNs Setup
- [ ] New interest received
- [ ] Interest accepted
- [ ] New message received
- [ ] Profile viewed (prime users)
- [ ] Subscription expiring (3 days)
- [ ] Subscription expired

### 8.2 In-App Notification Center
- [ ] Bell icon with unread badge
- [ ] Tappable → relevant screen
- [ ] Mark all read, delete individual

### 8.3 Notification Preferences
- [ ] Toggle each type on/off
- [ ] Quiet hours setting
- [ ] Saved to DB per user

---

## PHASE 9 — Subscription & Payments

### 9.1 Plans Screen
- [ ] Free / Prime Lite / Prime VIP cards
- [ ] Feature comparison table
- [ ] Current plan highlighted
- [ ] Monthly / annual toggle
- [ ] "Most Popular" badge
- [ ] Upgrade CTA → Payment

### 9.2 Razorpay Payment
- [ ] Order created server-side (Edge Function — never client-side)
- [ ] Razorpay checkout SDK
- [ ] Webhook signature validation
- [ ] Success → auto-activate plan
- [ ] Failure → retry option
- [ ] Receipt screen + email

### 9.3 Subscription Management
- [ ] Plan details in Settings
- [ ] Renewal date shown
- [ ] Cancel option with confirmation
- [ ] Transaction history screen

### 9.4 Contact Unlock
- [ ] Blurred contact card on profile
- [ ] "Unlock (X remaining)" button
- [ ] Quota shown clearly
- [ ] After unlock: phone + email visible

---

## PHASE 10 — Safety & Privacy

### 10.1 Block User
- [ ] From Profile Detail + Chat (⋯ menu)
- [ ] Confirmation modal
- [ ] Blocked list in Settings
- [ ] Both users hidden from each other immediately

### 10.2 Report User
- [ ] Reason selector (fake / inappropriate / harassment / spam / other)
- [ ] Optional description
- [ ] Stored in `user_reports` with full context
- [ ] Admin alerted

### 10.3 Ghost Mode
- [ ] Toggle in Privacy Settings
- [ ] When ON: your views not recorded for others
- [ ] Prime Lite+ only

### 10.4 Privacy Controls
- [ ] Profile visibility: Everyone / Interests only / Hidden
- [ ] Show online status: Yes/No
- [ ] Show last seen: Yes/No
- [ ] Show in search: Yes/No
- [ ] Photo visibility settings

### 10.5 Account Deletion (2-Step)
- [ ] Step 1: Warning modal (data loss explained)
- [ ] Step 2: Password confirm → 30-day grace period
- [ ] Reactivation by logging in within 30 days
- [ ] After 30 days: hard delete all data (GDPR)
- [ ] Confirmation email sent

---

## PHASE 11 — Profile & Settings

### 11.1 My Profile Screen
- [ ] View profile as others see it
- [ ] Completion ring
- [ ] Edit button
- [ ] Photo grid: add / reorder / delete

### 11.2 Edit Profile Sections
- [ ] Basic Info, Astrology, Education, Family, Lifestyle, Location
- [ ] Save → immediate DB update → cache invalidated

### 11.3 Partner Preferences Screen
- [ ] Editable (same as Step 7)
- [ ] Reset to default option

### 11.4 Settings Screen
- [ ] Account, Privacy, Notifications, Subscription, Security, Legal, Danger Zone

### 11.5 Active Sessions Screen
- [ ] All logged-in devices listed
- [ ] Log out individual device
- [ ] Log out all other devices

### 11.6 Change Password Screen
- [ ] Current password → New → Confirm
- [ ] Strength indicator
- [ ] Logs out all other sessions on change

---

## PHASE 12 — Legal & Compliance

### 12.1 Terms & Conditions
- [ ] Full scrollable legal text
- [ ] Account rules, prohibited content, payment policy, cancellation, disputes
- [ ] Last updated date

### 12.2 Privacy Policy
- [ ] What data collected, why, retention period
- [ ] GDPR/PDPA rights section
- [ ] Contact for privacy queries

### 12.3 About Screen
- [ ] App version, company name/address
- [ ] Grievance officer contact
- [ ] Links to T&C and Privacy Policy

### 12.4 Consent Records
- [ ] T&C checkbox on signup stored as `consented_at` in DB
- [ ] Age 18+ declaration stored

---

## PHASE 13 — Security Hardening

### 13.1 Flutter App (Obfuscation & Hardening)
- [ ] Code Obfuscation (`--obfuscate` flag during build)
- [ ] ProGuard / R8 Shrinking for Android (`build.gradle`)
- [ ] Certificate SSL Pinning (Block MITM attacks)
- [ ] Biometric auth (fingerprint/face) for app lock
- [ ] Jailbreak/root detection warning
- [ ] Screenshot prevention in chat + contact screens
- [ ] JWT in FlutterSecureStorage (not SharedPreferences)
- [ ] Logout clears all local data
- [ ] Session timeout after 30 days inactivity

### 13.2 Backend
- [ ] RLS on every table — verified and tested
- [ ] All RPCs: SECURITY DEFINER + explicit search_path
- [ ] Rate limiting on sensitive RPCs
- [ ] Webhook signature validation (Razorpay)
- [ ] Service role key never in client code
- [ ] File uploads: server-side type + size validation
- [ ] Audit log for sensitive actions
- [ ] No PII in Supabase logs

### 13.3 Data Privacy
- [ ] Signed URLs for all photos (30-min expiry)
- [ ] E2EE keys never stored server-side
- [ ] GDPR data export endpoint
- [ ] Hard delete after 30-day grace period verified

---

## PHASE 14 — CI/CD & Quality Gates

### 14.1 GitHub Actions CI
- [ ] `flutter analyze` — zero warnings gate
- [ ] `flutter test` — all tests pass
- [ ] `dart format` check
- [ ] Supabase migration lint
- [ ] APK + IPA build check on every PR

### 14.2 Release Pipeline (Fastlane)
- [ ] iOS: auto build number, TestFlight upload
- [ ] Android: sign + Play Store internal track
- [ ] Secrets via GitHub Secrets
- [ ] main = production, develop = staging

### 14.3 Monitoring
- [ ] Sentry Flutter: crashes + performance
- [ ] Supabase Logs: error rate alerts
- [ ] PostHog: user funnel analytics
- [ ] Slack alerts on error rate > 1%

---

## PHASE 15 — AI/ML Hooks (Future-Ready)

### 15.1 Event Logging Table (Build Now)
- [ ] `match_events`: user_id, target_id, event_type, dwell_seconds, score_at_time
- [ ] Populated on every: view, skip, interest, shortlist, chat_open

### 15.2 ML Feature Vector
- [ ] `ml_feature_vector` jsonb in user_match_cache
- [ ] Fields: age_delta, caste_match, education_delta, guna_score, behavioral_signals

### 15.3 A/B Testing Framework
- [ ] `get_user_experiment_variant()` RPC — stable hash-based
- [ ] Results logged to analytics_events

### 15.4 ML Edge Function Hook
- [ ] Shell function ready at `supabase/functions/ml-score/`
- [ ] `ML_ENABLED` env var gates it (false by default)
- [ ] Graceful fallback to SQL score

---

## FINAL QA CHECKLIST (Before Handover)

### Functional
- [ ] Full journey: signup → onboarding → home → match → interest → chat
- [ ] Payment end-to-end (test + live)
- [ ] All push notification types
- [ ] Block flow — truly invisible both sides
- [ ] Account deletion — 30-day grace → hard delete

### Device Testing
- [ ] Android (2 latest major versions)
- [ ] iOS (2 latest major versions)
- [ ] 5.5" screen — zero overflow
- [ ] 6.7" screen — proper spacing
- [ ] Low connectivity — graceful degradation

### Performance
- [ ] Cold start < 3 seconds
- [ ] Home feed < 1.5 seconds
- [ ] Profile detail < 1 second
- [ ] Chat latency < 300ms
- [ ] p95 API < 500ms

### Security
- [ ] Cross-user access attempt → blocked
- [ ] Unauthenticated API call → blocked
- [ ] SQL injection in search → sanitized
- [ ] Quota bypass attempt → blocked at DB
- [ ] Razorpay webhook replay → blocked

### Final Gate
- [ ] `flutter analyze` → No issues found
- [ ] `flutter test` → All tests pass

---

## HANDOVER DELIVERABLES
- [ ] Complete Flutter source code (clean, documented)
- [ ] All Supabase migrations in sequence
- [ ] Environment variables list
- [ ] Razorpay setup guide
- [ ] FCM/APNs setup guide
- [ ] Supabase dashboard admin access
- [ ] Postman collection for all APIs
- [ ] `PROGRESS.md` — full completion record
