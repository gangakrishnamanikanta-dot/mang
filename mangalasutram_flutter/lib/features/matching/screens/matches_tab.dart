import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/di.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/route_observer.dart';
import '../../../models/match_result.dart';
import '../../../models/lookup_option.dart';
import '../../../models/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/supabase_service.dart';
import '../../home/services/home_service.dart';
import '../../interests/services/interest_service.dart';
import '../../profile/screens/profile_detail_screen.dart';
import '../../profile/screens/edit_sections/edit_religion_screen.dart';
import '../../shared/services/lookup_service.dart';
import '../../subscription/services/subscription_service.dart';
import '../../subscription/widgets/quota_exhausted_sheet.dart';
import '../../family/services/family_service.dart';
import '../../family/screens/family_room_screen.dart';
import 'detailed_guna_milan_screen.dart';

enum MatchSortFilter { bestMatch, onlineNow, highGuna, nearYou, newlyJoined, notContacted }

class MatchesTab extends StatefulWidget {
  final String? initialProfileId;
  final ValueChanged<String?>? onProfileScrolled;

  const MatchesTab({
    super.key,
    this.initialProfileId,
    this.onProfileScrolled,
  });

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab>
    with RouteAware, WidgetsBindingObserver {
  final _homeService = getIt<HomeService>();
  final _interestService = getIt<InterestService>();

  final PageController _pageCtrl = PageController();

  List<MatchResult> _allMatches = [];
  bool _isLoading = true;
  bool _hasError = false;

  bool _isRegular = true;
  MatchSortFilter _selectedFilter = MatchSortFilter.bestMatch;
  final Set<String> _shortlistedProfileIds = {};
  final Set<String> _sentInterestProfileIds = {};
  final Set<String> _viewedProfileIds = {};

  Map<String, List<LookupOption>>? _lookups;
  bool _initialScrollDone = false;
  dynamic _realtimeChannel;
  CandidateContextModel? _guardianContext;

  // ── Pagination ────────────────────────────────────────────────────────────
  static const int _pageSize = 50;
  bool _isLoadingMore = false;
  bool _hasMoreMatches = true;

  // ── Profile view debounce + dwell tracking (#7, #8) ───────────────────────
  Timer? _viewDebounce;
  DateTime? _pageEnteredAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLookups();
    _loadData();
    _homeService.matchesRefreshTrigger.addListener(_onRefreshTriggered);
    SubscriptionService.instance.statusNotifier.addListener(_onSubscriptionChanged);
    _initRealtimeSubscription();
  }

  void _onSubscriptionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _initRealtimeSubscription() {
    try {
      final myId = SupabaseService.client.auth.currentUser?.id;
      if (myId == null) return;

      _realtimeChannel = SupabaseService.client
          .channel('public:matches_multi_realtime_sync:$myId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'interests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_profile_id',
              value: myId,
            ),
            callback: (payload) {
              debugPrint('[Realtime]: DB Interests update detected -> refreshing');
              if (mounted) _loadData(forceRefresh: false);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'shortlists',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: myId,
            ),
            callback: (payload) {
              debugPrint('[Realtime]: DB Shortlists update detected -> refreshing');
              if (mounted) _loadData(forceRefresh: false);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_subscriptions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: myId,
            ),
            callback: (payload) {
              debugPrint('[Realtime]: DB user_subscriptions update detected -> live tier sync');
              SubscriptionService.instance.getMyStatus(forceRefresh: true);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[Realtime Subscription Error]: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      debugPrint('[MatchesTab]: App resumed -> Refreshing latest DB data');
      _loadData(forceRefresh: true);
      SubscriptionService.instance.getMyStatus(forceRefresh: true);
    }
  }

  void _onRefreshTriggered() {
    if (mounted) _loadData(forceRefresh: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      if (_realtimeChannel != null) {
        SupabaseService.client.removeChannel(_realtimeChannel);
      }
    } catch (_) {}
    _viewDebounce?.cancel();
    _homeService.matchesRefreshTrigger.removeListener(_onRefreshTriggered);
    routeObserver.unsubscribe(this);
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadData(forceRefresh: true);
  }

  @override
  void didUpdateWidget(covariant MatchesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialProfileId != null &&
        widget.initialProfileId != oldWidget.initialProfileId) {
      _initialScrollDone = false;
      _tryScrollToInitialProfile();
    }
  }

