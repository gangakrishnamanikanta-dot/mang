---
name: flutter-migration
description: React Native → Flutter migration status, project location, architecture, completed work, and remaining fixes
metadata:
  type: project
---

## Flutter Migration — Mangalasutram App

### Project Location
```
Flutter project: c:\Users\Neerajara\Desktop\mangalasutram final app\mangalasutram_flutter\
React Native (old): c:\Users\Neerajara\Desktop\mangalasutram final app\ (root — DO NOT use)
```

### Architecture
```
lib/
  main.dart                   — App entry, MaterialApp, routes, Provider
  constants/theme.dart        — AppColors, AppSpacing, AppTypography, AppBorderRadius, AppShadows
  providers/auth_provider.dart — ChangeNotifier for auth state
  services/auth_service.dart  — Supabase auth methods
  services/google_auth_service.dart — Google Sign-In
  services/supabase_service.dart — Supabase initialization
  widgets/
    app_button.dart           — AppButton widget (title, onPressed, loading, disabled)
    app_input.dart            — AppInput widget (label, controller, keyboardType, etc.)
    safe_area_view.dart       — SafeAreaView wrapper (SafeArea + SingleChildScrollView)
  screens/
    auth/
      splash_screen.dart      — Checks auth state → /login or /home
      login_screen.dart       — Email login + Mobile OTP login + Google
      signup_screen.dart      — Register with email+phone+password → OTP
      otp_verification_screen.dart — Verify email OTP during signup
      forgot_password_screen.dart — Send reset OTP
      reset_password_screen.dart — Enter OTP + new password
    main/
      home_screen.dart        — Dashboard with sidebar + match cards
    profile/
      profile_builder_screen.dart — 7-step profile builder
      edit_profile_screen.dart    — Edit existing profile
```

### Routing (in main.dart)
```
/splash → SplashScreen
/login → LoginScreen
/signup → SignUpScreen
/otp-verification → OTPVerificationScreen (args: {email, phone, password})
/forgot-password → ForgotPasswordScreen
/reset-password → ResetPasswordScreen (args: {email})
/profile-builder → ProfileBuilderScreen
/edit-profile → EditProfileScreen
/home → HomeScreen
```

### Theme Constants
- `AppColors.primary` = Color(0xFF8E1639) — deep maroon/crimson
- `AppColors.secondary` = Color(0xFFC99A4B) — gold
- `AppColors.background` = white
- `AppColors.surface` = Color(0xFFF8F8F8)
- `AppColors.textPrimary` = Color(0xFF2D2D2D)
- `AppColors.textSecondary` = Color(0xFF9E9E9E)
- `AppShadows.sm/md/lg` are `List<BoxShadow>` — use directly as `boxShadow: AppShadows.md`
- `AppTypography.heading/subheading/title/body/caption/small` — TextStyle constants

### Completed Work (Previous Session)
1. ✅ theme.dart — AppColors, AppSpacing, AppTypography, AppBorderRadius, AppShadows all defined
2. ✅ AppShadows changed to List<BoxShadow> (NOT wrapped in `[...]` when assigning to boxShadow)
3. ✅ widgets/app_button.dart — AppButton widget created
4. ✅ widgets/app_input.dart — AppInput widget created
5. ✅ widgets/safe_area_view.dart — SafeAreaView wrapper created
6. ✅ services/auth_service.dart — All auth methods implemented
7. ✅ services/google_auth_service.dart — Google Sign-In
8. ✅ services/supabase_service.dart — Supabase init
9. ✅ All screen files created with correct UI logic
10. ✅ main.dart with routing, Provider, MaterialApp

### Remaining Flutter Analyze Errors (As of 2026-08-01)
See flutter_fix_prompt.md artifact for the complete fix instructions.

Summary of remaining fixes:
- splash_screen.dart: Wrong import paths (`../` should be `../../`), unused auth_provider import
- login_screen.dart: Unused auth_provider import, missing widget imports, unused variable `isMobileVerify`, null-aware operator, `onKey` → `onKeyEvent`, for-loop braces
- otp_verification_screen.dart: `textAlign` in copyWith (wrong), `onKey` → `onKeyEvent`
- reset_password_screen.dart: `textAlign` in copyWith (wrong), `onKey` → `onKeyEvent`
- signup_screen.dart: Unused imports (services.dart, auth_provider.dart), missing widget imports
- home_screen.dart: Missing SafeAreaView import, `_buildMenuItem` signature mismatch with `_handleLogout`, boxShadow wrapping, possible syntax error
- forgot_password_screen.dart: `_error` field set but never displayed in UI
- main.dart: `background` deprecated in ColorScheme

### Key Dart Facts for This Project
- `onKeyEvent:` (NOT `onKey:`) is the correct TextField parameter in this Flutter version
- `textAlign` is a `Text` widget property, NOT a `TextStyle` property — never put it in `.copyWith()`
- `AppShadows.md` IS already `List<BoxShadow>` — use `boxShadow: AppShadows.md` NOT `boxShadow: [AppShadows.md]`
- Import paths from `screens/auth/` to `widgets/` = `../../widgets/xxx.dart`
- Import paths from `screens/auth/` to `constants/` = `../../constants/theme.dart`
- `withOpacity()` is deprecated → use `.withValues(alpha: 0.xx)`
