import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/theme.dart';
import '../../../models/interest.dart';
import '../services/interest_service.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/di.dart';
import '../../shared/services/lookup_service.dart';
import '../../../models/profile.dart';

enum InterestDirection { received, sent }

enum InterestStatus { all, pending, accepted, declined }

class InterestsTab extends StatefulWidget {
  const InterestsTab({super.key});

  @override
  State<InterestsTab> createState() => _InterestsTabState();
}

class _InterestsTabState extends State<InterestsTab> {
  final _svc = getIt<InterestService>();
  Map<String, List<LookupOption>>? _lookups;

  InterestDirection _selectedDirection = InterestDirection.received;
  InterestStatus _selectedStatus = InterestStatus.all;

  final List<Interest> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _fetchToken = 0;

  final ScrollController _scrollController = ScrollController();

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadLookups();
    _loadData(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadData();
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

      final data = _selectedDirection == InterestDirection.received
          ? await _svc.getReceivedInterests(
              status: statusStr,
              lastCreatedAt: lastCreatedAt,
              lastId: lastId,
              limit: _pageSize,
            )
          : await _svc.getSentInterests(
              status: statusStr,
              lastCreatedAt: lastCreatedAt,
              lastId: lastId,
              limit: _pageSize,
            );

      if (mounted && _fetchToken == currentToken) {
        setState(() {
          _items.addAll(data);
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

  void _onDirectionChanged(InterestDirection dir) {
    if (_selectedDirection == dir) return;
    setState(() => _selectedDirection = dir);
    _loadData(refresh: true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildToggleBar(),
            _buildStatusFilters(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
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
                  'Interests',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage people you are interested in and who are interested in you.',
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
    final isReceived = _selectedDirection == InterestDirection.received;

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
            Expanded(
              child: GestureDetector(
                onTap: () => _onDirectionChanged(InterestDirection.received),
                child: Container(
                  decoration: BoxDecoration(
                    color: isReceived ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 14,
                          color: isReceived
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Received',
                          style: GoogleFonts.inter(
                            color: isReceived
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _onDirectionChanged(InterestDirection.sent),
                child: Container(
                  decoration: BoxDecoration(
                    color: !isReceived ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.send_outlined,
                          size: 14,
                          color: !isReceived
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sent',
                          style: GoogleFonts.inter(
                            color: !isReceived
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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
          final p = interest.otherProfile;
          if (p == null) return const SizedBox.shrink();

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
            onAccept: () => _handleAccept(interest.id),
            onDecline: () => _handleDecline(interest.id),
            onCancel: () => _handleCancel(interest.id),
          );
        },
      ),
    );
  }

  Future<void> _handleAccept(String id) async {
    try {
      await _svc.acceptInterest(id);
      _loadData(refresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interest accepted!'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
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
    final p = interest.otherProfile!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5D5C5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
