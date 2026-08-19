import 'package:get_it/get_it.dart';
import '../features/auth/services/auth_service.dart';
import '../features/profile/services/profile_service.dart';
import '../features/interests/services/interest_service.dart';

/// Global service locator instance.
/// Usage: getIt<AuthService>() instead of AuthService()
final GetIt getIt = GetIt.instance;

/// Call this once at app startup (before runApp).
void configureDependencies() {
  // Auth Service
  getIt.registerLazySingleton<AuthService>(() => AuthService());

  // Profile Service — already a singleton internally, but registering here
  // makes it mockable in tests.
  getIt.registerLazySingleton<ProfileService>(() => ProfileService());

  // Interest Service
  getIt.registerLazySingleton<InterestService>(() => InterestService());
}
