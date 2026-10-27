import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di.dart';
import '../../../models/profile.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../../subscription/services/subscription_service.dart';
import '../../notifications/services/fcm_messaging_service.dart';
import '../../home/services/home_service.dart';
import '../../messaging/services/e2ee_crypto_service.dart';

class AuthProvider extends ChangeNotifier {
  bool initialized = false;
  bool isAuthenticated = false;
  bool isProfileComplete = false;
  bool hasError = false;
  String? errorMessage;
  // tempPassword is intentionally NOT stored here anymore.
  // It is passed via Navigator route arguments to keep it scoped
  // to the navigation stack and not the global provider heap.

  RealtimeChannel? _authChannel;

  AuthProvider() {
    _checkAuth();
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        _handleLoggedOut();
      } else if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        _checkAuth();
      }
    });
  }

  void _handleLoggedOut() {
    _authChannel?.unsubscribe();
    _authChannel = null;
    isAuthenticated = false;
    hasError = false;
    errorMessage = null;
    isProfileComplete = false;
    try {
      HomeService.instance.invalidateCache();
    } catch (_) {}
    try {
      SubscriptionService.instance.reset();
    } catch (_) {}
    try {
      getIt<E2eeCryptoService>().clearKeys();
    } catch (_) {}
    getIt<FcmMessagingService>().handleSignOut().catchError((_) => false);
    notifyListeners();
  }

  Future<void> _checkAuth() async {
    try {
      hasError = false;
      errorMessage = null;

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        _handleLoggedOut();
        return;
      }

      // Fetch profile — may be null if the user was mid-signup when the app crashed
      Profile? profile;
      try {
        profile = await getIt<AuthService>().getCurrentProfile();
      } catch (e) {
        debugPrint('[AuthProvider]: Profile fetch error: $e');
      }

      if (profile == null) {
        // The auth session is valid but the profiles row does not exist yet.
        // This happens when the app crashes between auth.signUp() and
        // profiles.upsert(). Do NOT force-logout — instead let the router
        // send the user back to onboarding so they can complete registration.
        debugPrint('[AuthProvider]: Authenticated user has no profile row -> routing to onboarding');
        isAuthenticated = true;
        isProfileComplete = false;
        initialized = true;
        getIt<FcmMessagingService>().syncDeviceToken(userId: user.id).catchError((e) {
          debugPrint('[AuthProvider] Error syncing FCM device token: $e');
          return null;
        });
        notifyListeners();
        return;
      }

      if (profile.isSuspended) {
        debugPrint('[AuthProvider]: Authenticated user is suspended -> logging out');
        errorMessage = 'Your account has been suspended: ${profile.suspensionReason ?? "Please contact support@mangalasutram.in"}';
        hasError = true;
        await forceLogout();
        notifyListeners();
        return;
      }

      isAuthenticated = true;
      isProfileComplete = profile.isGuardian || profile.profileCompleted == true;
      _initRealtimeAuthCheck(user.id);
      SubscriptionService.instance.initRealtimeListener();

      // Sync FCM device token for the verified active session
      getIt<FcmMessagingService>().syncDeviceToken(userId: user.id).catchError((e) {
        debugPrint('[AuthProvider] Error syncing FCM device token: $e');
        return null;
      });
    } catch (e) {
      debugPrint('[AuthProvider Error]: $e');
      // If error indicates unauthenticated / invalid user, logout
      await forceLogout();
    } finally {
      initialized = true;
      notifyListeners();
    }
  }

  void _initRealtimeAuthCheck(String userId) {
    try {
      _authChannel?.unsubscribe();
      _authChannel = SupabaseService.client
          .channel('public:auth_user_lifecycle:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: userId,
            ),
            callback: (payload) {
              if (payload.eventType == PostgresChangeEvent.delete) {
                debugPrint('[AuthProvider Realtime]: User deleted on server -> Instant auto logout');
                forceLogout();
              } else if (payload.eventType == PostgresChangeEvent.update) {
                final isSuspended = payload.newRecord['is_suspended'] == true;
                if (isSuspended) {
                  debugPrint('[AuthProvider Realtime]: User suspended on server -> Instant auto logout');
                  errorMessage = 'Your account has been suspended by administration.';
                  hasError = true;
                  forceLogout();
                }
              }
            },
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> forceLogout() async {
    try {
      await getIt<AuthService>().signOut();
    } catch (_) {}
    _handleLoggedOut();
  }

  void clearSessionState() {
    isProfileComplete = false;
  }

  Future<void> refreshProfile() async {
    await _checkAuth();
  }

  @override
  void dispose() {
    _authChannel?.unsubscribe();
    super.dispose();
  }
}
