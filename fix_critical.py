import os

base = "c:/Users/Neerajara/Desktop/mangalasutram final app/mangalasutram_flutter/lib"

fixes = [
    # supabase_service.dart: ../config/env.dart is WRONG (should be ../../)
    ("features/auth/services/supabase_service.dart",
     "import '../config/env.dart';",
     "import '../../config/env.dart';"),

    # home_tab.dart: ../../../ is too many levels
    ("features/home/views/home_tab.dart",
     "import '../../../matching/services/profile_match_service.dart';",
     "import '../../matching/services/profile_match_service.dart';"),
    ("features/home/views/home_tab.dart",
     "import '../../../models/profile.dart';",
     "import '../../models/profile.dart';"),
    ("features/home/views/home_tab.dart",
     "import '../../../constants/theme.dart';",
     "import '../../constants/theme.dart';"),
    ("features/home/views/home_tab.dart",
     "import '../../../shared/widgets/verified_badge.dart';",
     "import '../../shared/widgets/verified_badge.dart';"),

    # edit_profile_screen.dart: ../../ is too few levels (needs ../../../../)
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

    # profile_builder_layout.dart: ../../ is too few levels (needs ../../../)
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
        print(f"NO MATCH: {relpath}")

print(f"\nTotal fixed: {count}")
