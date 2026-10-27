import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../config/firebase_options.dart';
import '../../../core/di.dart';
import 'device_token_service.dart';

/// Top-level background message handler for FCM.
/// Executed in an isolated background thread when the application is backgrounded or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('[FCM Background] Firebase initialization skipped or already present: $e');
  }

  // Notice: Private end-to-end encrypted chat message text is never logged or exposed.
  debugPrint('[FCM Background] Received push notification ID: ${message.messageId}, type: ${message.data['notification_type']}');
}

/// Abstract contract for Firebase Cloud Messaging operations
abstract class FcmMessagingService {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<String?> syncDeviceToken({required String userId});
  Future<bool> handleSignOut();
  Future<Map<String, dynamic>?> checkTerminatedLaunch();
  void setForegroundHandler(void Function(RemoteMessage message) handler);
  void setNotificationTapHandler(void Function(Map<String, dynamic> data) handler);
  void dispose();
}

/// Production implementation of FcmMessagingService.
/// Integrates with FirebaseMessaging and DeviceTokenService.
class DefaultFcmMessagingService implements FcmMessagingService {
  final FirebaseMessaging? _messagingOverride;
  final DeviceTokenService _deviceTokenService;
  final Stream<RemoteMessage>? _onMessageStreamOverride;
  final Stream<RemoteMessage>? _onMessageOpenedAppStreamOverride;
  final Stream<String>? _onTokenRefreshStreamOverride;
  final Future<String?> Function()? _getTokenOverride;
  final Future<void> Function()? _deleteTokenOverride;

  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;
  StreamSubscription<String>? _onTokenRefreshSubscription;

  void Function(RemoteMessage message)? _foregroundHandler;
  void Function(Map<String, dynamic> data)? _notificationTapHandler;

  String? _currentToken;
  String? _lastUserId;
  bool _isInitialized = false;
  Future<void>? _activeQueue;

  DefaultFcmMessagingService({
    FirebaseMessaging? messaging,
    DeviceTokenService? deviceTokenService,
    Stream<RemoteMessage>? onMessageStream,
    Stream<RemoteMessage>? onMessageOpenedAppStream,
    Stream<String>? onTokenRefreshStream,
    Future<String?> Function()? getTokenOverride,
    Future<void> Function()? deleteTokenOverride,
  })  : _messagingOverride = messaging,
        _deviceTokenService = deviceTokenService ?? getIt<DeviceTokenService>(),
        _onMessageStreamOverride = onMessageStream,
        _onMessageOpenedAppStreamOverride = onMessageOpenedAppStream,
        _onTokenRefreshStreamOverride = onTokenRefreshStream,
        _getTokenOverride = getTokenOverride,
        _deleteTokenOverride = deleteTokenOverride;

  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;

  Stream<RemoteMessage> get _onMessageStream =>
      _onMessageStreamOverride ?? FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get _onMessageOpenedAppStream =>
      _onMessageOpenedAppStreamOverride ?? FirebaseMessaging.onMessageOpenedApp;

  Stream<String> get _onTokenRefreshStream =>
      _onTokenRefreshStreamOverride ?? _messaging.onTokenRefresh;

  bool get _isTestEnvironment =>
      _messagingOverride != null ||
      _onTokenRefreshStreamOverride != null ||
      _getTokenOverride != null ||
      _deleteTokenOverride != null;

  /// Serializes asynchronous state transitions (login, logout, refresh)
  /// to guarantee strict FIFO order and prevent race conditions.
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final prev = _activeQueue;
    final completer = Completer<T>();

    _activeQueue = () async {
      try {
        if (prev != null) await prev;
      } catch (_) {}
      try {
        final res = await action();
        completer.complete(res);
      } catch (err, st) {
        completer.completeError(err, st);
      }
    }();

