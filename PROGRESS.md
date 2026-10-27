# 📋 Mangalasutram — Live Progress & Verification Tracker

> **Last Updated:** 2026-09-27  
> **Overall Completion:** **93%** (Core Mobile + Supabase Backend — Phase 1 Complete)  
> **Master 20-Day Sprint Plan:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)

---

## LEGEND
- ✅ **Complete** — Built, wired to live Supabase, and verified
- 🛡️ **Pending Security / QA Sign-Off** — Scheduled in Days 5–13
- ❌ **Not Started** — Scheduled in Days 14–18 (Admin Panel)

---

## 1. BACKEND & SUPABASE INFRASTRUCTURE

| Module / RPC | Status | Date | Verification Notes |
| :--- | :---: | :---: | :--- |
| Supabase Auth (Email + Google OAuth) | ✅ | Aug 20 | Working with `FlutterSecureStorage` AES-256 |
| Edge Function OTP (`send-otp` / `verify-otp`) | ✅ | Sep 21 | Verified live; `consented_at` crash resolved |
| Profiles Table & Public View RLS (`public_profiles`) | ✅ | Sep 27 | Exposes all 55+ public Biodata fields while masking `phone`/`email`; `pada` & `pada_id` auto-synced |
| Partner Preferences Table | ✅ | Sep 27 | All 19 criteria columns wired & verified live under `ROLE authenticated` |
| Canonical Vedic Guna Milan Engine | ✅ | Sep 27 | 6-arg `calculate_guna_milan_points` with `pada_id` (0–36 Ashta-Koota) |
| Reciprocal Compatibility Engine | ✅ | Sep 27 | Evaluates all Partner Preferences criteria + 6-arg Guna Milan; verified across 160+ profiles |
| Match Cache Refresh (`refresh_user_match_cache`) | ✅ | Sep 27 | Caches full biodata JSONB + 6-arg Guna Milan across 58 candidates |
| Top Matches RPC (`get_top_matches_v2`) | ✅ | Sep 27 | Enforces plan ceiling & permits authorized Family Guardians |
| Discovery Cohorts & Search (`get_discovery_cohorts`, `search_discovery_profiles`) | ✅ | Sep 27 | Supports `p_on_behalf_of` Guardian proxy & filters out `is_hidden = true` |
| Family Circle & Invite Code System | ✅ | Sep 27 | `family_circles`, `family_members`, `family_profile_reviews` verified under non-superuser RLS |
| Family Group Chat (`family_messages`) | ✅ | Sep 27 | Real-time family deliberation table & non-recursive RLS |
| Unified Proxy Chat (`send_proxy_message`) | ✅ | Sep 27 | Enforces `allow_guardian_proxy_chat` Candidate Veto |
| E2EE Messaging & Delivery Ticks | ✅ | Sep 22 | Deterministic room key for multi-device family reading |
| Profile Photos Table & Storage RLS | ✅ | Sep 22 | `public.profile_photos` + 5MB limit bucket policies |
| Safety Moderation & Account Erasure RPCs | ✅ | Sep 14 | Block, Report, and cascading account deletion |
| Sidebar Summary RPC (`get_sidebar_summary`) | ✅ | Sep 26 | Returns Matrimony ID (`MS-XXXX`), invite code, counts, quota |
| Profile Visibility RPC (`toggle_profile_visibility`) | ✅ | Sep 26 | Toggles `profiles.is_hidden` (Incognito mode) |
| Guardian Veto RPC (`toggle_guardian_proxy_chat`) | ✅ | Sep 26 | Toggles `profiles.allow_guardian_proxy_chat` live |
| Dynamic Success Stories (`public.success_stories`) | ✅ | Sep 26 | Live RLS table replacing static mock stories |

---

## 2. FLUTTER MOBILE APP (CANDIDATE & GUARDIAN)

