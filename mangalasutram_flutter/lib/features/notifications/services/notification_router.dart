import 'package:flutter/material.dart';
import '../../interests/screens/interests_tab.dart';
import '../../messaging/screens/inbox_tab.dart';
import '../../subscription/screens/premium_tab.dart';

// UUID validation regex (RFC 4122)
final RegExp _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Safe, allowlisted navigation handler for push notification taps.
/// Enforces:
/// 1. Strict route allowlist (rejects arbitrary/external URI schemes).
/// 2. Identifier format validation (RFC 4122 UUID).
/// 3. Zero-Trust Access: Push payloads are hints only; target screens independently
///    enforce authentication and RLS ownership on data fetch.
class NotificationRouter {
  static const Set<String> allowedRoutes = {
    '/notifications',
    '/interests',
    '/plans',
    '/chat',
    '/profile',
    '/home',
  };

  /// Validates whether a route string is in the strict allowlist
  static bool isAllowedRoute(String? route) {
    if (route == null || route.isEmpty) return false;
    final normalized = route.trim().toLowerCase();
    return allowedRoutes.contains(normalized);
  }

  /// Validates that an identifier matches RFC 4122 UUID format
  static bool isValidId(String? id) {
    if (id == null || id.isEmpty) return false;
    return _uuidRegex.hasMatch(id.trim());
  }

  /// Dispatches navigation safely based on validated payload metadata
  static void navigateFromPayload(
    BuildContext context,
    Map<String, dynamic>? data,
  ) {
    if (data == null || data.isEmpty) {
      _navigateToDefault(context);
      return;
    }

    final rawRoute = data['route'] as String?;
    final targetId = data['id'] as String? ?? data['conversation_id'] as String?;

    if (!isAllowedRoute(rawRoute)) {
      debugPrint('[NotificationRouter] Disallowed or unmapped route: "$rawRoute". Falling back to Notification Center.');
      _navigateToDefault(context);
      return;
    }

    final route = rawRoute!.trim().toLowerCase();

    switch (route) {
      case '/notifications':
        _navigateToDefault(context);
        break;

      case '/interests':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: const Color(0xFFFAF6F0),
              appBar: AppBar(
                title: const Text('Alliance Interests'),
                backgroundColor: const Color(0xFFFAF6F0),
              ),
              body: const InterestsTab(),
            ),
          ),
        );
        break;

      case '/plans':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PremiumTab(),
          ),
        );
        break;

      case '/chat':
        // Safe navigation to chats inbox; destination screen authorizes conversation access
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: const Color(0xFFFAF6F0),
              appBar: AppBar(
                title: const Text('Conversations'),
                backgroundColor: const Color(0xFFFAF6F0),
              ),
              body: const InboxTab(),
            ),
          ),
        );
        break;

      case '/profile':
        // If valid profile UUID provided, fallback to notification center or profile view
        if (targetId != null && isValidId(targetId)) {
          _navigateToDefault(context);
        } else {
          _navigateToDefault(context);
        }
        break;

      default:
        _navigateToDefault(context);
    }
  }

  static void _navigateToDefault(BuildContext context) {
    Navigator.pushNamed(context, '/notifications');
  }
}
