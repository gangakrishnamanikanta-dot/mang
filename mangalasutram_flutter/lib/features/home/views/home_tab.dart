import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/di.dart';
import '../../../models/profile.dart';
import '../../../models/match_result.dart';
import '../services/home_service.dart';
import '../screens/visited_profiles_screen.dart';
import '../../discovery/screens/discover_tab.dart';
import '../../interests/screens/interests_tab.dart';
import '../../profile/screens/profile_detail_screen.dart';
import '../../profile/screens/edit_sections/edit_religion_screen.dart';
import '../../profile/screens/edit_profile_screen.dart';
import '../../shared/services/lookup_service.dart';
import '../../family/services/family_service.dart';
import '../../family/screens/family_room_screen.dart';
import '../../matching/screens/detailed_guna_milan_screen.dart';
import '../../notifications/widgets/notification_badge.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../../core/route_observer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model fetched from Supabase
// ─────────────────────────────────────────────────────────────────────────────
class _HomeData {
  final Profile? myProfile;
  final List<MatchResult> dailyRecommendations;
  final List<MatchResult> highGunaMatches;
  final List<Profile> watchedProfiles;
  final List<MatchResult> newMembers;
  final List<Profile> recentlyActive;
  final Map<int, String> occupationLookup;
  final List<Map<String, dynamic>> successStories;
  final UserActivityCounts activityCounts;

  const _HomeData({
    this.myProfile,
    required this.dailyRecommendations,
    required this.highGunaMatches,
    required this.watchedProfiles,
    required this.newMembers,
    required this.recentlyActive,
    required this.occupationLookup,
    this.successStories = const [],
    this.activityCounts = const UserActivityCounts(),
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// HomeTab — main widget
// ─────────────────────────────────────────────────────────────────────────────
class HomeTab extends StatefulWidget {
  final ValueChanged<String?> onNavigateToMatches;
  final ValueChanged<int>? onNavigateToTab;

  const HomeTab({
    super.key,
    required this.onNavigateToMatches,
    this.onNavigateToTab,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with RouteAware {
  final _svc = getIt<HomeService>();
  final _lookupSvc = LookupService();

  final PageController _bannerCtrl = PageController();
  int _currentBanner = 0;

  _HomeData? _cachedData;
  late Future<_HomeData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadAll();
    _svc.matchesRefreshTrigger.addListener(_onMatchesRefreshTriggered);
  }

  void _onMatchesRefreshTriggered() {
    if (mounted) {
      setState(() {
        _dataFuture = _loadAll();
      });
    }
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
    _svc.matchesRefreshTrigger.removeListener(_onMatchesRefreshTriggered);
    routeObserver.unsubscribe(this);
    _bannerCtrl.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    setState(() {
      _dataFuture = _loadAll();
    });
  }

  Future<_HomeData> _loadAll() async {
    _svc.updateMyActiveTimestamp();

    final myProf = await _svc.getMyProfile();
    String? candidateId;
    if (myProf?.accountType == 'guardian') {
      final cand = await FamilyService.instance.getGuardianActiveCandidate();
      candidateId = cand?.candidateId;
    }

    final results = await Future.wait([
      _svc.getDiscoveryCohorts(onBehalfOf: candidateId),
      _svc.getRecentlyActiveProfiles(limit: 12),
      _lookupSvc.getOccupations(),
      _svc.getSuccessStories(),
      _svc.getUserActivityCounts(onBehalfOf: candidateId),
    ]);

    final cohorts = results[0] as Map<String, dynamic>;
    final recentlyActive = results[1] as List<Profile>;
    final occupationsList = results[2] as List<dynamic>;
    final storiesList = results[3] as List<Map<String, dynamic>>;
    final activityCounts = results[4] as UserActivityCounts;

    final occMap = <int, String>{};
    for (final opt in occupationsList) {
      occMap[opt.id as int] = opt.label as String;
    }

    final data = _HomeData(
      myProfile: myProf,
      dailyRecommendations:
          cohorts['daily_recommendations'] as List<MatchResult>? ?? [],
      highGunaMatches: cohorts['high_guna_milan'] as List<MatchResult>? ?? [],
      watchedProfiles: cohorts['watched_profiles'] as List<Profile>? ?? [],
      newMembers: cohorts['new_members'] as List<MatchResult>? ?? [],
      recentlyActive: recentlyActive,
      occupationLookup: occMap,
      successStories: storiesList,
      activityCounts: activityCounts,
    );

    _cachedData = data;
    return data;
  }

  void _showGunaMilanSheet(BuildContext context, {MatchResult? candidateMatch}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GunaMilanBottomSheet(
        candidateMatch: candidateMatch,
        onViewDetailed: () {
          Navigator.pop(ctx);
          _openDetailedGunaMilan(context, candidateMatch: candidateMatch);
        },
        onEditMyAstrology: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EditReligionScreen(),
            ),
          ).then((_) {
            setState(() {
              _dataFuture = _loadAll();
            });
          });
        },
      ),
    );
  }

  void _openDetailedGunaMilan(BuildContext context, {MatchResult? candidateMatch}) {
    if (candidateMatch == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailedGunaMilanScreen(match: candidateMatch),
      ),
    );
  }

