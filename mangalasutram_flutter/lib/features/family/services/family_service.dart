import 'package:flutter/foundation.dart';
import '../../auth/services/supabase_service.dart';

class FamilyMemberModel {
  final String id;
  final String userId;
  final String role;
  final String displayName;
  final DateTime createdAt;

  FamilyMemberModel({
    required this.id,
    required this.userId,
    required this.role,
    required this.displayName,
    required this.createdAt,
  });

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    return FamilyMemberModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'Family Member',
      displayName: json['display_name'] as String? ?? 'Member',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class FamilyReviewModel {
  final String id;
  final String circleId;
  final String targetProfileId;
  final String reviewedBy;
  final String reaction; // 'shortlist', 'discuss', 'decline'
  final String? note;
  final DateTime createdAt;
  final String? reviewerName;
  final String? reviewerRole;
  final String? candidateName;
  final String? candidatePhoto;
  final String? candidateCity;

  FamilyReviewModel({
    required this.id,
    required this.circleId,
    required this.targetProfileId,
    required this.reviewedBy,
    required this.reaction,
    this.note,
    required this.createdAt,
    this.reviewerName,
    this.reviewerRole,
    this.candidateName,
    this.candidatePhoto,
    this.candidateCity,
  });

  factory FamilyReviewModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final reviewer = json['reviewer'] as Map<String, dynamic>?;
    return FamilyReviewModel(
      id: json['id'] as String,
      circleId: json['family_circle_id'] as String,
      targetProfileId: json['target_profile_id'] as String,
      reviewedBy: json['reviewed_by'] as String,
      reaction: json['reaction'] as String? ?? 'discuss',
      note: json['note'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      reviewerName: json['reviewer_name'] as String? ?? reviewer?['full_name'] as String?,
      reviewerRole: json['reviewer_role'] as String?,
      candidateName: profile?['full_name'] as String?,
      candidatePhoto: profile?['profile_photo_url'] as String?,
      candidateCity: profile?['city'] as String?,
    );
  }
}

class FamilyMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String messageType; // 'text', 'shared_profile', 'audio', 'system'
  final String content;
  final String? mediaUrl;
  final String? sharedProfileId;
  final String? sharedProfileName;
  final String? sharedProfilePhoto;
  final DateTime createdAt;

  FamilyMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.messageType,
    required this.content,
    this.mediaUrl,
    this.sharedProfileId,
    this.sharedProfileName,
    this.sharedProfilePhoto,
    required this.createdAt,
  });

  factory FamilyMessageModel.fromJson(Map<String, dynamic> json) {
    return FamilyMessageModel(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderName: json['sender_name'] as String? ?? 'Family Member',
      senderRole: json['sender_role'] as String? ?? 'Member',
      messageType: json['message_type'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
      mediaUrl: json['media_url'] as String?,
      sharedProfileId: json['shared_profile_id']?.toString(),
      sharedProfileName: json['shared_profile_name'] as String?,
      sharedProfilePhoto: json['shared_profile_photo'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

class CandidateContextModel {
  final String candidateId;
  final String candidateName;
  final String? gender;
  final int? casteId;
  final String? subCaste;
  final int? gothramId;
  final int? nakshatraId;
  final int? rashiId;
  final String? photoUrl;
  final String circleId;
  final String guardianRole;
  final bool allowGuardianProxyChat;

  CandidateContextModel({
    required this.candidateId,
    required this.candidateName,
    this.gender,
    this.casteId,
    this.subCaste,
    this.gothramId,
    this.nakshatraId,
    this.rashiId,
    this.photoUrl,
    required this.circleId,
    required this.guardianRole,
    this.allowGuardianProxyChat = true,
  });

  factory CandidateContextModel.fromJson(Map<String, dynamic> json) {
    return CandidateContextModel(
      candidateId: json['candidate_id'] as String? ?? '',
      candidateName: json['candidate_name'] as String? ?? 'Candidate',
      gender: json['gender'] as String?,
      casteId: json['caste_id'] as int?,
      subCaste: json['sub_caste'] as String?,
      gothramId: json['gothram_id'] as int?,
      nakshatraId: json['nakshatra_id'] as int?,
      rashiId: json['rashi_id'] as int?,
      photoUrl: json['photo_url'] as String?,
      circleId: json['circle_id'] as String? ?? '',
      guardianRole: json['guardian_role'] as String? ?? 'Parent',
      allowGuardianProxyChat: json['allow_guardian_proxy_chat'] as bool? ?? true,
    );
  }
}

class FamilyService {
  static final FamilyService instance = FamilyService._internal();
  FamilyService._internal();

  final _client = SupabaseService.client;

  /// Fetches or initializes the family circle for the current user
  Future<Map<String, dynamic>?> getOrCreateCircle() async {
    try {
      final res = await _client.rpc('get_or_create_family_circle');
      if (res != null && res is Map<String, dynamic>) {
        return res;
      }
      return null;
    } catch (e) {
      debugPrint('[FamilyService getOrCreateCircle Error]: $e');
      return null;
    }
  }

  /// Joins an existing family circle via 6-character code
  Future<bool> joinCircle({
    required String inviteCode,
    String role = 'Parent',
    String displayName = 'Parent',
  }) async {
    final res = await joinCircleWithResult(
      inviteCode: inviteCode,
      role: role,
      displayName: displayName,
    );
    return res['success'] == true;
  }

  /// Detailed join circle method returning backend validation messages (e.g. 2 guardian limit)
  Future<Map<String, dynamic>> joinCircleWithResult({
    required String inviteCode,
    String role = 'Parent',
    String displayName = 'Parent',
  }) async {
    try {
      final res = await _client.rpc('join_family_circle', params: {
        'p_invite_code': inviteCode.trim(),
        'p_role': role,
        'p_display_name': displayName,
      });
      if (res != null && res['status'] == 'success') {
        return {'success': true, 'data': res};
      } else {
        return {
          'success': false,
          'message': res?['message'] as String? ?? 'Failed to join family circle'
        };
      }
    } catch (e) {
      debugPrint('[FamilyService joinCircle Error]: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Fetches candidate context if current logged-in user is a guardian
  Future<CandidateContextModel?> getGuardianActiveCandidate() async {
    try {
      final res = await _client.rpc('get_guardian_active_candidate');
      if (res != null && res is List && res.isNotEmpty) {
        return CandidateContextModel.fromJson(Map<String, dynamic>.from(res.first as Map));
      }
      return null;
    } catch (e) {
      debugPrint('[FamilyService getGuardianActiveCandidate Error]: $e');
      return null;
    }
  }

  /// Fetches all members in the current family circle
  Future<List<FamilyMemberModel>> getMembers(String circleId) async {
    try {
      final data = await _client
          .from('family_members')
          .select()
          .eq('family_circle_id', circleId)
          .order('created_at');
      return (data as List).map((e) => FamilyMemberModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[FamilyService getMembers Error]: $e');
      return [];
    }
  }

  /// Fetches all profile reviews discussed in the family circle
  Future<List<FamilyReviewModel>> getReviews(String circleId) async {
    try {
      final data = await _client
          .from('family_profile_reviews')
          .select('*, profiles:target_profile_id(full_name, profile_photo_url, city), reviewer:reviewed_by(full_name)')
          .eq('family_circle_id', circleId)
          .order('created_at', ascending: false);
      final members = await getMembers(circleId);
      final roleByUser = <String, String>{
        for (final m in members) m.userId: m.role,
      };
      return (data as List).map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        final reviewedBy = map['reviewed_by']?.toString() ?? '';
        map['reviewer_role'] ??= roleByUser[reviewedBy];
        return FamilyReviewModel.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('[FamilyService getReviews Error]: $e');
      return [];
    }
  }

  /// Fetches messages in the private Family Group Chat via RPC (includes joined shared_profile info)
  Future<List<FamilyMessageModel>> getFamilyMessages(String circleId, {int limit = 100}) async {
    try {
      final res = await _client.rpc('get_family_messages', params: {
        'p_circle_id': circleId,
        'p_limit': limit,
      });
      if (res is List) {
        return res
            .map((e) => FamilyMessageModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[FamilyService getFamilyMessages Error]: $e');
      return [];
    }
  }

  /// Sends a message to the private Family Group Chat
  Future<bool> sendFamilyMessage({
    required String circleId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
    String? sharedProfileId,
  }) async {
    try {
      final res = await _client.rpc('send_family_message', params: {
        'p_circle_id': circleId,
        'p_content': content.trim(),
        'p_message_type': messageType,
        'p_media_url': mediaUrl,
        'p_shared_profile_id': sharedProfileId,
      });
      return res is Map && res['status'] == 'success';
    } catch (e) {
      debugPrint('[FamilyService sendFamilyMessage Error]: $e');
      return false;
    }
  }

  /// Adds or updates a profile review in the family circle and broadcasts to Family Group Chat
  Future<bool> addReview({
    required String circleId,
    required String targetProfileId,
    required String reaction, // 'shortlist', 'discuss', 'decline'
    String? note,
  }) async {
    try {
      final myId = _client.auth.currentUser?.id;
      if (myId == null) return false;

      final existing = await _client
          .from('family_profile_reviews')
          .select('id')
          .eq('family_circle_id', circleId)
          .eq('target_profile_id', targetProfileId)
          .maybeSingle();

      if (existing != null && existing['id'] != null) {
        await _client.from('family_profile_reviews').update({
          'reviewed_by': myId,
          'reaction': reaction,
          'note': note?.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', existing['id'] as String);
      } else {
        await _client.from('family_profile_reviews').insert({
          'family_circle_id': circleId,
          'target_profile_id': targetProfileId,
          'reviewed_by': myId,
          'reaction': reaction,
          'note': note?.trim(),
        });
      }

      final verdictLabel = reaction == 'shortlist'
          ? 'Shortlisted for Alliance'
          : reaction == 'decline'
              ? 'Passed / Declined'
              : 'Shared for Family Deliberation';
      final msgContent = (note != null && note.trim().isNotEmpty)
          ? '$verdictLabel — "${note.trim()}"'
          : verdictLabel;

      await sendFamilyMessage(
        circleId: circleId,
        content: msgContent,
        messageType: 'shared_profile',
        sharedProfileId: targetProfileId,
      );

      return true;
    } catch (e) {
      debugPrint('[FamilyService addReview Error]: $e');
      return false;
    }
  }

  /// Updates a review reaction in the family circle
  Future<bool> updateReviewReaction({
    required String reviewId,
    required String reaction,
  }) async {
    try {
      await _client
          .from('family_profile_reviews')
          .update({
            'reaction': reaction,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', reviewId);
      return true;
    } catch (e) {
      debugPrint('[FamilyService updateReviewReaction Error]: $e');
      return false;
    }
  }
}
