import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../models/interest.dart';
import '../../auth/services/supabase_service.dart';

class InterestService {
  final SupabaseClient _client = SupabaseService.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AppAuthException('User is not authenticated.');
    }
    return user.id;
  }

  /// Sends an interest request to a user.
  /// Throws an exception if one already exists.
  Future<void> sendInterest(String receiverId) async {
    try {
      await _client
          .from('interests')
          .insert({
            'sender_profile_id': _userId,
            'receiver_profile_id': receiverId,
            'status': 'pending',
          })
          .timeout(const Duration(seconds: 15));
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Unique constraint violation
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

  /// Accepts a pending interest.
  Future<void> acceptInterest(String interestId) async {
    try {
      await _client
          .from('interests')
          .update({'status': 'accepted'})
          .eq('id', interestId)
          .eq(
            'receiver_profile_id',
            _userId,
          ) // enforced by RLS, added for safety
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Declines a pending interest.
  Future<void> declineInterest(String interestId) async {
    try {
      await _client
          .from('interests')
          .update({'status': 'declined'})
          .eq('id', interestId)
          .eq('receiver_profile_id', _userId)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Cancels (deletes) a pending interest sent by the current user.
  Future<void> cancelInterest(String interestId) async {
    try {
      await _client
          .from('interests')
          .delete()
          .eq('id', interestId)
          .eq('sender_profile_id', _userId)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Checks the relationship status between current user and target user.
  /// Returns the Interest if it exists, otherwise null.
  Future<Interest?> getInterestStatus(String targetUserId) async {
    try {
      final data = await _client
          .from('interests')
          .select()
          .or(
            'and(sender_profile_id.eq.$_userId,receiver_profile_id.eq.$targetUserId),and(sender_profile_id.eq.$targetUserId,receiver_profile_id.eq.$_userId)',
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