  Future<void> _loadLookups() async {
    try {
      final data = await LookupService().fetchAllProfileLookups();
      if (mounted) setState(() => _lookups = data);
    } catch (_) {}
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      if (forceRefresh) {
        _hasMoreMatches = true;
      }
    });

    try {
      final myProf = await _homeService.getMyProfile();
      String? candidateId;
      if (myProf?.accountType == 'guardian') {
        final cand = await FamilyService.instance.getGuardianActiveCandidate();
        candidateId = cand?.candidateId;
      }

      if (forceRefresh) {
        await _homeService.forceRefreshMyMatches(onBehalfOf: candidateId);
      }

      // ✅ Use shared cache — same profiles as Home tab's recent matches
      final matches = await _homeService.getSharedMatches(
        forceRefresh: forceRefresh,
        homePreview: false,
        limit: _pageSize,
        onBehalfOf: candidateId,
      );

      // Fetch existing shortlists, interests & viewed profiles for current user (or linked candidate)
      final userId = SupabaseService.client.auth.currentUser?.id;
      final effectiveUserId = candidateId ?? userId;
      if (effectiveUserId != null) {
        try {
          final shortlists = await SupabaseService.client
              .from('shortlists')
              .select('profile_id')
              .eq('user_id', effectiveUserId);
          _shortlistedProfileIds.clear();
          for (final row in shortlists) {
            _shortlistedProfileIds.add(row['profile_id'].toString());
          }

          final sentInterests = await SupabaseService.client
              .from('interests')
              .select('receiver_profile_id')
              .eq('sender_profile_id', effectiveUserId);
          _sentInterestProfileIds.clear();
          for (final row in sentInterests) {
            _sentInterestProfileIds.add(row['receiver_profile_id'].toString());
          }

          final viewedRows = await SupabaseService.client
              .from('profile_views')
              .select('viewed_id')
              .eq('viewer_id', effectiveUserId);
          _viewedProfileIds.clear();
          for (final row in viewedRows) {
            _viewedProfileIds.add(row['viewed_id'].toString());
          }
        } catch (_) {}
      }

      // Fetch guardian context if logged in user is a parent/guardian
      final guardianCtx = await FamilyService.instance.getGuardianActiveCandidate();

      if (mounted) {
        setState(() {
          _allMatches = matches;
          _guardianContext = guardianCtx;
          _isLoading = false;
          // If we got fewer than the page size, there are no more to load
          _hasMoreMatches = matches.length >= _pageSize;
        });
        _tryScrollToInitialProfile();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  // #6: Append next page of matches when user approaches end of list
  Future<void> _loadMoreMatches() async {
    if (!mounted || _isLoadingMore || !_hasMoreMatches) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = await _homeService.getTopMatches(
        limit: _pageSize,
        offset: _allMatches.length,
        onBehalfOf: _guardianContext?.candidateId,
      );
      if (mounted) {
        setState(() {
          _allMatches.addAll(nextPage);
          _hasMoreMatches = nextPage.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }


  void _tryScrollToInitialProfile() {
    if (widget.initialProfileId == null || _initialScrollDone) return;
    final targetId = widget.initialProfileId;
    if (targetId == null) return;

    final filtered = _getFilteredMatches();
    final index = filtered.indexWhere((m) => m.profileId == targetId);

    if (index >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageCtrl.hasClients) {
          _pageCtrl.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
          _initialScrollDone = true;
          widget.onProfileScrolled?.call(targetId);
        }
      });
    }
  }

  List<MatchResult> _getFilteredMatches() {
    List<MatchResult> list = List.from(_allMatches);

    // 1. Regular vs PRIME filter
    if (!_isRegular) {
      // PRIME: Top-tier matches (score >= 80)
      list = list.where((m) => m.matchScore >= 80.0).toList();
    }

    // 2. Secondary Filter Chips
    switch (_selectedFilter) {
      case MatchSortFilter.bestMatch:
        list.sort((a, b) => b.matchScore.compareTo(a.matchScore));
        break;
      case MatchSortFilter.onlineNow:
        list = list
            .where((m) =>
                m.isOnline ||
                (m.lastActiveLabel != null && m.lastActiveLabel!.contains('m ago')))
            .toList()
          ..sort((a, b) => b.matchScore.compareTo(a.matchScore));
        break;
      case MatchSortFilter.highGuna:
        list = list.where((m) => (m.gunaScore ?? 0) >= 26).toList()
          ..sort((a, b) => (b.gunaScore ?? 0).compareTo(a.gunaScore ?? 0));
        break;
      case MatchSortFilter.nearYou:
        list.sort((a, b) => (b.city != null ? 1 : 0).compareTo(a.city != null ? 1 : 0));
        break;
      case MatchSortFilter.newlyJoined:
        list.sort((a, b) {
          final aDate = a.createdAt != null ? DateTime.tryParse(a.createdAt!) : null;
          final bDate = b.createdAt != null ? DateTime.tryParse(b.createdAt!) : null;
          if (aDate != null && bDate != null) {
            return bDate.compareTo(aDate);
          }
          if (bDate != null) return 1;
          if (aDate != null) return -1;
          return b.matchScore.compareTo(a.matchScore);
        });
        break;
      case MatchSortFilter.notContacted:
        list = list
            .where((m) => !_viewedProfileIds.contains(m.profileId))
            .toList();
        break;
    }

    return list;
  }

  String _getLookupLabel(String table, int? id, {String fallback = ''}) {
    if (id == null || _lookups == null) return fallback;
    final list = _lookups![table];
    if (list == null) return fallback;
    try {
      return list.firstWhere((e) => e.id == id).label;
    } catch (_) {
      return fallback;
    }
  }

  String _formatHeight(int? inches) {
    if (inches == null || inches <= 0) return '';
    final ft = inches ~/ 12;
    final inch = inches % 12;
    final cm = (inches * 2.54).round();
    return '$ft\' $inch" ($cm cm)';
  }

  void _nextCard() {
    if (_pageCtrl.hasClients) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleInterest(MatchResult match) async {
    HapticFeedback.mediumImpact();

    try {
      await _interestService.sendInterest(match.profileId);
      setState(() {
        _sentInterestProfileIds.add(match.profileId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Interest sent to ${match.fullName}!'),
              ],
            ),
            backgroundColor: const Color(0xFF6E1732),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      _nextCard();
    } on QuotaExceededException catch (e) {
      if (mounted) {
        QuotaExhaustedSheet.show(
          context,
          tier: e.tier,
          limit: e.limit,
        );
      }
    } catch (e) {
      debugPrint('[Send Interest Error]: $e');
    }
  }

  Future<void> _handleShortlist(MatchResult match) async {
    HapticFeedback.lightImpact();
    final isAlreadyShortlisted = _shortlistedProfileIds.contains(match.profileId);

    setState(() {
      if (isAlreadyShortlisted) {
        _shortlistedProfileIds.remove(match.profileId);
      } else {
        _shortlistedProfileIds.add(match.profileId);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAlreadyShortlisted
              ? 'Removed from Shortlist'
              : 'Profile shortlisted!',
        ),
        backgroundColor: isAlreadyShortlisted
            ? const Color(0xFF555555)
            : const Color(0xFF8B6B38),
        duration: const Duration(seconds: 1),
      ),
    );

    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        if (isAlreadyShortlisted) {
          await SupabaseService.client
              .from('shortlists')
              .delete()
              .eq('user_id', userId)
              .eq('profile_id', match.profileId);
        } else {
          await SupabaseService.client.from('shortlists').upsert({
            'user_id': userId,
            'profile_id': match.profileId,
          });
        }
      } catch (e) {
        debugPrint('[Shortlist Error]: $e');
      }
    }
  }

  Future<void> _handleSkip(MatchResult match) async {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Passed on ${match.fullName}'),
        backgroundColor: const Color(0xFF424242),
        duration: const Duration(milliseconds: 1200),
      ),
    );

    try {
      await _homeService.excludeProfile(match.profileId, reason: 'skip');
      setState(() {
        _allMatches.removeWhere((m) => m.profileId == match.profileId);
      });
    } catch (e) {
      debugPrint('[Exclude Profile Error]: $e');
    }

    _nextCard();
  }

  void _openProfileDetail(MatchResult match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileDetailScreen(
          profile: match.profile,
        ),
      ),
    );
  }

  void _openParentDrawer() {
    HapticFeedback.lightImpact();
    ScaffoldState? drawerScaffold;
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScaffoldState) {
        final s = element.state as ScaffoldState;
        if (s.hasDrawer) {
          drawerScaffold = s;
          return false;
        }
      }
      return true;
    });
    drawerScaffold?.openDrawer();
  }

  Widget _buildGuardianBanner() {
    if (_guardianContext == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC99A4B).withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC99A4B).withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _openParentDrawer,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6E1732).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.menu_rounded,
                size: 18,
                color: Color(0xFF6E1732),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FamilyRoomScreen()),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Finding Alliances for ${_guardianContext!.candidateName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6E1732),
                    ),
                  ),
                  Text(
                    'Viewing as ${_guardianContext!.guardianRole} • Tap for Family Room',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6D635B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FamilyRoomScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6E1732),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _guardianContext!.guardianRole.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFD56B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMatches = _getFilteredMatches();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF6F0),
      body: SafeArea(
        child: Column(
          children: [
            // ── Guardian Delegated Context Banner ──
            if (_guardianContext != null) _buildGuardianBanner(),

            // ── 1. Top Header: Switchable Regular / PRIME & Match Count ──
            _buildHeader(filteredMatches.length),

            // ── 2. Filter & Sort Chips ──
            _buildFilterChips(),

            const SizedBox(height: 8),

            // ── 3. Full-Bleed Recommendation Cards ──
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6E1732),
                      ),
                    )
                  : _hasError
                      ? _buildErrorView()
                      : filteredMatches.isEmpty
                          ? _buildEmptyView()
                          : RefreshIndicator(
                              color: const Color(0xFF6E1732),
                              onRefresh: () => _loadData(forceRefresh: true),
                              child: PageView.builder(
                                controller: _pageCtrl,
                                scrollDirection: Axis.vertical,
                                itemCount: filteredMatches.length + 1,
                                onPageChanged: (index) {
                                  if (index < 0 || index >= filteredMatches.length) return;
                                  final item = filteredMatches[index];

                                  // #8: Calculate dwell_seconds for the profile we just LEFT
                                  final dwellSeconds = _pageEnteredAt != null
                                      ? DateTime.now().difference(_pageEnteredAt!).inSeconds
                                      : 0;
                                  _pageEnteredAt = DateTime.now();

                                  // #7: Debounce recordProfileView — only fire if user
                                  // stays on this card for at least 1 second
                                  _viewDebounce?.cancel();
                                  final profileId = item.profileId;
                                  _viewDebounce = Timer(const Duration(seconds: 1), () {
                                    _viewedProfileIds.add(profileId);
                                    _homeService.recordProfileView(
                                      profileId,
                                      dwellSeconds: dwellSeconds.clamp(0, 3600),
                                    );
                                  });

                                  // #6: Load more when approaching end of list
                                  if (_hasMoreMatches &&
                                      !_isLoadingMore &&
                                      index >= filteredMatches.length - 10) {
                                    _loadMoreMatches();
                                  }
                                },
                                itemBuilder: (context, index) {
                                  if (index == filteredMatches.length) {
                                    return _buildDailyPacingPaywallCard(filteredMatches.length);
                                  }
                                  final match = filteredMatches[index];
                                  return _buildFullBleedCard(match);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyPacingPaywallCard(int totalShown) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5D5C5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6E1732).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD4A373), width: 2),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 40,
              color: Color(0xFF8B2500),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "You're All Caught Up! 🎉",
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2B2118),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "You have reviewed today's $totalShown daily recommendations curated for you.",
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF6E5D4F),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECDA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFE65100)),
                const SizedBox(width: 6),
                Text(
                  "Next batch arrives tomorrow at 9:00 AM",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE65100),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5D5C5)),
            ),
            child: Column(
              children: [
                _buildPerkRow("⚡ Up to 25 Daily Recommendations"),
                const SizedBox(height: 6),
                _buildPerkRow("📞 Direct Phone & WhatsApp Unlocks"),
                const SizedBox(height: 6),
                _buildPerkRow("👑 3× Profile Spotlight Visibility Boost"),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/plans');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B2500),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Upgrade to Prime",
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerkRow(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2B2118),
            ),
          ),
        ),
      ],
    );
  }

  // ── 1. Top Header with Switchable Capsule & Count ──────────────────────────
  Widget _buildHeader(int matchCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Switchable Capsule Segmented Control
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFE6DC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2D6C7), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Regular Switch Tab
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isRegular = true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    height: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _isRegular
                          ? const Color(0xFF6E1732) // Deep Burgundy
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'Regular',
                      style: GoogleFonts.inter(
                        color: _isRegular
                            ? Colors.white
                            : const Color(0xFF5D4A3A),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                // PRIME Switch Tab
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final status =
                        await SubscriptionService.instance.getMyStatus(forceRefresh: true);
                    if (status.isFree && mounted) {
                      QuotaExhaustedSheet.show(context, tier: 'free', limit: 5);
                      return;
                    }
                    if (mounted) setState(() => _isRegular = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: !_isRegular
                          ? const Color(0xFF6E1732)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: !_isRegular
                              ? const Color(0xFFFFD56B)
                              : const Color(0xFFB89230),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PRIME',
                          style: GoogleFonts.inter(
                            color: !_isRegular
                                ? Colors.white
                                : const Color(0xFF5D4A3A),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Total Match Count & Force Refresh Button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$matchCount Matches',
                style: GoogleFonts.inter(
                  color: const Color(0xFF5D4A3A),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _loadData(forceRefresh: true);
                },
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: Color(0xFF6E1732),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2. Filter & Sort Chips Row ─────────────────────────────────────────────
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All Matches',
            icon: Icons.swap_vert_rounded,
            isSelected: _selectedFilter == MatchSortFilter.bestMatch,
            onTap: () => setState(() => _selectedFilter = MatchSortFilter.bestMatch),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Online Now',
            icon: Icons.circle,
            iconColor: const Color(0xFF22C55E),
            isSelected: _selectedFilter == MatchSortFilter.onlineNow,
            onTap: () => setState(() => _selectedFilter = MatchSortFilter.onlineNow),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: '28+ Gunas',
            icon: Icons.flare_rounded,
            iconColor: const Color(0xFFF5B759),
            isSelected: _selectedFilter == MatchSortFilter.highGuna,
            onTap: () => setState(() => _selectedFilter = MatchSortFilter.highGuna),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Near You',
            icon: Icons.location_on_rounded,
            isSelected: _selectedFilter == MatchSortFilter.nearYou,
            onTap: () => setState(() => _selectedFilter = MatchSortFilter.nearYou),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Newly Joined',
            icon: Icons.auto_awesome_rounded,
            isSelected: _selectedFilter == MatchSortFilter.newlyJoined,
            onTap: () => setState(() => _selectedFilter = MatchSortFilter.newlyJoined),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Not Seen',
            icon: Icons.visibility_off_outlined,
            isSelected: _selectedFilter == MatchSortFilter.notContacted,
            onTap: () => setState(() => _selectedFilter = MatchSortFilter.notContacted),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    Color? iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6E1732) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6E1732)
                : const Color(0xFFE2D6C7),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: icon == Icons.circle ? 9 : 14,
              color: isSelected
                  ? Colors.white
                  : (iconColor ?? const Color(0xFF5D4A3A)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : const Color(0xFF5D4A3A),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. Full-Bleed Profile Card matching Reference Picture ──────────────────
  Widget _buildFullBleedCard(MatchResult match) {
    final occupation = _getLookupLabel('occupations', match.occupationId, fallback: 'Professional');
    final gothram = _getLookupLabel('gothrams', match.gothramId, fallback: 'Brahmin');
    final caste = _getLookupLabel('castes', match.casteId);
    final heightStr = _formatHeight(match.profile.heightInches);
    final location = [match.city, match.state].where((s) => s != null && s.isNotEmpty).join(', ');
    final isShortlisted = _shortlistedProfileIds.contains(match.profileId);
    final hasSentInterest = _sentInterestProfileIds.contains(match.profileId);

    return GestureDetector(
      onTap: () => _openProfileDetail(match),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background Photo ──
              match.profilePhotoUrl != null && match.profilePhotoUrl!.isNotEmpty
                  ? Image.network(
                      match.profilePhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),

              // ── Gradient Shadow Overlay ──
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black45,
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black54,
                      Colors.black87,
                      Colors.black,
                    ],
                    stops: [0.0, 0.18, 0.45, 0.65, 0.85, 1.0],
                  ),
                ),
              ),

              // ── Top Left: Match % & Live Presence Badges ──
              Positioned(
                top: 18,
                left: 18,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC99A4B),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC99A4B).withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${match.matchScore.round()}% Match',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (match.isOnline || (match.lastActiveLabel != null && match.lastActiveLabel!.contains('Online')))
                              ? const Color(0xFF22C55E).withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (match.isOnline || (match.lastActiveLabel != null && match.lastActiveLabel!.contains('Online')))
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFF5B759),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            match.lastActiveLabel ?? (match.isOnline ? 'Online' : 'Active'),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Top Right: Guna Milan & Photo Count Badges ──
              Positioned(
                top: 18,
                right: 18,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF54121F).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFC99A4B),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.flare_rounded,
                            size: 11,
                            color: Color(0xFFF5B759),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${match.gunaScore}/36',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFDE8C0),
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Bottom Content & Floating Action Buttons ──
              Positioned(
                bottom: 16,
                left: 18,
                right: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name, Age & Info Icon
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '${match.fullName}${match.age != null ? ' , ${match.age}' : ''}',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (match.profile.isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFFD4AF37), // Gold Scalloped Verified Tick
                                  size: 22,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _openProfileDetail(match),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Location / Height
                    Text(
                      [
                        if (heightStr.isNotEmpty) heightStr,
                        if (location.isNotEmpty) location,
                      ].join(' · '),
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Occupation
                    Text(
                      occupation,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Gothram / Caste Details
                    Text(
                      [
                        if (gothram.isNotEmpty) '$gothram Gothram',
                        if (caste.isNotEmpty) caste,
                      ].join(' · '),
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Profile Managed by / Active status
                    Text(
                      'Profile managed by Self · Active recently',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Action Buttons (Interest, Shortlist, Family Room, Guna Milan, Skip) ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 1. Interest Button
                        _buildActionButton(
                          icon: hasSentInterest
                              ? Icons.favorite
                              : Icons.favorite_border_rounded,
                          label: hasSentInterest ? 'Interested' : 'Interest',
                          iconColor: hasSentInterest
                              ? const Color(0xFFFF4D67)
                              : Colors.white,
                          onTap: () => _handleInterest(match),
                        ),

                        // 2. Shortlist Button
                        _buildActionButton(
                          icon: isShortlisted
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          label: 'Shortlist',
                          iconColor: isShortlisted
                              ? const Color(0xFFFFD56B)
                              : Colors.white,
                          onTap: () => _handleShortlist(match),
                        ),

                        // 3. Family Room Button
                        _buildActionButton(
                          icon: Icons.groups_rounded,
                          label: 'Family Room',
                          iconColor: const Color(0xFFFFD56B),
                          borderColor: const Color(0xFFC99A4B),
                          onTap: () => _shareToFamilyRoom(match),
                        ),

                        // 4. Guna Milan Button
                        _buildActionButton(
                          icon: Icons.flare_rounded,
                          label: 'Guna Milan',
                          iconColor: const Color(0xFFF5B759),
                          borderColor: const Color(0xFFC99A4B).withValues(alpha: 0.8),
                          onTap: () => _showGunaMilanSheet(match),
                        ),

                        // 5. Skip Button
                        _buildActionButton(
                          icon: Icons.close_rounded,
                          label: 'Skip',
                          iconColor: Colors.white,
                          onTap: () => _handleSkip(match),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareToFamilyRoom(MatchResult match) async {
    HapticFeedback.mediumImpact();
    try {
      final circle = await FamilyService.instance.getOrCreateCircle();
      final circleId = circle?['circle_id'] as String?;
      if (circleId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please create or join a Family Room first.',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF6E1732),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final success = await FamilyService.instance.addReview(
        circleId: circleId,
        targetProfileId: match.profileId,
        reaction: 'discuss',
        note: 'Shared for family review',
      );

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFFFFD56B), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🪔 Shared ${match.fullName} to Family Room for review!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF6E1732),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not share to Family Room. Please try again.',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showGunaMilanSheet(MatchResult match) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MatchesGunaMilanBottomSheet(
        match: match,
        onViewDetailed: () {
          Navigator.pop(ctx);
          _openDetailedGunaMilan(match);
        },
        onEditMyAstrology: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EditReligionScreen(),
            ),
          ).then((_) {
            _loadData(forceRefresh: true);
          });
        },
      ),
    );
  }

  void _openDetailedGunaMilan(MatchResult match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailedGunaMilanScreen(match: match),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color iconColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.45),
              border: Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.35),
                width: borderColor != null ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              shadows: [
                const Shadow(
                  color: Colors.black54,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF2C2420),
      child: const Center(
        child: Icon(
          Icons.person,
          size: 90,
          color: Color(0xFF6B584C),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEFE6DC),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 48,
                color: Color(0xFF6E1732),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No matches available right now',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF333333),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try switching between Regular and PRIME or check back after tomorrow\'s daily refresh.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF777777),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _loadData(forceRefresh: true),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh Feed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6E1732),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Color(0xFFC62828),
            ),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t load matches',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your internet connection and try again.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF777777),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _loadData(forceRefresh: true),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6E1732),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interactive Guna Milan Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
// 4-State Smart Guna Milan Bottom Sheet (Industry Standard)
// ─────────────────────────────────────────────────────────────────────────────
class _MatchesGunaMilanBottomSheet extends StatefulWidget {
  final MatchResult match;
  final VoidCallback onViewDetailed;
  final VoidCallback onEditMyAstrology;

  const _MatchesGunaMilanBottomSheet({
    required this.match,
    required this.onViewDetailed,
    required this.onEditMyAstrology,
  });

  @override
  State<_MatchesGunaMilanBottomSheet> createState() =>
      _MatchesGunaMilanBottomSheetState();
}

class _MatchesGunaMilanBottomSheetState
    extends State<_MatchesGunaMilanBottomSheet> {
  Profile? _myProfile;
  bool _loading = true;
  bool _requestSending = false;
  bool _requestSent = false;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  Future<void> _loadMyProfile() async {
    final profile = await HomeService.instance.getMyProfile();
    if (!mounted) return;
    setState(() {
      _myProfile = profile;
      _loading = false;
    });

    // Check if request was already sent
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        final existing = await SupabaseService.client
            .from('horoscope_requests')
            .select('id')
            .eq('sender_id', userId)
            .eq('receiver_id', widget.match.profileId)
            .maybeSingle();
        if (existing != null && mounted) {
          setState(() => _requestSent = true);
        }
      } catch (_) {}
    }
  }

  Future<void> _sendHoroscopeRequest() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _requestSending = true);
    HapticFeedback.mediumImpact();

    try {
      await SupabaseService.client.from('horoscope_requests').upsert({
        'sender_id': userId,
        'receiver_id': widget.match.profileId,
        'status': 'pending',
      });

      if (mounted) {
        setState(() {
          _requestSending = false;
          _requestSent = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📩 Horoscope request sent to ${widget.match.fullName}!',
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _requestSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send request. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidateName = widget.match.fullName;

    final isUserMissing =
        _myProfile == null ||
        _myProfile!.rashiId == null ||
        _myProfile!.nakshatraId == null;

    final isCandidateMissing =
        widget.match.profile.rashiId == null ||
        widget.match.profile.nakshatraId == null;

    final hasValidGunaScore =
        !isUserMissing && !isCandidateMissing && (widget.match.gunaScore ?? 0) > 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: _loading
          ? const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF8B1E2D)),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4C4B5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    const Icon(
                      Icons.flare_rounded,
                      color: Color(0xFFC99A4B),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasValidGunaScore
                            ? 'Guna Milan with $candidateName'
                            : 'Horoscope Verification',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF231F20),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFFF2EBE3)),
                const SizedBox(height: 12),

                // ── STATE 1: BOTH HAVE DATA (VERIFIED SCORE) ──
                if (hasValidGunaScore) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF6F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFECE4D8)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFC99A4B)),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/vedic_mandala_gold.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.stars_rounded,
                                color: Color(0xFFC99A4B),
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${widget.match.gunaScore} ',
                                      style: GoogleFonts.inter(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF8B1E2D),
                                      ),
                                    ),
                                    TextSpan(
                                      text: '/ 36',
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6B5E55),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (widget.match.gunaScore ?? 0) >= 28
                                    ? 'Uttama Compatibility ✨'
                                    : 'Good Compatibility',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your birth charts show auspicious astrological harmony for marriage.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF6B5E55),
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: widget.onViewDetailed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF54121F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'View Ashtakoot Breakdown',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),

                // ── STATE 2: CURRENT USER HAS NOT FILLED ASTROLOGY ──
                ] else if (isUserMissing) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9EE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8D7B8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC99A4B)
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                color: Color(0xFFC99A4B),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Guna Milan Calculation Locked',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF4A121A),
                                    ),
                                  ),
                                  Text(
                                    'Your Birth Star & Rashi missing',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: const Color(0xFF8C7A6B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'In Vedic astrology, Guna Milan cannot be calculated without both charts. Please add your Nakshatra (Star) and Rashi (Moon Sign) in your profile to unlock compatibility scores.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF5D4A3A),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: widget.onEditMyAstrology,
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: Text(
                        'Fill My Astrology Details',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF54121F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                // ── STATE 3: USER HAS DATA, BUT CANDIDATE HAS NOT FILLED ──
                ] else if (isCandidateMissing) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF6F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFECE4D8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B1E2D)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_clock_rounded,
                                color: Color(0xFF8B1E2D),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Guna Milan Calculation Locked',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF4A121A),
                                    ),
                                  ),
                                  Text(
                                    '$candidateName has not added birth star',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF8B1E2D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your birth details are set, but $candidateName has not provided their Nakshatra or Rashi yet. Guna matching is locked until both charts are present. Send a request to notify $candidateName to add them.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF5D4A3A),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: _requestSent
                        ? Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFA5D6A7)),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF2E7D32),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Horoscope Requested 📩',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed:
                                _requestSending ? null : _sendHoroscopeRequest,
                            icon: _requestSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.mark_email_unread_rounded,
                                    size: 20),
                            label: Text(
                              _requestSending
                                  ? 'Sending Request...'
                                  : 'Request Horoscope from $candidateName',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF54121F),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                  ),
                ],
              ],
            ),
    );
  }
}