    return completer.future;
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!_isTestEnvironment) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
      } catch (e) {
        debugPrint('[FcmMessagingService] Firebase.initializeApp note: $e');
      }

      if (!kIsWeb) {
        try {
          FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        } catch (e) {
          debugPrint('[FcmMessagingService] onBackgroundMessage note: $e');
        }
      }
    }

    _setupListeners();
    _isInitialized = true;
  }

  void _setupListeners() {
    // 1. Cancel any prior listeners to guarantee zero duplicates
    _onMessageSubscription?.cancel();
    _onMessageOpenedAppSubscription?.cancel();
    _onTokenRefreshSubscription?.cancel();

    // 2. Foreground notifications
    _onMessageSubscription = _onMessageStream.listen((RemoteMessage message) {
      debugPrint('[FcmMessagingService] Foreground notification received: ${message.messageId}');
      if (_foregroundHandler != null) {
        _foregroundHandler!(message);
      }
    });

    // 3. Resumed app from background tap
    _onMessageOpenedAppSubscription =
        _onMessageOpenedAppStream.listen((RemoteMessage message) {
      debugPrint('[FcmMessagingService] Notification tap resumed app: ${message.messageId}');
      if (_notificationTapHandler != null) {
        _notificationTapHandler!(message.data);
      }
    });

    // 4. Token refresh listener (serialized to preserve auth ordering)
    _onTokenRefreshSubscription = _onTokenRefreshStream.listen((String newToken) {
      _enqueue(() async {
        debugPrint('[FcmMessagingService] FCM token refreshed: ${maskFcmToken(newToken)}');
        _currentToken = newToken;
        if (_lastUserId != null && _lastUserId!.isNotEmpty) {
          await _registerTokenOnBackend(newToken, _lastUserId!);
        }
      });
    });
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      debugPrint('[FcmMessagingService] Push permission status: ${settings.authorizationStatus}');
      return granted;
    } catch (e) {
      debugPrint('[FcmMessagingService] Error requesting notification permissions: $e');
      return false;
    }
  }

  @override
  Future<String?> syncDeviceToken({required String userId}) {
    return _enqueue(() async {
      if (userId.isEmpty) {
        debugPrint('[FcmMessagingService] Cannot sync token: userId is empty.');
        return null;
      }

      final isAccountSwitch = _lastUserId != null && _lastUserId != userId;
      if (isAccountSwitch) {
        debugPrint('[FcmMessagingService] Account switch detected ($_lastUserId -> $userId).');
        // Security Directives:
        // 1. Do NOT attempt to call remove_device_token here. The RPC executes under auth.uid() = userId (the new user),
        //    which CANNOT delete the previous user's record (WHERE user_id = auth.uid() will not match _lastUserId).
        // 2. In PostgreSQL, register_device_token handles atomic reassignment via
        //    ON CONFLICT (fcm_token) DO UPDATE SET user_id = EXCLUDED.user_id.
        // 3. If registration fails during an account switch, we invalidate the local token via _deleteLocalToken()
        //    so that the device will never receive push notifications intended for the previous user.
      }

      try {
        final token = _getTokenOverride != null
            ? await _getTokenOverride()
            : await _messaging.getToken();

        if (token == null || token.isEmpty) {
          debugPrint('[FcmMessagingService] FCM token unavailable on current platform/environment.');
          if (isAccountSwitch) {
            await _deleteLocalToken();
            _currentToken = null;
          }
          return null;
        }

        final tokenId = await _registerTokenOnBackend(token, userId);
        if (tokenId != null) {
          _currentToken = token;
          _lastUserId = userId;
          return tokenId;
        } else {
          debugPrint('[FcmMessagingService] Token registration failed for user $userId.');
          if (isAccountSwitch) {
            // Failed re-registration during account switch: invalidate local token
            // so device stops receiving notifications from prior user.
            await _deleteLocalToken();
            _currentToken = null;
          }
          return null;
        }
      } catch (e) {
        debugPrint('[FcmMessagingService] Error syncing device token: $e');
        if (isAccountSwitch) {
          await _deleteLocalToken();
          _currentToken = null;
        }
        return null;
      }
    });
  }

  Future<String?> _registerTokenOnBackend(String token, String userId) async {
    String platformStr = 'android';
    if (!kIsWeb) {
      if (Platform.isIOS) {
        platformStr = 'ios';
      } else if (Platform.isAndroid) {
        platformStr = 'android';
      }
    } else {
      platformStr = 'web';
    }

    final deviceInfo = {
      'is_web': kIsWeb,
      'platform': platformStr,
      'synced_at': DateTime.now().toIso8601String(),
    };

    return await _deviceTokenService.registerToken(
      fcmToken: token,
      platform: platformStr,
      deviceInfo: deviceInfo,
    );
  }

  @override
  Future<bool> handleSignOut() {
    return _enqueue(() async {
      bool unlinkedSuccessfully = false;
      final tokenToRemove = _currentToken ??
          (_getTokenOverride != null ? await _getTokenOverride() : null);

      if (tokenToRemove != null && tokenToRemove.isNotEmpty) {
        debugPrint('[FcmMessagingService] User signing out. Unregistering FCM token: ${maskFcmToken(tokenToRemove)}');
        try {
          unlinkedSuccessfully = await _deviceTokenService.removeToken(fcmToken: tokenToRemove);
        } catch (e) {
          debugPrint('[FcmMessagingService] Error unregistering token on logout: $e');
          unlinkedSuccessfully = false;
        }

        // Invalidate token locally so device no longer receives push messages
        await _deleteLocalToken();
      }

      _currentToken = null;
      _lastUserId = null;
      return unlinkedSuccessfully;
    });
  }

  Future<void> _deleteLocalToken() async {
    try {
      if (_deleteTokenOverride != null) {
        await _deleteTokenOverride();
      } else if (!_isTestEnvironment) {
        await _messaging.deleteToken();
      }
    } catch (e) {
      debugPrint('[FcmMessagingService] Error deleting local FCM token: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> checkTerminatedLaunch() async {
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FcmMessagingService] App launched from terminated state via notification: ${initialMessage.messageId}');
        return initialMessage.data;
      }
    } catch (e) {
      debugPrint('[FcmMessagingService] Error checking initial terminated message: $e');
    }
    return null;
  }

  @override
  void setForegroundHandler(void Function(RemoteMessage message) handler) {
    _foregroundHandler = handler;
  }

  @override
  void setNotificationTapHandler(void Function(Map<String, dynamic> data) handler) {
    _notificationTapHandler = handler;
  }

  @override
  void dispose() {
    _onMessageSubscription?.cancel();
    _onMessageOpenedAppSubscription?.cancel();
    _onTokenRefreshSubscription?.cancel();
    _foregroundHandler = null;
    _notificationTapHandler = null;
  }
}
