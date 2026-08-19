import os

base = "c:/Users/Neerajara/Desktop/mangalasutram final app/mangalasutram_flutter/lib"

def fix_file(relpath, replacements):
    """Apply exact string replacements to a file."""
    fpath = os.path.join(base, relpath)
    if not os.path.exists(fpath):
        return f"MISSING: {relpath}"
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
    original = content
    for old, new in replacements:
        if old in content:
            content = content.replace(old, new)
        else:
            return f"NOT FOUND: '{old[:50]}' in {relpath}"
    if content != original:
        with open(fpath, 'w', encoding='utf-8') as f:
            f.write(content)
        return "FIXED"
    return "OK"

# Fix main.dart
r = fix_file("main.dart", [
    ("import 'core/supabase_service.dart';",
     "import 'features/auth/services/supabase_service.dart';"),
])
print(f"main.dart: {r}")

# Fix features/auth/services/auth_service.dart
r = fix_file("features/auth/services/auth_service.dart", [
    ("import '../../config/env.dart';", "import '../../../config/env.dart';"),
    ("import '../../models/profile.dart';", "import '../../../models/profile.dart';"),
    ("import '../../features/auth/interfaces/i_auth_service.dart';",
     "import '../../../features/auth/interfaces/i_auth_service.dart';"),
])
print(f"auth_service.dart: {r}")

# Fix features/auth/services/phone_auth_service.dart
r = fix_file("features/auth/services/phone_auth_service.dart", [
    ("import '../../features/auth/interfaces/i_phone_auth_service.dart';",
     "import '../../../features/auth/interfaces/i_phone_auth_service.dart';"),
])
print(f"phone_auth_service.dart: {r}")

# Fix features/auth/services/supabase_service.dart
r = fix_file("features/auth/services/supabase_service.dart", [
    ("import '../../config/env.dart';", "import '../../../config/env.dart';"),
])
print(f"supabase_service.dart: {r}")

# Fix features/auth/providers/auth_provider.dart
r = fix_file("features/auth/providers/auth_provider.dart", [
    ("import '../../features/auth/interfaces/i_auth_service.dart';",
     "import '../../features/auth/interfaces/i_auth_service.dart';"),
])
print(f"auth_provider.dart: {r}")

# Fix features/auth/interfaces/i_auth_service.dart
r = fix_file("features/auth/interfaces/i_auth_service.dart", [
    ("import '../../models/profile.dart';", "import '../../../models/profile.dart';"),
])
print(f"i_auth_service.dart: {r}")

# Fix auth screens
for screen in ['login_screen.dart', 'signup_screen.dart', 'otp_verification_screen.dart',
               'forgot_password_screen.dart', 'reset_password_screen.dart', 'splash_screen.dart']:
    replacements = []
    # Read file to see current imports
    fpath = os.path.join(base, f"features/auth/screens/{screen}")
    with open(fpath, 'r') as f:
        content = f.read()

    # Fix di imports
    if "import '../../core/di.dart';" in content:
        replacements.append(("import '../../core/di.dart';", "import '../../../core/di.dart';"))
    if "import '../../features/auth/interfaces/i_auth_service.dart';" in content:
        replacements.append(("import '../../features/auth/interfaces/i_auth_service.dart';",
                            "import '../../../features/auth/interfaces/i_auth_service.dart';"))
    if "import '../../features/auth/interfaces/i_phone_auth_service.dart';" in content:
        replacements.append(("import '../../features/auth/interfaces/i_phone_auth_service.dart';",
                            "import '../../../features/auth/interfaces/i_phone_auth_service.dart';"))
    if "import '../../../../shared/widgets/apple_scale_button.dart';" in content:
        replacements.append(("import '../../../../shared/widgets/apple_scale_button.dart';",
                            "import '../../../shared/widgets/apple_scale_button.dart';"))
    if "import '../../../features/shared/widgets/apple_scale_button.dart';" in content:
        replacements.append(("import '../../../features/shared/widgets/apple_scale_button.dart';",
                            "import '../../../shared/widgets/apple_scale_button.dart';"))
    if "import '../../constants/theme.dart';" in content and 'splash' in screen:
        replacements.append(("import '../../constants/theme.dart';", "import '../../../constants/theme.dart';"))

    if replacements:
        r = fix_file(f"features/auth/screens/{screen}", replacements)
    else:
        r = "OK (no changes needed)"
    print(f"{screen}: {r}")

