import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mangalasutram/features/profile/screens/settings_screen.dart';

Widget createChangePasswordTestApp() {
  return const MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ChangePasswordSheet(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    dotenv.testLoad(mergeWith: {
      'SUPABASE_URL': 'https://test.supabase.co',
      'SUPABASE_PUBLISHABLE_KEY': 'testkey',
      'GOOGLE_WEB_CLIENT_ID': 'test-web',
      'GOOGLE_IOS_CLIENT_ID': 'test-ios',
    });
  });

  group('Change Password Sheet in Settings & Privacy Tests', () {
    testWidgets('Renders all 3 password fields with eye visibility toggles', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createChangePasswordTestApp());
      await tester.pumpAndSettle();

      // Verify title and description
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);

      // Verify 3 visibility toggle icons exist
      final eyeIcons = find.byIcon(CupertinoIcons.eye);
      expect(eyeIcons, findsNWidgets(3));
    });

    testWidgets('Validates empty current password field', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createChangePasswordTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your current password.'), findsOneWidget);
    });

    testWidgets('Validates short new password (< 8 chars)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createChangePasswordTestApp());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));

      await tester.enterText(textFields.at(0), 'OldPass123!');
      await tester.enterText(textFields.at(1), 'short');
      await tester.enterText(textFields.at(2), 'short');

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('New password must be at least 8 characters long.'), findsOneWidget);
    });

    testWidgets('Validates new password must be different from current password', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createChangePasswordTestApp());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'CurrentPassword123!');
      await tester.enterText(textFields.at(1), 'CurrentPassword123!');
      await tester.enterText(textFields.at(2), 'CurrentPassword123!');

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('New password must be different from current password.'), findsOneWidget);
    });

    testWidgets('Validates new password and confirm password mismatch', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createChangePasswordTestApp());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'OldPassword123!');
      await tester.enterText(textFields.at(1), 'BrandNewPassword123!');
      await tester.enterText(textFields.at(2), 'DifferentPassword123!');

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('New passwords do not match.'), findsOneWidget);
    });
  });
}
