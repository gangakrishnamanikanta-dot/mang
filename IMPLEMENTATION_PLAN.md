# Mangalasutram — Implementation Roadmap

> **Started:** 2026-08-02
> **Status:** Phase 1 — In Progress
> **Branch:** (no git repo yet)

---

## Current State

- Flutter app with Supabase backend
- 3 auth screens (Login, Signup, OTP) — UI needs rebuild per reference images
- Auth flows are mocked (Future.delayed) — real APIs exist in AuthService but not wired
- Duplicate `_AppleScaleButton` widget across 3 screens
- Local color constants in auth screens instead of shared theme
- `countryId` field missing from Profile model but referenced in EditProfileScreen
- HomeScreen, ProfileBuilderScreen exist but are commented out in main.dart routes

---

## Phase 1 — Rebuild Auth Screens UI (Current Phase)

### Phase 1a — Login Screen
- [x] Understand existing login_screen.dart
- [ ] Rebuild widget tree to match reference image
- [ ] Keep all controllers, validation, navigation, AuthService calls, callbacks, providers, API logic EXACTLY as-is
- [ ] Only replace widget tree and styling
- [ ] Ensure responsiveness

### Phase 1b — Signup Screen
- [ ] Rebuild widget tree to match reference image
- [ ] Keep all controllers, validation, navigation, AuthService calls, callbacks, providers, API logic EXACTLY as-is
- [ ] Only replace widget tree and styling
- [ ] Ensure responsiveness

### Phase 1c — OTP Screen
- [ ] Rebuild widget tree to match reference image
- [ ] Keep all controllers, validation, navigation, AuthService calls, callbacks, providers, API logic EXACTLY as-is
- [ ] Only replace widget tree and styling
- [ ] Ensure responsiveness

---

## Phase 2 — Pixel-Perfect Verification

- [ ] Compare every screen against reference images
- [ ] Verify padding, spacing, typography, shadows, button radius, icon sizes, safe areas, responsiveness
- [ ] Fix any discrepancies
- [ ] Re-verify until perfect

---

## Phase 3 — Extract Duplicated Widgets

- [ ] Create `widgets/apple_scale_button.dart`
- [ ] Replace all 3 copies of `_AppleScaleButton` with shared widget
- [ ] Create other shared auth widgets (segmented toggle, OTP input, headers) if applicable
- [ ] Verify no regressions

---

## Phase 4 — Wire Real APIs

- [ ] Replace `Future.delayed(...)` in LoginScreen with `AuthService.signInWithPassword()` or `AuthService.signInWithOtp()`
- [ ] Replace `Future.delayed(...)` in SignupScreen with `AuthService.signUpWithEmail()`
- [ ] Replace `Future.delayed(...)` in OTPVerificationScreen with `AuthService.verifyOtp()`
- [ ] Wire Google Sign-In properly
- [ ] Wire Forgot Password flow
- [ ] Wire Reset Password flow
- [ ] Do NOT rewrite AuthService — only connect existing methods

---

## Phase 5 — Fix Compile/Runtime Issues

- [ ] Add `countryId` field to Profile model
- [ ] Run `flutter analyze` and fix all errors/warnings
- [ ] Fix any other issues found during audit

---

## Phase 6 — Full Code Audit (Pre-Refactor)

### Before modifying anything, produce a complete audit report:

**Areas to inspect:**
- [ ] Duplicated widgets
- [ ] Duplicated colors
- [ ] Duplicated spacing
- [ ] Hardcoded values
- [ ] Hardcoded dimensions
- [ ] Dead code
- [ ] Unused imports
- [ ] Unnecessary rebuilds
- [ ] RenderFlex risks
- [ ] Overflow risks
- [ ] Missing const constructors
- [ ] Performance improvements
- [ ] Theme inconsistencies
- [ ] Architecture violations

**Deliverable:** Audit report file with findings, severity, and recommended fixes.

---

## Phase 7 — Refactor Auth Screens to Use Shared Theme

- [ ] Replace local color constants in auth screens with `AppColors`
- [ ] Replace local spacing with `AppSpacing`
- [ ] Replace hardcoded font sizes with `AppTypography`
- [ ] Ensure all auth screens use the unified theme system
- [ ] Verify no visual regressions

---

## Phase 8 — Profile Builder & Home Screens

- [ ] Uncomment and fix ProfileBuilderScreen routes
- [ ] Uncomment and fix HomeScreen routes
- [ ] Ensure ProfileBuilderScreen navigates to HomeScreen on completion
- [ ] Ensure HomeScreen sidebar routes work
- [ ] Test full auth → profile → home flow

---

## ⚠️ Reference Images Needed

**Status:** Not yet received from user.
**Action required:** User needs to share reference images for Login, Signup, and OTP screens.
**Blocking:** Phase 1a (Login Screen UI rebuild) cannot start until reference images are provided.

---

## Rollback Strategy

Every phase is isolated. If something breaks:

1. **Phase 1 issues** → Revert only the affected screen file(s)
2. **Phase 2 issues** → Revert styling changes in affected screen(s)
3. **Phase 3 issues** → Revert widget extraction, keep inline copies
4. **Phase 4 issues** → Revert API wiring, restore mock delays
5. **Phase 5 issues** → Fix individually, no rollback needed (bug fixes)
6. **Phase 6 issues** → No code changes, just a report
7. **Phase 7 issues** → Revert theme migration, restore local constants
8. **Phase 8 issues** → Revert screen uncommenting

**Rule:** Never modify more than one phase at a time. Complete and verify each phase before starting the next.

---

## Files Modified Tracking

| Phase | File | Change Type | Date |
|-------|------|-------------|------|
| — | — | — | — |

---

## Decisions Log

| Date | Decision | Reason |
|------|----------|--------|
| 2026-08-02 | Follow phased approach: UI → Verify → Extract → Wire → Fix → Audit → Refactor | Minimize risk, catch issues early |
