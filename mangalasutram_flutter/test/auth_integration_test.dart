import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:mangalasutram/features/auth/screens/signup_screen.dart';
import 'package:mangalasutram/features/auth/screens/forgot_password_screen.dart';
import 'package:mangalasutram/features/auth/screens/reset_password_screen.dart';
import 'package:mangalasutram/features/auth/screens/otp_verification_screen.dart';
import 'package:mangalasutram/core/di.dart';
import 'package:mangalasutram/features/auth/services/auth_service.dart';
import 'package:mangalasutram/features/auth/providers/auth_provider.dart';
import 'package:mangalasutram/models/profile.dart';

class MockAuthService implements AuthService {
  @override
  Future<void> signOut() async {}

  @override
  Future<Profile?> getCurrentProfile() async => null;

  @override
  Future<void> signInWithGoogle() async {}
}

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool initialized = true;
  @override
  bool isAuthenticated = false;
  @override
  bool isProfileComplete = false;
  @override
  bool hasError = false;
  @override
  String? errorMessage;

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<void> forceLogout() async {}

  @override
  void clearSessionState() {}
}

Widget createTestApp(Widget child, {Map<String, dynamic>? routeArgs}) {
  return ChangeNotifierProvider<AuthProvider>(
    create: (_) => MockAuthProvider(),
    child: MaterialApp(
      home: Scaffold(body: child),
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: RouteSettings(arguments: routeArgs),
          builder: (context) => child,
        );
      },
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

    if (getIt.isRegistered<AuthService>()) {
      getIt.unregister<AuthService>();
    }
    getIt.registerLazySingleton<AuthService>(() => MockAuthService());
  });

  group('Signup Screen Comprehensive Validation Tests', () {
    testWidgets('Empty fields trigger validation error SnackBar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const SignupScreen()));

      await tester.ensureVisible(find.text('Register'));
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your full name'), findsOneWidget);
    });

    testWidgets('Invalid email format triggers validation error', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const SignupScreen()));

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(4));

      await tester.enterText(textFields.at(0), 'Krishna Sharma');
      await tester.enterText(textFields.at(1), 'invalid-email');

      await tester.ensureVisible(find.text('Register'));
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('Short password triggers password length validation error', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const SignupScreen()));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Krishna Sharma');
      await tester.enterText(textFields.at(1), 'krishna@mangalasutram.in');
      await tester.enterText(textFields.at(2), '12345');

      await tester.ensureVisible(find.text('Register'));
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 8 characters long'), findsOneWidget);
    });

    testWidgets('Password mismatch triggers confirm password validation error', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const SignupScreen()));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Krishna Sharma');
      await tester.enterText(textFields.at(1), 'krishna@mangalasutram.in');
      await tester.enterText(textFields.at(2), 'VedicPassword123!');
      await tester.enterText(textFields.at(3), 'DifferentPassword123!');

      await tester.ensureVisible(find.text('Register'));
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match. Please re-check.'), findsOneWidget);
    });

    testWidgets('Missing Terms and Age agreements trigger mandatory consent validation error', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const SignupScreen()));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Krishna Sharma');
      await tester.enterText(textFields.at(1), 'krishna@mangalasutram.in');
      await tester.enterText(textFields.at(2), 'VedicPassword123!');
      await tester.enterText(textFields.at(3), 'VedicPassword123!');

      await tester.ensureVisible(find.text('Register'));
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('Please agree to the Terms & Conditions and Privacy Policy'), findsOneWidget);
    });
  });

  group('Forgot and Reset Password Flow Tests', () {
    testWidgets('Forgot Password rejects empty email input', (tester) async {
      await tester.pumpWidget(createTestApp(const ForgotPasswordScreen()));

      await tester.tap(find.text('Send Reset Code'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email address'), findsOneWidget);
    });

    testWidgets('Forgot Password rejects invalid email address', (tester) async {
      await tester.pumpWidget(createTestApp(const ForgotPasswordScreen()));

      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.tap(find.text('Send Reset Code'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('Reset Password requires matching passwords and minimum 8 characters', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => MockAuthProvider(),
          child: MaterialApp(
            initialRoute: '/reset',
            routes: {
              '/reset': (context) => const ResetPasswordScreen(),
            },
            onGenerateInitialRoutes: (initialRoute) {
              return [
                MaterialPageRoute(
                  settings: const RouteSettings(
                    name: '/reset',
                    arguments: {'email': 'user@mangalasutram.in', 'code': '123456'},
                  ),
                  builder: (context) => const ResetPasswordScreen(),
                ),
              ];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2)); // New password, Confirm new password

      // Test short password
      await tester.enterText(textFields.at(0), 'pass');
      await tester.ensureVisible(find.text('Update Password'));
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();
      expect(find.text('Password must be at least 8 characters'), findsOneWidget);

      // Test mismatch
      await tester.enterText(textFields.at(0), 'SecurePass123!');
      await tester.enterText(textFields.at(1), 'OtherPass123!');
      await tester.ensureVisible(find.text('Update Password'));
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });

  group('OTP Verification Advanced Functionality Tests', () {
    testWidgets('OTP screen renders all 6 boxes properly and accepts input', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const OtpVerificationScreen(
            contactInfo: 'verify@mangalasutram.in',
            purpose: 'signup',
          ),
        ),
      );

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(6));

      // Enter digits into each box
      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), '${i + 1}');
        await tester.pump();
      }

      expect(find.byType(OtpVerificationScreen), findsOneWidget);
    });
  });
}