# Fix home screens
r = fix_file("features/home/screens/home_screen.dart", [
    ("import '../core/di.dart';", "import '../../core/di.dart';"),
    ("import '../features/auth/providers/auth_provider.dart';",
     "import '../../features/auth/providers/auth_provider.dart';"),
    ("import '../features/auth/interfaces/i_auth_service.dart';",
     "import '../../features/auth/interfaces/i_auth_service.dart';"),
    ("import '../constants/theme.dart';", "import '../../constants/theme.dart';"),
    ("import 'views/home_tab.dart';", "import '../views/home_tab.dart';"),
    ("import '../features/home/views/home_tab.dart';",
     "import '../../features/home/views/home_tab.dart';"),
    ("import '../features/discovery/screens/discover_tab.dart';",
     "import '../../features/discovery/screens/discover_tab.dart';"),
    ("import '../features/messaging/screens/chat_tab.dart';",
     "import '../../features/messaging/screens/chat_tab.dart';"),
    ("import 'views/profile_view.dart';", "import '../views/profile_view.dart';"),
])
print(f"home_screen.dart: {r}")

# Fix home views
r = fix_file("features/home/views/home_tab.dart", [
    ("import '../../../../features/matching/services/profile_match_service.dart';",
     "import '../../matching/services/profile_match_service.dart';"),
    ("import '../../../../models/profile.dart';",
     "import '../../models/profile.dart';"),
    ("import '../../../../features/auth/services/supabase_service.dart';",
     "import '../../features/auth/services/supabase_service.dart';"),
    ("import '../../../../constants/theme.dart';",
     "import '../../constants/theme.dart';"),
    ("import '../../../shared/widgets/verified_badge.dart';",
     "import '../../shared/widgets/verified_badge.dart';"),
    ("import '../../../features/matching/widgets/match_badge.dart';",
     "import '../../matching/widgets/match_badge.dart';"),
])
print(f"home_tab.dart: {r}")

r = fix_file("features/home/views/profile_view.dart", [
    ("import '../../../features/auth/providers/auth_provider.dart';",
     "import '../../features/auth/providers/auth_provider.dart';"),
])
print(f"profile_view.dart: {r}")

# Fix matching files
r = fix_file("features/matching/screens/match_feed_view.dart", [
    ("import '../../../providers/match_provider.dart';",
     "import '../../features/matching/providers/match_provider.dart';"),
    ("import '../../../features/profile/widgets/profile_card.dart';",
     "import '../../features/profile/widgets/profile_card.dart';"),
    ("import '../../../features/matching/widgets/match_action_buttons.dart';",
     "import '../../features/matching/widgets/match_action_buttons.dart';"),
])
print(f"match_feed_view.dart: {r}")

r = fix_file("features/matching/services/lookup_service.dart", [
    ("import '../../models/profile.dart';", "import '../../../models/profile.dart';"),
    ("import '../../features/auth/services/supabase_service.dart';",
     "import '../../../features/auth/services/supabase_service.dart';"),
])
print(f"lookup_service.dart: {r}")

r = fix_file("features/matching/services/profile_match_service.dart", [
    ("import '../../models/profile.dart';", "import '../../../models/profile.dart';"),
    ("import '../../features/auth/services/supabase_service.dart';",
     "import '../../../features/auth/services/supabase_service.dart';"),
])
print(f"profile_match_service.dart: {r}")

r = fix_file("features/matching/providers/match_provider.dart", [
    ("import '../../models/profile.dart';", "import '../../../models/profile.dart';"),
])
print(f"match_provider.dart: {r}")

