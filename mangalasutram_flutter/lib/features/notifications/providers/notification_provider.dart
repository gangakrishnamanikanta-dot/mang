import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di.dart';
import '../models/notification_item.dart';
import '../services/notification_service.dart';
import '../../auth/services/supabase_service.dart';

enum NotificationFilter { all, unreadOnly }

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service;

  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  NotificationFilter _filter = NotificationFilter.all;

  RealtimeChannel? _realtimeChannel;
  String? _subscribedUserId;
  StreamSubscription<AuthState>? _authSubscription;

  static const int pageSize = 20;

  NotificationProvider({NotificationService? service})
      : _service = service ?? getIt<NotificationService>() {
    _initAuthListener();
  }

  void _initAuthListener() {
    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser != null) {
      loadInitialNotifications();
      startRealtime(currentUser.id);
    }

    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        reset();
      } else if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        final userId = data.session?.user.id ?? SupabaseService.client.auth.currentUser?.id;
        if (userId != null && userId != _subscribedUserId) {
          loadInitialNotifications();
          startRealtime(userId);
        }
      }
    });
  }

  /// Wipes notifications and stops realtime sync on sign out
  void reset() {
    stopRealtime();
    _notifications = [];
    _unreadCount = 0;
    _isLoading = false;
    _isLoadingMore = false;
    _hasMore = true;
    _errorMessage = null;
    notifyListeners();
    debugPrint('[NotificationProvider] In-memory notifications wiped and realtime stopped');
  }

  // Getters
  List<NotificationItem> get notifications => List.unmodifiable(_notifications);

  List<NotificationItem> get filteredNotifications {
    if (_filter == NotificationFilter.unreadOnly) {
      return _notifications.where((n) => !n.isRead).toList();
    }
    return _notifications;
  }

  int get unreadCount => _unreadCount;

  /// Formatted unread badge text capped at 99+
  String get unreadBadgeText {
    if (_unreadCount <= 0) return '';
    if (_unreadCount > 99) return '99+';
    return _unreadCount.toString();
  }

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  NotificationFilter get currentFilter => _filter;

  void setFilter(NotificationFilter filter) {
    if (_filter != filter) {
      _filter = filter;
      notifyListeners();
    }
  }

  /// Initial load or pull-to-refresh
  Future<void> loadInitialNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    _hasMore = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getActiveNotifications(limit: pageSize, offset: 0),
        _service.getUnreadCount(),
      ]);

      final items = results[0] as List<NotificationItem>;
      final count = results[1] as int;

      _notifications = items;
      _unreadCount = count;
      _hasMore = items.length >= pageSize;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  /// Bounded incremental pagination
  Future<void> loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final newItems = await _service.getActiveNotifications(
        limit: pageSize,
        offset: _notifications.length,
      );

      if (newItems.isEmpty) {
        _hasMore = false;
      } else {
        // Deduplicate in case concurrent records arrived
        final existingIds = _notifications.map((n) => n.id).toSet();
        final distinctNew = newItems.where((n) => !existingIds.contains(n.id)).toList();

        _notifications.addAll(distinctNew);
        if (newItems.length < pageSize) {
          _hasMore = false;
        }
      }

      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isLoadingMore = false;
      debugPrint('[NotificationProvider] loadMoreNotifications error: $e');
      notifyListeners();
    }
  }

  /// Marks a notification as read with optimistic UI update
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;

    final existing = _notifications[index];
    if (existing.isRead) return; // Already read

    // Optimistic update
    _notifications[index] = existing.copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );
    if (_unreadCount > 0) {
      _unreadCount--;
    }
    notifyListeners();

    try {
      await _service.markAsRead(notificationId);
    } catch (e) {
      debugPrint('[NotificationProvider] Failed to mark as read on server: $e');
      // If server RPC failed, refresh count conservatively
      await refreshUnreadCount();
    }
  }

  /// Marks all active notifications as read
  Future<void> markAllAsRead() async {
    final hadUnread = _notifications.any((n) => !n.isRead);
    if (!hadUnread && _unreadCount == 0) return;

    // Optimistic update
    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true, readAt: DateTime.now()))
        .toList();
    _unreadCount = 0;
    notifyListeners();

    try {
      await _service.markAllAsRead();
    } catch (e) {
      debugPrint('[NotificationProvider] Failed to mark all as read on server: $e');
      await refreshUnreadCount();
    }
  }

  /// Dismisses / soft-deletes a notification
  Future<void> dismissNotification(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;

    final existing = _notifications[index];
    // Optimistic removal
    _notifications.removeAt(index);
    if (!existing.isRead && _unreadCount > 0) {
      _unreadCount--;
    }
    notifyListeners();

    try {
      await _service.dismissNotification(notificationId);
    } catch (e) {
      debugPrint('[NotificationProvider] Failed to dismiss notification on server: $e');
      // Rollback item if needed or refresh
      await refreshUnreadCount();
    }
  }

  /// Dismisses all notifications
  Future<void> dismissAll() async {
    if (_notifications.isEmpty) return;

    // Optimistic clear
    _notifications.clear();
    _unreadCount = 0;
    _hasMore = false;
    notifyListeners();

    try {
      await _service.dismissAllNotifications();
    } catch (e) {
      debugPrint('[NotificationProvider] Failed to dismiss all notifications on server: $e');
      await loadInitialNotifications();
    }
  }

  /// Refreshes unread count independently (e.g. after screen transitions)
  Future<void> refreshUnreadCount() async {
    try {
      final count = await _service.getUnreadCount();
      if (_unreadCount != count) {
        _unreadCount = count;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[NotificationProvider] refreshUnreadCount error: $e');
    }
  }

  /// Realtime lifecycle management
  void startRealtime(String userId) {
    if (userId.isEmpty || _subscribedUserId == userId) return;

    stopRealtime();
    _subscribedUserId = userId;

    _realtimeChannel = _service.subscribeToUserNotifications(
      userId,
      onInsert: (newItem) {
        // Prevent duplicate insertion
        if (!_notifications.any((n) => n.id == newItem.id)) {
          _notifications.insert(0, newItem);
          if (!newItem.isRead) {
            _unreadCount++;
          }
          notifyListeners();
        }
      },
      onUpdate: (updatedItem) {
        if (updatedItem.isDismissed) {
          // Soft-deleted item: remove from active view
          final idx = _notifications.indexWhere((n) => n.id == updatedItem.id);
          if (idx != -1) {
            final old = _notifications.removeAt(idx);
            if (!old.isRead && _unreadCount > 0) {
              _unreadCount--;
            }
            notifyListeners();
          }
        } else {
          // Updated state (e.g., isRead)
          final idx = _notifications.indexWhere((n) => n.id == updatedItem.id);
          if (idx != -1) {
            final old = _notifications[idx];
            _notifications[idx] = updatedItem;
            if (!old.isRead && updatedItem.isRead && _unreadCount > 0) {
              _unreadCount--;
            }
            notifyListeners();
          }
        }
      },
    );
  }

  void stopRealtime() {
    if (_realtimeChannel != null) {
      _service.unsubscribe(_realtimeChannel);
      _realtimeChannel = null;
      _subscribedUserId = null;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    stopRealtime();
    super.dispose();
  }
}