  void _openDiscoverScreen(BuildContext context, {String title = 'Discover Profiles'}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFFAF6F0),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFAF6F0),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF4A121A)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4A121A),
              ),
            ),
          ),
          body: const DiscoverTab(),
        ),
      ),
    );
  }

  void _openInterestsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFFAF6F0),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFAF6F0),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF4A121A)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Interests',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4A121A),
              ),
            ),
          ),
          body: const InterestsTab(),
        ),
      ),
    );
  }

  int _calculateCompleteness(Profile? p) {
    if (p == null) return 60;
    int score = 20;
    if (p.profilePhotoUrl != null && p.profilePhotoUrl!.isNotEmpty) score += 25;
    if (p.dateOfBirth != null && p.dateOfBirth!.isNotEmpty) score += 15;
    if (p.aboutMe != null && p.aboutMe!.trim().isNotEmpty) score += 15;
    if (p.occupationId != null || p.highestEducationId != null) score += 15;
    if (p.gothramId != null || p.nakshatraId != null || p.rashiId != null) score += 10;
    return score.clamp(30, 100);
  }

  String _getNextStepSuggestion(Profile? p) {
    if (p == null) return 'Add your photo to get 5x more responses';
    if (p.profilePhotoUrl == null || p.profilePhotoUrl!.isEmpty) {
      return 'Upload a photo to get 5x more responses';
    }
    if (p.gothramId == null && p.nakshatraId == null) {
      return 'Add Gothram & Nakshatra for Vedic Guna Milan';
    }
    if (p.aboutMe == null || p.aboutMe!.trim().isEmpty) {
      return 'Write a short bio to introduce yourself';
    }
    return 'Your profile is looking great!';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Container(
      color: const Color(0xFFFAF6F0),
      child: FutureBuilder<_HomeData>(
        future: _dataFuture,
        builder: (ctx, snap) {
          final data = snap.data ?? _cachedData;
          final isLoading =
              snap.connectionState == ConnectionState.waiting && data == null;
          final hasError = snap.hasError && data == null;
          final completeness = _calculateCompleteness(data?.myProfile);
          final suggestion = _getNextStepSuggestion(data?.myProfile);

          return RefreshIndicator(
            color: const Color(0xFF54121F),
            backgroundColor: Colors.white,
            edgeOffset: MediaQuery.of(context).padding.top,
            onRefresh: () async {
              final messenger = ScaffoldMessenger.of(context);
              setState(() {
                _dataFuture = _loadAll();
              });
              // Concurrently sync notification unread counter
              unawaited(context.read<NotificationProvider>().refreshUnreadCount());
              final fresh = await _dataFuture;
              if (!mounted) return;
              final totalFound = fresh.dailyRecommendations.length +
                  fresh.highGunaMatches.length;
              messenger.showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFFC99A4B),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Refreshed • Found $totalFound top recommendations ✨',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: const Color(0xFF4A121A),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
            },
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Top App Bar ───────────────────────────────────────
                  _HomeHeader(
                    profile: data?.myProfile,
                    isTablet: isTablet,
                    onProfileTap: () => Scaffold.of(context).openDrawer(),
                    onSearchTap: () => _openDiscoverScreen(context),
                    onNotificationTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationCenterScreen(),
                        ),
                      );
                      if (context.mounted) {
                        context.read<NotificationProvider>().refreshUnreadCount();
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  // ── Profile Completeness Booster (Item 4) ───────────────
                  if (completeness < 100) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
                      child: _ProfileCompletenessCard(
                        completeness: completeness,
                        suggestion: suggestion,
                        onCompleteTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          ).then((_) {
                            if (mounted) {
                              setState(() {
                                _dataFuture = _loadAll();
                              });
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ── Hero Mandap Carousel Banner ─────────────────────────
                  _HeroMandapBanner(
                    controller: _bannerCtrl,
                    currentPage: _currentBanner,
                    isTablet: isTablet,
                    onPageChanged: (i) => setState(() => _currentBanner = i),
                    onActionTap: (int slideIndex) {
                      if (slideIndex == 1) {
                        final candidate = data?.dailyRecommendations.isNotEmpty == true
                            ? data!.dailyRecommendations.first
                            : null;
                        _showGunaMilanSheet(context, candidateMatch: candidate);
                      } else if (slideIndex == 2) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FamilyRoomScreen(),
                          ),
                        );
                      } else {
                        widget.onNavigateToMatches(null);
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  // ── Live Matrimonial Activity Metrics ───────────────────
                  _ActivityMetricStrip(
                    activityCounts:
                        data?.activityCounts ?? const UserActivityCounts(),
                    totalDailyMatches: data?.dailyRecommendations.length ?? 0,
                    isTablet: isTablet,
                    onInterestsTap: () {
                      if (widget.onNavigateToTab != null) {
                        widget.onNavigateToTab!(2);
                      } else {
                        _openInterestsScreen(context);
                      }
                    },
                    onProfileViewsTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VisitedProfilesScreen(),
                        ),
                      );
                    },
                    onMatchesTap: () => widget.onNavigateToMatches(null),
                  ),

                  const SizedBox(height: 12),

                  // ── 4 Quick Actions Strip ───────────────────────────────
                  _QuickActionsBar(
                    isTablet: isTablet,
                    onPremiumMatchesTap: () => widget.onNavigateToMatches(null),
                    onGunaMilanTap: () {
                      final candidate = data?.dailyRecommendations.isNotEmpty == true
                          ? data!.dailyRecommendations.first
                          : null;
                      _showGunaMilanSheet(context, candidateMatch: candidate);
                    },
                    onInterestsTap: () => _openInterestsScreen(context),
                    onVerifiedProfilesTap: () => _openDiscoverScreen(
                      context,
                      title: 'Verified Profiles',
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Cohort 1: Daily Top Recommendations ─────────────────
                  _SectionHeader(
                    title: 'Daily Recommendations',
                    badgeLabel: 'Top Picks',
                    isTablet: isTablet,
                    onViewAll: () => widget.onNavigateToMatches(null),
                  ),
                  const SizedBox(height: 10),

                  if (hasError)
                    const _ErrorSection(
                      message: "Couldn't load matches. Pull down to retry.",
                    )
                  else if (isLoading)
                    _MatchesSkeletonRow(isTablet: isTablet)
                  else if (data!.dailyRecommendations.isEmpty)
                    const _EmptySection(message: 'No recommendations found yet.')
                  else
                    _TopMatchesRow(
                      matches: data.dailyRecommendations,
                      occupationLookup: data.occupationLookup,
                      isTablet: isTablet,
                      onTap: (match) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileDetailScreen(
                              profile: match.profile,
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 20),

                  // ── Section: Recently Active (Live Presence Avatars) ─────
                  _SectionHeader(
                    title: 'Recently Active',
                    isTablet: isTablet,
                    onViewAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VisitedProfilesScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  if (hasError)
                    const _EmptySection(
                      message: "Couldn't load recently active profiles.",
                    )
                  else if (isLoading)
                    _ActiveAvatarsSkeletonRow(isTablet: isTablet)
                  else if (data!.recentlyActive.isEmpty)
                    const _EmptySection(
                      message: 'No recently active profiles.',
                    )
                  else
                    _RecentlyActiveRow(
                      profiles: data.recentlyActive,
                      isTablet: isTablet,
                      onProfileTap: (profile) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileDetailScreen(
                              profile: profile,
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 18),

                  // ── Section: Profiles I Watched (Recently Viewed) ─────────
                  if (data != null && data.watchedProfiles.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Profiles I Watched',
                      badgeLabel: 'Watched',
                      isTablet: isTablet,
                      onViewAll: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VisitedProfilesScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _WatchedProfilesRow(
                      profiles: data.watchedProfiles,
                      occupationLookup: data.occupationLookup,
                      isTablet: isTablet,
                      onTap: (profile) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileDetailScreen(
                              profile: profile,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Banner 2: Check your Guna Milan ─────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
                    child: _GunaMilanBanner(
                      isTablet: isTablet,
                      onCheckNow: () {
                        final candidate = data?.dailyRecommendations.isNotEmpty == true
                            ? data!.dailyRecommendations.first
                            : null;
                        _showGunaMilanSheet(context, candidateMatch: candidate);
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Cohort 4: New Members / Just Joined ─────────────────
                  if (data != null && data.newMembers.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'New Members',
                      badgeLabel: 'Just Joined',
                      isTablet: isTablet,
                      onViewAll: () => widget.onNavigateToMatches(null),
                    ),
                    const SizedBox(height: 10),
                    _TopMatchesRow(
                      matches: data.newMembers,
                      occupationLookup: data.occupationLookup,
                      isTablet: isTablet,
                      onTap: (match) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileDetailScreen(
                              profile: match.profile,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Section: Success Stories (Item 6) ───────────────────
                  if (data != null && data.successStories.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Success Stories',
                      isTablet: isTablet,
                      onViewAll: () {},
                    ),
                    const SizedBox(height: 10),
                    _SuccessStoriesCarousel(stories: data.successStories),
                  ],

                  const SizedBox(height: 28),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Top App Bar (Header)
// ─────────────────────────────────────────────────────────────────────────────
class _HomeHeader extends StatelessWidget {
  final Profile? profile;
  final bool isTablet;
  final VoidCallback onProfileTap;
  final VoidCallback onSearchTap;
  final FutureOr<void> Function()? onNotificationTap;

  const _HomeHeader({
    this.profile,
    required this.isTablet,
    required this.onProfileTap,
    required this.onSearchTap,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarSize = isTablet ? 46.0 : 40.0;

    return Container(
      color: const Color(0xFFFAF6F0),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        left: isTablet ? 24 : 16,
        right: isTablet ? 24 : 16,
        bottom: 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onProfileTap();
            },
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC99A4B), width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC99A4B).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: profile?.profilePhotoUrl != null &&
                        profile!.profilePhotoUrl!.isNotEmpty
                    ? Image.network(
                        profile!.profilePhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(),
                      )
                    : _buildAvatarFallback(),
              ),
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (profile?.fullName.trim().isNotEmpty ?? false) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Namaste, ${profile!.fullName.trim().split(' ').first}',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: isTablet ? 22 : 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF4A121A),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('🙏', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  Text(
                    'Sacred matches curated for you',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 12 : 10.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8C7A6B),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Mangalasutram',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isTablet ? 24 : 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4A121A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    'Sacred bonds. Beautiful beginnings.',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 12 : 10.5,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF8C7A6B),
                    ),
                  ),
                ],
              ],
            ),
          ),

          _CircleIconButton(
            icon: Icons.search_rounded,
            isTablet: isTablet,
            onTap: onSearchTap,
          ),
          const SizedBox(width: 8),

          NotificationBadge(
            isTablet: isTablet,
            onTap: onNotificationTap,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      color: const Color(0xFF54121F),
      child: const Icon(
        Icons.person_rounded,
        size: 24,
        color: Color(0xFFC99A4B),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final bool isTablet;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final btnSize = isTablet ? 42.0 : 36.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: btnSize,
        height: btnSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE8E0D5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, color: const Color(0xFF4A3B32), size: isTablet ? 21 : 19),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Completeness Card (Item 4)
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileCompletenessCard extends StatelessWidget {
  final int completeness;
  final String suggestion;
  final VoidCallback onCompleteTap;

  const _ProfileCompletenessCard({
    required this.completeness,
    required this.suggestion,
    required this.onCompleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0EBE5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: completeness / 100.0,
                  strokeWidth: 3.5,
                  backgroundColor: const Color(0xFFF0EBE5),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC99A4B)),
                ),
                Text(
                  '$completeness%',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4A121A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Profile $completeness% Complete',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF231F20),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  suggestion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF8C7A6B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onCompleteTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF6F0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC99A4B).withValues(alpha: 0.5)),
              ),
              child: Text(
                'Complete',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8B1E2D),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Hero Mandap Banner Carousel
// ─────────────────────────────────────────────────────────────────────────────
class _HeroMandapBanner extends StatelessWidget {
  final PageController controller;
  final int currentPage;
  final bool isTablet;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onActionTap;

  static const List<Map<String, String>> _bannerSlides = [
    {
      'title': 'Find your perfect\nlife partner',
      'subtitle': 'Trusted by families, chosen by hearts.',
      'cta': 'Explore Matches',
    },
    {
      'title': 'Vedic Astrology &\nGuna Milan',
      'subtitle': 'Authentic 36-Koota Vedic compatibility.',
      'cta': 'Check Milan',
    },
    {
      'title': 'Verified Sacred\nFamily Circles',
      'subtitle': '100% authenticated matrimonial profiles.',
      'cta': 'Family Circle',
    },
  ];

  const _HeroMandapBanner({
    required this.controller,
    required this.currentPage,
    required this.isTablet,
    required this.onPageChanged,
    required this.onActionTap,
  });

  Widget _buildGradientFallback(Color startColor, Color endColor, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: const Color(0xFFC99A4B).withValues(alpha: 0.35),
          size: 64,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bannerHeight = isTablet ? 230.0 : 175.0;
    final activeSlide = _bannerSlides[currentPage % _bannerSlides.length];

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: bannerHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView(
                    controller: controller,
                    onPageChanged: onPageChanged,
                    physics: const ClampingScrollPhysics(),
                    children: [
                      Image.asset(
                        'assets/images/wedding_mandap_hero.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildGradientFallback(
                          const Color(0xFF54121F),
                          const Color(0xFF2B0912),
                          Icons.favorite_rounded,
                        ),
                      ),
                      Image.asset(
                        'assets/images/decoration.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildGradientFallback(
                          const Color(0xFF4A121A),
                          const Color(0xFF1E050B),
                          Icons.auto_awesome,
                        ),
                      ),
                      Image.asset(
                        'assets/images/purohit.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildGradientFallback(
                          const Color(0xFF350810),
                          const Color(0xFF150206),
                          Icons.family_restroom_rounded,
                        ),
                      ),
                    ],
                  ),

                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.82),
                        ],
                        stops: const [0.25, 1.0],
                      ),
                    ),
                  ),

                  Positioned(
                    left: isTablet ? 24 : 16,
                    bottom: isTablet ? 20 : 14,
                    right: 125,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activeSlide['title']!,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: isTablet ? 23 : 19,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.15,
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeSlide['subtitle']!,
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 13 : 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onActionTap(currentPage % _bannerSlides.length);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 16 : 13,
                          vertical: isTablet ? 8 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC99A4B),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC99A4B).withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          activeSlide['cta']!,
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 13 : 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_bannerSlides.length, (i) {
            final active = i == (currentPage % _bannerSlides.length);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: active ? 16 : 4.5,
              height: 4.5,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFC99A4B)
                    : const Color(0xFFD4C4B5).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2.5 Live Matrimonial Activity & Engagement Counters
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityMetricStrip extends StatelessWidget {
  final UserActivityCounts activityCounts;
  final int totalDailyMatches;
  final bool isTablet;
  final VoidCallback onInterestsTap;
  final VoidCallback onProfileViewsTap;
  final VoidCallback onMatchesTap;

  const _ActivityMetricStrip({
    required this.activityCounts,
    required this.totalDailyMatches,
    required this.isTablet,
    required this.onInterestsTap,
    required this.onProfileViewsTap,
    required this.onMatchesTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEADBCE), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6E1732).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // 1. Pending Interests Received
            Expanded(
              child: _MetricItem(
                icon: Icons.volunteer_activism_rounded,
                iconColor: const Color(0xFF6E1732),
                iconBg: const Color(0xFFFBECEF),
                count: activityCounts.pendingInterestsCount,
                label: 'Interests',
                subtitle: activityCounts.pendingInterestsCount > 0 ? 'Pending' : 'Received',
                badgeText: activityCounts.pendingInterestsCount > 0 ? 'NEW' : null,
                onTap: onInterestsTap,
              ),
            ),
            _buildDivider(),
            // 2. Profile Visitors
            Expanded(
              child: _MetricItem(
                icon: Icons.visibility_rounded,
                iconColor: const Color(0xFFC99A4B),
                iconBg: const Color(0xFFFFF9EE),
                count: activityCounts.profileViewsCount,
                label: 'Visitors',
                subtitle: 'Viewed You',
                onTap: onProfileViewsTap,
              ),
            ),
            _buildDivider(),
            // 3. Daily Vedic Matches
            Expanded(
              child: _MetricItem(
                icon: Icons.auto_awesome_rounded,
                iconColor: const Color(0xFF9E2A2B),
                iconBg: const Color(0xFFFAF0EA),
                count: totalDailyMatches,
                label: 'Matches',
                subtitle: "Today's Picks",
                onTap: onMatchesTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 38,
      width: 1,
      color: const Color(0xFFF0EBE5),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final int count;
  final String label;
  final String subtitle;
  final String? badgeText;
  final VoidCallback onTap;

  const _MetricItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.count,
    required this.label,
    required this.subtitle,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(icon, color: iconColor, size: 18),
                    ),
                  ),
                  if (badgeText != null)
                    Positioned(
                      top: -4,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6E1732),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeText!,
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFFFF7ED),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '$count',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF332018),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5A4A3E),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF9A8A7A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Quick Actions 4-Feature Strip
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionsBar extends StatelessWidget {
  final bool isTablet;
  final VoidCallback onPremiumMatchesTap;
  final VoidCallback onGunaMilanTap;
  final VoidCallback onInterestsTap;
  final VoidCallback onVerifiedProfilesTap;

  const _QuickActionsBar({
    required this.isTablet,
    required this.onPremiumMatchesTap,
    required this.onGunaMilanTap,
    required this.onInterestsTap,
    required this.onVerifiedProfilesTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 14 : 10,
          horizontal: 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0EBE5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _QuickActionItem(
              icon: Icons.diamond_outlined,
              label: 'Premium\nMatches',
              isTablet: isTablet,
              onTap: onPremiumMatchesTap,
            ),
            _buildDivider(),
            _QuickActionItem(
              icon: Icons.flare_rounded,
              label: 'Guna Milan',
              isTablet: isTablet,
              onTap: onGunaMilanTap,
            ),
            _buildDivider(),
            _QuickActionItem(
              icon: Icons.volunteer_activism_outlined,
              label: 'Interests',
              isTablet: isTablet,
              onTap: onInterestsTap,
            ),
            _buildDivider(),
            _QuickActionItem(
              icon: Icons.verified_user_outlined,
              label: 'Verified\nProfiles',
              isTablet: isTablet,
              onTap: onVerifiedProfilesTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 28,
      width: 1,
      color: const Color(0xFFF2EBE3),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isTablet;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF4A121A), size: isTablet ? 24 : 21),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 12 : 10.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF332924),
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Section Header with Badge & View All
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? badgeLabel;
  final bool isTablet;
  final VoidCallback onViewAll;

  const _SectionHeader({
    required this.title,
    this.badgeLabel,
    required this.isTablet,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isTablet ? 21 : 17.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF231F20),
                    ),
                  ),
                ),
                if (badgeLabel != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF54121F),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeLabel!,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFDE8C0),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onViewAll();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 13 : 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4A121A),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: isTablet ? 17 : 15,
                    color: const Color(0xFF4A121A),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Top Matches Cards Row (with Omnipresent Presence Badge)
