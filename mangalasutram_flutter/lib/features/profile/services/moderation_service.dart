import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../auth/services/supabase_service.dart';

class BlockedUser {
  final String id;
  final String fullName;
  final String? city;
  final String? state;
  final String? profilePhotoUrl;
  final DateTime blockedAt;

  const BlockedUser({
    required this.id,
    required this.fullName,
    this.city,
    this.state,
    this.profilePhotoUrl,
    required this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Member',
      city: json['city'] as String?,
      state: json['state'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      blockedAt: DateTime.tryParse(json['blocked_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ModerationService {
  final SupabaseClient? _customClient;

  ModerationService([SupabaseClient? client]) : _customClient = client;

  SupabaseClient get _client => _customClient ?? SupabaseService.client;

  /// Blocks another user atomically, severing mutual match cache and interests.
  Future<void> blockUser(String profileId, {String reason = 'User blocked'}) async {
    try {
      final res = await _client.rpc(
        'block_user',
        params: {
          'p_blocked_id': profileId,
          'p_reason': reason,
        },
      );
      if (res is Map && res['status'] != 'success') {
        throw AppException(res['message']?.toString() ?? 'Failed to block user');
      }
    } on PostgrestException catch (e) {
      throw AppException(e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('An unexpected error occurred while blocking: $e');
    }
  }

  /// Unblocks a previously blocked user.
  Future<void> unblockUser(String profileId) async {
    try {
      final res = await _client.rpc(
        'unblock_user',
        params: {
          'p_blocked_id': profileId,
        },
      );
      if (res is Map && res['status'] != 'success') {
        throw AppException(res['message']?.toString() ?? 'Failed to unblock user');
      }
    } on PostgrestException catch (e) {
      throw AppException(e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('An unexpected error occurred while unblocking: $e');
    }
  }

  /// Reports a profile for inappropriate content or safety violation.
  Future<void> reportUser(
    String profileId, {
    required String category,
    required String reason,
    String? details,
  }) async {
    try {
      final res = await _client.rpc(
        'report_user',
        params: {
          'p_reported_id': profileId,
          'p_category': category,
          'p_reason': reason,
          'p_details': details,
        },
      );
      if (res is Map && res['status'] != 'success') {
        throw AppException(res['message']?.toString() ?? 'Failed to submit report');
      }
    } on PostgrestException catch (e) {
      throw AppException(e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('An unexpected error occurred while reporting: $e');
    }
  }

  /// Fetches the list of users blocked by the current user.
  Future<List<BlockedUser>> getBlockedUsers() async {
    try {
      final res = await _client.rpc('get_blocked_users');
      if (res is List) {
        return res
            .map((item) => BlockedUser.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return [];
    } on PostgrestException catch (e) {
      throw AppException(e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to load blocked users: $e');
    }
  }

  /// Permanently erases the user's account and personal details (Apple Guideline 5.1.1(v)).
  Future<void> deleteAccount() async {
    try {
      await _client.rpc('delete_user_account');
      await _client.auth.signOut();
    } on PostgrestException catch (e) {
      throw AppException(e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Failed to delete account: $e');
    }
  }
}
