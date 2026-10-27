import 'package:get_it/get_it.dart';
import '../features/auth/services/auth_service.dart';
import '../features/profile/services/profile_service.dart';
import '../features/interests/services/interest_service.dart';
import '../features/home/services/home_service.dart';
import '../features/messaging/services/chat_service.dart';
import '../features/messaging/services/e2ee_crypto_service.dart';
import '../features/shared/services/lookup_service.dart';
import '../features/profile/services/moderation_service.dart';
import '../features/notifications/services/notification_service.dart';
import '../features/notifications/services/device_token_service.dart';
import '../features/notifications/services/fcm_messaging_service.dart';

final GetIt getIt = GetIt.instance;

void configureDependencies() {
  getIt.registerLazySingleton<AuthService>(() => AuthService());
  getIt.registerLazySingleton<ProfileService>(() => ProfileService());
  getIt.registerLazySingleton<InterestService>(() => InterestService());
  getIt.registerLazySingleton<HomeService>(() => HomeService.instance);
  getIt.registerLazySingleton<ChatService>(() => ChatService());
  getIt.registerLazySingleton<E2eeCryptoService>(() => E2eeCryptoService());
  getIt.registerLazySingleton<LookupService>(() => LookupService());
  getIt.registerLazySingleton<ModerationService>(() => ModerationService());
  getIt.registerLazySingleton<NotificationService>(() => SupabaseNotificationService());
  getIt.registerLazySingleton<DeviceTokenService>(() => SupabaseDeviceTokenService());
  getIt.registerLazySingleton<FcmMessagingService>(() => DefaultFcmMessagingService());
}
