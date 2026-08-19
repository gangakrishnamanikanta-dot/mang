import os

base = "c:/Users/Neerajara/Desktop/mangalasutram final app/mangalasutram_flutter/lib"

fixes = [
    # auth_service.dart
    ("features/auth/services/auth_service.dart", "import '../config/env.dart';", "import '../../config/env.dart';"),
    ("features/auth/services/auth_service.dart", "import '../models/profile.dart';", "import '../../models/profile.dart';"),
    ("features/auth/services/auth_service.dart", "import '../interfaces/i_auth_service.dart';", "import '../../features/auth/interfaces/i_auth_service.dart';"),

    # phone_auth_service.dart
    ("features/auth/services/phone_auth_service.dart", "import '../interfaces/i_phone_auth_service.dart';", "import '../../features/auth/interfaces/i_phone_auth_service.dart';"),

    # i_auth_service.dart
    ("features/auth/interfaces/i_auth_service.dart", "import '../../models/profile.dart';", "import '../../../models/profile.dart';"),

    # auth_provider.dart
    ("features/auth/providers/auth_provider.dart", "import '../../core/di.dart';", "import '../../../core/di.dart';"),
    ("features/auth/providers/auth_provider.dart", "import '../../models/profile.dart';", "import '../../../models/profile.dart';"),
    ("features/auth/providers/auth_provider.dart", "import '../../features/auth/interfaces/i_auth_service.dart';", "import '../../features/auth/interfaces/i_auth_service.dart';"),

    # login_screen.dart
    ("features/auth/screens/login_screen.dart", "import '../../core/di.dart';", "import '../../../core/di.dart';"),
    ("features/auth/screens/login_screen.dart", "import '../../features/auth/interfaces/i_auth_service.dart';", "import '../../../features/auth/interfaces/i_auth_service.dart';"),
    ("features/auth/screens/login_screen.dart", "import '../../features/auth/interfaces/i_phone_auth_service.dart';", "import '../../../features/auth/interfaces/i_phone_auth_service.dart';"),
    ("features/auth/screens/login_screen.dart", "import '../../../features/shared/widgets/apple_scale_button.dart';", "import '../../../shared/widgets/apple_scale_button.dart';"),

    # signup_screen.dart
    ("features/auth/screens/signup_screen.dart", "import '../../core/di.dart';", "import '../../../core/di.dart';"),
    ("features/auth/screens/signup_screen.dart", "import '../../features/auth/interfaces/i_auth_service.dart';", "import '../../../features/auth/interfaces/i_auth_service.dart';"),
    ("features/auth/screens/signup_screen.dart", "import '../../../../shared/widgets/apple_scale_button.dart';", "import '../../../shared/widgets/apple_scale_button.dart';"),

    # otp_verification_screen.dart
    ("features/auth/screens/otp_verification_screen.dart", "import '../../core/di.dart';", "import '../../../core/di.dart';"),
    ("features/auth/screens/otp_verification_screen.dart", "import '../../features/auth/interfaces/i_auth_service.dart';", "import '../../../features/auth/interfaces/i_auth_service.dart';"),
    ("features/auth/screens/otp_verification_screen.dart", "import '../../features/auth/interfaces/i_phone_auth_service.dart';", "import '../../../features/auth/interfaces/i_phone_auth_service.dart';"),
    ("features/auth/screens/otp_verification_screen.dart", "import '../../../../shared/widgets/apple_scale_button.dart';", "import '../../../shared/widgets/apple_scale_button.dart';"),

    # forgot_password_screen.dart
    ("features/auth/screens/forgot_password_screen.dart", "import '../../core/di.dart';", "import '../../../core/di.dart';"),
    ("features/auth/screens/forgot_password_screen.dart", "import '../../features/auth/interfaces/i_auth_service.dart';", "import '../../../features/auth/interfaces/i_auth_service.dart';"),

    # reset_password_screen.dart
    ("features/auth/screens/reset_password_screen.dart", "import '../../core/di.dart';", "import '../../../core/di.dart';"),
    ("features/auth/screens/reset_password_screen.dart", "import '../../features/auth/interfaces/i_auth_service.dart';", "import '../../../features/auth/interfaces/i_auth_service.dart';"),

    # splash_screen.dart
    ("features/auth/screens/splash_screen.dart", "import '../../constants/theme.dart';", "import '../../../constants/theme.dart';"),

    # home_screen.dart
    ("features/home/screens/home_screen.dart", "import '../../core/di.dart';", "import '../core/di.dart';"),
    ("features/home/screens/home_screen.dart", "import '../../features/auth/providers/auth_provider.dart';", "import '../features/auth/providers/auth_provider.dart';"),
    ("features/home/screens/home_screen.dart", "import '../../features/auth/interfaces/i_auth_service.dart';", "import '../features/auth/interfaces/i_auth_service.dart';"),
    ("features/home/screens/home_screen.dart", "import '../../constants/theme.dart';", "import '../constants/theme.dart';"),
    ("features/home/screens/home_screen.dart", "import '../../features/home/views/home_tab.dart';", "import '../features/home/views/home_tab.dart';"),
    ("features/home/screens/home_screen.dart", "import '../../features/discovery/screens/discover_tab.dart';", "import '../features/discovery/screens/discover_tab.dart';"),
    ("features/home/screens/home_screen.dart", "import '../../features/messaging/screens/chat_tab.dart';", "import '../features/messaging/screens/chat_tab.dart';"),

    # home_tab.dart
    ("features/home/views/home_tab.dart", "import '../../../../features/matching/services/profile_match_service.dart';", "import '../../matching/services/profile_match_service.dart';"),
    ("features/home/views/home_tab.dart", "import '../../../../models/profile.dart';", "import '../../models/profile.dart';"),
    ("features/home/views/home_tab.dart", "import '../../../../core/supabase_service.dart';", "import '../../features/auth/services/supabase_service.dart';"),
    ("features/home/views/home_tab.dart", "import '../../../../constants/theme.dart';", "import '../../constants/theme.dart';"),
    ("features/home/views/home_tab.dart", "import '../../../features/shared/widgets/verified_badge.dart';", "import '../../../shared/widgets/verified_badge.dart';"),
    ("features/home/views/home_tab.dart", "import '../../../features/matching/widgets/match_badge.dart';", "import '../../matching/widgets/match_badge.dart';"),

    # profile_view.dart
    ("features/home/views/profile_view.dart", "import '../../../providers/auth_provider.dart';", "import '../../features/auth/providers/auth_provider.dart';"),

    # match_feed_view.dart
    ("features/matching/screens/match_feed_view.dart", "import '../../../providers/match_provider.dart';", "import '../../features/matching/providers/match_provider.dart';"),
    ("features/matching/screens/match_feed_view.dart", "import '../../../features/profile/widgets/profile_card.dart';", "import '../../features/profile/widgets/profile_card.dart';"),
    ("features/matching/screens/match_feed_view.dart", "import '../../../features/matching/widgets/match_action_buttons.dart';", "import '../../features/matching/widgets/match_action_buttons.dart';"),

    # lookup_service.dart
    ("features/matching/services/lookup_service.dart", "import '../../models/profile.dart';", "import '../../../models/profile.dart';"),

    # profile_match_service.dart
    ("features/matching/services/profile_match_service.dart", "import '../../models/profile.dart';", "import '../../../models/profile.dart';"),

    # match_provider.dart
    ("features/matching/providers/match_provider.dart", "import '../../models/profile.dart';", "import '../../../models/profile.dart';"),

    # profile_card.dart
    ("features/profile/widgets/profile_card.dart", "import '../../models/profile.dart';", "import '../../../models/profile.dart';"),

    # profile_service.dart
    ("features/profile/services/profile_service.dart", "import '../models/profile.dart';", "import '../../models/profile.dart';"),

    # profile_builder_layout.dart - needs supabase_service fixed
    ("features/onboarding/screens/profile_builder_layout.dart", "import '../../core/supabase_service.dart';", "import '../../features/auth/services/supabase_service.dart';"),

    # onboarding steps - fix ../../../../ to ../../../
    ("features/onboarding/steps/step1_basic_info.dart", "import '../../../../shared/widgets/apple_text_field.dart';", "import '../../../shared/widgets/apple_text_field.dart';"),
    ("features/onboarding/steps/step1_basic_info.dart", "import '../../../../shared/widgets/bottom_sheet_selector.dart';", "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
    ("features/onboarding/steps/step1_basic_info.dart", "import '../../../../models/profile.dart';", "import '../../../models/profile.dart';"),
    ("features/onboarding/steps/step1_basic_info.dart", "import '../../../../features/profile/services/profile_service.dart';", "import '../../../features/profile/services/profile_service.dart';"),

    ("features/onboarding/steps/step2_traditional.dart", "import '../../../../shared/widgets/apple_text_field.dart';", "import '../../../shared/widgets/apple_text_field.dart';"),
    ("features/onboarding/steps/step2_traditional.dart", "import '../../../../shared/widgets/bottom_sheet_selector.dart';", "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
    ("features/onboarding/steps/step2_traditional.dart", "import '../../../../models/profile.dart';", "import '../../../models/profile.dart';"),

    ("features/onboarding/steps/step3_education.dart", "import '../../../../shared/widgets/bottom_sheet_selector.dart';", "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
    ("features/onboarding/steps/step3_education.dart", "import '../../../../shared/widgets/apple_text_field.dart';", "import '../../../shared/widgets/apple_text_field.dart';"),
    ("features/onboarding/steps/step3_education.dart", "import '../../../../models/profile.dart';", "import '../../../models/profile.dart';"),

    ("features/onboarding/steps/step4_family.dart", "import '../../../../shared/widgets/apple_text_field.dart';", "import '../../../shared/widgets/apple_text_field.dart';"),
    ("features/onboarding/steps/step4_family.dart", "import '../../../../shared/widgets/bottom_sheet_selector.dart';", "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
    ("features/onboarding/steps/step4_family.dart", "import '../../../../models/profile.dart';", "import '../../../models/profile.dart';"),

    ("features/onboarding/steps/step5_lifestyle.dart", "import '../../../../shared/widgets/bottom_sheet_selector.dart';", "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
    ("features/onboarding/steps/step5_lifestyle.dart", "import '../../../../models/profile.dart';", "import '../../../models/profile.dart';"),

    ("features/onboarding/steps/step6_location.dart", "import '../../../../shared/widgets/apple_text_field.dart';", "import '../../../shared/widgets/apple_text_field.dart';"),
    ("features/onboarding/steps/step6_location.dart", "import '../../../../shared/widgets/bottom_sheet_selector.dart';", "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
    ("features/onboarding/steps/step6_location.dart", "import '../../../../models/profile.dart';", "import '../../../models/profile.dart';"),

    ("features/onboarding/steps/step7_review.dart", "import '../../../models/profile.dart';", "import '../../../../models/profile.dart';"),

    # edit_profile_screen.dart
    ("features/profile/screens/edit_profile_screen.dart", "import '../../../../shared/widgets/apple_text_field.dart';", "import '../../../shared/widgets/apple_text_field.dart';"),
    ("features/profile/screens/edit_profile_screen.dart", "import '../../../../shared/widgets/bottom_sheet_selector.dart';", "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
]

count = 0
for relpath, old, new in fixes:
    fpath = os.path.join(base, relpath)
    if not os.path.exists(fpath):
        print(f"MISSING: {relpath}")
        continue
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
    if old in content:
        content = content.replace(old, new)
        with open(fpath, 'w', encoding='utf-8') as f:
            f.write(content)
        count += 1
        print(f"FIXED: {relpath}")
    else:
        # Check if already correct
        if new in content:
            print(f"OK: {relpath}")
        else:
            print(f"NO MATCH: {relpath} (looking for: {old[:50]}...)")

print(f"\nTotal fixed: {count}")