| Feature Area | Status | Date | Notes |
| :--- | :---: | :---: | :--- |
| **Auth & 8-Step Vedic Onboarding** | ✅ | Sep 02 | Playfair/Inter luxury theme, cached lookups, multi-photo upload |
| **Guardian Restricted Navigation** | ✅ | Sep 22 | Dynamically locks Guardians to 3 tabs (`Matches`, `Discover`, `Chats`) |
| **Guardian Proxy Mode (`onBehalfOf`)** | ✅ | Sep 27 | End-to-end verified across Home, Matches, Discover, Interests & Chat |
| **Vedic Luxury Chat UI** | ✅ | Sep 22 | Bubble tails, Transparency Notice banner, *"Sent by Father"* gold badge |
| **Matches Swipe Feed & Sort Chips** | ✅ | Sep 23 | Regular/Prime toggle + 6 sort chips + pull-to-refresh |
| **Interests & Shortlists Tab** | ✅ | Sep 16 | Received, Sent, Shortlisted, Horoscope Requests |
| **5-Card Luxury Sidebar (`home_screen.dart`)** | ✅ | Sep 26 | Matrimony ID copy, Public Profile Preview, Gold Quota Strip, 5 clean cards |
| **Apple HIG Inner Screens (`Biodata`, `Prefs`, `Saved`)** | ✅ | Sep 27 | All 7 Biodata Edit sections + Partner Preferences with 100% field parity & auto cache refresh |
| **Static Data Removal (`_SuccessStoriesCarousel`)** | ✅ | Sep 26 | Wired `home_tab.dart` to live `public.success_stories` rows |
| **Settings: Change Password, Hide Profile & Veto** | ✅ | Sep 26 | Live `CupertinoSwitch` toggles + `_ChangePasswordSheet` |
| **Legal & Support Pages (T&C, Privacy, Help)** | ✅ | Sep 26 | Full store-compliant `_LegalDocumentSheet` & `_HelpSupportSheet` |

---

## 3. FULL LIFECYCLE QA & CYBER SECURITY TESTING (DAYS 5–13)

| Test Suite | Status | Target | Scope |
| :--- | :---: | :---: | :--- |
| End-to-End Candidate & Guardian Lifecycle | 🛡️ | Days 5–9 | Auth ➔ Onboarding ➔ Match ➔ Interest ➔ Chat ➔ Logout/Erase |
| IDOR & Cross-User RLS Penetration Test | 🛡️ | Day 10 | Verify zero unauthorized read/write across UUIDs |
| OTP Brute-Force & JWT Tampering Audit | 🛡️ | Day 11 | Verify rate limits and token signature enforcement |
| SQL Injection & RPC Payload Fuzzing | 🛡️ | Day 12 | Fuzz all RPC inputs and verify phone/email masking |
| Storage Bucket & E2EE Ciphertext Audit | 🛡️ | Day 13 | Verify 5MB image-only guard and raw DB encryption |

---

## 4. ADMIN DASHBOARD (DAYS 14–18)

| Admin Module | Status | Target | Scope |
| :--- | :---: | :---: | :--- |
| Admin RBAC & Secure Login | ❌ | Day 14 | `admin_users` RLS guard |
| Profile & Photo Verification Queue | ❌ | Day 15 | Approve/Reject candidate profiles & photos |
| Trust & Safety Moderation Desk | ❌ | Day 16 | Review user reports, block logs, ban/suspend accounts |
| Subscriptions & KPI Analytics | ❌ | Day 17 | Active users, Prime conversions, manual tier overrides |
| Admin Security Penetration Test | ❌ | Day 18 | Verify zero non-admin privilege escalation |

---

## 5. RECENT SESSION LOG

| Date | Milestone Completed |
| :--- | :--- |
| **Sep 21** | Built Family Group Chat & Unified Proxy Chat migrations; fixed OTP signup `consented_at` bug. |
| **Sep 22** | Completed pixel-perfect Chat UI (tails, gold proxy badges, transparency notice); added Candidate Veto RPC; restricted Guardian bottom navigation to 3 tabs. |
| **Sep 23** | Audited and fixed 3 critical matching engine bugs live in Supabase (`p_user_pref.profile_id`, `me.excluded_id`, and Guardian `Access denied` in `get_top_matches_v2`). Verified 58 cached matches and 10 daily recommendations live. |
| **Sep 26** | **Days 1, 2 & 3 Complete**: Deployed `20260926000001_sidebar_summary_and_dynamic_stories.sql` live via Supabase MCP (`get_sidebar_summary`, `toggle_profile_visibility`, `toggle_guardian_proxy_chat`, `public.success_stories`). Rebuilt 5-Card Luxury Sidebar and refined all inner screens (`My Biodata`, `Partner Preferences`, `Saved & Visited`, `Settings & Privacy`, `apple_settings_form.dart`) to Apple HIG standards (`flutter analyze` = 0 issues). |
| **Sep 27** | **Day 4 Complete (Phase 1 100% Done)**: Hardened Guardian RLS & Discovery proxy RPCs (`20260927000002_guardian_rls_and_discovery_audit.sql`). Deployed `20260927000003_biodata_public_view_and_matching_sync.sql` (`public_profiles` 55+ column projection, `trg_sync_profile_pada`, full-criteria `calculate_reciprocal_compatibility`, and 6-arg Guna Milan `refresh_user_match_cache`). Upgraded all 7 Biodata Edit screens + `PartnerPreferencesScreen` + `ProfileService` with instant cached lookups, `FocusScope` unfocusing, and automatic match cache invalidation. Verified live under `SET LOCAL ROLE authenticated` across 58 cached candidates (`flutter analyze` = 0 issues). |
