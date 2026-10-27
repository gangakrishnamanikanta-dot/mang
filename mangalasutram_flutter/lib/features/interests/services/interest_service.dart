import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../models/interest.dart';
import '../../auth/services/supabase_service.dart';

class InterestService {
  final SupabaseClient _client = SupabaseService.client;
  final ValueNotifier<int> interestsRefreshTrigger = ValueNotifier<int>(0);

  void notifyInterestsChanged() {
    interestsRefreshTrigger.value++;
  }

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AppAuthException('User is not authenticated.');
    }
    return user.id;
  }

  /// Sends an interest request to a user with quota check.
  Future<Map<String, dynamic>> sendInterest(String receiverId) async {
    try {
      final result = await _client.rpc(
        'send_interest_with_quota',
        params: {'p_receiver_id': receiverId},
      );

      if (result is Map<String, dynamic>) {
        if (result['success'] == false) {
          if (result['error'] == 'quota_exceeded') {
            throw QuotaExceededException(
              tier: result['tier']?.toString() ?? 'free',
              limit: (result['limit'] as num?)?.toInt() ?? 5,
              message: result['message']?.toString() ??
                  'Daily limit of interests reached.',
            );
          }
          if (result['error'] == 'unauthenticated') {
            throw const AppAuthException('User is not authenticated.');
          }
          throw ServerException(
            result['message']?.toString() ?? 'Failed to send interest.',
            result['error']?.toString() ?? 'unknown',
          );
        }
      }

      notifyInterestsChanged();
      return result as Map<String, dynamic>;
    } on QuotaExceededException {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ServerException(
          'You\'ve already sent an interest to this profile.',
          'duplicate',
        );
      }
      throw AppException.from(e);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Gets interests sent BY the current user.
  Future<List<Interest>> getSentInterests({
    String? status,
    String? lastCreatedAt,
    String? lastId,
    int limit = 20,
  }) async {
    try {
      var query = _client
          .from('interests')
          .select()
          .eq('sender_profile_id', _userId);

      if (status != null && status != 'All') {
        query = query.eq('status', status.toLowerCase());
      }

      if (lastCreatedAt != null && lastId != null) {
        query = query.or('created_at.lt.$lastCreatedAt,and(created_at.eq.$lastCreatedAt,id.lt.$lastId)');
      }

      final data = await query
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      if (data.isEmpty) return [];

      final receiverIds = data
          .map((e) => e['receiver_profile_id'] as String)
          .toList();
      final profilesData = await _client
          .from('public_profiles')
          .select()
          .inFilter('id', receiverIds);

      final profilesMap = {for (var p in profilesData) p['id'] as String: p};

      return data.map((json) {
        final receiverId = json['receiver_profile_id'] as String;
        json['profiles'] = profilesMap[receiverId]; // Inject so fromJson works
        return Interest.fromJson(json);
      }).toList();
    } catch (e) {
      debugPrint('[InterestService getSentInterests Error]: $e');
      throw AppException.from(e);
    }
  }

  /// Gets interests received BY the current user.
  Future<List<Interest>> getReceivedInterests({
    String? status,
    String? lastCreatedAt,
    String? lastId,
    int limit = 20,
  }) async {
    try {
      var query = _client
          .from('interests')
          .select()
          .eq('receiver_profile_id', _userId);

      if (status != null && status != 'All') {
        query = query.eq('status', status.toLowerCase());
      }

      if (lastCreatedAt != null && lastId != null) {
        query = query.or('created_at.lt.$lastCreatedAt,and(created_at.eq.$lastCreatedAt,id.lt.$lastId)');
      }

      final data = await query
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      if (data.isEmpty) return [];

      final senderIds = data
          .map((e) => e['sender_profile_id'] as String)
          .toList();
      final profilesData = await _client
          .from('public_profiles')
          .select()
          .inFilter('id', senderIds);

      final profilesMap = {for (var p in profilesData) p['id'] as String: p};

      return data.map((json) {
        final senderId = json['sender_profile_id'] as String;
        json['profiles'] = profilesMap[senderId]; // Inject so fromJson works
        return Interest.fromJson(json);
      }).toList();
    } catch (e) {
      debugPrint('[InterestService getReceivedInterests Error]: $e');
      throw AppException.from(e);
    }
  }

  /// Accepts a pending interest using secure atomic RPC (and unlocks mutual chat).
  Future<void> acceptInterest(String interestId) async {
    try {
      final res = await _client.rpc(
        'respond_to_interest',
        params: {'p_interest_id': interestId, 'p_action': 'accepted'},
      );
      if (res is Map<String, dynamic> && res['success'] == false) {
        throw ServerException(
          res['message']?.toString() ?? 'Failed to accept interest.',
          res['error']?.toString() ?? 'unknown',
        );
      }
      notifyInterestsChanged();
    } catch (e) {
      debugPrint('[InterestService acceptInterest Error]: $e');
      throw AppException.from(e);
    }
  }

  /// Declines a pending interest using secure atomic RPC.
  Future<void> declineInterest(String interestId) async {
    try {
      final res = await _client.rpc(
        'respond_to_interest',
        params: {'p_interest_id': interestId, 'p_action': 'declined'},
      );
      if (res is Map<String, dynamic> && res['success'] == false) {
        throw ServerException(
          res['message']?.toString() ?? 'Failed to decline interest.',
          res['error']?.toString() ?? 'unknown',
        );
      }
      notifyInterestsChanged();
    } catch (e) {
      debugPrint('[InterestService declineInterest Error]: $e');
      throw AppException.from(e);
    }
  }

  /// Cancels (withdraws) a pending interest sent by the current user.
  Future<void> cancelInterest(String interestId) async {
    try {
      final res = await _client.rpc(
        'cancel_sent_interest',
        params: {'p_interest_id': interestId},
      );
      if (res is Map<String, dynamic> && res['success'] == false) {
        throw ServerException(
          res['message']?.toString() ?? 'Failed to cancel interest.',
          res['error']?.toString() ?? 'unknown',
        );
      }
      notifyInterestsChanged();
    } catch (e) {
      debugPrint('[InterestService cancelInterest Error]: $e');
      throw AppException.from(e);
    }
  }

  /// Toggles shortlist (bookmark) on a target profile. Returns true if shortlisted, false if un-shortlisted.
  Future<bool> toggleShortlist(String targetProfileId) async {
    try {
      final res = await _client.rpc(
        'toggle_shortlist',
        params: {'p_target_id': targetProfileId},
      );
      if (res is Map<String, dynamic> && res['success'] == true) {
        notifyInterestsChanged();
        return res['is_shortlisted'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[InterestService toggleShortlist Error]: $e');
      throw AppException.from(e);
    }
  }

  /// Fetches shortlisted candidate profiles with match scores and details.
  Future<List<Map<String, dynamic>>> getMyShortlists({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final res = await _client.rpc(
        'get_my_shortlists',
        params: {'p_limit': limit, 'p_offset': offset},
      );
      if (res is List) {
        return List<Map<String, dynamic>>.from(res.map((e) => Map<String, dynamic>.from(e as Map)));
      }
      return [];
    } catch (e) {
      debugPrint('[InterestService getMyShortlists Error]: $e');
      throw AppException.from(e);
    }
  }

  /// Checks the relationship status between current user (or linked candidate) and target user.
  /// Returns the Interest if it exists, otherwise null.
  Future<Interest?> getInterestStatus(String targetUserId, {String? onBehalfOf}) async {
    try {
      final effectiveId = (onBehalfOf != null && onBehalfOf.isNotEmpty)
          ? onBehalfOf
          : _userId;
      final data = await _client
          .from('interests')
          .select()
          .or(
            'and(sender_profile_id.eq.$effectiveId,receiver_profile_id.eq.$targetUserId),and(sender_profile_id.eq.$targetUserId,receiver_profile_id.eq.$effectiveId)',
          )
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (data != null) {
        return Interest.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('[InterestService getInterestStatus Error]: $e');
      throw AppException.from(e);
    }
  }
}
