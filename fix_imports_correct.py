import os

base = "c:/Users/Neerajara/Desktop/mangalasutram final app/mangalasutram_flutter/lib"

# Each file's imports - CORRECT versions based on actual directory depth
fixes = [
    # main.dart (in lib/)
    ("main.dart",
     "import 'core/supabase_service.dart';",
     "import 'features/auth/services/supabase_service.dart';"),

    # features/auth/services/ (3 deep: lib/features/auth/services/)
    ("features/auth/services/auth_service.dart",
     "import '../../config/env.dart';",
     "import '../../../config/env.dart';"),
    ("features/auth/services/auth_service.dart",
     "import '../../models/profile.dart';",
     "import '../../../models/profile.dart';"),
    ("features/auth/services/auth_service.dart",
     "import '../../features/auth/interfaces/i_auth_service.dart';",
     "import '../../../features/auth/interfaces/i_auth_service.dart';"),

    ("features/auth/services/phone_auth_service.dart",
     "import '../../features/auth/interfaces/i_phone_auth_service.dart';",
     "import '../../../features/auth/interfaces/i_phone_auth_service.dart';"),

    ("features/auth/services/supabase_service.dart",
     "import '../../config/env.dart';",
     "import '../../../config/env.dart';"),

    # features/auth/providers/ (3 deep)
    ("features/auth/providers/auth_provider.dart",
     "import '../../features/auth/interfaces/i_auth_service.dart';",
     "import '../../features/auth/interfaces/i_auth_service.dart';"),

    # features/auth/interfaces/ (3 deep)
    ("features/auth/interfaces/i_auth_service.dart",
     "import '../../models/profile.dart';",
     "import '../../../models/profile.dart';"),

    # features/auth/screens/ (4 deep)
    ("features/auth/screens/login_screen.dart",
     "import '../../core/di.dart';",
     "import '../../../core/di.dart';"),
    ("features/auth/screens/login_screen.dart",
     "import '../../features/auth/interfaces/i_auth_service.dart';",
     "import '../../../features/auth/interfaces/i_auth_service.dart';"),
    ("features/auth/screens/login_screen.dart",
     "import '../../features/auth/interfaces/i_phone_auth_service.dart';",
     "import '../../../features/auth/interfaces/i_phone_auth_service.dart';"),
    ("features/auth/screens/login_screen.dart",
     "import '../../../features/shared/widgets/apple_scale_button.dart';",
     "import '../../../shared/widgets/apple_scale_button.dart';"),

    ("features/auth/screens/signup_screen.dart",
     "import '../../core/di.dart';",
     "import '../../../core/di.dart';"),
    ("features/auth/screens/signup_screen.dart",
     "import '../../features/auth/interfaces/i_auth_service.dart';",
     "import '../../../features/auth/interfaces/i_auth_service.dart';"),
    ("features/auth/screens/signup_screen.dart",
     "import '../../../../shared/widgets/apple_scale_button.dart';",
     "import '../../../shared/widgets/apple_scale_button.dart';"),

    ("features/auth/screens/otp_verification_screen.dart",
     "import '../../core/di.dart';",
     "import '../../../core/di.dart';"),
    ("features/auth/screens/otp_verification_screen.dart",
     "import '../../features/auth/interfaces/i_auth_service.dart';",
     "import '../../../features/auth/interfaces/i_auth_service.dart';"),
    ("features/auth/screens/otp_verification_screen.dart",
     "import '../../features/auth/interfaces/i_phone_auth_service.dart';",
     "import '../../../features/auth/interfaces/i_phone_auth_service.dart';"),
    ("features/auth/screens/otp_verification_screen.dart",
     "import '../../../../shared/widgets/apple_scale_button.dart';",
     "import '../../../shared/widgets/apple_scale_button.dart';"),

    ("features/auth/screens/forgot_password_screen.dart",
     "import '../../core/di.dart';",
     "import '../../../core/di.dart';"),
    ("features/auth/screens/forgot_password_screen.dart",
     "import '../../features/auth/interfaces/i_auth_service.dart';",
     "import '../../../features/auth/interfaces/i_auth_service.dart';"),

    ("features/auth/screens/reset_password_screen.dart",
     "import '../../core/di.dart';",
     "import '../../../core/di.dart';"),
    ("features/auth/screens/reset_password_screen.dart",
     "import '../../features/auth/interfaces/i_auth_service.dart';",
     "import '../../../features/auth/interfaces/i_auth_service.dart';"),

    ("features/auth/screens/splash_screen.dart",
     "import '../../constants/theme.dart';",
     "import '../../../constants/theme.dart';"),

    # features/home/screens/ (3 deep: lib/features/home/screens/)
    ("features/home/screens/home_screen.dart",
     "import '../core/di.dart';",
     "import '../../core/di.dart';"),
    ("features/home/screens/home_screen.dart",
     "import '../features/auth/providers/auth_provider.dart';",
     "import '../../features/auth/providers/auth_provider.dart';"),
    ("features/home/screens/home_screen.dart",
     "import '../features/auth/interfaces/i_auth_service.dart';",
     "import '../../features/auth/interfaces/i_auth_service.dart';"),
    ("features/home/screens/home_screen.dart",
     "import '../constants/theme.dart';",
     "import '../../constants/theme.dart';"),
    ("features/home/screens/home_screen.dart",
     "import 'views/home_tab.dart';",
     "import '../views/home_tab.dart';"),
    ("features/home/screens/home_screen.dart",
     "import '../features/home/views/home_tab.dart';",
     "import '../../features/home/views/home_tab.dart';"),
    ("features/home/screens/home_screen.dart",
     "import '../features/discovery/screens/discover_tab.dart';",
     "import '../../features/discovery/screens/discover_tab.dart';"),
    ("features/home/screens/home_screen.dart",
     "import '../features/messaging/screens/chat_tab.dart';",
     "import '../../features/messaging/screens/chat_tab.dart';"),
    ("features/home/screens/home_screen.dart",
     "import 'views/profile_view.dart';",
     "import '../views/profile_view.dart';"),

    # features/home/views/ (4 deep)
    ("features/home/views/home_tab.dart",
     "import '../../../../features/matching/services/profile_match_service.dart';",
     "import '../../matching/services/profile_match_service.dart';"),
    ("features/home/views/home_tab.dart",
     "import '../../../../models/profile.dart';",
     "import '../../models/profile.dart';"),
    ("features/home/views/home_tab.dart",
     "import '../../../../features/auth/services/supabase_service.dart';",
     "import '../../features/auth/services/supabase_service.dart';"),
    ("features/home/views/home_tab.dart",
     "import '../../../../constants/theme.dart';",
     "import '../../constants/theme.dart';"),
    ("features/home/views/home_tab.dart",
     "import '../../../shared/widgets/verified_badge.dart';",
     "import '../../shared/widgets/verified_badge.dart';"),
    ("features/home/views/home_tab.dart",
     "import '../../../features/matching/widgets/match_badge.dart';",
     "import '../../matching/widgets/match_badge.dart';"),

    ("features/home/views/profile_view.dart",
     "import '../../../features/auth/providers/auth_provider.dart';",
     "import '../../features/auth/providers/auth_provider.dart';"),

    # features/matching/screens/ (4 deep)
    ("features/matching/screens/match_feed_view.dart",
     "import '../../../providers/match_provider.dart';",
     "import '../../features/matching/providers/match_provider.dart';"),
    ("features/matching/screens/match_feed_view.dart",
     "import '../../../features/profile/widgets/profile_card.dart';",
     "import '../../features/profile/widgets/profile_card.dart';"),
    ("features/matching/screens/match_feed_view.dart",
     "import '../../../features/matching/widgets/match_action_buttons.dart';",
     "import '../../features/matching/widgets/match_action_buttons.dart';"),

    # features/matching/services/ (4 deep)
    ("features/matching/services/lookup_service.dart",
     "import '../../models/profile.dart';",
     "import '../../../models/profile.dart';"),
    ("features/matching/services/lookup_service.dart",
     "import '../../features/auth/services/supabase_service.dart';",
     "import '../../../features/auth/services/supabase_service.dart';"),

    ("features/matching/services/profile_match_service.dart",
     "import '../../models/profile.dart';",
     "import '../../../models/profile.dart';"),
    ("features/matching/services/profile_match_service.dart",
     "import '../../features/auth/services/supabase_service.dart';",
     "import '../../../features/auth/services/supabase_service.dart';"),

    # features/matching/providers/ (4 deep)
    ("features/matching/providers/match_provider.dart",
     "import '../../models/profile.dart';",
     "import '../../../models/profile.dart';"),

    # features/profile/screens/ (4 deep)
    ("features/profile/screens/edit_profile_screen.dart",
     "import '../../core/di.dart';",
     "import '../../../../core/di.dart';"),
    ("features/profile/screens/edit_profile_screen.dart",
     "import '../../models/profile.dart';",
     "import '../../../../models/profile.dart';"),
    ("features/profile/screens/edit_profile_screen.dart",
     "import '../../features/auth/interfaces/i_auth_service.dart';",
     "import '../../../../features/auth/interfaces/i_auth_service.dart';"),
    ("features/profile/screens/edit_profile_screen.dart",
     "import '../../features/matching/services/lookup_service.dart';",
     "import '../../../../features/matching/services/lookup_service.dart';"),
    ("features/profile/screens/edit_profile_screen.dart",
     "import '../../features/profile/services/profile_service.dart';",
     "import '../../../../features/profile/services/profile_service.dart';"),
    ("features/profile/screens/edit_profile_screen.dart",
     "import '../../../../shared/widgets/apple_text_field.dart';",
     "import '../../../shared/widgets/apple_text_field.dart';"),
    ("features/profile/screens/edit_profile_screen.dart",
     "import '../../../../shared/widgets/bottom_sheet_selector.dart';",
     "import '../../../shared/widgets/bottom_sheet_selector.dart';"),

    # features/profile/services/ (4 deep)
    ("features/profile/services/profile_service.dart",
     "import '../../models/profile.dart';",
     "import '../../../models/profile.dart';"),
    ("features/profile/services/profile_service.dart",
     "import '../../features/auth/services/supabase_service.dart';",
     "import '../../../features/auth/services/supabase_service.dart';"),

    # features/profile/widgets/ (4 deep)
    ("features/profile/widgets/profile_card.dart",
     "import '../../models/profile.dart';",
     "import '../../../models/profile.dart';"),

    # features/onboarding/screens/ (4 deep)
    ("features/onboarding/screens/profile_builder_layout.dart",
     "import '../../features/auth/providers/auth_provider.dart';",
     "import '../../../features/auth/providers/auth_provider.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart",
     "import '../../core/di.dart';",
     "import '../../../core/di.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart",
     "import '../../models/profile.dart';",
     "import '../../../models/profile.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart",
     "import '../../features/auth/interfaces/i_auth_service.dart';",
     "import '../../../features/auth/interfaces/i_auth_service.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart",
     "import '../../features/profile/services/profile_service.dart';",
     "import '../../../features/profile/services/profile_service.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart",
     "import '../../features/matching/services/lookup_service.dart';",
     "import '../../../features/matching/services/lookup_service.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart",
     "import '../../core/supabase_service.dart';",
     "import '../../../features/auth/services/supabase_service.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart",
     "import '../../../../shared/widgets/apple_scale_button.dart';",
     "import '../../../shared/widgets/apple_scale_button.dart';"),

    # features/onboarding/steps/ (5 deep)
    ("features/onboarding/steps/step1_basic_info.dart",
     "import '../../../../shared/widgets/apple_text_field.dart';",
     "import '../../../shared/widgets/apple_text_field.dart';"),
    ("features/onboarding/steps/step1_basic_info.dart",
     "import '../../../../shared/widgets/bottom_sheet_selector.dart';",
     "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
    ("features/onboarding/steps/step1_basic_info.dart",
     "import '../../../../models/profile.dart';",
     "import '../../../models/profile.dart';"),
    ("features/onboarding/steps/step1_basic_info.dart",
     "import '../../../../features/profile/services/profile_service.dart';",
     "import '../../../features/profile/services/profile_service.dart';"),

    ("features/onboarding/steps/step2_traditional.dart",
     "import '../../../../shared/widgets/apple_text_field.dart';",
     "import '../../../shared/widgets/apple_text_field.dart';"),
    ("features/onboarding/steps/step2_traditional.dart",
     "import '../../../../shared/widgets/bottom_sheet_selector.dart';",
     "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
    ("features/onboarding/steps/step2_traditional.dart",
     "import '../../../../models/profile.dart';",
     "import '../../../models/profile.dart';"),

    ("features/onboarding/steps/step3_education.dart",
     "import '../../../../shared/widgets/bottom_sheet_selector.dart';",
     "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
    ("features/onboarding/steps/step3_education.dart",
     "import '../../../../shared/widgets/apple_text_field.dart';",
     "import '../../../shared/widgets/apple_text_field.dart';"),
    ("features/onboarding/steps/step3_education.dart",
     "import '../../../../models/profile.dart';",
     "import '../../../models/profile.dart';"),

    ("features/onboarding/steps/step4_family.dart",
     "import '../../../../shared/widgets/apple_text_field.dart';",
     "import '../../../shared/widgets/apple_text_field.dart';"),
    ("features/onboarding/steps/step4_family.dart",
     "import '../../../../shared/widgets/bottom_sheet_selector.dart';",
     "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
    ("features/onboarding/steps/step4_family.dart",
     "import '../../../../models/profile.dart';",
     "import '../../../models/profile.dart';"),

    ("features/onboarding/steps/step5_lifestyle.dart",
     "import '../../../../shared/widgets/bottom_sheet_selector.dart';",
     "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
    ("features/onboarding/steps/step5_lifestyle.dart",
     "import '../../../../models/profile.dart';",
     "import '../../../models/profile.dart';"),

    ("features/onboarding/steps/step6_location.dart",
     "import '../../../../shared/widgets/apple_text_field.dart';",
     "import '../../../shared/widgets/apple_text_field.dart';"),
    ("features/onboarding/steps/step6_location.dart",
     "import '../../../../shared/widgets/bottom_sheet_selector.dart';",
     "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
    ("features/onboarding/steps/step6_location.dart",
     "import '../../../../models/profile.dart';",
     "import '../../../models/profile.dart';"),

    ("features/onboarding/steps/step7_review.dart",
     "import '../../../models/profile.dart';",
     "import '../../../../models/profile.dart';"),
]

count = 0
errors = []
for relpath, old, new in fixes:
    fpath = os.path.join(base, relpath)
    if not os.path.exists(fpath):
        errors.append(f"MISSING: {relpath}")
        continue
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
    if old in content:
        content = content.replace(old, new)
        with open(fpath, 'w', encoding='utf-8') as f:
            f.write(content)
        count += 1
    elif new in content:
        pass  # already correct
    else:
        errors.append(f"NO MATCH: {relpath} (looking for: {old[:60]})")

print(f"Fixed: {count}")
if errors:
    print("Errors:")
    for e in errors:
        print(f"  {e}")
