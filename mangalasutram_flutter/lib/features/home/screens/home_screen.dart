import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/theme.dart';
import '../../../core/di.dart';
import '../views/home_tab.dart';
import '../../matching/screens/matches_tab.dart';
import '../../messaging/screens/inbox_tab.dart';
import '../../subscription/screens/premium_tab.dart';
import '../../interests/screens/interests_tab.dart';
import '../../../models/profile.dart';
import '../services/home_service.dart';
import '../../profile/screens/settings_screen.dart';
import '../../profile/screens/partner_preferences_screen.dart';
import '../../profile/screens/profile_detail_screen.dart';
import '../../profile/services/profile_service.dart';
import '../../family/screens/family_room_screen.dart';
import '../../discovery/screens/discover_tab.dart';
import '../../auth/services/auth_service.dart';
import '../../notifications/services/fcm_messaging_service.dart';
import '../../notifications/services/notification_router.dart';
import './visited_profiles_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Profile? _myProfile;
  int _currentIndex = 0;
  String? _selectedProfileId;
  DateTime? _lastBackPressTime;
  final List<int> _tabHistory = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _tabHistory.remove(index);
      _tabHistory.add(_currentIndex);
      _currentIndex = index;
    });
  }

  bool _handleBackPress() {
    // 1. Pop back through tab history if user navigated between tabs
    while (_tabHistory.isNotEmpty) {
      final prevTab = _tabHistory.removeLast();
      if (prevTab != _currentIndex) {
        setState(() {
          _currentIndex = prevTab;
        });
        return false; // Handled, stay in app
      }
    }

    // 2. If on any tab other than Home, navigate back to Home tab (index 0)
    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
      });
      return false; // Handled, stay in app
    }

    // 3. Double-back press on Home tab to exit (Jeevansathi / Industry standard)
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Press back again to exit',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2B2118).withValues(alpha: 0.92),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.only(bottom: 70, left: 60, right: 60),
        ),
      );
      return false; // Don't exit on first press
    }

    return true; // Exit app on second press within 2s
  }

  Future<void> _loadProfile() async {
    final profile = await getIt<HomeService>().getMyProfile();
    if (mounted) {
      setState(() => _myProfile = profile);
      if (profile != null) {
        // Sync FCM device token and setup navigation tap handling
        final fcm = getIt<FcmMessagingService>();
        await fcm.initialize();
        await fcm.syncDeviceToken(userId: profile.id);
        fcm.setNotificationTapHandler((data) {
          if (mounted) {
            NotificationRouter.navigateFromPayload(context, data);
          }
        });
        final initialLaunchData = await fcm.checkTerminatedLaunch();
        if (initialLaunchData != null && mounted) {
          NotificationRouter.navigateFromPayload(context, initialLaunchData);
        }
      }
    }
  }

  List<_NavItem> get _activeNavItems {
    final isGuardian = _myProfile?.accountType == 'guardian';
    if (isGuardian) {
      return const [
        _NavItem(
          icon: Icons.favorite_rounded,
          outlinedIcon: Icons.favorite_outline_rounded,
          label: 'Matches',
        ),
        _NavItem(
          icon: Icons.search_rounded,
          outlinedIcon: Icons.search_outlined,
          label: 'Discover',
        ),
        _NavItem(
          icon: Icons.chat_bubble_rounded,
          outlinedIcon: Icons.chat_bubble_outline_rounded,
          label: 'Chats',
        ),
      ];
    }
    return const [
      _NavItem(
        icon: Icons.home_rounded,
        outlinedIcon: Icons.home_outlined,
        label: 'Home',
      ),
      _NavItem(
        icon: Icons.favorite_rounded,
        outlinedIcon: Icons.favorite_outline_rounded,
        label: 'Matches',
      ),
      _NavItem(
        icon: Icons.handshake_rounded,
        outlinedIcon: Icons.handshake_outlined,
        label: 'Interests',
      ),
      _NavItem(
        icon: Icons.chat_bubble_rounded,
        outlinedIcon: Icons.chat_bubble_outline_rounded,
        label: 'Chats',
      ),
      _NavItem(
        icon: Icons.workspace_premium_rounded,
        outlinedIcon: Icons.workspace_premium_outlined,
        label: 'Plans',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
    );

    final isGuardian = _myProfile?.accountType == 'guardian';
    final activeItems = _activeNavItems;

    // Constrain index
    if (_currentIndex >= activeItems.length) {
      _currentIndex = 0;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final shouldExit = _handleBackPress();
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF6F0),
        appBar: null,
        drawer: _ProfileSidebar(
          profile: _myProfile,
          onProfileUpdated: _loadProfile,
          onNavigateToPlans: () {
            if (!isGuardian) {
              _onTabSelected(4);
            }
          },
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: isGuardian
              ? [
                  MatchesTab(initialProfileId: _selectedProfileId),
                  const DiscoverTab(),
                  const InboxTab(),
                ]
              : [
                  HomeTab(
                    onNavigateToMatches: (String? profileId) {
                      _selectedProfileId = profileId;
                      _onTabSelected(1);
                    },
                    onNavigateToTab: (int index) {
                      _onTabSelected(index);
                    },
                  ),
                  MatchesTab(initialProfileId: _selectedProfileId),
                  const InterestsTab(),
                  const InboxTab(),
                  const PremiumTab(),
                ],
        ),
        bottomNavigationBar: _HomeBottomNav(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
          items: activeItems,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5-Card Luxury Vedic Sidebar (Drawer) — Wired to Supabase get_sidebar_summary
// ---------------------------------------------------------------------------
class _ProfileSidebar extends StatefulWidget {
  final Profile? profile;
  final VoidCallback onProfileUpdated;
  final VoidCallback? onNavigateToPlans;

  const _ProfileSidebar({
    this.profile,
    required this.onProfileUpdated,
    this.onNavigateToPlans,
  });

  @override
  State<_ProfileSidebar> createState() => _ProfileSidebarState();
}

class _ProfileSidebarState extends State<_ProfileSidebar> {
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _loadSidebarSummary();
  }

  Future<void> _loadSidebarSummary() async {
    final data = await HomeService.instance.getSidebarSummary();
    if (mounted && data.isNotEmpty) {
      setState(() => _summary = data);
    }
  }

  Future<void> _openPublicProfilePreview() async {
    HapticFeedback.lightImpact();
    final targetId = _summary['target_profile_id'] as String? ?? widget.profile?.id;
    if (targetId == null) return;

    Profile? targetProfile =
        await getIt<ProfileService>().getProfileById(targetId) ?? widget.profile;
    if (!mounted || targetProfile == null) return;

    final resolvedProfile = targetProfile;
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileDetailScreen(profile: resolvedProfile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGuardian = (_summary['account_type'] as String? ??
            widget.profile?.accountType ??
            'candidate') ==
        'guardian';

    final fullName = _summary['full_name'] as String? ??
        widget.profile?.fullName ??
        'Valued Member';
    final photoUrl = _summary['profile_photo_url'] as String? ??
        widget.profile?.profilePhotoUrl;
    final matrimonyId = _summary['matrimony_id'] as String? ??
        (widget.profile?.id != null
            ? 'MS-${widget.profile!.id.substring(0, 6).toUpperCase()}'
            : 'MS-MEMBER');
    final isVerified = _summary['is_verified'] as bool? ??
        widget.profile?.isVerified ??
        false;
    final isHidden = _summary['is_hidden'] as bool? ?? false;
    final inviteCode = _summary['family_invite_code'] as String?;
    final linkedCandName = _summary['linked_candidate_name'] as String?;
    final guardianRole = _summary['guardian_role'] as String?;

    final membership = _summary['membership'] is Map
        ? Map<String, dynamic>.from(_summary['membership'] as Map)
        : <String, dynamic>{};
    final tier = (membership['tier'] as String? ?? 'free').toUpperCase();
    final dailyMatchesLimit = membership['daily_matches_limit'] as int? ?? 5;
    final isPrime = tier != 'FREE';

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.84,
      backgroundColor: const Color(0xFFFBF8F1),
      child: Column(
        children: [
          // ── 1. Royal Burgundy Profile Header ───────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 18,
              left: 20,
              right: 20,
              bottom: 18,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF6E1732),
            ),
            child: Column(
              children: [
                // Circular Portrait with Temple Gold Ring
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFC99A4B),
                      width: 2.2,
                    ),
                    color: const Color(0xFF521024),
                    image: photoUrl != null && photoUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(photoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? const Icon(
                          Icons.person_rounded,
                          color: Color(0xFFE6C786),
                          size: 40,
                        )
                      : null,
                ),
                const SizedBox(height: 12),

                // Member Name in Temple Gold Playfair
                Text(
                  fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE6C786),
                  ),
                ),
                const SizedBox(height: 8),

                // Copyable Matrimony ID Pill + Verified Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Clipboard.setData(ClipboardData(text: matrimonyId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied ID: $matrimonyId'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ID: $matrimonyId',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy_rounded,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (isGuardian)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shield_rounded,
                            color: Color(0xFFC99A4B),
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            guardianRole ?? 'Guardian',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFE6C786),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: isVerified
                                ? const Color(0xFFC99A4B)
                                : Colors.white54,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVerified ? 'Verified' : 'Standard',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isVerified
                                  ? const Color(0xFFE6C786)
                                  : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Full-width Translucent Preview Button
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton(
                    onPressed: _openPublicProfilePreview,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isGuardian
                          ? (linkedCandName != null
                              ? 'View $linkedCandName\'s Biodata'
                              : 'View Child\'s Public Biodata')
                          : 'Preview My Public Profile',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Slim Temple Gold Quota & Plan Strip ─────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFC99A4B), Color(0xFFDAB065)],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isPrime
                        ? '✨ $tier PLAN • $dailyMatchesLimit Daily Matches'
                        : 'FREE PLAN • $dailyMatchesLimit/Day Matches Limit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3E101E),
                    ),
                  ),
                ),
                if (!isGuardian)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      if (widget.onNavigateToPlans != null) {
                        widget.onNavigateToPlans!();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PremiumTab(),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isPrime ? 'Manage' : 'Upgrade',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6E1732),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── 3. Five Clean Menu Cards ───────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              physics: const BouncingScrollPhysics(),
              children: [
                // Card 1: My Biodata (or Child's Biodata for Guardian)
                _SidebarMenuCard(
                  icon: Icons.badge_outlined,
                  title: isGuardian ? 'Child\'s Biodata' : 'My Biodata',
                  subtitle: isGuardian
                      ? 'Inspect photos, horoscope & personal bio'
                      : 'Edit photos, horoscope & personal details',
                  onTap: () async {
                    if (isGuardian) {
                      await _openPublicProfilePreview();
                    } else {
                      Navigator.pop(context);
                      await Navigator.pushNamed(context, '/edit-profile');
                      widget.onProfileUpdated();
                      _loadSidebarSummary();
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Card 2: Partner Preferences (Candidate only)
                if (!isGuardian) ...[
                  _SidebarMenuCard(
                    icon: Icons.tune_rounded,
                    title: 'Partner Preferences',
                    subtitle: 'Age, caste, gothram & match criteria',
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditPartnerPreferencesScreen(),
                        ),
                      );
                      widget.onProfileUpdated();
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // Card 3: Family Room (with inline Gold Invite Code badge)
                _SidebarMenuCard(
                  icon: Icons.groups_2_outlined,
                  title: 'Family Room',
                  subtitle: 'Discuss alliances with parents',
                  badgeText: inviteCode != null && inviteCode.isNotEmpty
                      ? 'Code: $inviteCode'
                      : null,
                  badgeBgColor: const Color(0xFFC99A4B),
                  badgeTextColor: Colors.white,
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FamilyRoomScreen(),
                      ),
                    );
                    _loadSidebarSummary();
                  },
                ),
                const SizedBox(height: 10),

                // Card 4: Saved & Visited
                _SidebarMenuCard(
                  icon: Icons.bookmark_border_rounded,
                  title: 'Saved & Visited',
                  subtitle: 'Shortlisted & recently viewed profiles',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VisitedProfilesScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Card 5: Settings & Privacy (with inline Active / Hidden status pill)
                _SidebarMenuCard(
                  icon: Icons.settings_outlined,
                  title: 'Settings & Privacy',
                  subtitle: 'Password, visibility, legal & support',
                  badgeText: isHidden ? 'Hidden' : 'Active',
                  badgeBgColor: isHidden
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFE6F4EA),
                  badgeTextColor: isHidden
                      ? const Color(0xFFE65100)
                      : const Color(0xFF1E8E3E),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                    widget.onProfileUpdated();
                    _loadSidebarSummary();
                  },
                ),
              ],
            ),
          ),

          // ── 4. Bottom Log Out Button ───────────────────────────────────
          Padding(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              bottom: MediaQuery.of(context).padding.bottom + 14,
              top: 4,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  await getIt<AuthService>().signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFEDE6DC)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Log Out',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6E1732),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color? badgeBgColor;
  final Color? badgeTextColor;
  final VoidCallback onTap;

  const _SidebarMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.badgeBgColor,
    this.badgeTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEDE6DC), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFF9F3EB),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF6E1732),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBgColor ?? const Color(0xFFC99A4B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badgeText!,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: badgeTextColor ?? Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF6E6259),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9A8A7A),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App Bar
