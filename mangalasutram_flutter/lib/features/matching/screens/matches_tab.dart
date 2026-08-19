import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/theme.dart';
import '../../home/services/home_service.dart';
import '../../shared/widgets/profile_card.dart';
import '../../../core/route_observer.dart';

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

class _MatchesTabState extends State<MatchesTab> with RouteAware {
  final _svc = HomeService.instance;
  late Future<List<dynamic>> _matchesFuture;
  final PageController _pageCtrl = PageController();

  bool _isRegular = true;
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryScrollToInitialProfile();
    });
    _svc.matchesRefreshTrigger.addListener(_onMatchesRefreshTriggered);
  }

  void _onMatchesRefreshTriggered() {
    if (mounted) {
      setState(() => _loadData());
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
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    setState(() => _loadData());
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

  void _tryScrollToInitialProfile() {
    if (widget.initialProfileId == null || _initialScrollDone) return;
    if (!_pageCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryScrollToInitialProfile();
      });
      return;
    }
    // We need the matches data — trigger a load if not already in flight
    _matchesFuture.then((matches) {
      final targetId = widget.initialProfileId;
      if (targetId == null) return;
      final index = matches.indexWhere(
        (m) => (m as dynamic).profile.id == targetId,
      );
      if (index >= 0 && _pageCtrl.hasClients) {
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

  void _loadData() {
    _matchesFuture = _svc.refreshAndWaitForMatches(limit: 20);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _matchesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text("Couldn't load matches. Pull down to retry."),
                    );
                  }
                  final matches = snapshot.data ?? [];
                  if (matches.isEmpty) {
                    return const Center(child: Text('No matches found.'));
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() => _loadData());
                      await _matchesFuture;
                    },
                    child: PageView.builder(
                      controller: _pageCtrl,
                      scrollDirection: Axis.vertical,
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final match = matches[index];
                        final profile = match.profile;
                        final score = match.totalScore;
                        return ProfileCard(
                          profile: profile,
                          matchScore: score,
                          variant: ProfileCardVariant.expanded,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5D5C5), width: 1),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isRegular = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _isRegular
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Regular',
                      style: GoogleFonts.inter(
                        color: _isRegular
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isRegular = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: !_isRegular
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: !_isRegular
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PRIME',
                          style: GoogleFonts.inter(
                            color: !_isRegular
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          FutureBuilder<List<dynamic>>(
            future: _matchesFuture,
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return Text(
                '$count Matches',
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFFE5D5C5), width: 1),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.search, color: Color(0xFF9A8A7A)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Search by name, location...',
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFF9A8A7A),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