// ─────────────────────────────────────────────────────────────────────────────
class _TopMatchesRow extends StatelessWidget {
  final List<MatchResult> matches;
  final Map<int, String> occupationLookup;
  final bool isTablet;
  final ValueChanged<MatchResult> onTap;

  const _TopMatchesRow({
    required this.matches,
    required this.occupationLookup,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rowHeight = isTablet ? 290.0 : 255.0;

    return SizedBox(
      height: rowHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
        itemCount: matches.length,
        itemBuilder: (context, i) {
          final match = matches[i];
          final occupation = match.occupationId != null &&
                  occupationLookup.containsKey(match.occupationId!)
              ? occupationLookup[match.occupationId!]!
              : (match.subCaste != null && match.subCaste!.isNotEmpty
                  ? match.subCaste!
                  : 'Professional');

          return _TopMatchCard(
            match: match,
            occupation: occupation,
            isTablet: isTablet,
            onTap: () => onTap(match),
          );
        },
      ),
    );
  }
}

class _TopMatchCard extends StatelessWidget {
  final MatchResult match;
  final String occupation;
  final bool isTablet;
  final VoidCallback onTap;

  const _TopMatchCard({
    required this.match,
    required this.occupation,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final location = [match.city, match.state]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    final cardWidth = isTablet ? 190.0 : 155.0;
    final presenceLabel = match.lastActiveLabel ?? (match.isOnline ? 'Online' : 'Active');
    final isOnline = match.isOnline || presenceLabel == 'Online';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (match.profilePhotoUrl != null &&
                  match.profilePhotoUrl!.isNotEmpty)
                Image.network(
                  match.profilePhotoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                )
              else
                _buildPlaceholder(),

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    stops: const [0.3, 0.6, 1.0],
                  ),
                ),
              ),

              // Vedic Guna Milan / Match % Pill Badge (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: match.gunaScore != null
                        ? const Color(0xFF6E1732)
                        : const Color(0xFFC99A4B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFC99A4B),
                      width: match.gunaScore != null ? 1 : 0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (match.gunaScore != null) ...[
                        const Icon(
                          Icons.auto_awesome,
                          size: 10,
                          color: Color(0xFFC99A4B),
                        ),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        match.gunaScore != null
                            ? '${match.gunaScore}/36'
                            : '${match.matchScore.round()}%',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 11.5 : 10.5,
                          fontWeight: FontWeight.w700,
                          color: match.gunaScore != null
                              ? const Color(0xFFFDE8C0)
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Omnipresent Presence & Trust Badge Pill (Top Left)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isOnline
                          ? const Color(0xFF22C55E).withValues(alpha: 0.5)
                          : Colors.transparent,
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
                          color: isOnline
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFF5B759),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        presenceLabel,
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Details
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${match.fullName}, ${match.age ?? 24}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 14 : 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (match.isVerified) ...[
                          const SizedBox(width: 3.5),
                          const Icon(
                            Icons.verified_rounded,
                            size: 13,
                            color: Color(0xFFF5B759),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),

                    Text(
                      occupation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 12 : 10.5,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 2),

                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 10.5,
                          color: Color(0xFFF5B759),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            location.isNotEmpty ? location : 'Location on Request',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 11 : 9.5,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
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

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF4A121A),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 48,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5B. Profiles I Watched Row (Recently Viewed)
// ─────────────────────────────────────────────────────────────────────────────
class _WatchedProfilesRow extends StatelessWidget {
  final List<Profile> profiles;
  final Map<int, String> occupationLookup;
  final bool isTablet;
  final ValueChanged<Profile> onTap;

