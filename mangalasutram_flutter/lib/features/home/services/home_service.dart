
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../models/match_result.dart';
import '../../../models/profile.dart';
import '../../auth/services/supabase_service.dart';

class HomeService {
  HomeService._internal();
  static final HomeService instance = HomeService._internal();

  final matchesRefreshTrigger = ValueNotifier<int>(0);

  // ── Shared Matches Cache ──────────────────────────────────────────────────
  // Single source of truth for BOTH Home tab (top 5) and Matches tab (all).
  // This prevents both screens from independently calling get_top_matches_v2
  // and receiving different profiles due to match_shown_log rotation.
  List<MatchResult> _cachedMatches = [];
  DateTime? _cacheTime;
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Notifier — HomeTab and MatchesTab both listen to this for live updates
  final ValueNotifier<List<MatchResult>> cachedMatchesNotifier =
      ValueNotifier([]);

  bool get isCacheFresh =>
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheTtl &&
      _cachedMatches.isNotEmpty;

  List<MatchResult> get cachedMatches => List.unmodifiable(_cachedMatches);

  void _updateCache(List<MatchResult> matches) {
    _cachedMatches = matches;
    _cacheTime = DateTime.now();
    cachedMatchesNotifier.value = List.unmodifiable(_cachedMatches);
    debugPrint('[HomeService] Cache updated: ${matches.length} matches');
  }

  void notifyMatchesChanged() {
    matchesRefreshTrigger.value++;
  }

  /// Clears the in-memory cache so next fetch gets fresh DB calculations
  void invalidateCache() {
    _cachedMatches = [];
    _cacheTime = null;
    cachedMatchesNotifier.value = [];
    notifyMatchesChanged();
  }

  // ── Profile ───────────────────────────────────────────────────────────────

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

  // ── Matches ───────────────────────────────────────────────────────────────

  /// Raw DB call — use [getSharedMatches] in UI code instead.
  ///
  /// NOTE: The server enforces quota caps regardless of [limit]:
  ///   Free: max 5/day | Prime Lite: max 12/day | Prime VIP: max 25/day
  ///   The server will cap p_limit to the user's daily_matches_limit.
  Future<List<MatchResult>> getTopMatches(
      {int limit = 25, int offset = 0, String? onBehalfOf}) async {
    try {
      final userId = onBehalfOf ?? SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return [];

      final data = await SupabaseService.client.rpc(
        'get_top_matches_v2',
        params: {
          'p_user_id': userId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      if (data is List && data.isNotEmpty) {
        final results = data
            .map((e) => MatchResult.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint('[HomeService] Server returned ${results.length} matches (server-enforced per plan)');
        return results;
      }
      return [];
    } catch (e) {
      debugPrint('[HomeService getTopMatches Error]: $e');
      return [];
    }
  }

  /// ✅ PRIMARY METHOD — call this from BOTH HomeTab and MatchesTab.
  ///
  /// Returns from the shared 5-minute in-memory cache if fresh.
  /// Forces a DB fetch when [forceRefresh] is true.
  /// [homePreview] = true → returns only first 5 (for Home recent matches row).
  ///
  /// The [limit] is a HINT only — the server enforces the plan quota:
  ///   Free: 5/day | Prime Lite: 12/day | Prime VIP: 25/day
  Future<List<MatchResult>> getSharedMatches({
    bool forceRefresh = false,
    bool homePreview = false,
    int limit = 25,  // Server caps to plan quota regardless
    String? onBehalfOf,
  }) async {
    if (!forceRefresh && isCacheFresh) {
      final result = cachedMatches;
      return homePreview ? result.take(5).toList() : result.toList();
    }

    final userId = onBehalfOf ?? SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return [];

    // Fire background DB cache refresh (non-blocking)
    unawaited(_refreshMatches(userId));

    final fresh = await getTopMatches(limit: limit, onBehalfOf: onBehalfOf);
    // ✅ Sort by highest match score first
    fresh.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    _updateCache(fresh);

    return homePreview ? fresh.take(5).toList() : fresh;
  }

  /// Called by HomeTab's _loadAll() — always returns top 5 from shared cache
  Future<List<MatchResult>> refreshAndGetMatches({int limit = 20, String? onBehalfOf}) async {
    return getSharedMatches(forceRefresh: false, homePreview: true, onBehalfOf: onBehalfOf);
  }

  Future<void> _refreshMatches(String userId) async {
    try {
      await SupabaseService.client.rpc(
        'refresh_user_match_cache',
        params: {'p_user_id': userId, 'p_force': false},
      );
    } catch (e) {
      debugPrint('[HomeService _refreshMatches Error]: $e');
    }
  }

  // ── Visited Profiles ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getVisitedProfilesWithScore(
      {int limit = 10}) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final data = await SupabaseService.client.rpc(
        'get_visited_profiles_with_score',
        params: {'p_viewer_id': userId, 'p_limit': limit},
      );
      if (data is List) return List<Map<String, dynamic>>.from(data);
      return [];
    } catch (e) {
      debugPrint('[HomeService getVisitedProfilesWithScore Error]: $e');
      return [];
    }
  }

