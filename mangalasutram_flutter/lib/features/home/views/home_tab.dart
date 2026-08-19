import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../constants/theme.dart';
import '../../../models/profile.dart';
import '../services/home_service.dart';
import '../screens/visited_profiles_screen.dart';
import '../../shared/widgets/profile_card.dart';
import '../screens/home_screen.dart';
import '../../../core/route_observer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Banner data  (static — service info, NOT profile data)
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceBanner {
  final String image;
  final String title;
  final String subtitle;
  const _ServiceBanner({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}

const _banners = [
  _ServiceBanner(
    image: 'assets/images/mehandi.png',
    title: 'Expert Mehendi Artists',
    subtitle: 'Beautiful designs for the bride',
  ),
  _ServiceBanner(
    image: 'assets/images/purohit.png',
    title: 'Vedic Purohit Services',
    subtitle: 'Authentic rituals by learned priests',
  ),
  _ServiceBanner(
    image: 'assets/images/band_melam.png',
    title: 'Band & Nadaswaram Melam',
    subtitle: 'Traditional music for every ceremony',
  ),
  _ServiceBanner(
    image: 'assets/images/catering.png',
    title: 'Wedding Catering',
    subtitle: 'Authentic South Indian wedding feast',
  ),
  _ServiceBanner(
    image: 'assets/images/photography.png',
    title: 'Wedding Photography',
    subtitle: 'Memories crafted for a lifetime',
  ),
  _ServiceBanner(
    image: 'assets/images/decoration.png',
    title: 'Floral Decorations',
    subtitle: 'Transform your wedding venue',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Data holder fetched from Supabase
// ─────────────────────────────────────────────────────────────────────────────
class _HomeData {
  final Profile? myProfile;
  final List<dynamic> recentMatches; // MatchResult list from engine
  final List<Profile> visitedProfiles;
  const _HomeData({
    this.myProfile,
    required this.recentMatches,
    required this.visitedProfiles,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// HomeTab  — main widget
// ─────────────────────────────────────────────────────────────────────────────
class HomeTab extends StatefulWidget {
  final ValueChanged<String?> onNavigateToMatches;

  const HomeTab({super.key, required this.onNavigateToMatches});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with RouteAware {
  final _svc = HomeService.instance;

  final PageController _bannerCtrl = PageController();
  int _currentBanner = 0;
  Timer? _bannerTimer;

  late Future<_HomeData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadAll();
    _startAutoScroll();
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
    _bannerTimer?.cancel();
    _bannerCtrl.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Returned from a pushed screen (e.g. visited profiles) — refresh data
    setState(() {
      _dataFuture = _loadAll();
    });
  }

  Future<_HomeData> _loadAll() async {
    final results = await Future.wait([
      _svc.getMyProfile(),
      _svc.refreshAndGetMatches(limit: 10),
      _svc.getVisitedProfiles(limit: 6),
    ]);
    return _HomeData(
      myProfile: results[0] as Profile?,
      recentMatches: results[1] as List<dynamic>,
      visitedProfiles: results[2] as List<Profile>,
    );
  }

  void _startAutoScroll() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentBanner + 1) % _banners.length;
      _bannerCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8F2),
      child: FutureBuilder<_HomeData>(
        future: _dataFuture,
        builder: (ctx, snap) {
          final data = snap.data;
          final isLoading =
              snap.connectionState != ConnectionState.done && !snap.hasError;
          final hasError = snap.hasError;

          return RefreshIndicator(
            color: AppColors.primary,
            edgeOffset: MediaQuery.of(context).padding.top,
            onRefresh: () async {
              setState(() {
                _dataFuture = _loadAll();
              });
              await _dataFuture;
            },
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomeAppBar(currentIndex: 0, profile: data?.myProfile),
                  const SizedBox(height: 12),

                  // ── Banner carousel ────────────────────────────────────
                  _BannerCarousel(
                    banners: _banners,
                    controller: _bannerCtrl,
                    currentPage: _currentBanner,
                    onPageChanged: (i) => setState(() => _currentBanner = i),
                  ),

                  const SizedBox(height: 28),

                  // ── Recent Matches ─────────────────────────────────────
                  _SectionHeader(
                    title: 'Recent Matches',
                    onViewAll: () => widget.onNavigateToMatches(null),
                  ),
                  const SizedBox(height: 14),

                  if (hasError)
                    _ErrorSection(
                      message: "Couldn't load matches. Pull down to retry.",
                    )
                  else if (isLoading)
                    _SkeletonRow()
                  else if (data!.recentMatches.isEmpty)
                    _EmptySection(message: 'No matches found.')
                  else
                    _ProfileRow(
                      matchResults: data.recentMatches,
                      showInfo: false,
                      onProfileTap: widget.onNavigateToMatches,
                    ),

                  const SizedBox(height: 28),

                  // ── Profiles You Visited ───────────────────────────────
                  _SectionHeader(
                    title: 'Profiles You Visited',
                    subtitle: 'Revisit the profiles you explored',
                    onViewAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VisitedProfilesScreen(),
                        ),
                      );
                    },
                    icon: Icons.history_rounded,
                    iconColor: const Color(0xFF8B7355),
                  ),
                  const SizedBox(height: 14),

                  if (hasError)
                    _EmptySection(
                      message:
                          "Couldn't load visited profiles. Pull down to retry.",
                    )
                  else if (isLoading)
                    _SkeletonRow()
                  else if (data!.visitedProfiles.isEmpty)
                    _EmptySection(
                      message: "You haven't visited any profiles yet.",
                    )
                  else
                    _VisitedProfileRow(
                      profiles: data.visitedProfiles,
                      service: _svc,
                      showInfo: true,
                    ),

                  const SizedBox(height: 32),
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
// Banner Carousel
// ─────────────────────────────────────────────────────────────────────────────
class _BannerCarousel extends StatelessWidget {
  final List<_ServiceBanner> banners;
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  const _BannerCarousel({
    required this.banners,
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 190,
              child: Stack(
                children: [
                  // ── scrolling image layer ────────────────────────────
                  PageView.builder(
                    controller: controller,
                    itemCount: banners.length,
                    onPageChanged: onPageChanged,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (_, i) => Image.asset(
                      banners[i].image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, err, stack) => Container(
                        color: const Color(0xFFEEE0D5),
                        child: const Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                  // ── static overlay (text + button stay) ─────────────
                  _BannerOverlay(banner: banners[currentPage]),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(banners.length, (i) {
            final active = i == currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: active ? 12 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary.withValues(alpha: 0.8)
                    : const Color(0xFFD4C4B5).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BannerOverlay extends StatelessWidget {
  final _ServiceBanner banner;
  const _BannerOverlay({required this.banner});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // gradient
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.65),
                ],
                stops: const [0.3, 1.0],
              ),
            ),
          ),
        ),
        // text bottom-left
        Positioned(
          left: 16,
          bottom: 16,
          right: 120,
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Column(
                key: ValueKey(banner.title),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    banner.subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Book Now button
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: () => HapticFeedback.lightImpact(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Book Now',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onViewAll;
  final Color? dotColor;
  final IconData? icon;
  final Color? iconColor;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    required this.onViewAll,
    this.dotColor,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: dotColor!.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: iconColor ?? AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onViewAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF9A8A7A),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal Profile Row  — MatchResult list (engine-scored recent matches)
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileRow extends StatelessWidget {
  final List<dynamic> matchResults;
  final bool showInfo;
  final ValueChanged<String>? onProfileTap;

  const _ProfileRow({
    required this.matchResults,
    this.showInfo = true,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: matchResults.length,
        itemBuilder: (_, i) {
          final match = matchResults[i];
          final profile = match.profile;
          final score = match.totalScore;
          return ProfileCard(
            profile: profile,
            matchScore: score,
            variant: ProfileCardVariant.compact,
            showInfo: showInfo,
            onTap: onProfileTap != null
                ? () => onProfileTap!(profile.id)
                : null,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal Profile Row  — plain Profile list (visited profiles)
// ─────────────────────────────────────────────────────────────────────────────
class _VisitedProfileRow extends StatelessWidget {
  final List<Profile> profiles;
  final HomeService service;
  final bool showInfo;

  const _VisitedProfileRow({
    required this.profiles,
    required this.service,
    this.showInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: profiles.length,
        itemBuilder: (_, i) {
          final profile = profiles[i];
          // Visited profiles: score is approximate (no pre-computed score stored)
          final score = 50;
          return ProfileCard(
            profile: profile,
            matchScore: score,
            variant: ProfileCardVariant.compact,
            showInfo: showInfo,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton row while loading
// ─────────────────────────────────────────────────────────────────────────────
class _SkeletonRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 4,
        itemBuilder: (context, index) => _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 162,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Container(height: 145, color: const Color(0xFFEEE8E0)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBar(width: 100, height: 12),
                const SizedBox(height: 6),
                _shimmerBar(width: 120, height: 10),
                const SizedBox(height: 4),
                _shimmerBar(width: 80, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7DF),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptySection extends StatelessWidget {
  final String message;
  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF9A8A7A),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