  const _WatchedProfilesRow({
    required this.profiles,
    required this.occupationLookup,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rowHeight = isTablet ? 290.0 : 255.0;

    return SizedBox(
      height: rowHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
        itemCount: profiles.length,
        itemBuilder: (context, i) {
          final profile = profiles[i];
          final occupation = profile.occupationId != null &&
                  occupationLookup.containsKey(profile.occupationId!)
              ? occupationLookup[profile.occupationId!]!
              : (profile.subCaste != null && profile.subCaste!.isNotEmpty
                  ? profile.subCaste!
                  : 'Professional');

          return _WatchedProfileCard(
            profile: profile,
            occupation: occupation,
            isTablet: isTablet,
            onTap: () => onTap(profile),
          );
        },
      ),
    );
  }
}

class _WatchedProfileCard extends StatelessWidget {
  final Profile profile;
  final String occupation;
  final bool isTablet;
  final VoidCallback onTap;

  const _WatchedProfileCard({
    required this.profile,
    required this.occupation,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth = isTablet ? 190.0 : 155.0;
    final location = [profile.city, profile.state]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (profile.profilePhotoUrl != null &&
                  profile.profilePhotoUrl!.isNotEmpty)
                Image.network(
                  profile.profilePhotoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildPlaceholder(),
                )
              else
                _buildPlaceholder(),

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    stops: const [0.3, 0.6, 1.0],
                  ),
                ),
              ),

              // Watched Eye Badge (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF54121F).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFC99A4B).withValues(alpha: 0.6),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility_rounded,
                        size: 11,
                        color: Color(0xFFFDE8C0),
                      ),
                      const SizedBox(width: 3.5),
                      Text(
                        'Watched',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 11 : 9.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFDE8C0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Details
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${profile.fullName}, ${profile.age ?? 24}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 14 : 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      occupation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 12 : 10.5,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 10.5,
                          color: Color(0xFFF5B759),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            location.isNotEmpty ? location : 'India',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 11 : 9.5,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
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

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF4A121A),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          size: 48,
          color: Colors.white24,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Recently Active Avatars Row (Live Presence & Activity)
