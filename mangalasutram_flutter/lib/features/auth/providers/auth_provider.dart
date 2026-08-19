import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  bool initialized = false;
  bool isAuthenticated = false;
  bool isProfileComplete = false;
  bool hasError = false;
  String? errorMessage;
  String? tempPassword; // Secure temporary transit for signup

  AuthProvider() {
    _checkAuth();
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.userDeleted) {
        isAuthenticated = false;
        hasError = false;
        errorMessage = null;
        isProfileComplete = false;
        tempPassword = null;
        notifyListeners();
      } else if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        _checkAuth();
      }
    });
  }

  Future<void> _checkAuth() async {
    try {
      hasError = false;
      errorMessage = null;

      final user = SupabaseService.client.auth.currentUser;
      isAuthenticated = user != null;
      if (isAuthenticated) {
        final profile = await getIt<AuthService>().getCurrentProfile();
        isProfileComplete = profile != null && profile.profileCompleted == true;
      }
    } catch (e) {
      hasError = true;
      errorMessage = "Couldn't load your profile.";
      debugPrint('[AuthProvider Error]: $e');
    } finally {
      initialized = true;
      notifyListeners();
    }
  }

  void setTempPassword(String password) {
    tempPassword = password;
  }

  void clearTempPassword() {
    tempPassword = null;
  }

  void clearSessionState() {
    tempPassword = null;
    isProfileComplete = false;
  }

  Future<void> refreshProfile() async {
    await _checkAuth();
  }
}
