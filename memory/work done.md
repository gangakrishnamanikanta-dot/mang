# Mangalasutram — Complete Work Log
**Project:** Luxury Brahmin Matrimony App (Flutter + Supabase)  
**Last Updated:** 2 August 2026

---

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Phase 1 — UI Design & Screens](#2-phase-1--ui-design--screens)
3. [Phase 2 — Backend Architecture](#3-phase-2--backend-architecture)
4. [Authentication Strategy](#4-authentication-strategy)
5. [All Files Created / Modified](#5-all-files-created--modified)
6. [Key Decisions & Rules](#6-key-decisions--rules)
7. [What Remains to Be Done](#7-what-remains-to-be-done)

---

## 1. Project Overview

**App Name:** Mangalasutram  
**Tagline:** Sacred Matrimony — Traditional Brahmin Matrimony  
**Tech Stack:**
- Flutter (Dart) — Frontend
- Supabase — Backend (Auth, Database, Storage, Edge Functions)
- Provider — State Management
- `supabase_flutter`, `google_sign_in`, `flutter_dotenv`, `image_picker`

**Design Philosophy:** Apple Human Interface Design level quality. Premium, luxury, minimal. Burgundy (`#6E1732`) primary color, Cream (`#FFFDF8`) background. `Inter` font. 8px "boxed-round" input corners. Burgundy icons in all text fields.

**Target Devices:** Primarily Android (CPH2717 / OnePlus connected via USB). Designed for 390×844 (iPhone 16 Pro proportions).

---

## 2. Phase 1 — UI Design & Screens

### 2.1 What Was Planned
Build the complete UI for the following screens before wiring any backend:
1. Splash Screen
2. Login Screen
3. Sign Up Screen
4. OTP Verification Screen
5. Profile Builder (7 Steps)
6. Forgot Password Screen
7. Reset Password Screen

### 2.2 Splash Screen (`splash_screen.dart`)
- Premium animated splash with Mangalasutram logo
- Auto-navigates to Login after a brief delay
- Apple-quality animation

### 2.3 Login Screen (`login_screen.dart`)
**Design decisions made:**
- Segmented control: **Email** tab | **Mobile** tab
- When Email selected: Email field + Password field + Login button + Google button
- When Mobile selected: Mobile number field + Continue button (navigates to OTP screen)
- "Forgot Password?" link navigates to `/forgot-password`
- Google Sign-In button with native Google branding
- All inputs use 8px border radius (NOT rounded pill style)
- All icons inside inputs colored Burgundy `#6E1732`
- Back button preserved on all screens so tapping Back does not close the app

**Corrections made:**
- Originally used `pushReplacementNamed` which broke back-navigation — fixed to `pushNamed` where appropriate

### 2.4 Sign Up Screen (`signup_screen.dart`)
- Fields: Email, Mobile Number, Password, Confirm Password
- All validations: empty check, password match, minimum length
- Google Sign-Up button at bottom
- On success: navigates to OTP Verification screen

### 2.5 OTP Verification Screen (`otp_verification_screen.dart`)
- 6 individual OTP boxes (NOT a single text field)
- Auto-focus on first box when screen opens
- Auto-advance cursor to next box on digit entry
- Backspace moves cursor to previous box
- Paste support (pastes across all 6 boxes)
- Countdown timer (28 seconds)
- Resend button (appears only after timer expires)
- Loading state on Verify button
- Success animation placeholder
- Error message placeholder
- Receives `phoneNumber` or `email` as argument
- Receives `mode` argument: `'signup'`, `'login'`, `'password_reset'`
- Routes to `/profile_builder` after successful OTP (for new users)
- Routes to `/home` after successful OTP (for returning users) — to be wired

### 2.6 Profile Builder — 7 Steps

**Architecture Decision:** Instead of one giant monolithic 945-line file (`profile_builder_screen.dart`), we modularised it into:
- `ProfileBuilderLayout` — master container, handles step navigation, progress bar, Continue/Back buttons
- `Step1BasicInfo` through `Step7Review` — individual step widgets

**Layout features:**
- Burgundy progress bar at top showing step completion percentage
- Step title in header
- Back arrow (taps go to previous step; on Step 1 it pops back to previous screen)
- "Continue" button at bottom (becomes "Complete Profile" on Step 7)
- All data collected into a shared `_formData` map and passed down via `onUpdate` callback

**Step 1 — Basic Info** (`step1_basic_info.dart`)
- Full Name (text)
- Gender (segmented toggle: Male / Female)
- Date of Birth (date picker formatted DD/MM/YYYY)
- Mobile Number (phone input with +91 prefix shown)
- Email (email keyboard)

**Step 2 — Traditional** (`step2_traditional.dart`)
- Marital Status (BottomSheetSelector)
- Mother Tongue (BottomSheetSelector)
- Caste (BottomSheetSelector)
- Sub-Caste (text, optional)
- Gothram (BottomSheetSelector)
- Veda Shakha (BottomSheetSelector)
- Nakshatra (BottomSheetSelector)
- Rashi (BottomSheetSelector)

**Step 3 — Education & Career** (`step3_education.dart`)
- Highest Education (BottomSheetSelector)
- Occupation (BottomSheetSelector)
- Annual Income (BottomSheetSelector)

**Step 4 — Family** (`step4_family.dart`)
- Father's Name, Father's Occupation
- Mother's Name, Mother's Occupation
- Native Place

**Step 5 — Lifestyle** (`step5_lifestyle.dart`)
- Food Preference (BottomSheetSelector)
- Smoking Habit (BottomSheetSelector)
- Drinking Habit (BottomSheetSelector)
- About Me (multi-line text, 500 char limit)

**Step 6 — Location** (`step6_location.dart`)
- Country (BottomSheetSelector)
- State (text)
- City (text)

**Step 7 — Review & Submit** (`step7_review.dart`)
- Dynamic completion % bar (calculates filled mandatory fields)
- Color: Green if ≥ 60%, Red if < 60%
- Warning message if profile is incomplete
- Summary table showing Name, Gender, DOB, Location
- "Complete Profile" triggers `ProfileService.saveProfile()`

### 2.7 Shared Widgets Created

**`apple_scale_button.dart`**
- Premium CTA button with scale-down press animation
- Color, text, loading state all configurable

**`apple_text_field.dart`**
- Consistent text field with 8px radius, Burgundy icons, focused Burgundy 1.5px border
- Configurable: hintText, prefixIcon, keyboardType, obscureText, controller

**`bottom_sheet_selector.dart`**
- Premium modal bottom sheet for all dropdown selections
- Shows a list of `LookupOption` items
- Has search box for long lists
- Shows a checkmark on selected item
- Returns the selected `LookupOption` on dismiss

### 2.8 Forgot Password Screen (`forgot_password_screen.dart`)
**V1 Rule: NO magic links. Only OTP.**

Flow:
1. User enters email
2. We call `supabase.auth.signInWithOtp(email: email)` — sends 6-digit OTP code to email
3. Navigates to `/otp-verification` with args `{mode: 'password_reset', email: email}`
4. OTP screen verifies the code
5. On success, navigates to `/reset-password`

### 2.9 Reset Password Screen (`reset_password_screen.dart`)
**V1 Rule: No OTP boxes here — OTP already verified on previous screen.**

Fields:
- New Password (min 8 chars, must have letter + number)
- Confirm New Password
- "Update Password" button → calls `supabase.auth.updateUser(UserAttributes(password: ...))`
- On success → shows green success state → "Sign In" button clears stack and goes to `/login`

---

## 3. Phase 2 — Backend Architecture

### 3.1 Environment Variables
- Installed `flutter_dotenv` package
- Created `.env` file at project root with:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `GOOGLE_WEB_CLIENT_ID`
- Added `.env` to `pubspec.yaml` assets
- Updated `SupabaseService` to load from `.env` instead of `String.fromEnvironment`

### 3.2 Supabase Project
- **Project ID:** `jvjfkufxwjcwsrzmnyry`
- **URL:** `https://jvjfkufxwjcwsrzmnyry.supabase.co`
- RLS is **already enabled** on ALL tables in the database

**Database Tables Found (all RLS-enabled):**
| Table | Rows |
|-------|------|
| `profiles` | 2 |
| `castes` | 32 |
| `gothrams` | 30 |
| `nakshatras` | 27 |
| `rashis` | 12 |
| `veda_shakhas` | 14 |
| `mother_tongues` | 18 |
| `marital_statuses` | 3 |
| `education_levels` | 25 |
| `occupations` | 49 |
| `annual_incomes` | 12 |
| `family_types` | 4 |
| `food_preferences` | 2 |
| `smoking_habits` | 3 |
| `drinking_habits` | 3 |
| `countries` | 13 |
| `indian_states` | 36 |
| `blood_groups` | 8 |
| `hobbies` | 20 |
| `otps` | 1 |
| `otp_rate_limits` | 8 |

### 3.3 Services Created

#### `supabase_service.dart` (updated)
- Loads credentials from `.env` via `flutter_dotenv`
- Exposes `SupabaseService.client` singleton

#### `phone_auth_service.dart` (NEW)
**Production-ready abstraction layer for SMS OTP.**

Architecture:
```
UI → PhoneAuthService → SmsProvider (interface) → Implementation
```

- `SmsProvider` — abstract interface with `sendOtp()` and `verifyOtp()` methods
- `MockSmsProvider` — dev implementation, accepts `"123456"` as valid OTP for any number
- `PhoneAuthService` — orchestrator, enforces `+91` prefix, delegates to provider
- **Migration path:** When SMS provider is purchased, create a new class implementing `SmsProvider` and swap `MockSmsProvider` for it in `PhoneAuthService`. Zero UI changes required.

#### `lookup_service.dart` (NEW)
- Fetches all dropdown/selector data from real Supabase tables
- In-memory cache — data fetched only once per session
- `fetchAllProfileLookups()` — batch fetches all 17 lookup tables in parallel with `Future.wait`
- Methods: `getCastes()`, `getGothrams()`, `getNakshatras()`, `getRashis()`, etc.

#### `profile_service.dart` (NEW)
- `getProfile()` — fetches current user's profile from `profiles` table
- `saveProfile()` — upserts all 7-step form data to `profiles` table; sets `profile_completed: true`
- `updateProfileFields()` — partial update for Edit Profile screen
- `pickAndUploadProfilePhoto()` — picks from gallery, uploads to Supabase `avatars` storage bucket, saves public URL back to `profiles` table
- All writes protected by Supabase RLS

#### `auth_service.dart` (REWRITTEN)
- `signUpWithEmail()` — calls `supabase.auth.signUp()` + immediately upserts empty `profiles` row
- `signInWithPassword()` — calls `supabase.auth.signInWithPassword()` + detects Google-linked accounts and shows specific error message
- `signInWithGoogle()` — full native Google Sign-In using `google_sign_in` package, exchanges `idToken` + `accessToken` with Supabase, upserts `profiles` row pre-filled with Google display name and photo URL (uses `ignoreDuplicates: true` so existing users are not overwritten)
- `signOut()`, `getCurrentProfile()`, `getCurrentProfileWithRetry()`, `upsertProfile()`, `updateProfile()`

#### `google_auth_service.dart` (superseded)
- Original stub using `signInWithOAuth` (web redirect flow) — replaced by native `signInWithGoogle()` in `auth_service.dart`

### 3.4 Native Configuration (Google Sign-In)
- **Android:**
  - Added `google-services.json` to `android/app/`
  - Applied `com.google.gms.google-services` plugin in Gradle scripts
  - Registered SHA-1 fingerprint in Firebase Console
- **iOS:**
  - Added `GoogleService-Info.plist` to `ios/Runner/`
  - Added `REVERSED_CLIENT_ID` to `Info.plist` `CFBundleURLTypes` for OAuth redirect
- **Environment Separation:**
  - **Flutter `.env`:** Public Client IDs (`GOOGLE_WEB_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`) safely stored for the app.
  - **Root `.env`:** Backend secret keys (`RESEND_API_KEY`, `RESEND_AUTH_HOOK_SECRET_KEY`) strictly isolated from the mobile build to prevent security leaks.

---

## 4. Authentication Strategy

### 4.1 Active Auth Methods (V1)
| Method | Status |
|--------|--------|
| Email + Password Sign Up | ✅ Real (Supabase) |
| Email + Password Sign In | ✅ Real (Supabase) |
| Google Sign Up | ✅ Real (native SDK) |
| Google Sign In | ✅ Real (native SDK) |
| Mobile OTP | 🔧 Mocked (accepts `123456`) |
| Forgot Password (Email OTP) | ✅ Real (Supabase email OTP) |

### 4.2 Routing Logic After Auth
After any successful authentication:
1. Query `profiles` table for `profile_completed` flag
2. If `false` (new user) → route to `/profile_builder`
3. If `true` (returning user) → route to `/home`

### 4.3 Google User Tries Email+Password Login
- Supabase returns "Invalid credentials"
- `AuthService` catches this and throws a human-friendly message: *"This email may be linked to a Google account. Please tap 'Continue with Google' to sign in."*
- No crash. No confusion.

### 4.4 Google Client IDs
- **Web Client ID** (`he5m6c...`): Used in `AuthService.signInWithGoogle()` as `serverClientId` for token exchange with Supabase
- **Installed Client ID** (`l3t24r...`): Must be configured in `android/app/google-services.json` for the Android OAuth flow

### 4.5 V1 Rules (Strictly Enforced)
- ❌ No magic links anywhere in the app
- ❌ No Twilio / MSG91 / any paid SMS provider
- ❌ No Firebase Phone Auth
- ✅ All user flows go through 6-digit OTP entry
- ✅ Mobile OTP screen UI is 100% production-ready; only the SMS delivery layer is mocked
- ✅ Password reset via Email OTP (6-digit code to email inbox, user types it manually)

### 4.6 Password Security
- Supabase handles Bcrypt hashing of all passwords server-side
- Passwords are never stored in plain text anywhere
- Even the app owner cannot see user passwords
- HTTPS/TLS encrypts all traffic between app and Supabase

---

## 5. All Files Created / Modified

### Created (New Files)
| File | Purpose |
|------|---------|
| `lib/screens/profile/profile_builder_layout.dart` | Master 7-step container |
| `lib/screens/profile/steps/step1_basic_info.dart` | Step 1 |
| `lib/screens/profile/steps/step2_traditional.dart` | Step 2 |
| `lib/screens/profile/steps/step3_education.dart` | Step 3 |
| `lib/screens/profile/steps/step4_family.dart` | Step 4 |
| `lib/screens/profile/steps/step5_lifestyle.dart` | Step 5 |
| `lib/screens/profile/steps/step6_location.dart` | Step 6 |
| `lib/screens/profile/steps/step7_review.dart` | Step 7 |
| `lib/widgets/apple_scale_button.dart` | Premium CTA button |
| `lib/widgets/apple_text_field.dart` | Luxury text input |
| `lib/widgets/bottom_sheet_selector.dart` | Premium dropdown selector |
| `lib/services/phone_auth_service.dart` | SMS abstraction + MockSmsProvider |
| `lib/services/lookup_service.dart` | Supabase lookup data fetcher |
| `lib/services/profile_service.dart` | Profile CRUD + photo upload |
| `.env` | Environment variables |

### Modified (Existing Files)
| File | What Changed |
|------|-------------|
| `lib/services/supabase_service.dart` | Now loads credentials from `.env` |
| `lib/services/auth_service.dart` | Full rewrite — real Email+Password + Google auth |
| `lib/screens/auth/forgot_password_screen.dart` | Rewritten — OTP-only flow, no magic links |
| `lib/screens/auth/reset_password_screen.dart` | Rewritten — new password + confirm, no OTP boxes |
| `lib/main.dart` | Added `/profile_builder`, `/forgot-password`, `/reset-password` routes |
| `pubspec.yaml` | Added `flutter_dotenv`, `google_sign_in`; added `.env` to assets |

### Packages Added
| Package | Purpose |
|---------|---------|
| `flutter_dotenv` | Secure env variable management |
| `google_sign_in` | Native Google OAuth for Android/iOS |
| `image_picker` | Gallery access for profile photo upload |

---

## 6. Key Decisions & Rules

| Rule | Decision |
|------|----------|
| Input styling | 8px border radius, Burgundy focused border 1.5px |
| Icon colors | All input prefix/suffix icons → Burgundy `#6E1732` |
| OTP in V1 | All user flows → OTP. Zero magic links. Zero deep links. |
| SMS OTP | Mocked with `123456` — no paid provider in dev |
| Architecture | `SmsProvider` interface → swap provider later with zero UI changes |
| Password reset | Email OTP flow (6-digit code in email inbox) |
| Navigation | `pushNamed` (not `pushReplacementNamed`) to preserve back stack |
| Backend phase | Profile Builder UI complete first → then backend wiring |
| Lookup data | Hardcoded in UI for now → will replace with `LookupService` real fetch |
| Recommendation engine | Cold start: baseline demographic matching → seed swipe batch → collaborative filtering |
| Google user + email login | Friendly error message, no crash |

---

## 7. What Remains to Be Done

### Phase 3: Core App Experience (Next Steps)
- [ ] **Home / Feed Screen**: Build the main feed UI where users see their recommended matches. Needs a Tinder/Bumble style stack or a grid view.
- [ ] **Edit Profile Screen**: A screen for users to view and update their profile details (re-using the `ProfileBuilderLayout` or a new scrollable form).
- [ ] **Matches / Connections Screen**: A screen to show mutual interests and accepted matches.
- [ ] **Settings Screen**: Logout, account deletion, and notification preferences.
- [ ] **Database Triggers (Optional)**: Automatically call the `send-email` edge function when a new user joins.
- [ ] **Supabase Storage**: Ensure the `avatars` bucket is configured publicly so profile photos load.

### Phase 4: Matchmaking & Analytics
- [ ] **Recommendation Engine**: Implement collaborative filtering and strict preference matching (e.g., must match caste/gothram preferences).
- [ ] **Analytics**: Implement the `monthly_summary` and `match_digest` background jobs to trigger Resend emails.
