import os

base = "c:/Users/Neerajara/Desktop/mangalasutram final app/mangalasutram_flutter/lib"

fixes = [
    # auth_service.dart
    ("features/auth/services/auth_service.dart", "import '../../config/env.dart';", "import '../../config/env.dart';"),
    ("features/auth/services/auth_service.dart", "import '../../models/profile.dart';", "import '../../models/profile.dart';"),
    ("features/auth/services/auth_service.dart", "import '../../features/auth/interfaces/i_auth_service.dart';", "import '../../features/auth/interfaces/i_auth_service.dart';"),

    # phone_auth_service.dart
    ("features/auth/services/phone_auth_service.dart", "import '../../features/auth/interfaces/i_phone_auth_service.dart';", "import '../../features/auth/interfaces/i_phone_auth_service.dart';"),

    # supabase_service.dart
    ("features/auth/services/supabase_service.dart", "import '../config/env.dart';", "import '../config/env.dart';"),

    # auth_provider.dart
    ("features/auth/providers/auth_provider.dart", "import '../../features/auth/interfaces/i_auth_service.dart';", "import '../../features/auth/interfaces/i_auth_service.dart';"),

    # home_screen.dart
    ("features/home/screens/home_screen.dart", "import '../core/di.dart';", "import '../core/di.dart';"),
    ("features/home/screens/home_screen.dart", "import '../features/auth/providers/auth_provider.dart';", "import '../features/auth/providers/auth_provider.dart';"),
    ("features/home/screens/home_screen.dart", "import '../features/auth/interfaces/i_auth_service.dart';", "import '../features/auth/interfaces/i_auth_service.dart';"),
    ("features/home/screens/home_screen.dart", "import '../constants/theme.dart';", "import '../constants/theme.dart';"),
    ("features/home/screens/home_screen.dart", "import 'views/home_tab.dart';", "import 'views/home_tab.dart';"),
    ("features/home/screens/home_screen.dart", "import '../features/home/views/home_tab.dart';", "import '../features/home/views/home_tab.dart';"),
    ("features/home/screens/home_screen.dart", "import '../features/discovery/screens/discover_tab.dart';", "import '../features/discovery/screens/discover_tab.dart';"),
    ("features/home/screens/home_screen.dart", "import '../features/messaging/screens/chat_tab.dart';", "import '../features/messaging/screens/chat_tab.dart';"),
    ("features/home/screens/home_screen.dart", "import 'views/profile_view.dart';", "import 'views/profile_view.dart';"),

    # home_tab.dart
    ("features/home/views/home_tab.dart", "import '../../matching/services/profile_match_service.dart';", "import '../../matching/services/profile_match_service.dart';"),
    ("features/home/views/home_tab.dart", "import '../../models/profile.dart';", "import '../../models/profile.dart';"),
    ("features/home/views/home_tab.dart", "import '../../features/auth/services/supabase_service.dart';", "import '../../features/auth/services/supabase_service.dart';"),
    ("features/home/views/home_tab.dart", "import '../../constants/theme.dart';", "import '../../constants/theme.dart';"),
    ("features/home/views/home_tab.dart", "import '../../../shared/widgets/verified_badge.dart';", "import '../../../shared/widgets/verified_badge.dart';"),
    ("features/home/views/home_tab.dart", "import '../../matching/widgets/match_badge.dart';", "import '../../matching/widgets/match_badge.dart';"),

    # profile_view.dart
    ("features/home/views/profile_view.dart", "import '../../features/auth/providers/auth_provider.dart';", "import '../../features/auth/providers/auth_provider.dart';"),

    # match_feed_view.dart
    ("features/matching/screens/match_feed_view.dart", "import '../../features/matching/providers/match_provider.dart';", "import '../../features/matching/providers/match_provider.dart';"),
    ("features/matching/screens/match_feed_view.dart", "import '../../features/profile/widgets/profile_card.dart';", "import '../../features/profile/widgets/profile_card.dart';"),
    ("features/matching/screens/match_feed_view.dart", "import '../../features/matching/widgets/match_action_buttons.dart';", "import '../../features/matching/widgets/match_action_buttons.dart';"),

    # lookup_service.dart
    ("features/matching/services/lookup_service.dart", "import '../../features/auth/services/supabase_service.dart';", "import '../../features/auth/services/supabase_service.dart';"),

    # profile_builder_layout.dart
    ("features/onboarding/screens/profile_builder_layout.dart", "import '../features/auth/providers/auth_provider.dart';", "import '../features/auth/providers/auth_provider.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart", "import '../core/di.dart';", "import '../core/di.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart", "import '../models/profile.dart';", "import '../models/profile.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart", "import '../features/auth/interfaces/i_auth_service.dart';", "import '../features/auth/interfaces/i_auth_service.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart", "import '../features/profile/services/profile_service.dart';", "import '../features/profile/services/profile_service.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart", "import '../features/matching/services/lookup_service.dart';", "import '../features/matching/services/lookup_service.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart", "import '../core/supabase_service.dart';", "import '../features/auth/services/supabase_service.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart", "import 'steps/step1_basic_info.dart';", "import 'steps/step1_basic_info.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart", "import 'steps/step2_traditional.dart';", "import 'steps/step2_traditional.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart", "import 'steps/step3_education.dart';", "import 'steps/step3_education.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart", "import 'steps/step4_family.dart';", "import 'steps/step4_family.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart", "import 'steps/step5_lifestyle.dart';", "import 'steps/step5_lifestyle.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart", "import 'steps/step6_location.dart';", "import 'steps/step6_location.dart';"),
    ("features/onboarding/screens/profile_builder_layout.dart", "import 'steps/step7_review.dart';", "import 'steps/step7_review.dart';"),

    # edit_profile_screen.dart
    ("features/profile/screens/edit_profile_screen.dart", "import '../../core/di.dart';", "import '../../core/di.dart';"),
    ("features/profile/screens/edit_profile_screen.dart", "import '../../models/profile.dart';", "import '../../models/profile.dart';"),
    ("features/profile/screens/edit_profile_screen.dart", "import '../../features/auth/interfaces/i_auth_service.dart';", "import '../../features/auth/interfaces/i_auth_service.dart';"),
    ("features/profile/screens/edit_profile_screen.dart", "import '../../features/matching/services/lookup_service.dart';", "import '../../features/matching/services/lookup_service.dart';"),
    ("features/profile/screens/edit_profile_screen.dart", "import '../../features/profile/services/profile_service.dart';", "import '../../features/profile/services/profile_service.dart';"),

    # profile_service.dart
    ("features/profile/services/profile_service.dart", "import '../../models/profile.dart';", "import '../../models/profile.dart';"),
    ("features/profile/services/profile_service.dart", "import '../../features/auth/services/supabase_service.dart';", "import '../../features/auth/services/supabase_service.dart';"),
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

print(f"Fixed: {count}")