// ─────────────────────────────────────────────────────────────────────────────
class _RecentlyActiveRow extends StatelessWidget {
  final List<Profile> profiles;
  final bool isTablet;
  final ValueChanged<Profile> onProfileTap;

  const _RecentlyActiveRow({
    required this.profiles,
    required this.isTablet,
    required this.onProfileTap,
  });

  String _formatPresence(Profile p) {
    DateTime? dt;
    try {
      dt = DateTime.tryParse(p.updatedAt) ?? DateTime.tryParse(p.createdAt);
    } catch (_) {}
    if (dt == null) return 'Online';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 15) return 'Online';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return 'Active';
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = isTablet ? 68.0 : 54.0;
    final rowHeight = isTablet ? 120.0 : 105.0;

    return SizedBox(
      height: rowHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
        itemCount: profiles.length,
        itemBuilder: (context, i) {
          final profile = profiles[i];
          final firstName = profile.fullName.split(' ').first;
          final presenceText = _formatPresence(profile);
          final isOnline = presenceText == 'Online';

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onProfileTap(profile);
            },
            child: Container(
              width: avatarSize + 8,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isOnline
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFD4C4B5),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isOnline
                                      ? const Color(0xFF22C55E)
                                      : Colors.black)
                                  .withValues(alpha: isOnline ? 0.25 : 0.06),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: profile.profilePhotoUrl != null &&
                                  profile.profilePhotoUrl!.isNotEmpty
                              ? Image.network(
                                  profile.profilePhotoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildAvatarFallback(),
                                )
                              : _buildAvatarFallback(),
                        ),
                      ),

                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: (isOnline
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFF94A3B8))
                                    .withValues(alpha: 0.4),
                                blurRadius: 2.5,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  Text(
                    firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 12 : 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF332924),
                    ),
                  ),

                  Text(
                    presenceText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 10 : 8.5,
                      fontWeight: FontWeight.w500,
                      color: isOnline
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF8C7A6B),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      color: const Color(0xFFEEE0D5),
      child: const Icon(
        Icons.face_3,
        size: 30,
        color: Color(0xFF8C7A6B),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. Guna Milan Banner
// ─────────────────────────────────────────────────────────────────────────────
class _GunaMilanBanner extends StatelessWidget {
  final bool isTablet;
  final VoidCallback onCheckNow;

  const _GunaMilanBanner({
    required this.isTablet,
    required this.onCheckNow,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onCheckNow();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 18 : 14,
          vertical: isTablet ? 14 : 11,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF4A121A),
              Color(0xFF350810),
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A121A).withValues(alpha: 0.28),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: isTablet ? 38 : 32,
              height: isTablet ? 38 : 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFC99A4B).withValues(alpha: 0.6),
                  width: 1.2,
                ),
                color: const Color(0xFF5E1724),
              ),
              child: Icon(
                Icons.stars_rounded,
                color: const Color(0xFFC99A4B),
                size: isTablet ? 22 : 19,
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Check your Guna Milan',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 14 : 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFDE8C0),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Find matches that are astrologically compatible',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 11 : 10,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 14 : 11,
                vertical: isTablet ? 7 : 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFC99A4B),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC99A4B).withValues(alpha: 0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Check Now',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 12 : 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: isTablet ? 15 : 13,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. Success Stories Section (Item 6)
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessStoriesCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> stories;
  const _SuccessStoriesCarousel({required this.stories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stories.length,
        itemBuilder: (ctx, i) {
          final s = stories[i];
          final couple = s['couple_names']?.toString() ??
              s['couple']?.toString() ??
              'Blessed Couple';
          final sub = s['subtitle']?.toString() ??
              s['sub']?.toString() ??
              'Mangalasutram Alliance';
          final quote = s['quote']?.toString() ?? '';
          return Container(
            width: 270,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0EBE5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF9EE),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('💍', style: TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        couple,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4A121A),
                        ),
                      ),
                      Text(
                        sub,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFC99A4B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        quote,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF6B5E55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. 4-State Smart Guna Milan Bottom Sheet (Industry Standard & Locked)
// ─────────────────────────────────────────────────────────────────────────────
class _GunaMilanBottomSheet extends StatefulWidget {
  final MatchResult? candidateMatch;
  final VoidCallback onViewDetailed;
  final VoidCallback onEditMyAstrology;

  const _GunaMilanBottomSheet({
    this.candidateMatch,
    required this.onViewDetailed,
    required this.onEditMyAstrology,
  });

  @override
  State<_GunaMilanBottomSheet> createState() => _GunaMilanBottomSheetState();
}

class _GunaMilanBottomSheetState extends State<_GunaMilanBottomSheet> {
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

    final match = widget.candidateMatch;
    if (match != null) {
      final sent = await HomeService.instance.hasSentHoroscopeRequest(match.profileId);
      if (sent && mounted) {
        setState(() => _requestSent = true);
      }
    }
  }

  Future<void> _sendHoroscopeRequest() async {
    final match = widget.candidateMatch;
    if (match == null) return;

    setState(() => _requestSending = true);
    HapticFeedback.mediumImpact();

    final success = await HomeService.instance.sendHoroscopeRequest(match.profileId);

    if (mounted) {
      setState(() {
        _requestSending = false;
        if (success) _requestSent = true;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📩 Horoscope request sent to ${match.fullName}!',
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
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
    final match = widget.candidateMatch;
    final candidateName = match?.fullName ?? 'Candidate Profile';

    final isUserMissing =
        _myProfile == null ||
        _myProfile!.rashiId == null ||
        _myProfile!.nakshatraId == null;

    final isCandidateMissing =
        match == null ||
        match.profile.rashiId == null ||
        match.profile.nakshatraId == null;

    final hasValidGunaScore =
        !isUserMissing && !isCandidateMissing && (match.gunaScore ?? 0) > 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
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
                      : 'Astrological Guna Milan',
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

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF8B1E2D),
                ),
              ),
            )
          else if (hasValidGunaScore)
            _buildStateComplete(match)
          else if (isUserMissing && isCandidateMissing)
            _buildStateBothMissing(candidateName)
          else if (isUserMissing)
            _buildStateUserMissing()
          else
            _buildStateCandidateMissing(candidateName),
        ],
      ),
    );
  }

  Widget _buildStateComplete(MatchResult match) {
    final gunaScore = match.gunaScore;
    final isUttama = (gunaScore ?? 0) >= 28;

    return Column(
      children: [
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
                    errorBuilder: (context, error, stackTrace) => const Icon(
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
                            text: '$gunaScore ',
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF8B1E2D),
                            ),
                          ),
                          TextSpan(
                            text: '/ 36 Gunas',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B5E55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUttama ? 'Uttama Compatibility ✨' : 'Madhyama Compatibility',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isUttama ? const Color(0xFF2E7D32) : const Color(0xFFC99A4B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isUttama
                          ? 'Highly auspicious horoscope harmony for traditional marriage.'
                          : 'Favorable alignment across canonical Vedic Koots.',
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
                  'View 8-Koot Ashtakoot Breakdown',
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
      ],
    );
  }

  Widget _buildStateUserMissing() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFEDD5)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEDD5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_clock_rounded,
                  color: Color(0xFFC2410C),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guna Milan Calculation Locked',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF9A3412),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Your Birth Star (Nakshatra) & Rashi are missing from your profile. Add them to unlock instant 36-point Guna Milan.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF7C2D12),
                        height: 1.3,
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
          child: ElevatedButton.icon(
            onPressed: widget.onEditMyAstrology,
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: Text(
              'Fill My Astrology Details ✏️',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1E2D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateCandidateMissing(String candidateName) {
    return Column(
      children: [
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
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFE6DC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: Color(0xFF8B1E2D),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Awaiting Horoscope Details',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4A121A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$candidateName has not added their birth star yet. Request their horoscope to calculate mutual Guna Milan.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF6B5E55),
                        height: 1.3,
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
          child: ElevatedButton.icon(
            onPressed: _requestSent || _requestSending ? null : _sendHoroscopeRequest,
            icon: _requestSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _requestSent ? Icons.check_circle_rounded : Icons.mail_outline_rounded,
                    size: 20,
                  ),
            label: Text(
              _requestSent
                  ? 'Horoscope Requested 📩'
                  : 'Request Horoscope from $candidateName',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _requestSent
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF8B1E2D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateBothMissing(String candidateName) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFEDD5)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEDD5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_motion_rounded,
                  color: Color(0xFFC2410C),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Astrology Details Required',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF9A3412),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Fill your birth star to unlock Vedic Guna compatibility and request matching details from $candidateName.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF7C2D12),
                        height: 1.3,
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
          child: ElevatedButton.icon(
            onPressed: widget.onEditMyAstrology,
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: Text(
              'Fill My Astrology Details ✏️',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1E2D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loaders & empty states
// ─────────────────────────────────────────────────────────────────────────────
class _MatchesSkeletonRow extends StatelessWidget {
  final bool isTablet;
  const _MatchesSkeletonRow({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final rowHeight = isTablet ? 290.0 : 235.0;
    final cardWidth = isTablet ? 190.0 : 155.0;

    return SizedBox(
      height: rowHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
        itemCount: 3,
        itemBuilder: (context, index) => Container(
          width: cardWidth,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEE8E0),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _ActiveAvatarsSkeletonRow extends StatelessWidget {
  final bool isTablet;
  const _ActiveAvatarsSkeletonRow({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final avatarSize = isTablet ? 68.0 : 54.0;
    final rowHeight = isTablet ? 112.0 : 92.0;

    return SizedBox(
      height: rowHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          width: avatarSize + 8,
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEE8E0),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 40,
                height: 10,
                color: const Color(0xFFEEE8E0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;
  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF8C7A6B),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: const Color(0xFF8C7A6B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorSection extends StatelessWidget {
  final String message;
  const _ErrorSection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
