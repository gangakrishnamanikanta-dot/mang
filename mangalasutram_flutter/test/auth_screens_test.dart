import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mangalasutram/features/auth/screens/splash_screen.dart';
import 'package:mangalasutram/features/auth/screens/login_screen.dart';
import 'package:mangalasutram/features/auth/screens/signup_screen.dart';
import 'package:mangalasutram/features/auth/screens/otp_verification_screen.dart';
import 'package:mangalasutram/features/auth/screens/widgets/password_strength_indicator.dart';
import 'package:mangalasutram/core/di.dart';
import 'package:mangalasutram/features/auth/services/auth_service.dart';
import 'package:mangalasutram/models/profile.dart';

class MockAuthService implements AuthService {
  @override
  Future<void> signOut() async {}

  @override
  Future<Profile?> getCurrentProfile() async => null;

  @override
  Future<void> signInWithGoogle() async {}
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

  group('Splash Screen Tests', () {
    testWidgets('SplashScreen renders title, subtitle and animations smoothly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      // Verify title and subtitle exist in widget tree
      expect(find.text('MANGALASUTRAM'), findsOneWidget);
      expect(find.text('Sacred Matrimony'), findsOneWidget);

      // Advance animation frames
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('MANGALASUTRAM'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('MANGALASUTRAM'), findsOneWidget);
    });
  });

  group('Auth Validation and Logic Unit Tests', () {
    test('Email regex correctly identifies valid and invalid emails', () {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

      expect(emailRegex.hasMatch('test@mangalasutram.com'), isTrue);
      expect(emailRegex.hasMatch('user.name+tag@domain.co.in'), isTrue);
      expect(emailRegex.hasMatch('plainaddress'), isFalse);
      expect(emailRegex.hasMatch('@missingusername.com'), isFalse);
      expect(emailRegex.hasMatch('username@.com'), isFalse);
    });

    test('Indian phone sanitization and regex validates correctly', () {
      final indianPhoneRegex = RegExp(r'^[6-9]\d{9}$');

      String sanitizePhone(String raw) {
        String clean = raw.replaceAll(RegExp(r'[\s\-()]'), '');
        if (clean.startsWith('0')) clean = clean.substring(1);
        if (clean.startsWith('+91')) {
          clean = clean.substring(3);
        } else if (clean.startsWith('91') && clean.length == 12) {
          clean = clean.substring(2);
        }
        return clean;
      }

      // Valid numbers
      expect(indianPhoneRegex.hasMatch(sanitizePhone('9876543210')), isTrue);
      expect(indianPhoneRegex.hasMatch(sanitizePhone('+91 98765 43210')), isTrue);
      expect(indianPhoneRegex.hasMatch(sanitizePhone('09876543210')), isTrue);
      expect(indianPhoneRegex.hasMatch(sanitizePhone('+91-81234-56789')), isTrue);
      expect(indianPhoneRegex.hasMatch(sanitizePhone('917012345678')), isTrue);

      // Invalid numbers
      expect(indianPhoneRegex.hasMatch(sanitizePhone('1234567890')), isFalse);
      expect(indianPhoneRegex.hasMatch(sanitizePhone('5555555555')), isFalse);
      expect(indianPhoneRegex.hasMatch(sanitizePhone('98765')), isFalse);
      expect(indianPhoneRegex.hasMatch(sanitizePhone('9876543210999')), isFalse);
    });

    test('Friendly auth error mapping handles all expected Supabase error messages', () {
      String friendlyAuthMessage(String raw) {
        final lower = raw.toLowerCase();
        if (lower.contains('invalid login credentials') || lower.contains('invalid')) {
          return 'Incorrect email or password';
        }
        if (lower.contains('email not confirmed')) {
          return 'Please verify your email first';
        }
        if (lower.contains('too many requests') || lower.contains('rate limit')) {
          return 'Too many attempts. Please wait and try again';
        }
        if (lower.contains('user not found')) {
          return 'No account found with this email';
        }
        return raw;
      }

      expect(friendlyAuthMessage('Invalid login credentials provided'), 'Incorrect email or password');
      expect(friendlyAuthMessage('Email not confirmed by user'), 'Please verify your email first');
      expect(friendlyAuthMessage('too many requests: rate limit exceeded'), 'Too many attempts. Please wait and try again');
      expect(friendlyAuthMessage('User not found in system'), 'No account found with this email');
      expect(friendlyAuthMessage('Custom error'), 'Custom error');
    });

    testWidgets('PasswordStrengthIndicator calculates correct strength tiers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PasswordStrengthIndicator(password: 'short'),
                PasswordStrengthIndicator(password: 'simplepass123'),
                PasswordStrengthIndicator(password: 'Vedic#Secure2026!'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Weak (minimum 8 characters)'), findsOneWidget);
      expect(find.text('Moderate (add numbers / symbols)'), findsOneWidget);
      expect(find.text('Strong password'), findsOneWidget);
    });
  });

  group('Login Screen Widget Tests', () {
    testWidgets('LoginScreen toggles between Email and Mobile modes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Default state: Email mode
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Register Now'), findsOneWidget);

      // Switch to Mobile mode
      await tester.tap(find.text('Mobile'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your mobile number'), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);
      expect(find.text('Enter your email'), findsNothing);
      expect(find.text('Enter your password'), findsNothing);

      // Switch back to Email mode
      await tester.tap(find.text('Email'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('Password visibility toggle toggles obscure state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      final visibilityOffFinder = find.byIcon(Icons.visibility_off);
      expect(visibilityOffFinder, findsOneWidget);

      await tester.tap(visibilityOffFinder);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });
  });

  group('Signup Screen Widget Tests', () {
    testWidgets('SignupScreen renders all fields, T&C and age checkboxes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignupScreen(),
        ),
      );

      expect(find.text('Create Sacred Profile'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Create Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('I am 18+ and agree to the '), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });
  });

  group('OTP Verification Screen Widget Tests', () {
    testWidgets('OtpVerificationScreen renders 6 pin input boxes and countdown timer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OtpVerificationScreen(
            contactInfo: 'dev@mangalasutram.in',
            purpose: 'signup',
          ),
        ),
      );

      expect(find.text('Verification'), findsOneWidget);
      expect(find.text('Enter 6-Digit Code'), findsOneWidget);
      expect(find.textContaining('dev@mangalasutram.in'), findsOneWidget);
      expect(find.text('Verify Code'), findsOneWidget);

      // Verify 6 OTP TextFields
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(6));
    });
  });
}
