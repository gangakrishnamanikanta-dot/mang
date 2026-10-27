import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../auth/services/supabase_service.dart';
import '../models/notification_item.dart';

/// Abstract service contract for all notification operations
abstract class NotificationService {
  /// Fetches paginated active notifications for the authenticated user
  Future<List<NotificationItem>> getActiveNotifications({
    int limit = 20,
    int offset = 0,
  });

  /// Marks a specific notification as read via secure server-side RPC
  Future<bool> markAsRead(String notificationId);

  /// Bulk marks all unread notifications for the user as read via RPC
  Future<int> markAllAsRead();

  /// Soft-deletes / dismisses a single notification via secure RPC
  Future<bool> dismissNotification(String notificationId);

  /// Bulk soft-deletes / dismisses all notifications via secure RPC
  Future<int> dismissAllNotifications();

  /// Gets the count of active unread notifications via fast index-backed RPC
  Future<int> getUnreadCount();

  /// Subscribes to user-scoped Realtime notification events (INSERT, UPDATE)
  RealtimeChannel? subscribeToUserNotifications(
    String userId, {
    required void Function(NotificationItem item) onInsert,
    required void Function(NotificationItem item) onUpdate,
  });

  /// Safely removes and unsubscribes a Realtime channel
  Future<void> unsubscribe(RealtimeChannel? channel);
}

/// Supabase RPC-mediated implementation of NotificationService.
/// Note: Enforces Zero Direct Client Table Writes (all modifications go through RPCs).
class SupabaseNotificationService implements NotificationService {
  final SupabaseClient? _clientOverride;

  SupabaseNotificationService({SupabaseClient? client})
      : _clientOverride = client;

  SupabaseClient get _client {
    return _clientOverride ?? SupabaseService.client;
  }

  void _verifyAuthenticated() {
    if (_client.auth.currentUser == null) {
      throw const AppException(
        'Authentication required to access notifications.',
        'AUTH_REQUIRED',
      );
    }
  }

  @override
  Future<List<NotificationItem>> getActiveNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    _verifyAuthenticated();

    // Bound limits to prevent excessive payloads
    final safeLimit = limit.clamp(1, 100);
    final safeOffset = offset < 0 ? 0 : offset;

    try {
      final response = await _client.rpc(
        'get_active_notifications',
        params: {
          'p_limit': safeLimit,
          'p_offset': safeOffset,
        },
      );

      if (response == null) return [];

      final list = response as List<dynamic>;
      return list
          .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('[NotificationService] getActiveNotifications error: ${e.message} (${e.code})');
      throw AppException(
        'Unable to load notifications. Please try again.',
        e.code,
      );
    } catch (e) {
      debugPrint('[NotificationService] Unexpected error: $e');
      throw const AppException('Failed to fetch notifications.');
    }
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    _verifyAuthenticated();

    try {
      final response = await _client.rpc(
        'mark_notification_as_read',
        params: {
          'p_notification_id': notificationId,
        },
      );

      return response == true;
    } on PostgrestException catch (e) {
      debugPrint('[NotificationService] markAsRead error: ${e.message}');
      throw AppException('Failed to mark notification as read.', e.code);
    } catch (e) {
      debugPrint('[NotificationService] markAsRead unexpected: $e');
      throw const AppException('Failed to update notification.');
    }
  }

  @override
  Future<int> markAllAsRead() async {
    _verifyAuthenticated();

    try {
      final response = await _client.rpc('mark_all_notifications_as_read');
      return (response as num?)?.toInt() ?? 0;
    } on PostgrestException catch (e) {
      debugPrint('[NotificationService] markAllAsRead error: ${e.message}');
      throw AppException('Failed to mark all as read.', e.code);
    } catch (e) {
      debugPrint('[NotificationService] markAllAsRead unexpected: $e');
      throw const AppException('Failed to update notifications.');
    }
  }

  @override
  Future<bool> dismissNotification(String notificationId) async {
    _verifyAuthenticated();

    try {
      final response = await _client.rpc(
        'dismiss_notification',
        params: {
          'p_notification_id': notificationId,
        },
      );

      return response == true;
    } on PostgrestException catch (e) {
      debugPrint('[NotificationService] dismissNotification error: ${e.message}');
      throw AppException('Failed to dismiss notification.', e.code);
    } catch (e) {
      debugPrint('[NotificationService] dismissNotification unexpected: $e');
      throw const AppException('Failed to dismiss notification.');
    }
  }

  @override
  Future<int> dismissAllNotifications() async {
    _verifyAuthenticated();

    try {
      final response = await _client.rpc('dismiss_all_notifications');
      return (response as num?)?.toInt() ?? 0;
    } on PostgrestException catch (e) {
      debugPrint('[NotificationService] dismissAllNotifications error: ${e.message}');
      throw AppException('Failed to clear notifications.', e.code);
    } catch (e) {
      debugPrint('[NotificationService] dismissAllNotifications unexpected: $e');
      throw const AppException('Failed to clear notifications.');
    }
  }

  @override
  Future<int> getUnreadCount() async {
    _verifyAuthenticated();

    try {
      final response = await _client.rpc('get_unread_notifications_count');
      return (response as num?)?.toInt() ?? 0;
    } on PostgrestException catch (e) {
      debugPrint('[NotificationService] getUnreadCount error: ${e.message}');
      // Fallback gracefully on query error
      return 0;
    } catch (e) {
      debugPrint('[NotificationService] getUnreadCount unexpected: $e');
      return 0;
    }
  }

  @override
  RealtimeChannel? subscribeToUserNotifications(
    String userId, {
    required void Function(NotificationItem item) onInsert,
    required void Function(NotificationItem item) onUpdate,
  }) {
    if (userId.isEmpty) return null;

    try {
      final channelName = 'user-notifications-$userId';
      final channel = _client.channel(channelName);

      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          try {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              final item = NotificationItem.fromJson(newRecord);
              if (!item.isDismissed) {
                onInsert(item);
              }
            }
          } catch (err) {
            debugPrint('[Realtime] Error parsing inserted notification: $err');
          }
        },
      );

      channel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          try {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              final item = NotificationItem.fromJson(newRecord);
              onUpdate(item);
            }
          } catch (err) {
            debugPrint('[Realtime] Error parsing updated notification: $err');
          }
        },
      );

      channel.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('[Realtime] Subscribed to notifications for user: $userId');
        } else if (status == RealtimeSubscribeStatus.timedOut ||
            status == RealtimeSubscribeStatus.channelError) {
          debugPrint('[Realtime] Notification channel status: $status ($error)');
        }
      });

      return channel;
    } catch (e) {
      debugPrint('[Realtime] Exception during channel subscription: $e');
      return null;
    }
  }

  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {
    if (channel != null) {
      try {
        await _client.removeChannel(channel);
        debugPrint('[Realtime] Successfully unsubscribed notification channel.');
      } catch (e) {
        debugPrint('[Realtime] Error unsubscribing channel: $e');
      }
    }
  }
}
