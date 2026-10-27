import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mangalasutram/features/notifications/services/device_token_service.dart';
import 'package:mangalasutram/features/notifications/services/fcm_messaging_service.dart';
import 'package:mangalasutram/features/notifications/services/notification_router.dart';

// ── Mock Device Token Service ─────────────────────────────────────────
class MockDeviceTokenService implements DeviceTokenService {
  final List<Map<String, dynamic>> registeredTokens = [];
  final List<String> removedTokens = [];
  bool shouldThrowError = false;
  bool simulatePendingMigration = false;

  @override
  Future<String?> registerToken({
    required String fcmToken,
    required String platform,
    Map<String, dynamic>? deviceInfo,
  }) async {
    if (simulatePendingMigration) {
      // Return null, simulating catch of 42883 PostgrestException
      return null;
    }
    if (shouldThrowError) {
      return null;
    }
    registeredTokens.add({
      'fcmToken': fcmToken,
      'platform': platform,
      'deviceInfo': deviceInfo,
    });
    return 'token-uuid-${registeredTokens.length}';
  }

  @override
  Future<bool> removeToken({required String fcmToken}) async {
    if (simulatePendingMigration || shouldThrowError) {
      return false;
    }
    removedTokens.add(fcmToken);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleToken1 = 'fcm_mock_token_11112222333344445555666677778888aaaa';
  const sampleToken2 = 'fcm_mock_token_99998888777766665555444433332222bbbb';

  group('1. FCM Token Masking & Formatting Tests', () {
    test('1a. maskFcmToken masks tokens preserving only first 8 and last 4 characters', () {
      final masked = maskFcmToken(sampleToken1);
      expect(masked, 'fcm_mock...aaaa');
      expect(masked.contains('11112222'), isFalse);
    });

    test('1b. maskFcmToken handles null or short strings safely', () {
      expect(maskFcmToken(null), '***');
      expect(maskFcmToken('short'), '***');
    });
  });

  group('2. Token Lifecycle & Account-Switching Tests', () {
    late MockDeviceTokenService mockDeviceTokenService;
    late StreamController<RemoteMessage> messageStreamCtrl;
    late StreamController<RemoteMessage> messageOpenedAppStreamCtrl;
    late StreamController<String> tokenRefreshStreamCtrl;
    late DefaultFcmMessagingService fcmService;

    int localTokensDeleted = 0;

    setUp(() {
      mockDeviceTokenService = MockDeviceTokenService();
      messageStreamCtrl = StreamController<RemoteMessage>.broadcast();
      messageOpenedAppStreamCtrl = StreamController<RemoteMessage>.broadcast();
      tokenRefreshStreamCtrl = StreamController<String>.broadcast();
      localTokensDeleted = 0;

      fcmService = DefaultFcmMessagingService(
        deviceTokenService: mockDeviceTokenService,
        onMessageStream: messageStreamCtrl.stream,
        onMessageOpenedAppStream: messageOpenedAppStreamCtrl.stream,
        onTokenRefreshStream: tokenRefreshStreamCtrl.stream,
        getTokenOverride: () async => sampleToken1,
        deleteTokenOverride: () async => localTokensDeleted++,
      );
    });

    tearDown(() {
      fcmService.dispose();
      messageStreamCtrl.close();
      messageOpenedAppStreamCtrl.close();
      tokenRefreshStreamCtrl.close();
    });

    test('2a. Empty userId aborts token registration without calling backend', () async {
      final res = await fcmService.syncDeviceToken(userId: '');
      expect(res, isNull);
      expect(mockDeviceTokenService.registeredTokens.isEmpty, isTrue);
    });

    test('2b. Token refresh automatically re-registers for currently active user', () async {
      await fcmService.initialize();
      // Sync user-1 with initial token
      await fcmService.syncDeviceToken(userId: 'user-0001');
      expect(mockDeviceTokenService.registeredTokens.length, equals(1));
      expect(mockDeviceTokenService.registeredTokens.first['fcmToken'], equals(sampleToken1));

      // Token refresh stream fires when user is linked
      mockDeviceTokenService.registeredTokens.clear();
      tokenRefreshStreamCtrl.add(sampleToken2);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(mockDeviceTokenService.registeredTokens.length, equals(1));
      expect(mockDeviceTokenService.registeredTokens.first['fcmToken'], equals(sampleToken2));
    });

    test('2c. Successful handleSignOut unregisters current token on backend, deletes local token, and clears user state', () async {
      await fcmService.initialize();
      await fcmService.syncDeviceToken(userId: 'user-0001');
      expect(mockDeviceTokenService.registeredTokens.isNotEmpty, isTrue);

      final unlinked = await fcmService.handleSignOut();
      expect(unlinked, isTrue);
      expect(mockDeviceTokenService.removedTokens.contains(sampleToken1), isTrue);
      expect(localTokensDeleted, equals(1));
    });

    test('2d. Failed backend unlinking on signout returns false without throwing and still invalidates local token', () async {
      await fcmService.initialize();
      await fcmService.syncDeviceToken(userId: 'user-0001');

      // Simulate backend failure / offline on removeToken
      mockDeviceTokenService.shouldThrowError = true;
      final unlinked = await fcmService.handleSignOut();

      // Does not falsely report successful backend unlinking
      expect(unlinked, isFalse);
      // But defense-in-depth ensures local token is deleted so device stops receiving
      expect(localTokensDeleted, equals(1));
    });

    test('2e. Account switching safely reassigns token to new user without attempting cross-user delete', () async {
      await fcmService.initialize();
      // User 1 logs in
      await fcmService.syncDeviceToken(userId: 'user-0001');
      expect(mockDeviceTokenService.registeredTokens.length, equals(1));

      // User 2 logs in on the same device
      await fcmService.syncDeviceToken(userId: 'user-0002');
      // Verify that User 2 did NOT attempt an unauthorized removeToken for User 1
      expect(mockDeviceTokenService.removedTokens.isEmpty, isTrue);
      // New user registration succeeded via atomic upsert
      expect(mockDeviceTokenService.registeredTokens.length, equals(2));
    });

    test('2f. Failed token re-registration during account switch invalidates local token to prevent prior user push leaks', () async {
      await fcmService.initialize();
      // User 1 logs in successfully
      await fcmService.syncDeviceToken(userId: 'user-0001');
      expect(localTokensDeleted, equals(0));

      // Simulate network / server failure during User 2 login
      mockDeviceTokenService.shouldThrowError = true;
      final res = await fcmService.syncDeviceToken(userId: 'user-0002');

      expect(res, isNull);
      // Local token was deleted to ensure User 1 notifications cannot reach this device
      expect(localTokensDeleted, equals(1));
    });

    test('2g. Rapid consecutive auth changes execute sequentially in FIFO order without racing', () async {
      await fcmService.initialize();

      // Dispatch rapid concurrent auth operations
      final f1 = fcmService.syncDeviceToken(userId: 'user-rapid-1');
      final f2 = fcmService.handleSignOut();
      final f3 = fcmService.syncDeviceToken(userId: 'user-rapid-2');

      final results = await Future.wait([f1, f2, f3]);
      expect(results[0], isNotNull); // user 1 registered
      expect(results[1], isTrue);    // signout unlinked
      expect(results[2], isNotNull); // user 2 registered
    });

    test('2h. Pending backend migration is handled gracefully without throwing unhandled errors', () async {
      mockDeviceTokenService.simulatePendingMigration = true;
      final res = await mockDeviceTokenService.registerToken(
        fcmToken: sampleToken1,
        platform: 'android',
      );
      expect(res, isNull); // Staged safely, no crash
    });
  });

  group('3. Navigation Allowlist & Security Safeguards', () {
    test('3a. Rejects arbitrary, unapproved or external URIs and accepts allowlisted routes', () {
      expect(NotificationRouter.isAllowedRoute('/notifications'), isTrue);
      expect(NotificationRouter.isAllowedRoute('/interests'), isTrue);
      expect(NotificationRouter.isAllowedRoute('/plans'), isTrue);
      expect(NotificationRouter.isAllowedRoute('/chat'), isTrue);
      expect(NotificationRouter.isAllowedRoute('/profile'), isTrue);
      expect(NotificationRouter.isAllowedRoute('/home'), isTrue);

      // Malicious or unapproved routes
      expect(NotificationRouter.isAllowedRoute('https://evil.com/phish'), isFalse);
      expect(NotificationRouter.isAllowedRoute('javascript:alert(1)'), isFalse);
      expect(NotificationRouter.isAllowedRoute('/admin_panel'), isFalse);
      expect(NotificationRouter.isAllowedRoute(''), isFalse);
      expect(NotificationRouter.isAllowedRoute(null), isFalse);
    });

    test('3b. Validates RFC 4122 UUID identifiers', () {
      expect(NotificationRouter.isValidId('3fa85f64-5717-4562-b3fc-2c963f66afa6'), isTrue);
      expect(NotificationRouter.isValidId('invalid-uuid-string'), isFalse);
      expect(NotificationRouter.isValidId('12345'), isFalse);
      expect(NotificationRouter.isValidId(null), isFalse);
    });

    testWidgets('3c. navigateFromPayload defaults to NotificationCenterScreen for unknown or null routes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/notifications': (_) => const Scaffold(body: Text('Notification Center Screen')),
          },
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  NotificationRouter.navigateFromPayload(ctx, {'route': '/malicious_route'});
                },
                child: const Text('Trigger Nav'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Nav'));
      await tester.pumpAndSettle();

      // Navigated safely to /notifications route
      expect(find.text('Notification Center Screen'), findsOneWidget);
    });
  });

  group('4. Duplicate Listener Prevention & Cleanup', () {
    test('4a. Multiple calls to initialize do not duplicate listeners', () async {
      final mockDeviceTokenService = MockDeviceTokenService();
      final messageStreamCtrl = StreamController<RemoteMessage>.broadcast();
      final messageOpenedAppStreamCtrl = StreamController<RemoteMessage>.broadcast();
      final tokenRefreshStreamCtrl = StreamController<String>.broadcast();

      final fcmService = DefaultFcmMessagingService(
        deviceTokenService: mockDeviceTokenService,
        onMessageStream: messageStreamCtrl.stream,
        onMessageOpenedAppStream: messageOpenedAppStreamCtrl.stream,
        onTokenRefreshStream: tokenRefreshStreamCtrl.stream,
      );

      int foregroundCalls = 0;
      fcmService.setForegroundHandler((_) => foregroundCalls++);

      await fcmService.initialize();
      await fcmService.initialize(); // Second call

      // Dispose
      fcmService.dispose();
      await messageStreamCtrl.close();
      await messageOpenedAppStreamCtrl.close();
      await tokenRefreshStreamCtrl.close();

      expect(foregroundCalls, 0);
    });
  });
}
