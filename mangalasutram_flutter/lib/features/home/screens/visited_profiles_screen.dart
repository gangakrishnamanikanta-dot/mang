import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/theme.dart';
import '../../../core/di.dart';
import '../../../core/route_observer.dart';
import '../../../models/profile.dart';
import '../../interests/services/interest_service.dart';
import '../../profile/screens/profile_detail_screen.dart';
import '../services/home_service.dart';

class VisitedProfilesScreen extends StatefulWidget {
  final int initialTab;
  const VisitedProfilesScreen({super.key, this.initialTab = 0});

  @override
  State<VisitedProfilesScreen> createState() => _VisitedProfilesScreenState();
}

class _VisitedProfilesScreenState extends State<VisitedProfilesScreen>
    with RouteAware {
  final _homeSvc = getIt<HomeService>();
  final _interestSvc = getIt<InterestService>();

  static const Color _burgundy = Color(0xFF6E1732);
  static const Color _gold = Color(0xFFC99A4B);
  static const Color _bgCream = Color(0xFFFBF8F1);

  late int _selectedSegment;
  bool _loading = true;
  List<Map<String, dynamic>> _shortlists = [];
  List<Map<String, dynamic>> _visited = [];

  @override
  void initState() {
    super.initState();
    _selectedSegment = widget.initialTab;
    _loadAll();
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
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _interestSvc.getMyShortlists(limit: 40, offset: 0).catchError((_) => <Map<String, dynamic>>[]),
        _homeSvc.getVisitedProfilesWithScore(limit: 30).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (mounted) {
        setState(() {
          _shortlists = results[0];
          _visited = results[1];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeShortlist(String profileId, int index) async {
    HapticFeedback.lightImpact();
    final removed = _shortlists[index];
    setState(() {
      _shortlists.removeAt(index);
    });
    try {
      await _interestSvc.toggleShortlist(profileId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _shortlists.insert(index, removed);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCream,
      appBar: AppBar(
        backgroundColor: _bgCream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: _burgundy, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Saved & Visited',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF2B0912),
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Apple Segmented Control ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                backgroundColor: const Color(0xFFEDE6DC),
                thumbColor: Colors.white,
                groupValue: _selectedSegment,
                onValueChanged: (val) {
                  if (val != null) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedSegment = val);
                  }
                },
                children: {
                  0: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Saved (${_shortlists.length})',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: _selectedSegment == 0
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: _selectedSegment == 0
                            ? _burgundy
                            : const Color(0xFF6B5E54),
                      ),
                    ),
                  ),
                  1: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Recently Visited (${_visited.length})',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: _selectedSegment == 1
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: _selectedSegment == 1
                            ? _burgundy
                            : const Color(0xFF6B5E54),
                      ),
                    ),
                  ),
                },
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _burgundy),
                  )
                : RefreshIndicator(
                    color: _burgundy,
                    onRefresh: _loadAll,
                    child: _selectedSegment == 0
                        ? _buildSavedList()
                        : _buildVisitedGrid(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedList() {
    if (_shortlists.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EFE6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE6DDD0)),
                  ),
                  child: const Icon(
                    CupertinoIcons.bookmark,
                    size: 24,
                    color: _burgundy,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'No Saved Profiles Yet',
                  style: GoogleFonts.playfairDisplay(
                    color: const Color(0xFF2B0912),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Bookmark profiles from Matches or Discover to keep them organized here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7A6A5E),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: _shortlists.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _shortlists[index];
        final profile = Profile.fromJson(item);
        final matchScore = (item['match_score'] as num?)?.round();
        final location = [
          profile.city,
          profile.state,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
        final ageText = profile.age != null ? '${profile.age} yrs' : '';
        final subtitle = [ageText, location]
            .where((s) => s.isNotEmpty)
            .join(' • ');

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => ProfileDetailScreen(profile: profile),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE6DFD5), width: 0.7),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFF5EFE6),
                    backgroundImage: profile.profilePhotoUrl != null
                        ? NetworkImage(profile.profilePhotoUrl!)
                        : null,
                    child: profile.profilePhotoUrl == null
                        ? const Icon(
                            CupertinoIcons.person_fill,
                            color: _burgundy,
                            size: 24,
                          )
                        : null,
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
                                profile.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  color: const Color(0xFF1C1917),
                                ),
                              ),
                            ),
                            if (profile.isVerified) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.verified_rounded,
                                size: 15,
                                color: _gold,
                              ),
                            ],
                          ],
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF7A6A5E),
                            ),
                          ),
                        ],
                        if (matchScore != null && matchScore > 0) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF8EE),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _gold.withValues(alpha: 0.45),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              '$matchScore% Match',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF8A6218),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove from Saved',
                    icon: const Icon(
                      CupertinoIcons.bookmark_fill,
                      color: _burgundy,
                      size: 20,
                    ),
                    onPressed: () => _removeShortlist(profile.id, index),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVisitedGrid() {
    if (_visited.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EFE6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE6DDD0)),
                  ),
                  child: const Icon(
                    CupertinoIcons.clock,
                    size: 24,
                    color: _burgundy,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'No Recently Visited Profiles',
                  style: GoogleFonts.playfairDisplay(
                    color: const Color(0xFF2B0912),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Profiles you open will automatically appear here.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7A6A5E),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: _visited.length,
      itemBuilder: (context, index) {
        final data = _visited[index];
        final profile = Profile.fromJson(data);
        final score = (data['match_score'] as num?)?.round() ?? 75;
        final isBlurred = data['is_blurred'] == true;
        return _GridProfileCard(
          profile: profile,
          matchScore: score,
          isBlurred: isBlurred,
        );
      },
    );
  }
}

class _GridProfileCard extends StatelessWidget {
  final Profile profile;
  final int matchScore;
  final bool isBlurred;

  const _GridProfileCard({
    required this.profile,
    required this.matchScore,
    this.isBlurred = false,
  });

  int get _age => profile.computedAge;

  void _showUpgradeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3E0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.lock_open_fill,
                size: 30,
                color: Color(0xFFC99A4B),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unlock Full Profile History',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upgrade to Prime to view unlimited profile history and unlock full contact details.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/plans');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Upgrade to Prime',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = [
      profile.city,
      profile.state,
    ].where((s) => s != null && s.isNotEmpty).join(', ');
    final age = _age;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (isBlurred) {
          _showUpgradeSheet(context);
        } else {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => ProfileDetailScreen(profile: profile),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6DFD5), width: 0.7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (profile.profilePhotoUrl != null &&
                profile.profilePhotoUrl!.isNotEmpty)
              ImageFiltered(
                imageFilter: isBlurred
                    ? ImageFilter.blur(sigmaX: 12, sigmaY: 12)
                    : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Image.network(
                  profile.profilePhotoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildPlaceholder(),
                ),
              )
            else
              _buildPlaceholder(),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                  stops: const [0.4, 0.65, 1.0],
                ),
              ),
            ),

            // Top Match Pill
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFC99A4B).withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '$matchScore% Match',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF5D487),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            if (isBlurred)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.lock_fill,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),

            // Bottom Info
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isBlurred
                              ? 'Prime Member'
                              : '${profile.fullName}${age > 0 ? ', $age' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (profile.isVerified && !isBlurred) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFFC99A4B),
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFF3ECE2),
      child: const Center(
        child: Icon(
          CupertinoIcons.person_fill,
          size: 44,
          color: Color(0xFFB8A99A),
        ),
      ),
    );
  }
}
