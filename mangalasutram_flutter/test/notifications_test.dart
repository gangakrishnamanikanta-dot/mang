import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mangalasutram/core/exceptions/app_exception.dart';
import 'package:mangalasutram/features/notifications/models/notification_item.dart';
import 'package:mangalasutram/features/notifications/services/notification_service.dart';
import 'package:mangalasutram/features/notifications/providers/notification_provider.dart';
import 'package:mangalasutram/features/notifications/widgets/notification_badge.dart';
import 'package:mangalasutram/features/notifications/widgets/notification_card.dart';
import 'package:mangalasutram/features/notifications/screens/notifications_screen.dart';

// ── Mock Notification Service ─────────────────────────────────────────
class MockNotificationService implements NotificationService {
  List<NotificationItem> mockNotifications = [];
  int mockUnreadCount = 0;
  bool shouldThrowError = false;
  String errorMessage = 'Simulated RPC failure';

  final List<String> markedReadIds = [];
  final List<String> dismissedIds = [];
  bool markAllCalled = false;
  bool dismissAllCalled = false;

  void Function(NotificationItem)? onInsertCallback;
  void Function(NotificationItem)? onUpdateCallback;
  bool unsubscribed = false;

  @override
  Future<List<NotificationItem>> getActiveNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    if (shouldThrowError) {
      throw AppException(errorMessage, 'SIMULATED_RPC_ERROR');
    }
    if (offset >= mockNotifications.length) {
      return [];
    }
    final end = (offset + limit < mockNotifications.length)
        ? offset + limit
        : mockNotifications.length;
    return mockNotifications.sublist(offset, end);
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    if (shouldThrowError) throw AppException(errorMessage, 'SIMULATED_RPC_ERROR');
    markedReadIds.add(notificationId);
    return true;
  }

  @override
  Future<int> markAllAsRead() async {
    if (shouldThrowError) throw AppException(errorMessage, 'SIMULATED_RPC_ERROR');
    markAllCalled = true;
    final count = mockNotifications.where((n) => !n.isRead).length;
    return count;
  }

  @override
  Future<bool> dismissNotification(String notificationId) async {
    if (shouldThrowError) throw AppException(errorMessage, 'SIMULATED_RPC_ERROR');
    dismissedIds.add(notificationId);
    return true;
  }

  @override
  Future<int> dismissAllNotifications() async {
    if (shouldThrowError) throw AppException(errorMessage, 'SIMULATED_RPC_ERROR');
    dismissAllCalled = true;
    return mockNotifications.length;
  }

  @override
  Future<int> getUnreadCount() async {
    if (shouldThrowError) throw AppException(errorMessage, 'SIMULATED_RPC_ERROR');
    return mockUnreadCount;
  }

  @override
  RealtimeChannel? subscribeToUserNotifications(
    String userId, {
    required void Function(NotificationItem item) onInsert,
    required void Function(NotificationItem item) onUpdate,
  }) {
    onInsertCallback = onInsert;
    onUpdateCallback = onUpdate;
    return null; // Mock channel
  }

  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {
    unsubscribed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  NotificationItem createTestItem({
    required String id,
    String type = 'interest_received',
    String title = 'New Interest Received',
    String body = 'Ananya Sharma expressed interest in your profile.',
    bool isRead = false,
    DateTime? createdAt,
    Map<String, dynamic>? payload,
  }) {
    return NotificationItem(
      id: id,
      userId: 'user-uuid-1234',
      category: NotificationCategory.fromString(type),
      rawType: type,
      title: title,
      body: body,
      payload: payload ?? {'route': '/interests', 'id': 'int_1'},
      isRead: isRead,
      readAt: isRead ? DateTime.now() : null,
      isDismissed: false,
      dismissedAt: null,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  group('1. NotificationItem Model Tests', () {
    test('1a. Deserializes from Supabase public.notifications schema correctly', () {
      final json = {
        'id': 'notif-uuid-1',
        'user_id': 'user-uuid-1',
        'type': 'high_guna_milan',
        'title': 'High Guna Milan Match (32/36)',
        'body': 'Vedic compatibility score calculated with Priyamvada.',
        'payload': {'route': '/guna_milan', 'score': 32},
        'is_read': false,
        'read_at': null,
        'is_dismissed': false,
        'dismissed_at': null,
        'created_at': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
      };

      final item = NotificationItem.fromJson(json);

      expect(item.id, 'notif-uuid-1');
      expect(item.userId, 'user-uuid-1');
      expect(item.category, NotificationCategory.highGunaMilan);
      expect(item.title, 'High Guna Milan Match (32/36)');
      expect(item.isRead, isFalse);
      expect(item.isDismissed, isFalse);
      expect(item.targetRoute, '/guna_milan');
      expect(item.timeAgo, '15m ago');
    });

    test('1b. Maps Vedic matrimonial categories to distinct icons and colors', () {
      expect(NotificationCategory.interestReceived.icon, Icons.favorite_rounded);
      expect(NotificationCategory.interestReceived.iconColor, const Color(0xFF6E1732));

      expect(NotificationCategory.highGunaMilan.icon, Icons.auto_awesome_rounded);
      expect(NotificationCategory.highGunaMilan.iconColor, const Color(0xFFC99A4B));

      expect(NotificationCategory.chatMessage.icon, Icons.chat_bubble_rounded);
      expect(NotificationCategory.quotaExhausted.icon, Icons.hourglass_bottom_rounded);
    });

    test('1c. Serializes to JSON cleanly preserving database column conventions', () {
      final item = createTestItem(id: 'test-1', isRead: true);
      final json = item.toJson();

      expect(json['id'], 'test-1');
      expect(json['type'], 'interest_received');
      expect(json['is_read'], isTrue);
      expect(json['is_dismissed'], isFalse);
    });
  });

  group('2. NotificationProvider State Management Tests', () {
    late MockNotificationService mockService;
    late NotificationProvider provider;

    setUp(() {
      mockService = MockNotificationService();
      provider = NotificationProvider(service: mockService);
    });

    test('2a. Initial load populates notifications, unread count, and sets hasMore', () async {
      mockService.mockNotifications = List.generate(
        25,
        (i) => createTestItem(id: 'item-$i', isRead: i >= 5),
      );
      mockService.mockUnreadCount = 5;

      expect(provider.isLoading, isFalse);
      await provider.loadInitialNotifications();

      expect(provider.isLoading, isFalse);
      expect(provider.notifications.length, 20); // First page
      expect(provider.unreadCount, 5);
      expect(provider.unreadBadgeText, '5');
      expect(provider.hasMore, isTrue);
      expect(provider.errorMessage, isNull);
    });

    test('2b. Bounded incremental pagination loads next page and completes', () async {
      mockService.mockNotifications = List.generate(
        25,
        (i) => createTestItem(id: 'item-$i'),
      );
      mockService.mockUnreadCount = 25;

      await provider.loadInitialNotifications();
      expect(provider.notifications.length, 20);
      expect(provider.hasMore, isTrue);

      await provider.loadMoreNotifications();
      expect(provider.notifications.length, 25);
      expect(provider.hasMore, isFalse); // All loaded
    });

    test('2c. Unread badge formats capped 99+ display when count > 99', () async {
      mockService.mockNotifications = [];
      mockService.mockUnreadCount = 120;

      await provider.loadInitialNotifications();
      expect(provider.unreadCount, 120);
      expect(provider.unreadBadgeText, '99+');
    });

    test('2d. Unread filter returns only unread items', () async {
      mockService.mockNotifications = [
        createTestItem(id: '1', isRead: false),
        createTestItem(id: '2', isRead: true),
        createTestItem(id: '3', isRead: false),
      ];
      mockService.mockUnreadCount = 2;

      await provider.loadInitialNotifications();
      expect(provider.notifications.length, 3);
      expect(provider.filteredNotifications.length, 3);

      provider.setFilter(NotificationFilter.unreadOnly);
      expect(provider.filteredNotifications.length, 2);
      expect(provider.filteredNotifications.every((n) => !n.isRead), isTrue);

      provider.setFilter(NotificationFilter.all);
      expect(provider.filteredNotifications.length, 3);
    });

    test('2e. Optimistic markAsRead updates local state and decrements unread count', () async {
      mockService.mockNotifications = [
        createTestItem(id: 'target-1', isRead: false),
        createTestItem(id: 'target-2', isRead: false),
      ];
      mockService.mockUnreadCount = 2;

      await provider.loadInitialNotifications();
      expect(provider.unreadCount, 2);

      await provider.markAsRead('target-1');

      expect(provider.notifications.firstWhere((n) => n.id == 'target-1').isRead, isTrue);
      expect(provider.unreadCount, 1);
      expect(mockService.markedReadIds, contains('target-1'));
    });

    test('2f. Optimistic markAllAsRead marks all items read and resets unread count to 0', () async {
      mockService.mockNotifications = [
        createTestItem(id: '1', isRead: false),
        createTestItem(id: '2', isRead: false),
      ];
      mockService.mockUnreadCount = 2;

      await provider.loadInitialNotifications();
      await provider.markAllAsRead();

      expect(provider.unreadCount, 0);
      expect(provider.notifications.every((n) => n.isRead), isTrue);
      expect(mockService.markAllCalled, isTrue);
    });

    test('2g. Optimistic dismissNotification removes item from list and calls RPC', () async {
      mockService.mockNotifications = [
        createTestItem(id: 'dismiss-me', isRead: false),
        createTestItem(id: 'keep-me', isRead: false),
      ];
      mockService.mockUnreadCount = 2;

      await provider.loadInitialNotifications();
      await provider.dismissNotification('dismiss-me');

      expect(provider.notifications.any((n) => n.id == 'dismiss-me'), isFalse);
      expect(provider.notifications.length, 1);
      expect(provider.unreadCount, 1);
      expect(mockService.dismissedIds, contains('dismiss-me'));
    });

    test('2h. Optimistic dismissAll clears list and resets count', () async {
      mockService.mockNotifications = [
        createTestItem(id: '1'),
        createTestItem(id: '2'),
      ];
      mockService.mockUnreadCount = 2;

      await provider.loadInitialNotifications();
      await provider.dismissAll();

      expect(provider.notifications.isEmpty, isTrue);
      expect(provider.unreadCount, 0);
      expect(mockService.dismissAllCalled, isTrue);
    });

    test('2i. Realtime insert prepends new notification and increments unread count', () async {
      mockService.mockNotifications = [createTestItem(id: 'existing-1', isRead: true)];
      mockService.mockUnreadCount = 0;

      await provider.loadInitialNotifications();
      provider.startRealtime('user-uuid-1234');

      final realtimeItem = createTestItem(id: 'realtime-new', isRead: false);
      mockService.onInsertCallback!(realtimeItem);

      expect(provider.notifications.first.id, 'realtime-new');
      expect(provider.unreadCount, 1);
      expect(provider.unreadBadgeText, '1');
    });

    test('2j. Realtime update handles soft-deletion and read state transition', () async {
      final initialItem = createTestItem(id: 'item-update', isRead: false);
      mockService.mockNotifications = [initialItem];
      mockService.mockUnreadCount = 1;

      await provider.loadInitialNotifications();
      provider.startRealtime('user-uuid-1234');

      // 1. Updated to read
      final readUpdate = initialItem.copyWith(isRead: true, readAt: DateTime.now());
      mockService.onUpdateCallback!(readUpdate);
      expect(provider.notifications.first.isRead, isTrue);
      expect(provider.unreadCount, 0);

      // 2. Updated to dismissed (soft-deleted)
      final dismissedUpdate = readUpdate.copyWith(isDismissed: true);
      mockService.onUpdateCallback!(dismissedUpdate);
      expect(provider.notifications.isEmpty, isTrue);
    });

    test('2k. RPC error sets errorMessage and maintains resilient state without crashing', () async {
      mockService.shouldThrowError = true;
      mockService.errorMessage = 'Network connection failed.';

      await provider.loadInitialNotifications();
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, contains('Network connection failed'));
      expect(provider.notifications.isEmpty, isTrue);
    });
  });

  group('3. Widget Tests: NotificationBadge & NotificationCard', () {
    testWidgets('3a. NotificationBadge displays unread count and caps at 99+', (tester) async {
      final mockService = MockNotificationService();
      mockService.mockUnreadCount = 105;
      final provider = NotificationProvider(service: mockService);
      await provider.loadInitialNotifications();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<NotificationProvider>.value(
            value: provider,
            child: const Scaffold(
              body: Center(
                child: NotificationBadge(),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(NotificationBadge), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
    });

    testWidgets('3b. NotificationBadge hides badge pill when unread count is 0', (tester) async {
      final mockService = MockNotificationService();
      mockService.mockUnreadCount = 0;
      final provider = NotificationProvider(service: mockService);
      await provider.loadInitialNotifications();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<NotificationProvider>.value(
            value: provider,
            child: const Scaffold(
              body: Center(
                child: NotificationBadge(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('0'), findsNothing);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    });

    testWidgets('3c. NotificationCard displays title, body, and dismiss action triggers callback', (tester) async {
      final item = createTestItem(
        id: 'card-1',
        title: 'New Alliance Interest',
        body: 'Aditya Varma sent you an interest request.',
        isRead: false,
      );

      NotificationItem? tappedItem;
      NotificationItem? dismissedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationCard(
              item: item,
              onTap: (it) => tappedItem = it,
              onDismiss: (it) => dismissedItem = it,
            ),
          ),
        ),
      );

      expect(find.text('New Alliance Interest'), findsOneWidget);
      expect(find.text('Aditya Varma sent you an interest request.'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      // Tap card
      await tester.tap(find.text('New Alliance Interest'));
      expect(tappedItem?.id, 'card-1');

      // Tap dismiss icon button
      await tester.tap(find.byTooltip('Dismiss'));
      expect(dismissedItem?.id, 'card-1');
    });
  });

  group('4. Widget Tests: NotificationCenterScreen', () {
    testWidgets('4a. NotificationCenterScreen renders empty state when no notifications', (tester) async {
      final mockService = MockNotificationService();
      mockService.mockNotifications = [];
      mockService.mockUnreadCount = 0;
      final provider = NotificationProvider(service: mockService);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<NotificationProvider>.value(
            value: provider,
            child: const NotificationCenterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('All Caught Up'), findsOneWidget);
      expect(find.text('All (0)'), findsOneWidget);
      expect(find.text('Unread (0)'), findsOneWidget);
    });

    testWidgets('4b. NotificationCenterScreen renders error state and provides working retry button', (tester) async {
      final mockService = MockNotificationService();
      mockService.shouldThrowError = true;
      mockService.errorMessage = 'Database RPC unavailable';
      final provider = NotificationProvider(service: mockService);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<NotificationProvider>.value(
            value: provider,
            child: const NotificationCenterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Notifications'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      // Fix error and tap retry
      mockService.shouldThrowError = false;
      mockService.mockNotifications = [createTestItem(id: 'retry-recovered')];
      mockService.mockUnreadCount = 1;

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Notifications'), findsNothing);
      expect(find.text('New Interest Received'), findsOneWidget);
    });

    testWidgets('4c. NotificationCenterScreen switches between All and Unread filter tabs', (tester) async {
      final mockService = MockNotificationService();
      mockService.mockNotifications = [
        createTestItem(id: '1', title: 'Unread Notification', isRead: false),
        createTestItem(id: '2', title: 'Read Notification', isRead: true),
      ];
      mockService.mockUnreadCount = 1;
      final provider = NotificationProvider(service: mockService);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<NotificationProvider>.value(
            value: provider,
            child: const NotificationCenterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unread Notification'), findsOneWidget);
      expect(find.text('Read Notification'), findsOneWidget);

      // Tap "Unread (1)"
      await tester.tap(find.text('Unread (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Unread Notification'), findsOneWidget);
      expect(find.text('Read Notification'), findsNothing);

      // Tap "All (2)"
      await tester.tap(find.text('All (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Unread Notification'), findsOneWidget);
      expect(find.text('Read Notification'), findsOneWidget);
    });
  });
}
