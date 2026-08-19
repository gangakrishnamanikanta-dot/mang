import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/theme.dart';
import '../../../models/profile.dart';
import '../../shared/services/lookup_service.dart';
import '../../../models/interest.dart';
import '../../interests/services/interest_service.dart';
import '../../../core/di.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../auth/services/supabase_service.dart';

class ProfileDetailScreen extends StatefulWidget {
  final Profile profile;
  const ProfileDetailScreen({super.key, required this.profile});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  Map<String, List<LookupOption>> _lookups = {};
  bool _isLoading = true;
  String? _errorMessage;
  Interest? _currentInterest;
  bool _isSendingInterest = false;

  final ScrollController _scrollController = ScrollController();
  final ScrollController _navScrollController = ScrollController();

  final List<String> _sections = [
    'Basic',
    'Education',
    'Family',
    'Lifestyle',
    'Cultural',
    'Career',
  ];
  final List<GlobalKey> _sectionKeys = List.generate(6, (index) => GlobalKey());

  int _activeSectionIndex = 0;
  bool _isAutoScrolling = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadData() async {
    final lookupService = LookupService();
    final interestService = getIt<InterestService>();

    try {
      final results = await Future.wait([
        lookupService.fetchAllProfileLookups(),
        interestService.getInterestStatus(widget.profile.id),
      ]);

      if (mounted) {
        setState(() {
          _lookups = results[0] as Map<String, List<LookupOption>>;
          _currentInterest = results[1] as Interest?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppException.from(e).message;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _navScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isAutoScrolling || !_scrollController.hasClients) return;

    final safeAreaTop = MediaQuery.of(context).padding.top;
    final appBarHeight = kToolbarHeight + safeAreaTop;
    final stickyHeaderHeight = 60.0;
    final stickyBottom = appBarHeight + stickyHeaderHeight;
    final threshold = stickyBottom + 20.0; // 20px padding

    int newIndex = 0;

    for (int i = _sectionKeys.length - 1; i >= 0; i--) {
      final key = _sectionKeys[i];
      if (key.currentContext != null) {
        final RenderBox box =
            key.currentContext!.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero).dy;

        if (position <= threshold) {
          newIndex = i;
          break;
        }
      }
    }

    if (_activeSectionIndex != newIndex) {
      setState(() {
        _activeSectionIndex = newIndex;
      });
      _scrollToNav(newIndex);
    }
  }

  void _scrollToNav(int index) {
    if (!_navScrollController.hasClients) return;
    final itemWidth = 100.0; // Approx width of a nav item
    final targetOffset =
        (index * itemWidth) -
        (MediaQuery.of(context).size.width / 2) +
        (itemWidth / 2);
    _navScrollController.animateTo(
      targetOffset.clamp(0.0, _navScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onNavTapped(int index) async {
    final key = _sectionKeys[index];
    if (key.currentContext != null) {
      setState(() {
        _activeSectionIndex = index;
        _isAutoScrolling = true;
      });

      _scrollToNav(index);

      final RenderBox box = key.currentContext!.findRenderObject() as RenderBox;

      final safeAreaTop = MediaQuery.of(context).padding.top;
      final appBarHeight = kToolbarHeight + safeAreaTop;
      final stickyHeaderHeight = 60.0;
      final stickyBottom = appBarHeight + stickyHeaderHeight;

      final targetOffset =
          _scrollController.offset +
          box.localToGlobal(Offset.zero).dy -
          stickyBottom;

      await _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      setState(() {
        _isAutoScrolling = false;
      });
    }
  }

  String _getLookupLabel(String table, int? id) {
    if (id == null) return 'Not provided';
    final options = _lookups[table] ?? [];
    try {
      return options.firstWhere((opt) => opt.id == id).label;
    } catch (_) {
      return 'Not provided';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF8F2),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF8F2),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSliverAppBar(),
              _buildPersistentHeader(),
              SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionContainer(0, _buildBasicSection()),
                  _buildSectionContainer(1, _buildEducationSection()),
                  _buildSectionContainer(2, _buildFamilySection()),
                  _buildSectionContainer(3, _buildLifestyleSection()),
                  _buildSectionContainer(4, _buildCulturalSection()),
                  _buildSectionContainer(5, _buildCareerSection()),
                  const SizedBox(height: 120), // Padding for bottom action bar
                ]),
              ),
            ],
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomBar()),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 400.0,
      pinned: true,
      backgroundColor: const Color(0xFFFFF8F2),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ),
      ],
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            widget.profile.profilePhotoUrl != null
                ? Image.network(
                    widget.profile.profilePhotoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildImageFallback(),
                  )
                : _buildImageFallback(),
            // Gradient Overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.6, 1.0],
                ),
              ),
            ),
            // Info Text
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.profile.fullName,
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.profile.isVerified) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFFF5B759),
                          size: 24,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      _age > 0 ? '$_age yrs' : null,
                      widget.profile.company ?? 'Professional',
                    ].where((s) => s != null && s.isNotEmpty).join(' • '),
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (widget.profile.heightInches != null)
                    Text(
                      '${widget.profile.heightInches! ~/ 12}\'${widget.profile.heightInches! % 12}"',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 15,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _age {
    if (widget.profile.dateOfBirth == null) return 0;
    final dob = DateTime.tryParse(widget.profile.dateOfBirth!);
    if (dob == null) return 0;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Widget _buildImageFallback() {
    final isFemale = widget.profile.gender?.toLowerCase() == 'female';
    return Container(
      color: isFemale ? const Color(0xFFFFF0F0) : const Color(0xFFF0F4FF),
      child: Center(
        child: Icon(
          isFemale ? Icons.face_3_rounded : Icons.face_rounded,
          size: 100,
          color: isFemale ? const Color(0xFFE8A0A0) : const Color(0xFFA0B8E8),
        ),
      ),
    );
  }

  Widget _buildPersistentHeader() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SectionHeaderDelegate(
        child: Container(
          color: const Color(0xFFFFF8F2),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _navScrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: _sections.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final isActive = _activeSectionIndex == index;
                    return GestureDetector(
                      onTap: () => _onNavTapped(index),
                      child: Container(
                        margin: const EdgeInsets.only(
                          right: 8,
                          top: 10,
                          bottom: 10,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? AppColors.primary
                                : const Color(0xFFE5D5C5),
                          ),
                        ),
                        child: Text(
                          _sections[index],
                          style: GoogleFonts.inter(
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF9A8A7A),
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(height: 1, color: const Color(0xFFE5D5C5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContainer(int index, Widget child) {
    return Container(
      key: _sectionKeys[index],
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: child,
    );
  }

  Widget _buildBasicSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Basic Details'),
        _buildRow('Full Name', widget.profile.fullName),
        _buildRow('Gender', widget.profile.gender ?? 'Not provided'),
        if (widget.profile.dateOfBirth != null)
          _buildRow('Date of Birth', widget.profile.dateOfBirth!),
        _buildRow(
          'Height',
          widget.profile.heightInches != null
              ? '${widget.profile.heightInches! ~/ 12} ft ${widget.profile.heightInches! % 12} in'
              : 'Not provided',
        ),
        _buildRow(
          'Marital Status',
          _getLookupLabel('marital_statuses', widget.profile.maritalStatusId),
        ),
        _buildRow('City', widget.profile.city ?? 'Not provided'),
        _buildRow('State / Region', widget.profile.state ?? 'Not provided'),
      ],
    );
  }

  Widget _buildEducationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Education'),
        _buildRow(
          'Highest Education',
          _getLookupLabel(
            'education_levels',
            widget.profile.highestEducationId,
          ),
        ),
        _buildRow(
          'College / University',
          widget.profile.college ?? 'Not provided',
        ),
      ],
    );
  }

  Widget _buildFamilySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Family Details'),
        _buildRow(
          'Family Type',
          _getLookupLabel('family_types', widget.profile.familyTypeId),
        ),
        _buildRow('Father Name', widget.profile.fatherName ?? 'Not provided'),
        _buildRow(
          'Father Occupation',
          widget.profile.fatherOccupation ?? 'Not provided',
        ),
        _buildRow('Mother Name', widget.profile.motherName ?? 'Not provided'),
        _buildRow(
          'Mother Occupation',
          widget.profile.motherOccupation ?? 'Not provided',
        ),
        _buildRow(
          'No. of Brothers',
          widget.profile.brothersCount?.toString() ?? 'Not provided',
        ),
        _buildRow(
          'No. of Sisters',
          widget.profile.sistersCount?.toString() ?? 'Not provided',
        ),
        _buildRow('Native Place', widget.profile.nativePlace ?? 'Not provided'),
      ],
    );
  }

  Widget _buildLifestyleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Habits'),
        _buildRow(
          'Diet',
          _getLookupLabel('food_preferences', widget.profile.foodPreferenceId),
        ),
        _buildRow(
          'Smoking',
          _getLookupLabel('smoking_habits', widget.profile.smokingId),
        ),
        _buildRow(
          'Drinking',
          _getLookupLabel('drinking_habits', widget.profile.drinkingId),
        ),
        if (widget.profile.hobbies != null &&
            widget.profile.hobbies!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Hobbies & Interests',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF9A8A7A),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.profile.hobbies!
                  .map(
                    (h) => Chip(
                      label: Text(h, style: GoogleFonts.inter(fontSize: 12)),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE5D5C5)),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        if (widget.profile.aboutMe != null &&
            widget.profile.aboutMe!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'About Me',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF9A8A7A),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              widget.profile.aboutMe!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCulturalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Cultural & Astrology'),
        _buildRow(
          'Mother Tongue',
          _getLookupLabel('mother_tongues', widget.profile.motherTongueId),
        ),
        _buildRow('Caste', _getLookupLabel('castes', widget.profile.casteId)),
        _buildRow('Sub-caste', widget.profile.subCaste ?? 'Not provided'),
        _buildRow(
          'Gothram',
          _getLookupLabel('gothrams', widget.profile.gothramId),
        ),
        _buildRow('Pravara', widget.profile.pravara ?? 'Not provided'),
        _buildRow(
          'Veda Shakha',
          _getLookupLabel('veda_shakhas', widget.profile.vedaShakhaId),
        ),
        _buildRow(
          'Nakshatram',
          _getLookupLabel('nakshatras', widget.profile.nakshatraId),
        ),
        _buildRow('Rashi', _getLookupLabel('rashis', widget.profile.rashiId)),
        _buildRow('Pada', _getLookupLabel('padas', widget.profile.padaId)),
        _buildRow('Kuja Dosham', widget.profile.kujaDosham ?? 'Not provided'),
      ],
    );
  }

  Widget _buildCareerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Career'),
        _buildRow(
          'Occupation',
          _getLookupLabel('occupations', widget.profile.occupationId),
        ),
        _buildRow('Company Name', widget.profile.company ?? 'Not provided'),
        _buildRow(
          'Work Location',
          widget.profile.workLocation ?? 'Not provided',
        ),
        _buildRow(
          'Annual Income',
          _getLookupLabel('annual_incomes', widget.profile.annualIncomeId),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF9A8A7A),
              ),
            ),
          ),
          const Text(':', style: TextStyle(color: Color(0xFF9A8A7A))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return const SizedBox.shrink();
    final currentUserId = user.id;
    final isSender = _currentInterest?.isSentByMe(currentUserId) ?? false;
    final status = _currentInterest?.status;

    if (_currentInterest != null && !isSender && status == 'pending') {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSendingInterest
                    ? null
                    : () async {
                        setState(() => _isSendingInterest = true);
                        try {
                          await getIt<InterestService>().declineInterest(
                            _currentInterest!.id,
                          );
                          await _loadData();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e is AppException
                                      ? e.message
                                      : 'Error declining interest',
                                ),
                                backgroundColor: const Color(0xFFFF3B30),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isSendingInterest = false);
                          }
                        }
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFFC62828)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  'Decline',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFC62828),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSendingInterest
                    ? null
                    : () async {
                        setState(() => _isSendingInterest = true);
                        try {
                          await getIt<InterestService>().acceptInterest(
                            _currentInterest!.id,
                          );
                          await _loadData();
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
                                  e is AppException
                                      ? e.message
                                      : 'Error accepting interest',
                                ),
                                backgroundColor: const Color(0xFFFF3B30),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isSendingInterest = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.5,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  'Accept',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    String buttonText = 'Send Interest';
    IconData buttonIcon = Icons.favorite_rounded;
    Color buttonColor = AppColors.primary;
    VoidCallback? action;

    if (_currentInterest != null) {
      if (status == 'pending') {
        if (isSender) {
          buttonText = 'Cancel Request';
          buttonIcon = Icons.close_rounded;
          buttonColor = Colors.grey.shade600;
          action = () async {
            setState(() => _isSendingInterest = true);
            try {
              await getIt<InterestService>().cancelInterest(
                _currentInterest!.id,
              );
              await _loadData();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e is AppException
                          ? e.message
                          : 'Error cancelling request',
                    ),
                    backgroundColor: const Color(0xFFFF3B30),
                  ),
                );
              }
            } finally {
              if (mounted) setState(() => _isSendingInterest = false);
            }
          };
        }
      } else if (status == 'accepted') {
        buttonText = 'Connected';
        buttonIcon = Icons.check_circle;
        buttonColor = const Color(0xFF2E7D32);
        action = null; // Disabled
      } else if (status == 'declined') {
        buttonText = 'Declined';
        buttonIcon = Icons.cancel;
        buttonColor = const Color(0xFFC62828);
        action = null; // Disabled
      }
    } else {
      action = () async {
        setState(() => _isSendingInterest = true);
        try {
          await getIt<InterestService>().sendInterest(widget.profile.id);
          await _loadData();
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
                  e is AppException
                      ? e.message
                      : 'Something went wrong. Please try again.',
                ),
                backgroundColor: const Color(0xFFFF3B30),
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isSendingInterest = false);
        }
      };
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_isSendingInterest || action == null) ? null : action,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                disabledBackgroundColor: buttonColor.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: _isSendingInterest
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(buttonIcon, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          buttonText,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
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

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SectionHeaderDelegate({required this.child});

  @override
  double get minExtent => 60.0;

  @override
  double get maxExtent => 60.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate oldDelegate) {
    return true;
  }
}
