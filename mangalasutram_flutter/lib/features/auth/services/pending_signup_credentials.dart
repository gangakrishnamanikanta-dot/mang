import 'package:flutter/foundation.dart';

/// Ephemeral in-memory store for pending signup credentials.
/// Prevents passing sensitive credentials (like passwords) through
/// route arguments where they could be logged by route observers,
/// crashlytics breadcrumbs, or retained in the navigation history.
class PendingSignupCredentials {
  PendingSignupCredentials._();
  static final PendingSignupCredentials instance = PendingSignupCredentials._();

  String? _password;
  DateTime? _storedAt;

  /// Holds the password in memory temporarily
  void storePassword(String password) {
    _password = password;
    _storedAt = DateTime.now();
  }

  /// Retrieves the password and immediately scrubs it from memory.
  /// Automatically expires after 10 minutes.
  String? retrieveAndClearPassword() {
    if (_storedAt != null && DateTime.now().difference(_storedAt!).inMinutes > 10) {
      debugPrint('[PendingSignupCredentials] Pending password expired in memory.');
      clear();
      return null;
    }
    final pwd = _password;
    clear();
    return pwd;
  }

  /// Scrubs the credentials immediately
  void clear() {
    _password = null;
    _storedAt = null;
  }
}