  Future<List<Profile>> getVisitedProfiles({int limit = 10}) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final data = await getVisitedProfilesWithScore(limit: limit);
      return data.map((json) => Profile.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[HomeService getVisitedProfiles Error]: $e');
      return [];
    }
  }

  // ── Recently Active Profiles ──────────────────────────────────────────────

  Future<List<Profile>> getRecentlyActiveProfiles({int limit = 12}) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final data = await SupabaseService.client.rpc(
        'get_recently_active_profiles',
        params: {'p_viewer_id': userId, 'p_limit': limit},
      );
      if (data is List) {
        return data
            .map((json) => Profile.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[HomeService getRecentlyActiveProfiles Error]: $e');
      return [];
    }
  }

  // ── Profile Views & Exclusions ────────────────────────────────────────────

  Future<void> recordProfileView(String viewedProfileId,
      {int dwellSeconds = 0, String viewedFrom = 'matches'}) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService.client.rpc(
        'record_profile_view_capped',
        params: {
          'p_viewer_id': userId,
          'p_viewed_id': viewedProfileId,
          'p_dwell_seconds': dwellSeconds,
          'p_viewed_from': viewedFrom,
        },
      );
    } catch (e) {
      debugPrint('[HomeService recordProfileView Error]: $e');
    }
  }

  Future<void> excludeProfile(String excludedProfileId,
      {String reason = 'user_skipped'}) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService.client.from('match_exclusions').upsert(
        {
          'user_id': userId,
          'excluded_id': excludedProfileId,
          'reason': reason,
        },
        onConflict: 'user_id,excluded_id',
      );
    } catch (e) {
      debugPrint('[HomeService excludeProfile Error]: $e');
      rethrow;
    }
  }

  Future<void> forceRefreshMyMatches({String? onBehalfOf}) async {
    final userId = onBehalfOf ?? SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService.client.rpc(
        'refresh_user_match_cache',
        params: {'p_user_id': userId, 'p_force': true},
      );
      // Bust the in-memory cache so next call always fetches fresh from DB
      _cacheTime = null;
      _cachedMatches = [];
      cachedMatchesNotifier.value = [];
    } catch (e) {
      debugPrint('[HomeService forceRefreshMyMatches Error]: $e');
      rethrow;
    }
  }

  Future<void> updateMyActiveTimestamp() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', userId);
    } catch (e) {
      debugPrint('[HomeService updateMyActiveTimestamp Error]: $e');
    }
  }

  Future<Map<String, dynamic>> getDiscoveryCohorts({String? onBehalfOf}) async {
    final userId = onBehalfOf ?? SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      return {
        'daily_recommendations': <MatchResult>[],
        'high_guna_milan': <MatchResult>[],
        'watched_profiles': <Profile>[],
        'new_members': <MatchResult>[],
      };
    }
    try {
      final res = await SupabaseService.client.rpc(
        'get_discovery_cohorts',
        params: {'p_user_id': userId},
      );
      if (res is Map<String, dynamic>) {
        return {
          'daily_recommendations': (res['daily_recommendations'] as List? ?? [])
              .map((j) => MatchResult.fromJson(Map<String, dynamic>.from(j)))
              .toList(),
          'high_guna_milan': (res['high_guna_milan'] as List? ?? [])
              .map((j) => MatchResult.fromJson(Map<String, dynamic>.from(j)))
              .toList(),
          'watched_profiles': (res['watched_profiles'] as List? ?? [])
              .map((j) => Profile.fromJson(Map<String, dynamic>.from(j)))
              .toList(),
          'new_members': (res['new_members'] as List? ?? [])
              .map((j) => MatchResult.fromJson(Map<String, dynamic>.from(j)))
              .toList(),
        };
      }
      return {
        'daily_recommendations': [],
        'high_guna_milan': [],
        'near_you': [],
        'new_members': [],
      };
    } catch (e) {
      debugPrint('[HomeService getDiscoveryCohorts Error]: $e');
      return {
        'daily_recommendations': [],
        'high_guna_milan': [],
        'near_you': [],
        'new_members': [],
      };
    }
  }

  Future<List<Map<String, dynamic>>> getIncomingHoroscopeRequests() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final res = await SupabaseService.client.rpc(
        'get_incoming_horoscope_requests',
        params: {'p_user_id': userId},
      );
      if (res is List) {
        return List<Map<String, dynamic>>.from(res);
      }
      return [];
    } catch (e) {
      debugPrint('[HomeService getIncomingHoroscopeRequests Error]: $e');
      return [];
    }
  }

  Future<bool> sendHoroscopeRequest(String receiverId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await SupabaseService.client.from('horoscope_requests').upsert({
        'sender_id': userId,
        'receiver_id': receiverId,
        'status': 'pending',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'sender_id,receiver_id');
      return true;
    } catch (e) {
      debugPrint('[HomeService sendHoroscopeRequest Error]: $e');
      return false;
    }
  }

  Future<bool> hasSentHoroscopeRequest(String receiverId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final res = await SupabaseService.client
          .from('horoscope_requests')
          .select('id, status')
          .eq('sender_id', userId)
          .eq('receiver_id', receiverId)
          .maybeSingle();
      return res != null;
    } catch (e) {
      return false;
    }
  }

  /// Single-trip RPC fetching all live Sidebar data (ID, verification, plan, quota, invite code)
  Future<Map<String, dynamic>> getSidebarSummary() async {
    try {
      final res = await SupabaseService.client.rpc('get_sidebar_summary');
      if (res is Map<String, dynamic>) {
        return res;
      }
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {};
    } catch (e) {
      debugPrint('[HomeService getSidebarSummary Error]: $e');
      return {};
    }
  }

  /// Fetches dynamic success stories from public.success_stories
  Future<List<Map<String, dynamic>>> getSuccessStories() async {
    try {
      final res = await SupabaseService.client
          .from('success_stories')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('[HomeService getSuccessStories Error]: $e');
      return [];
    }
  }

  /// Toggles whether the current candidate's profile is hidden (paused) from discovery
  Future<bool> toggleProfileVisibility(bool isHidden) async {
    try {
      await SupabaseService.client.rpc(
        'toggle_profile_visibility',
        params: {'p_is_hidden': isHidden},
      );
      return true;
    } catch (e) {
      debugPrint('[HomeService toggleProfileVisibility Error]: $e');
      return false;
    }
  }

  /// Toggles whether linked Guardians can send chat messages on behalf of the Candidate
  Future<bool> toggleGuardianProxyChat(bool allow) async {
    try {
      await SupabaseService.client.rpc(
        'toggle_guardian_proxy_chat',
        params: {'p_allow': allow},
      );
      return true;
    } catch (e) {
      debugPrint('[HomeService toggleGuardianProxyChat Error]: $e');
      return false;
    }
  }

  /// Updates a single boolean privacy field on public.profiles
  Future<bool> updatePrivacyField(String column, bool value) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await SupabaseService.client
          .from('profiles')
          .update({
            column: value,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('[HomeService updatePrivacyField Error]: $e');
      return false;
    }
  }

  /// Fetches real-time matrimonial activity metrics (views, pending interests, shortlists).
  Future<UserActivityCounts> getUserActivityCounts({String? onBehalfOf}) async {
    final userId = onBehalfOf ?? SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return const UserActivityCounts();
    try {
      final res = await SupabaseService.client.rpc(
        'get_home_activity_counts',
        params: {'p_user_id': userId},
      );
      if (res is Map<String, dynamic>) {
        return UserActivityCounts.fromJson(res);
      }
      return const UserActivityCounts();
    } catch (e) {
      debugPrint('[HomeService getUserActivityCounts Error]: $e');
      return const UserActivityCounts();
    }
  }
}

/// Real-time activity metrics for the Home dashboard.
class UserActivityCounts {
  final int profileViewsCount;
  final int pendingInterestsCount;
  final int shortlistsCount;

  const UserActivityCounts({
    this.profileViewsCount = 0,
    this.pendingInterestsCount = 0,
    this.shortlistsCount = 0,
  });

  factory UserActivityCounts.fromJson(Map<String, dynamic> json) {
    return UserActivityCounts(
      profileViewsCount: (json['profile_views_count'] as num?)?.toInt() ?? 0,
      pendingInterestsCount:
          (json['pending_interests_count'] as num?)?.toInt() ?? 0,
      shortlistsCount: (json['shortlists_count'] as num?)?.toInt() ?? 0,
    );
  }
}

