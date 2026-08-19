import os

base = "c:/Users/Neerajara/Desktop/mangalasutram final app/mangalasutram_flutter/lib"

# CORRECT imports for each file based on actual directory depth
correct_imports = {
    # features/auth/services/ (3 levels deep from lib/)
    "features/auth/services/auth_service.dart": """import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/env.dart';
import '../../models/profile.dart';
import '../../features/auth/interfaces/i_auth_service.dart';
import 'supabase_service.dart';
import 'dart:io' show Platform;""",

    "features/auth/services/phone_auth_service.dart": """import '../../features/auth/interfaces/i_phone_auth_service.dart';""",

    "features/auth/services/supabase_service.dart": """import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/env.dart';""",

    # features/auth/providers/ (3 levels deep)
    "features/auth/providers/auth_provider.dart": """import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di.dart';
import '../../../models/profile.dart';
import '../../features/auth/interfaces/i_auth_service.dart';""",

    # features/auth/interfaces/ (3 levels deep)
    "features/auth/interfaces/i_auth_service.dart": """import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/profile.dart';""",

    # features/auth/screens/ (4 levels deep)
    "features/auth/screens/login_screen.dart": """import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/di.dart';
import '../../../features/auth/interfaces/i_auth_service.dart';
import '../../../features/auth/interfaces/i_phone_auth_service.dart';
import '../../../shared/widgets/apple_scale_button.dart';""",

    "features/auth/screens/signup_screen.dart": """import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/di.dart';
import '../../../features/auth/interfaces/i_auth_service.dart';
import '../../../shared/widgets/apple_scale_button.dart';""",

    "features/auth/screens/otp_verification_screen.dart": """import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../core/di.dart';
import '../../../features/auth/interfaces/i_auth_service.dart';
import '../../../features/auth/interfaces/i_phone_auth_service.dart';
import '../../../shared/widgets/apple_scale_button.dart';""",

    "features/auth/screens/forgot_password_screen.dart": """import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/di.dart';
import '../../../features/auth/interfaces/i_auth_service.dart';""",

    "features/auth/screens/reset_password_screen.dart": """import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../core/di.dart';
import '../../../features/auth/interfaces/i_auth_service.dart';""",

    "features/auth/screens/splash_screen.dart": """import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../constants/theme.dart';""",

    # features/home/screens/ (3 levels deep)
    "features/home/screens/home_screen.dart": """import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/di.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/interfaces/i_auth_service.dart';
import '../constants/theme.dart';
import 'views/home_tab.dart';
import '../features/home/views/home_tab.dart';
import '../features/discovery/screens/discover_tab.dart';
import '../features/messaging/screens/chat_tab.dart';
import 'views/profile_view.dart';""",

    # features/home/views/ (4 levels deep)
    "features/home/views/home_tab.dart": """import 'package:flutter/material.dart';
import '../../matching/services/profile_match_service.dart';
import '../../models/profile.dart';
import '../../features/auth/services/supabase_service.dart';
import '../../constants/theme.dart';
import '../../shared/widgets/verified_badge.dart';
import '../../matching/widgets/match_badge.dart';""",

    "features/home/views/profile_view.dart": """import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../../constants/theme.dart';""",

    # features/matching/screens/ (4 levels deep)
    "features/matching/screens/match_feed_view.dart": """import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/matching/providers/match_provider.dart';
import '../../features/profile/widgets/profile_card.dart';
import '../../features/matching/widgets/match_action_buttons.dart';""",

    # features/matching/services/ (4 levels deep)
    "features/matching/services/lookup_service.dart": """import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../../models/profile.dart';
import '../../features/auth/services/supabase_service.dart';""",

    "features/matching/services/profile_match_service.dart": """import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/profile.dart';
import '../../../features/auth/services/supabase_service.dart';""",

    # features/matching/providers/ (4 levels deep)
    "features/matching/providers/match_provider.dart": """import 'package:flutter/material.dart';
import '../../../models/profile.dart';""",

    # features/profile/screens/ (4 levels deep)
    "features/profile/screens/edit_profile_screen.dart": None,  # keep existing content, just fix imports

    # features/profile/services/ (4 levels deep)
    "features/profile/services/profile_service.dart": None,  # already correct

    # features/profile/widgets/ (4 levels deep)
    "features/profile/widgets/profile_card.dart": """import 'package:flutter/material.dart';
import '../../../models/profile.dart';""",

    # features/onboarding/screens/ (4 levels deep)
    "features/onboarding/screens/profile_builder_layout.dart": None,  # fix imports only

    # features/onboarding/steps/ (5 levels deep)
    "features/onboarding/steps/step7_review.dart": """import 'package:flutter/material.dart';
import '../../../../models/profile.dart';""",
}