# Fix profile files
r = fix_file("features/profile/screens/edit_profile_screen.dart", [
    ("import '../../core/di.dart';", "import '../../../../core/di.dart';"),
    ("import '../../models/profile.dart';", "import '../../../../models/profile.dart';"),
    ("import '../../features/auth/interfaces/i_auth_service.dart';",
     "import '../../../../features/auth/interfaces/i_auth_service.dart';"),
    ("import '../../features/matching/services/lookup_service.dart';",
     "import '../../../../features/matching/services/lookup_service.dart';"),
    ("import '../../features/profile/services/profile_service.dart';",
     "import '../../../../features/profile/services/profile_service.dart';"),
    ("import '../../../../shared/widgets/apple_text_field.dart';",
     "import '../../../shared/widgets/apple_text_field.dart';"),
    ("import '../../../../shared/widgets/bottom_sheet_selector.dart';",
     "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
])
print(f"edit_profile_screen.dart: {r}")

r = fix_file("features/profile/services/profile_service.dart", [
    ("import '../../models/profile.dart';", "import '../../../models/profile.dart';"),
    ("import '../../features/auth/services/supabase_service.dart';",
     "import '../../../features/auth/services/supabase_service.dart';"),
])
print(f"profile_service.dart: {r}")

r = fix_file("features/profile/widgets/profile_card.dart", [
    ("import '../../models/profile.dart';", "import '../../../models/profile.dart';"),
])
print(f"profile_card.dart: {r}")

# Fix onboarding files
r = fix_file("features/onboarding/screens/profile_builder_layout.dart", [
    ("import '../../features/auth/providers/auth_provider.dart';",
     "import '../../../features/auth/providers/auth_provider.dart';"),
    ("import '../../core/di.dart';", "import '../../../core/di.dart';"),
    ("import '../../models/profile.dart';", "import '../../../models/profile.dart';"),
    ("import '../../features/auth/interfaces/i_auth_service.dart';",
     "import '../../../features/auth/interfaces/i_auth_service.dart';"),
    ("import '../../features/profile/services/profile_service.dart';",
     "import '../../../features/profile/services/profile_service.dart';"),
    ("import '../../features/matching/services/lookup_service.dart';",
     "import '../../../features/matching/services/lookup_service.dart';"),
    ("import '../../core/supabase_service.dart';",
     "import '../../../features/auth/services/supabase_service.dart';"),
    ("import '../../../../shared/widgets/apple_scale_button.dart';",
     "import '../../../shared/widgets/apple_scale_button.dart';"),
    # Fix step imports - these are in screens/ so steps/ is correct relative path
    ("import 'steps/step1_basic_info.dart';", "import 'steps/step1_basic_info.dart';"),
    ("import 'steps/step2_traditional.dart';", "import 'steps/step2_traditional.dart';"),
    ("import 'steps/step3_education.dart';", "import 'steps/step3_education.dart';"),
    ("import 'steps/step4_family.dart';", "import 'steps/step4_family.dart';"),
    ("import 'steps/step5_lifestyle.dart';", "import 'steps/step5_lifestyle.dart';"),
    ("import 'steps/step6_location.dart';", "import 'steps/step6_location.dart';"),
    ("import 'steps/step7_review.dart';", "import 'steps/step7_review.dart';"),
])
print(f"profile_builder_layout.dart: {r}")

# Fix onboarding steps
for i in range(1, 8):
    step = f"step{i}_" + ["basic_info", "traditional", "education", "family", "lifestyle", "location", "review"][i-1] + ".dart"
    replacements = []
    fpath = os.path.join(base, f"features/onboarding/steps/{step}")
    with open(fpath, 'r') as f:
        content = f.read()

    if "import '../../../../shared/widgets/apple_text_field.dart';" in content:
        replacements.append(("import '../../../../shared/widgets/apple_text_field.dart';",
                            "import '../../../shared/widgets/apple_text_field.dart';"))
    if "import '../../../../shared/widgets/bottom_sheet_selector.dart';" in content:
        replacements.append(("import '../../../../shared/widgets/bottom_sheet_selector.dart';",
                            "import '../../../shared/widgets/bottom_sheet_selector.dart';"))
    if "import '../../../../models/profile.dart';" in content:
        replacements.append(("import '../../../../models/profile.dart';",
                            "import '../../../models/profile.dart';"))
    if "import '../../../../features/profile/services/profile_service.dart';" in content:
        replacements.append(("import '../../../../features/profile/services/profile_service.dart';",
                            "import '../../../features/profile/services/profile_service.dart';"))

    if replacements:
        r = fix_file(f"features/onboarding/steps/{step}", replacements)
    else:
        r = "OK"
    print(f"{step}: {r}")

print("\nDONE")