// ---------------------------------------------------------------------------
class HomeAppBar extends StatelessWidget {
  final int currentIndex;
  final Profile? profile;
  final ValueChanged<int>? onTabSelected;
  const HomeAppBar({
    super.key,
    required this.currentIndex,
    this.profile,
    this.onTabSelected,
  });

  String get _title {
    switch (currentIndex) {
      case 1:
        return 'Matches';
      case 2:
        return 'Interests';
      case 3:
        return 'Discover';
      case 4:
        return 'Chats';
      case 5:
        return 'Plans';
      default:
        return 'Mangalasutram';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8F2),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: Row(
        children: [
          // Profile avatar (Opens Drawer)
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
                color: const Color(0xFFEEE0D5),
                image: profile?.profilePhotoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(profile!.profilePhotoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: profile?.profilePhotoUrl == null
                  ? ClipOval(
                      child: Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          // Title
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
            ),
          ),
          // Search button -> Switches to Discover Tab (Index 3)
          _AppBarIconButton(
            icon: Icons.search_rounded,
            onTap: () => onTabSelected?.call(3),
          ),
          const SizedBox(width: 8),
          // Notification button
          _AppBarIconButton(
            icon: Icons.notifications_outlined,
            onTap: () {},
            badge: 3,
          ),
        ],
      ),
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badge;
  const _AppBarIconButton({
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFECE7E0), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: const Color(0xFF1E1E1E), size: 18),
            if (badge > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom Navigation
// ---------------------------------------------------------------------------
class _NavItem {
  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
  });
}

class _HomeBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_NavItem> items;

  const _HomeBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58 + MediaQuery.of(context).padding.bottom,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
        border: Border(top: BorderSide(color: Color(0xFFF0EBE5), width: 1)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Row(
          children: List.generate(items.length, (i) {
            final isSelected = i == currentIndex;
            final item = items[i];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(i);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? item.icon : item.outlinedIcon,
                      color: isSelected
                          ? AppColors.primary
                          : const Color(0xFF9A8A7A),
                      size: 22,
                    ),
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFF9A8A7A),
                      ),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold,
                        ),
                      )
                    else
                      const SizedBox(height: 6),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
