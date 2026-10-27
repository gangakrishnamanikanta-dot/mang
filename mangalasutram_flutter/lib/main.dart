import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'constants/theme.dart';
import 'core/di.dart';
import 'core/route_observer.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/services/supabase_service.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/auth/screens/otp_verification_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/auth/screens/reset_password_screen.dart';
import 'features/onboarding/screens/profile_builder_layout.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/profile/screens/partner_preferences_screen.dart';
import 'features/profile/screens/settings_screen.dart';
import 'features/subscription/screens/premium_tab.dart';
import 'features/home/screens/home_screen.dart';
import 'features/messaging/services/outbox_service.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/notifications/services/fcm_messaging_service.dart';
import 'features/notifications/services/notification_router.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Load environment variables from .env
  await dotenv.load(fileName: ".env");

  // 1. Initialize Supabase
  await SupabaseService.initialize();

  // 2. Wire up dependency injection BEFORE any widget touches a service
  configureDependencies();

  // 3. Initialize offline outbox connectivity monitor
  OutboxService.instance.initialize();

  // 4. Initialize FCM messaging service & tap handling
  final fcmService = getIt<FcmMessagingService>();
  await fcmService.initialize();
  fcmService.setNotificationTapHandler((data) {
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      NotificationRouter.navigateFromPayload(context, data);
    }
  });

  // Request notification permissions in background
  fcmService.requestPermission().catchError((e) {
    debugPrint('[main] Notification permission request error: $e');
    return false;
  });

  // Check if launched by tapping a push notification from terminated state
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final initialData = await fcmService.checkTerminatedLaunch();
    if (initialData != null && rootNavigatorKey.currentContext != null) {
      NotificationRouter.navigateFromPayload(rootNavigatorKey.currentContext!, initialData);
    }
  });

  runApp(const MangalasutramApp());
}

class MangalasutramApp extends StatelessWidget {
  const MangalasutramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return MaterialApp(
            navigatorKey: rootNavigatorKey,
            title: 'Mangalasutram',
            debugShowCheckedModeBanner: false,
            navigatorObservers: [routeObserver],
            theme: ThemeData(
              fontFamily: AppTypography.fontFamily,
              useMaterial3: false,
              primaryColor: AppColors.primary,
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                secondary: AppColors.secondary,
                surface: AppColors.surface,
              ),
              scaffoldBackgroundColor: AppColors.background,
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                centerTitle: true,
                titleTextStyle: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border, width: 1),
                  textStyle: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                hintStyle: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  color: AppColors.textSecondary,
                ),
              ),
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                },
              ),
            ),
            // Auth Router replaces static home: const LoginScreen()
            home: const AuthRouter(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignupScreen(),
              '/otp-verification': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                String contactInfo = '';
                String? password;
                String purpose = 'signup';
                bool isPhone = false;

                if (args is Map) {
                  contactInfo = args['email'] ?? args['phone'] ?? '';
                  password = args['password'];
                  purpose = args['purpose'] ?? 'signup';
                  isPhone = args['phone'] != null;
                } else if (args is String) {
                  contactInfo = args;
                }

                return OtpVerificationScreen(
                  contactInfo: contactInfo,
                  password: password,
                  purpose: purpose,
                  isPhone: isPhone,
                );
              },
              '/forgot-password': (context) => const ForgotPasswordScreen(),
              '/reset-password': (context) => const ResetPasswordScreen(),
              '/profile_builder': (context) => const ProfileBuilderLayout(),
              '/edit-profile': (context) => const EditProfileScreen(),
              '/partner-preferences': (context) =>
                  const EditPartnerPreferencesScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/plans': (context) => const PremiumTab(),
              '/home': (context) => const HomeScreen(),
              '/notifications': (context) => const NotificationCenterScreen(),
            },
          );
        },
      ),
    );
  }
}

/// AuthRouter: The single source of truth for where to send the user at startup.
///
/// - While AuthProvider is initializing → show SplashScreen (branding)
/// - Initialized + not authenticated → LoginScreen
/// - Authenticated + profile incomplete → ProfileBuilderLayout
/// - Authenticated + profile complete → HomeScreen
class AuthRouter extends StatelessWidget {
  const AuthRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.initialized) {
      return const SplashScreen();
    }

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    if (auth.hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                auth.errorMessage ?? "Couldn't load your profile.",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => auth.refreshProfile(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!auth.isProfileComplete) {
      return const ProfileBuilderLayout();
    }

    return const HomeScreen();
  }
}
