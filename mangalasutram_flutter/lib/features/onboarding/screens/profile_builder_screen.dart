// This file is DEPRECATED.
// The Profile Builder was fully modularised into:
//   lib/screens/profile/profile_builder_layout.dart
//   lib/screens/profile/steps/step1_basic_info.dart  through step7_review.dart
//
// This file is kept only to prevent import errors from any remaining references.
// DO NOT use this screen. Use ProfileBuilderLayout instead.

import 'package:flutter/material.dart';

class ProfileBuilderScreen extends StatelessWidget {
  const ProfileBuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'ProfileBuilderScreen is deprecated. Use ProfileBuilderLayout.',
        ),
      ),
    );
  }
}
