


import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../models/profile.dart';
import '../../auth/services/supabase_service.dart';

class MatchResult {
  final Profile profile;
  final int totalScore;
  final Map<String, dynamic> factorBreakdown;

  MatchResult({
    required this.profile,
    required this.totalScore,
    required this.factorBreakdown,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      profile: Profile.fromJson(json),
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      factorBreakdown:
          (json['factor_breakdown'] as Map<String, dynamic>?) ?? const {},
    );
  }
}

class HomeService {
  HomeService._internal();
  static final HomeService instance = HomeService._internal();

  /// Trigger to notify tabs that matches should be reloaded (e.g., after pref changes)
  final matchesRefreshTrigger = ValueNotifier<int>(0);

  void notifyMatchesChanged() {
    matchesRefreshTrigger.value++;
  }

  Future<Profile?> getMyProfile() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      return Profile.fromJson(data);
    } catch (e) {
      debugPrint('[HomeService getMyProfile Error]: $e');
      return null;
    }
  }

  Future<List<MatchResult>> getTopMatches({int limit = 20, int offset = 0}) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return [];

      final data = await SupabaseService.client.rpc(
        'get_top_matches',
        params: {
          'p_user_id': userId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      if (data is List && data.isNotEmpty) {
        return data
            .map((e) => MatchResult.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[HomeService getTopMatches Error]: $e');
      return [];
    }
  }

  Future<List<MatchResult>> refreshAndWaitForMatches({int limit = 20}) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return [];

    // Wait for the refresh RPC to complete so we get fresh scores
    try {
      await SupabaseService.client.rpc(
        'refresh_user_matches',
        params: {'p_user_id': userId},
      );
    } catch (e) {
      debugPrint('[HomeService refreshAndWaitForMatches Error]: $e');
    }

    return getTopMatches(limit: limit);
  }

  Future<List<MatchResult>> refreshAndGetMatches({int limit = 20}) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return [];

    // Fire refresh in background — don't wait; stale scores are still valid
    unawaited(_refreshMatches(userId));

    // Read immediately from cache
    return getTopMatches(limit: limit);
  }

  Future<void> _refreshMatches(String userId) async {
    try {
      await SupabaseService.client.rpc(
        'refresh_user_matches',
        params: {'p_user_id': userId},
      );
    } catch (e) {
      debugPrint('[HomeService _refreshMatches Error]: $e');
    }
  }

  Future<List<Profile>> getVisitedProfiles({int limit = 6}) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final data = await SupabaseService.client
          .from('profile_views')
          .select('viewed_at, viewed_id, profiles!profile_views_viewed_id_fkey(*)')
          .eq('viewer_id', userId)
          .order('viewed_at', ascending: false)
          .limit(limit);

      return (data as List)
          .where((e) => e['profiles'] != null)
          .map((e) => Profile.fromJson(e['profiles'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[HomeService getVisitedProfiles Error]: $e');
      return [];
    }
  }

  Future<void> recordProfileView(String viewedProfileId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService.client
          .from('profile_views')
          .upsert(
            {'viewer_id': userId, 'viewed_id': viewedProfileId},
            onConflict: 'viewer_id,viewed_id',
          );
    } catch (e) {
      debugPrint('[HomeService recordProfileView Error]: $e');
      rethrow;
    }
  }

  Future<void> excludeProfile(String excludedProfileId,
      {String reason = 'skip'}) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService.client
          .from('match_exclusions')
          .upsert(
            {'user_id': userId, 'excluded_id': excludedProfileId, 'reason': reason},
            onConflict: 'user_id,excluded_id',
          );
    } catch (e) {
      debugPrint('[HomeService excludeProfile Error]: $e');
      rethrow;
    }
  }

  Future<void> forceRefreshMyMatches() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService.client.rpc(
        'refresh_user_matches',
        params: {'p_user_id': userId},
      );
    } catch (e) {
      debugPrint('[HomeService forceRefreshMyMatches Error]: $e');
      rethrow;
    }
  }
}
