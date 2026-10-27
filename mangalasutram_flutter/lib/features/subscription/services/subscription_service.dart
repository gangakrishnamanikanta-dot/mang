import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/supabase_service.dart';
import '../models/subscription_status.dart';

class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._internal();
  SubscriptionService._internal() {
    initRealtimeListener();
  }

  final ValueNotifier<SubscriptionStatus?> statusNotifier =
      ValueNotifier<SubscriptionStatus?>(null);

  RealtimeChannel? _subChannel;

  /// Wipes active Realtime channels and in-memory status on sign out
  void reset() {
    if (_subChannel != null) {
      SupabaseService.client.removeChannel(_subChannel!);
      _subChannel = null;
    }
    statusNotifier.value = null;
    debugPrint('[SubscriptionService] In-memory subscription cache & channel reset');
  }

  /// Initializes live Realtime subscription on user_subscriptions and daily_user_quotas
  void initRealtimeListener() {
    final client = SupabaseService.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    if (_subChannel != null) {
      client.removeChannel(_subChannel!);
      _subChannel = null;
    }

    _subChannel = client
        .channel('public:realtime_subscription_sync:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_subscriptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('[SubscriptionService]: Realtime user_subscriptions update received -> Live sync');
            getMyStatus(forceRefresh: true);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'daily_user_quotas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('[SubscriptionService]: Realtime daily_user_quotas update received -> Live sync');
            getMyStatus(forceRefresh: true);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'contact_unlocks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('[SubscriptionService]: Realtime contact_unlocks update received -> Live sync');
            getMyStatus(forceRefresh: true);
          },
        )
        .subscribe();
  }

  Future<SubscriptionStatus> getMyStatus({bool forceRefresh = false}) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      final defaultStatus = SubscriptionStatus.defaultFree('');
      statusNotifier.value = defaultStatus;
      return defaultStatus;
    }

    if (!forceRefresh && statusNotifier.value != null) {
      return statusNotifier.value!;
    }

    try {
      final data = await SupabaseService.client.rpc(
        'get_user_membership_status',
        params: {'p_user_id': userId},
      );

      if (data is Map<String, dynamic>) {
        final status = SubscriptionStatus.fromJson(data);
        statusNotifier.value = status;
        return status;
      }
    } catch (e) {
      debugPrint('[SubscriptionService getMyStatus Error]: $e');
    }

    final fallback = SubscriptionStatus.defaultFree(userId);
    statusNotifier.value = fallback;
    return fallback;
  }

  Future<Map<String, dynamic>> unlockContact(String targetProfileId) async {
    try {
      final result = await SupabaseService.client.rpc(
        'unlock_contact_number',
        params: {'p_target_id': targetProfileId},
      );

      // Instantly refresh cached status and notify all UI listeners
      await getMyStatus(forceRefresh: true);

      if (result is Map<String, dynamic>) {
        return result;
      }
      return {'allowed': false, 'error': 'unknown'};
    } catch (e) {
      debugPrint('[SubscriptionService unlockContact Error]: $e');
      return {'allowed': false, 'error': e.toString()};
    }
  }

  Future<SubscriptionStatus> upgradeTier(
    SubscriptionTier tier, {
    int durationDays = 90,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    try {
      await SupabaseService.client.rpc(
        'set_user_subscription',
        params: {
          'p_user_id': userId,
          'p_tier': tier.dbValue,
          'p_duration_days': durationDays,
        },
      );

      final status = await getMyStatus(forceRefresh: true);
      return status;
    } catch (e) {
      debugPrint('[SubscriptionService upgradeTier Error]: $e');
      rethrow;
    }
  }
}
