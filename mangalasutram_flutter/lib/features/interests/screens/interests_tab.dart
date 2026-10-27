import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../constants/theme.dart';
import '../../../models/interest.dart';
import '../services/interest_service.dart';
import '../../home/services/home_service.dart';
import '../../profile/screens/edit_sections/edit_religion_screen.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/di.dart';
import '../../shared/services/lookup_service.dart';
import '../../../models/lookup_option.dart';
import '../../../models/profile.dart';
import '../../../core/route_observer.dart';
import '../../auth/services/supabase_service.dart';
import '../../profile/screens/profile_detail_screen.dart';
import '../../messaging/screens/chat_conversation_screen.dart';
import '../../matching/widgets/match_celebration_dialog.dart';

enum InterestDirection { received, sent, shortlisted }

enum InterestStatus { all, pending, accepted, declined }

class InterestsTab extends StatefulWidget {
  const InterestsTab({super.key});

  @override
  State<InterestsTab> createState() => _InterestsTabState();
}

class _InterestsTabState extends State<InterestsTab> with RouteAware {
  final _svc = getIt<InterestService>();
  Map<String, List<LookupOption>>? _lookups;

  InterestDirection _selectedDirection = InterestDirection.received;
  InterestStatus _selectedStatus = InterestStatus.all;

  final List<Interest> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _fetchToken = 0;

  // Shortlists state
  final List<Map<String, dynamic>> _shortlistedItems = [];
  bool _isLoadingShortlists = false;
  bool _hasMoreShortlists = true;
  int _shortlistOffset = 0;

  // Horoscope Requests state
  List<Map<String, dynamic>> _incomingHoroscopeRequests = [];

  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20;