# For files marked None, just do targeted fixes
partial_fixes = {
    "features/profile/screens/edit_profile_screen.dart": [
        ("import '../../core/di.dart';", "import '../../../../core/di.dart';"),
        ("import '../../models/profile.dart';", "import '../../../../models/profile.dart';"),
        ("import '../../features/auth/interfaces/i_auth_service.dart';", "import '../../../../features/auth/interfaces/i_auth_service.dart';"),
        ("import '../../features/matching/services/lookup_service.dart';", "import '../../../../features/matching/services/lookup_service.dart';"),
        ("import '../../features/profile/services/profile_service.dart';", "import '../../../../features/profile/services/profile_service.dart';"),
    ],
    "features/onboarding/screens/profile_builder_layout.dart": [
        ("import '../../features/auth/providers/auth_provider.dart';", "import '../../../features/auth/providers/auth_provider.dart';"),
        ("import '../../core/di.dart';", "import '../../../core/di.dart';"),
        ("import '../../models/profile.dart';", "import '../../../models/profile.dart';"),
        ("import '../../features/auth/interfaces/i_auth_service.dart';", "import '../../../features/auth/interfaces/i_auth_service.dart';"),
        ("import '../../features/profile/services/profile_service.dart';", "import '../../../features/profile/services/profile_service.dart';"),
        ("import '../../features/matching/services/lookup_service.dart';", "import '../../../features/matching/services/lookup_service.dart';"),
        ("import '../../core/supabase_service.dart';", "import '../../../features/auth/services/supabase_service.dart';"),
    ],
    "features/onboarding/steps/step1_basic_info.dart": [
        ("import '../../../../shared/widgets/apple_text_field.dart';", "import '../../../shared/widgets/apple_text_field.dart';"),
        ("import '../../../../shared/widgets/bottom_sheet_selector.dart';", "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
        ("import '../../../../models/profile.dart';", "import '../../../models/profile.dart';"),
        ("import '../../../../features/profile/services/profile_service.dart';", "import '../../../features/profile/services/profile_service.dart';"),
    ],
    "features/onboarding/steps/step2_traditional.dart": [
        ("import '../../../../shared/widgets/apple_text_field.dart';", "import '../../../shared/widgets/apple_text_field.dart';"),
        ("import '../../../../shared/widgets/bottom_sheet_selector.dart';", "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
        ("import '../../../../models/profile.dart';", "import '../../../models/profile.dart';"),
    ],
    "features/onboarding/steps/step3_education.dart": [
        ("import '../../../../shared/widgets/bottom_sheet_selector.dart';", "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
        ("import '../../../../shared/widgets/apple_text_field.dart';", "import '../../../shared/widgets/apple_text_field.dart';"),
        ("import '../../../../models/profile.dart';", "import '../../../models/profile.dart';"),
    ],
    "features/onboarding/steps/step4_family.dart": [
        ("import '../../../../shared/widgets/apple_text_field.dart';", "import '../../../shared/widgets/apple_text_field.dart';"),
        ("import '../../../../shared/widgets/bottom_sheet_selector.dart';", "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
        ("import '../../../../models/profile.dart';", "import '../../../models/profile.dart';"),
    ],
    "features/onboarding/steps/step5_lifestyle.dart": [
        ("import '../../../../shared/widgets/bottom_sheet_selector.dart';", "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
        ("import '../../../../models/profile.dart';", "import '../../../models/profile.dart';"),
    ],
    "features/onboarding/steps/step6_location.dart": [
        ("import '../../../../shared/widgets/apple_text_field.dart';", "import '../../../shared/widgets/apple_text_field.dart';"),
        ("import '../../../../shared/widgets/bottom_sheet_selector.dart';", "import '../../../shared/widgets/bottom_sheet_selector.dart';"),
        ("import '../../../../models/profile.dart';", "import '../../../models/profile.dart';"),
    ],
}

count = 0

# Full file rewrites
for relpath, new_content in correct_imports.items():
    if new_content is None:
        continue
    fpath = os.path.join(base, relpath)
    if not os.path.exists(fpath):
        print(f"MISSING: {relpath}")
        continue
    with open(fpath, 'r', encoding='utf-8') as f:
        old_content = f.read()
    if old_content != new_content:
        with open(fpath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        count += 1
        print(f"REWRITTEN: {relpath}")
    else:
        print(f"OK: {relpath}")

# Partial fixes
for relpath, fixes_list in partial_fixes.items():
    fpath = os.path.join(base, relpath)
    if not os.path.exists(fpath):
        print(f"MISSING: {relpath}")
        continue
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
    for old, new in fixes_list:
        if old in content:
            content = content.replace(old, new)
            count += 1
    with open(fpath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"PARTIAL FIXED: {relpath}")

print(f"\nTotal changes: {count}")
