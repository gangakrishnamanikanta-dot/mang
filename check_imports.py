import os

base = "c:/Users/Neerajara/Desktop/mangalasutram final app/mangalasutram_flutter/lib"

# Read actual file contents first to see what needs fixing
files_to_check = [
    "features/auth/services/auth_service.dart",
    "features/auth/services/phone_auth_service.dart",
    "features/auth/services/supabase_service.dart",
    "features/auth/providers/auth_provider.dart",
    "features/home/screens/home_screen.dart",
    "features/home/views/home_tab.dart",
    "features/home/views/profile_view.dart",
    "features/matching/screens/match_feed_view.dart",
    "features/matching/services/lookup_service.dart",
    "features/matching/services/profile_match_service.dart",
    "features/matching/providers/match_provider.dart",
    "features/profile/screens/edit_profile_screen.dart",
    "features/profile/services/profile_service.dart",
    "features/profile/widgets/profile_card.dart",
    "features/onboarding/screens/profile_builder_layout.dart",
    "features/onboarding/steps/step1_basic_info.dart",
    "features/onboarding/steps/step2_traditional.dart",
    "features/onboarding/steps/step3_education.dart",
    "features/onboarding/steps/step4_family.dart",
    "features/onboarding/steps/step5_lifestyle.dart",
    "features/onboarding/steps/step6_location.dart",
    "features/onboarding/steps/step7_review.dart",
]

for relpath in files_to_check:
    fpath = os.path.join(base, relpath)
    if not os.path.exists(fpath):
        print(f"MISSING: {relpath}")
        continue
    with open(fpath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    print(f"\n{relpath}:")
    for i, line in enumerate(lines[:12], 1):
        if 'import' in line:
            print(f"  {i}: {line.rstrip()}")