  RealtimeChannel? _interestsRealtimeChannel;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadLookups();
    _loadData(refresh: true);
    _svc.interestsRefreshTrigger.addListener(_onInterestsRefreshed);
    _initRealtime();
  }

  void _initRealtime() {
    try {
      final myId = SupabaseService.client.auth.currentUser?.id;
      if (myId == null) return;

      _interestsRealtimeChannel = SupabaseService.client
          .channel('public:interests_tab_realtime:$myId')
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
              debugPrint('[InterestsTab Realtime]: Interests change detected -> live refresh');
              if (mounted) _loadData(refresh: true);
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
              debugPrint('[InterestsTab Realtime]: Shortlist change detected -> live refresh');
              if (mounted && _selectedDirection == InterestDirection.shortlisted) {
                _loadShortlists(refresh: true);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[InterestsTab Realtime Error]: $e');
    }
  }

  void _onInterestsRefreshed() {
    if (mounted) {
      if (_selectedDirection == InterestDirection.shortlisted) {
        _loadShortlists(refresh: true);
      } else {
        _loadData(refresh: true);
      }
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
  void didPopNext() {
    if (_selectedDirection == InterestDirection.shortlisted) {
      _loadShortlists(refresh: true);
    } else {
      _loadData(refresh: true);
    }
  }

  @override
  void dispose() {
    _svc.interestsRefreshTrigger.removeListener(_onInterestsRefreshed);
    routeObserver.unsubscribe(this);
    try {
      if (_interestsRealtimeChannel != null) {
        SupabaseService.client.removeChannel(_interestsRealtimeChannel!);
      }
    } catch (_) {}
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_selectedDirection == InterestDirection.shortlisted) {
        _loadShortlists();
      } else {
        _loadData();
      }
    }
  }

  Future<void> _loadLookups() async {
    try {
      final val = await LookupService().fetchAllProfileLookups();
      if (mounted) setState(() => _lookups = val);
    } catch (_) {}
  }

  String _statusToString(InterestStatus s) {
    switch (s) {
      case InterestStatus.all:
        return 'All';
      case InterestStatus.pending:
        return 'Pending';
      case InterestStatus.accepted:
        return 'Accepted';
      case InterestStatus.declined:
        return 'Declined';
    }
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    if (refresh) {
      setState(() {
        _items.clear();
        _hasMore = true;
      });
    }

    if (!_hasMore) return;

    final currentToken = ++_fetchToken;

    setState(() {
      _isLoading = true;
    });

    try {
      String? lastCreatedAt;
      String? lastId;
      if (_items.isNotEmpty && !refresh) {
        lastCreatedAt = _items.last.createdAt.toUtc().toIso8601String();
        lastId = _items.last.id;
      }

      final statusStr = _statusToString(_selectedStatus);

      final requestsFuture = refresh
          ? HomeService.instance.getIncomingHoroscopeRequests()
          : Future.value(_incomingHoroscopeRequests);

      final results = await Future.wait([
        _selectedDirection == InterestDirection.received
            ? _svc.getReceivedInterests(
                status: statusStr,
                lastCreatedAt: lastCreatedAt,
                lastId: lastId,
                limit: _pageSize,
              )
            : _svc.getSentInterests(
                status: statusStr,
                lastCreatedAt: lastCreatedAt,
                lastId: lastId,
                limit: _pageSize,
              ),
        requestsFuture,
      ]);

      final data = results[0] as List<Interest>;
      final incomingReqs = results[1] as List<Map<String, dynamic>>;

      if (mounted && _fetchToken == currentToken) {
        setState(() {
          _items.addAll(data);
          if (refresh) _incomingHoroscopeRequests = incomingReqs;
          if (data.length < _pageSize) _hasMore = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _fetchToken == currentToken) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildHoroscopeRequestsBanner() {
    final count = _incomingHoroscopeRequests.length;
    final firstReq = _incomingHoroscopeRequests.first;
    final senderName = firstReq['sender_name'] ?? 'A member';
    final senderPhoto = firstReq['sender_photo'] as String?;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A121A), Color(0xFF320810)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A121A).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFC99A4B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flare_rounded, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '$count Horoscope ${count == 1 ? "Request" : "Requests"}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE5D5C5),
                backgroundImage: senderPhoto != null && senderPhoto.isNotEmpty
                    ? NetworkImage(senderPhoto)
                    : null,
                child: senderPhoto == null || senderPhoto.isEmpty
                    ? const Icon(Icons.person, color: Color(0xFF4A121A), size: 22)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$senderName requested your horoscope ✨',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFDE8C0),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Add your Birth Star & Rashi to calculate mutual 36-Guna matching.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditReligionScreen(),
                  ),
                ).then((_) => _loadData(refresh: true));
              },
              icon: const Icon(Icons.stars_rounded, size: 16),
              label: Text(
                'Add Birth Star & Share Horoscope ✨',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC99A4B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildToggleBar(),
            if (_incomingHoroscopeRequests.isNotEmpty &&
                _selectedDirection == InterestDirection.received)
              _buildHoroscopeRequestsBanner(),
            if (_selectedDirection != InterestDirection.shortlisted)
              _buildStatusFilters(),
            Expanded(
              child: _selectedDirection == InterestDirection.shortlisted
                  ? _buildShortlistsList()
                  : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadShortlists({bool refresh = false}) async {
    if (_isLoadingShortlists && !refresh) return;

    if (refresh) {
      setState(() {
        _shortlistedItems.clear();
        _hasMoreShortlists = true;
        _shortlistOffset = 0;
      });
    }

    if (!_hasMoreShortlists) return;

    setState(() => _isLoadingShortlists = true);

    try {
      final data = await _svc.getMyShortlists(
        limit: _pageSize,
        offset: _shortlistOffset,
      );

      if (mounted) {
        setState(() {
          _shortlistedItems.addAll(data);
          _shortlistOffset += data.length;
          if (data.length < _pageSize) _hasMoreShortlists = false;
          _isLoadingShortlists = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingShortlists = false);
    }
  }

  void _onDirectionChanged(InterestDirection dir) {
    if (_selectedDirection == dir) return;
    setState(() => _selectedDirection = dir);
    if (dir == InterestDirection.shortlisted) {
      _loadShortlists(refresh: true);
    } else {
      _loadData(refresh: true);
    }
  }

  void _onStatusChanged(InterestStatus status) {
    if (_selectedStatus == status) return;
    setState(() => _selectedStatus = status);
    _loadData(refresh: true);
  }

  int _calculateAge(String? dobStr) {
    if (dobStr == null) return 25;
    final dob = DateTime.tryParse(dobStr);
    if (dob == null) return 25;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  String _getOccupation(int? id, String? company) {
    String occLabel = '';
    if (id != null && _lookups != null) {
      try {
        occLabel = _lookups!['occupations']!
            .firstWhere((e) => e.id == id)
            .label;
      } catch (_) {}
    }
    if (occLabel.isNotEmpty) return occLabel;
    if (company != null && company.isNotEmpty) return company;
    return 'Occupation not specified';
  }

  String _getRelativeTime(DateTime? date) {
    if (date == null) return 'Recently';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 1) return '${diff.inDays} days ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mins ago';
    return 'Just now';
  }

  String _getEmptyMessage() {
    final dir = _selectedDirection == InterestDirection.received
        ? "received"
        : "sent";
    switch (_selectedStatus) {
      case InterestStatus.pending:
        return "No pending interests $dir yet.";
      case InterestStatus.accepted:
        return "No accepted interests $dir yet.";
      case InterestStatus.declined:
        return "No declined interests $dir yet.";
      case InterestStatus.all:
        return "No interests $dir yet.";
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedDirection == InterestDirection.shortlisted
                      ? 'Saved Profiles'
                      : 'Interests',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedDirection == InterestDirection.shortlisted
                      ? 'Profiles you have shortlisted and saved for later review.'
                      : 'Manage people you are interested in and who are interested in you.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5D5C5), width: 1),
        ),
        child: Row(
          children: [
            _buildSegmentButton(
              title: 'Received',
              icon: Icons.favorite,
              isSelected: _selectedDirection == InterestDirection.received,
              onTap: () => _onDirectionChanged(InterestDirection.received),
            ),
            _buildSegmentButton(
              title: 'Sent',
              icon: Icons.send_outlined,
              isSelected: _selectedDirection == InterestDirection.sent,
              onTap: () => _onDirectionChanged(InterestDirection.sent),
            ),
            _buildSegmentButton(
              title: 'Shortlisted',
              icon: Icons.star_rounded,
              isSelected: _selectedDirection == InterestDirection.shortlisted,
              onTap: () => _onDirectionChanged(InterestDirection.shortlisted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _buildFilterChip('All', InterestStatus.all),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Pending',
            InterestStatus.pending,
            icon: Icons.hourglass_bottom,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Accepted',
            InterestStatus.accepted,
            icon: Icons.check_circle_outline,
            iconColor: const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Declined',
            InterestStatus.declined,
            icon: Icons.cancel_outlined,
            iconColor: const Color(0xFFC62828),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    InterestStatus status, {
    IconData? icon,
    Color? iconColor,
  }) {
    final isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () => _onStatusChanged(status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFDECDA) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE5D5C5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? AppColors.primary
                    : (iconColor ?? AppColors.textPrimary),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_items.isEmpty && _isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadData(refresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.5,
            alignment: Alignment.center,
            child: Text(
              _getEmptyMessage(),
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }

          final interest = _items[index];
          final p = interest.otherProfile ??
              Profile(
                id: _selectedDirection == InterestDirection.sent
                    ? interest.receiverProfileId
                    : interest.senderProfileId,
                email: '',
                fullName: 'Member Profile',
                createdAt: '',
                updatedAt: '',
              );

          final location = [
            p.city,
            p.state,
          ].where((s) => s != null && s.isNotEmpty).join(', ');

          return _InterestCardWidget(
            interest: interest,
            direction: _selectedDirection,
            occupation: _getOccupation(p.occupationId, p.company),
            location: location.isEmpty ? 'Not specified' : location,
            timeText: _getRelativeTime(interest.createdAt),
            age: _calculateAge(p.dateOfBirth),
            onAccept: () => _handleAccept(interest),
            onDecline: () => _handleDecline(interest.id),
            onCancel: () => _handleCancel(interest.id),
          );
        },
      ),
    );
  }

  Widget _buildShortlistsList() {
    if (_shortlistedItems.isEmpty && _isLoadingShortlists) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_shortlistedItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadShortlists(refresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.5,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.star_outline_rounded,
                  size: 56,
                  color: Color(0xFFD4A373),
                ),
                const SizedBox(height: 12),
                Text(
                  'No shortlisted profiles yet',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap the star icon on any profile in Matches or Discover to bookmark them here for quick review.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadShortlists(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: _shortlistedItems.length + (_hasMoreShortlists ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _shortlistedItems.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }

          final item = _shortlistedItems[index];
          final profileId = item['id'] as String;
          final fullName = item['full_name']?.toString() ?? 'Member Profile';
          final photoUrl = item['profile_photo_url']?.toString();
          final age = item['age'] as int? ?? _calculateAge(item['date_of_birth']?.toString());
          final city = item['city']?.toString();
          final state = item['state']?.toString();
          final matchScore = (item['match_score'] as num?)?.toDouble() ?? 0.0;
          final occId = item['occupation_id'] as int?;
          final occupation = _getOccupation(occId, null);
          final location = [city, state].where((s) => s != null && s.isNotEmpty).join(', ');

          return _ShortlistCardWidget(
            profileId: profileId,
            fullName: fullName,
            photoUrl: photoUrl,
            age: age,
            location: location.isEmpty ? 'Location not specified' : location,
            occupation: occupation,
            matchScore: matchScore,
            isVerified: item['is_verified'] == true,
            onRemove: () => _handleRemoveShortlist(profileId, index),
            onSendInterest: () => _handleSendInterest(profileId),
            onTap: () {
              final profile = Profile.fromJson(item);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileDetailScreen(profile: profile),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleRemoveShortlist(String profileId, int index) async {
    setState(() {
      _shortlistedItems.removeAt(index);
    });

    try {
      await _svc.toggleShortlist(profileId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from shortlisted profiles'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF2B2118),
          ),
        );
      }
    } catch (e) {
      _loadShortlists(refresh: true);
    }
  }

  Future<void> _handleSendInterest(String profileId) async {
    try {
      await _svc.sendInterest(profileId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interest sent successfully!'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is AppException ? e.message : 'Failed to send interest.',
            ),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  Future<void> _handleAccept(Interest interest) async {
    try {
      await _svc.acceptInterest(interest.id);
      _loadData(refresh: true);
      if (mounted) {
        final otherProfile = interest.otherProfile;
        Profile? myProfile;
        try {
          myProfile = await getIt<HomeService>().getMyProfile();
        } catch (_) {}

        if (mounted && otherProfile != null && myProfile != null) {
          MatchCelebrationDialog.show(
            context,
            myProfile: myProfile,
            matchedProfile: otherProfile,
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Interest accepted! Auspicious connection made.'),
              backgroundColor: Color(0xFF34C759),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is AppException ? e.message : 'Error accepting interest',
            ),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  Future<void> _handleDecline(String id) async {
    try {
      await _svc.declineInterest(id);
      _loadData(refresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is AppException ? e.message : 'Error declining interest',
            ),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  Future<void> _handleCancel(String id) async {
    try {
      await _svc.cancelInterest(id);
      _loadData(refresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is AppException ? e.message : 'Error cancelling request',
            ),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
  }
}

class _ShortlistCardWidget extends StatelessWidget {
  final String profileId;
  final String fullName;
  final String? photoUrl;
  final int age;
  final String location;
  final String occupation;
  final double matchScore;
  final bool isVerified;
  final VoidCallback onRemove;
  final VoidCallback onSendInterest;
  final VoidCallback onTap;

  const _ShortlistCardWidget({
    required this.profileId,
    required this.fullName,
    required this.photoUrl,
    required this.age,
    required this.location,
    required this.occupation,
    required this.matchScore,
    required this.isVerified,
    required this.onRemove,
    required this.onSendInterest,
    required this.onTap,
  });

  Widget _buildScoreBadge() {
    final scoreStr = matchScore > 0 ? '${matchScore.toStringAsFixed(0)}% Match' : 'High Match';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF8B2500),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        scoreStr,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5D5C5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 76,
                height: 76,
                color: const Color(0xFFE5D5C5),
                child: photoUrl != null && photoUrl!.isNotEmpty
                    ? Image.network(photoUrl!, fit: BoxFit.cover)
                    : const Icon(Icons.person, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(width: 14),
            // Profile details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                fullName,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                color: Color(0xFF2E7D32),
                                size: 14,
                              ),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: onRemove,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.star_rounded,
                            color: Color(0xFFE65100),
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$age yrs • $location',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    occupation,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildScoreBadge(),
                      ElevatedButton.icon(
                        onPressed: onSendInterest,
                        icon: const Icon(Icons.send_rounded, size: 11),
                        label: Text(
                          'Send Interest',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
    );
  }
}

class _InterestCardWidget extends StatelessWidget {
  final Interest interest;
  final InterestDirection direction;
  final String occupation;
  final String location;
  final String timeText;
  final int age;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCancel;

  const _InterestCardWidget({
    required this.interest,
    required this.direction,
    required this.occupation,
    required this.location,
    required this.timeText,
    required this.age,
    required this.onAccept,
    required this.onDecline,
    required this.onCancel,
  });

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;
    String text = interest.status.toUpperCase();

    if (interest.status == 'pending') {
      bgColor = const Color(0xFFFFF3E0);
      textColor = const Color(0xFFE65100);
    } else if (interest.status == 'accepted') {
      bgColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF2E7D32);
    } else {
      bgColor = const Color(0xFFFFEBEE);
      textColor = const Color(0xFFC62828);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = interest.otherProfile;
    if (p == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5D5C5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Photo
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 72,
              height: 72,
              color: const Color(0xFFE5D5C5),
              child: p.profilePhotoUrl != null
                  ? Image.network(p.profilePhotoUrl!, fit: BoxFit.cover)
                  : const Icon(Icons.person, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(width: 16),
          // Info Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        p.fullName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeText,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$age yrs • $location',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  occupation,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                _buildStatusBadge(),

                // Action Buttons
                if (direction == InterestDirection.received &&
                    interest.status == 'pending') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onDecline,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFC62828),
                            side: const BorderSide(color: Color(0xFFC62828)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF34C759),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 36),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (direction == InterestDirection.sent &&
                    interest.status == 'pending') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: Color(0xFFE5D5C5)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel Request'),
                    ),
                  ),
                ],
                if (interest.status == 'accepted') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileDetailScreen(profile: p),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF8C6D23)),
                          label: Text(
                            'View Profile',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF8C6D23)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD4AF37)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatConversationScreen(
                                  profileId: p.id,
                                  name: p.fullName,
                                  photoUrl: p.profilePhotoUrl,
                                  subcaste: p.subCaste,
                                  isVerified: p.isVerified,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
                          label: Text(
                            'Chat Now',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 36),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
