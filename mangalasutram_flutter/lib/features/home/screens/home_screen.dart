import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/theme.dart';
import '../views/home_tab.dart';
import '../../matching/screens/matches_tab.dart';

import '../../messaging/screens/inbox_tab.dart';
import '../../subscription/screens/premium_tab.dart';
import '../../interests/screens/interests_tab.dart';
import '../../../models/profile.dart';
import '../services/home_service.dart';
import '../../auth/services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _selectedProfileId;
  Profile? _myProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await HomeService.instance.getMyProfile();
    if (mounted) {
      setState(() => _myProfile = profile);
    }
  }

  static const List<_NavItem> _navItems = [
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
      icon: Icons.volunteer_activism_rounded,
      outlinedIcon: Icons.volunteer_activism_outlined,
      label: 'Interests',
    ),
    _NavItem(
      icon: Icons.explore_rounded,
      outlinedIcon: Icons.explore_outlined,
      label: 'Discover',
    ),
    _NavItem(
      icon: Icons.star_rounded,
      outlinedIcon: Icons.star_outline_rounded,
      label: 'Plans',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      // Custom AppBar embedded as a PreferredSize widget
      appBar: (_currentIndex == 0 || _currentIndex == 1 || _currentIndex == 2)
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: HomeAppBar(
                currentIndex: _currentIndex,
                profile: _myProfile,
              ),
            ),
      drawer: (_currentIndex == 1 || _currentIndex == 2)
          ? null
          : _ProfileSidebar(
              profile: _myProfile,
              onProfileUpdated: _loadProfile,
            ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeTab(onNavigateToMatches: (String? profileId) {
            setState(() {
              _selectedProfileId = profileId;
              _currentIndex = 1;
            });
          }),
          MatchesTab(initialProfileId: _selectedProfileId),
          const InterestsTab(),
          const InboxTab(),
          const PremiumTab(),
        ],
      ),
      bottomNavigationBar: _HomeBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: _navItems,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Sidebar (Drawer)
// ---------------------------------------------------------------------------
class _ProfileSidebar extends StatelessWidget {
  final Profile? profile;
  final VoidCallback onProfileUpdated;
  const _ProfileSidebar({this.profile, required this.onProfileUpdated});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFFFF8F2),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            accountName: Text(
              profile?.fullName ?? 'My Profile',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            accountEmail: const Text('View and edit your details'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: profile?.profilePhotoUrl != null
                  ? NetworkImage(profile!.profilePhotoUrl!)
                  : null,
              child: profile?.profilePhotoUrl == null
                  ? const Icon(Icons.person, color: AppColors.primary, size: 40)
                  : null,
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.edit_rounded,
              color: AppColors.textSecondary,
            ),
            title: const Text('Edit Profile'),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.pushNamed(context, '/edit-profile');
              onProfileUpdated();
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.settings_rounded,
              color: AppColors.textSecondary,
            ),
            title: const Text('Settings'),
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () async {
              Navigator.pop(context); // close drawer
              await SupabaseService.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
          const SizedBox(height: 20),
        ],
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
  const HomeAppBar({super.key, required this.currentIndex, this.profile});

  String get _title {
    switch (currentIndex) {
      case 1:
        return 'Matches';
      case 2:
        return 'Interests';
      case 3:
        return 'Discover';
      case 4:
        return 'My Profile';
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
          // Search button
          _AppBarIconButton(icon: Icons.search_rounded, onTap: () {}),
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
      height: 60 + MediaQuery.of(context).padding.bottom,
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
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFF9A8A7A),
                      ),
                      child: Text(item.label),
                    ),
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
