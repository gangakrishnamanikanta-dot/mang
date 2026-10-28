import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/theme.dart';
import '../../../models/lookup_option.dart';
import '../../../models/profile.dart';
import '../../../models/partner_preference.dart';
import '../../shared/services/lookup_service.dart';
import '../../../models/interest.dart';
import '../../interests/services/interest_service.dart';
import '../../home/services/home_service.dart';
import './edit_sections/edit_religion_screen.dart';
import '../../../core/di.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../auth/services/supabase_service.dart';
import '../../subscription/widgets/contact_unlock_dialog.dart';
import '../../subscription/widgets/quota_exhausted_sheet.dart';
import '../../messaging/screens/chat_conversation_screen.dart';
import '../services/profile_service.dart';
import '../../shared/services/vedic_astrology_service.dart';
import '../widgets/safety_action_sheet.dart';
import '../../family/widgets/discuss_with_family_sheet.dart';
import '../../family/services/family_service.dart';

class ProfileDetailScreen extends StatefulWidget {
  final Profile profile;
  const ProfileDetailScreen({super.key, required this.profile});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final ProfileService _profileService = ProfileService();
  final LookupService _lookupService = LookupService();
  final InterestService _interestService = getIt<InterestService>();

  late Profile _profile;
  PartnerPreference? _partnerPreference;
  Map<String, List<LookupOption>> _lookups = {};
  bool _isLoading = true;
  String? _errorMessage;
  Interest? _currentInterest;
  bool _isSendingInterest = false;
  Profile? _myProfile;
  bool _hasSentHoroscopeRequest = false;
  bool _isSendingHoroscopeRequest = false;
  int? _gunaMilanScore;

  final ScrollController _scrollController = ScrollController();
  final ScrollController _navScrollController = ScrollController();

  final List<String> _sections = [
    'Basic',
    'Cultural',
    'Education',
    'Career',
    'Family',
    'Lifestyle',
    'Preferences',
  ];
  final List<GlobalKey> _sectionKeys = List.generate(7, (index) => GlobalKey());

  int _activeSectionIndex = 0;
  bool _isAutoScrolling = false;
  final DateTime _screenOpenedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    HomeService.instance.recordProfileView(
      widget.profile.id,
      viewedFrom: 'profile_detail',
    );
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadData() async {
    try {
      final myProf = await HomeService.instance.getMyProfile();
      String? candidateId;
      Profile? effectiveMyProfile = myProf;
      if (myProf?.accountType == 'guardian') {
        final cand = await FamilyService.instance.getGuardianActiveCandidate();
        candidateId = cand?.candidateId;
        if (candidateId != null && candidateId.isNotEmpty) {
          final candProf = await _profileService.getProfileById(candidateId);
          if (candProf != null) {
            effectiveMyProfile = candProf;
          }
        }
      }

      final results = await Future.wait([
        _lookupService.fetchAllProfileLookups(),
        _interestService.getInterestStatus(
          widget.profile.id,
          onBehalfOf: candidateId,
        ),
        _profileService.getProfileById(widget.profile.id),
        _profileService.getPartnerPreferencesByProfileId(widget.profile.id),
        HomeService.instance.hasSentHoroscopeRequest(widget.profile.id),
      ]);

      if (mounted) {
        final fetchedProfile = results[2] as Profile?;
        _myProfile = effectiveMyProfile;
        if (fetchedProfile != null) {
          _profile = fetchedProfile;
        }
        final calculatedScore = _calculateGunaMilanScore();

        setState(() {
          _lookups = results[0] as Map<String, List<LookupOption>>;
          _currentInterest = results[1] as Interest?;
          _partnerPreference = results[3] as PartnerPreference?;
          _hasSentHoroscopeRequest = results[4] as bool? ?? false;
          _gunaMilanScore = calculatedScore;
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

  Future<void> _sendHoroscopeRequest() async {
    setState(() => _isSendingHoroscopeRequest = true);
    HapticFeedback.mediumImpact();

    final success = await HomeService.instance.sendHoroscopeRequest(_profile.id);

    if (mounted) {
      setState(() {
        _isSendingHoroscopeRequest = false;
        if (success) _hasSentHoroscopeRequest = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '📩 Horoscope request sent to ${_profile.fullName}!'
                : 'Could not send request. Please try again.',
          ),
          backgroundColor:
              success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  String _formatDateOfBirth(String? rawDob) {
    if (rawDob == null || rawDob.isEmpty) return 'Not provided';
    try {
      final dt = DateTime.parse(rawDob);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return rawDob;
    }
  }

  int? _calculateGunaMilanScore() {
    if (_myProfile == null) return null;
    final isMale = _myProfile!.gender?.toLowerCase() == 'male';
    final result = VedicAstrologyService.calculate(
      boyRashiId: isMale ? _myProfile!.rashiId : _profile.rashiId,
      boyNakshatraId: isMale ? _myProfile!.nakshatraId : _profile.nakshatraId,
      boyPada: isMale ? _myProfile!.padaId : _profile.padaId,
      girlRashiId: isMale ? _profile.rashiId : _myProfile!.rashiId,
      girlNakshatraId: isMale ? _profile.nakshatraId : _myProfile!.nakshatraId,
      girlPada: isMale ? _profile.padaId : _myProfile!.padaId,
    );
    return result?.roundedScore;
  }

  @override
  void dispose() {
    final dwellSeconds = DateTime.now().difference(_screenOpenedAt).inSeconds;
    if (dwellSeconds >= 1) {
      HomeService.instance.recordProfileView(
        _profile.id,
        dwellSeconds: dwellSeconds,
        viewedFrom: 'profile_detail',
      );
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _navScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isAutoScrolling || !_scrollController.hasClients) return;

    final safeAreaTop = MediaQuery.of(context).padding.top;
    final appBarHeight = kToolbarHeight + safeAreaTop;
    const stickyHeaderHeight = 60.0;
    final stickyBottom = appBarHeight + stickyHeaderHeight;
    final threshold = stickyBottom + 20.0;

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
    const itemWidth = 100.0;
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
      const stickyHeaderHeight = 60.0;
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

  String _getLookupLabelsList(String table, List<int>? ids) {
    if (ids == null || ids.isEmpty) return 'Doesn\'t Matter';
    final options = _lookups[table] ?? [];
    final labels = ids
        .map((id) {
          try {
            return options.firstWhere((opt) => opt.id == id).label;
          } catch (_) {
            return null;
          }
        })
        .where((l) => l != null)
        .join(', ');
    return labels.isNotEmpty ? labels : 'Doesn\'t Matter';
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
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
                      borderRadius: BorderRadius.circular(20),
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
                  _buildSectionContainer(1, _buildCulturalSection()),
                  _buildSectionContainer(2, _buildEducationSection()),
                  _buildSectionContainer(3, _buildCareerSection()),
                  _buildSectionContainer(4, _buildFamilySection()),
                  _buildSectionContainer(5, _buildLifestyleSection()),
                  _buildSectionContainer(6, _buildPreferencesSection()),
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
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.family_restroom_rounded, color: Colors.white),
            tooltip: 'Discuss with Family',
            onPressed: () {
              FocusScope.of(context).unfocus();
              DiscussWithFamilySheet.show(
                context: context,
                targetProfileId: _profile.id,
                candidateName: _profile.fullName,
                candidatePhoto: _profile.profilePhotoUrl,
                candidateCity: _profile.city,
              );
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onPressed: () {
              FocusScope.of(context).unfocus();
              SafetyActionSheet.show(
                context,
                profileId: _profile.id,
                fullName: _profile.fullName,
                onBlocked: () => Navigator.pop(context),
              );
            },
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _profile.profilePhotoUrl != null
                ? Image.network(
                    _profile.profilePhotoUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildImageFallback();
                    },
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
                          _profile.fullName,
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_profile.isVerified) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFFD4AF37),
                          size: 24,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      _profile.computedAge > 0 ? '${_profile.computedAge} yrs' : null,
                      _profile.company ?? _getLookupLabel('occupations', _profile.occupationId),
                      _profile.city,
                    ].where((s) => s != null && s.isNotEmpty && s != 'Not provided').join(' • '),
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_profile.heightInches != null)
                    Text(
                      '${_profile.heightInches! ~/ 12}\'${_profile.heightInches! % 12}"',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 14,
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

  Widget _buildImageFallback() {
    final isFemale = _profile.gender?.toLowerCase() == 'female';
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
        activeIndex: _activeSectionIndex,
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
        if (_profile.createdFor != null)
          _buildRow('Profile Created For', _profile.createdFor!),
        _buildRow('Full Name', _profile.fullName),
        _buildRow('Gender', _profile.gender ?? 'Not provided'),
        if (_profile.dateOfBirth != null && _profile.dateOfBirth!.isNotEmpty)
          _buildRow('Date of Birth', _formatDateOfBirth(_profile.dateOfBirth)),
        _buildRow(
          'Height',
          _profile.heightInches != null
              ? '${_profile.heightInches! ~/ 12}\'${_profile.heightInches! % 12}" (${_profile.heightInches} in)'
              : 'Not provided',
        ),
        _buildRow(
          'Marital Status',
          _getLookupLabel('marital_statuses', _profile.maritalStatusId),
        ),
        _buildRow(
          'Mother Tongue',
          _getLookupLabel('mother_tongues', _profile.motherTongueId),
        ),
        if (_profile.nativePlace != null)
          _buildRow('Native Place', _profile.nativePlace!),
        if (_profile.city != null)
          _buildRow('City', _profile.city!),
        if (_profile.state != null)
          _buildRow('State / Region', _profile.state!),
        if (_profile.countryId != null)
          _buildRow('Country', _getLookupLabel('countries', _profile.countryId)),
      ],
    );
  }

  Widget _buildCulturalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Cultural, Vedic & Astrology'),
        if (_profile.sampradayam != null)
          _buildRow('Sampradayam', _profile.sampradayam!),
        _buildRow('Caste', _getLookupLabel('castes', _profile.casteId)),
        _buildRow('Sub-caste', _profile.subCaste ?? 'Not provided'),
        _buildRow(
          'Gothram',
          _getLookupLabel('gothrams', _profile.gothramId),
        ),
        _buildRow('Pravara', _profile.pravara ?? 'Not provided'),
        _buildRow(
          'Veda Shakha',
          _getLookupLabel('veda_shakhas', _profile.vedaShakhaId),
        ),
        _buildRow(
          'Nakshatram',
          _getLookupLabel('nakshatras', _profile.nakshatraId),
        ),
        _buildRow('Rashi', _getLookupLabel('rashis', _profile.rashiId)),
        _buildRow('Pada', _getLookupLabel('padas', _profile.padaId)),
        if (_profile.timeOfBirth != null && _profile.timeOfBirth!.isNotEmpty)
          _buildRow('Time of Birth', _profile.timeOfBirth!),
        if (_profile.placeOfBirth != null && _profile.placeOfBirth!.isNotEmpty)
          _buildRow('Place of Birth', _profile.placeOfBirth!),
        _buildRow('Kuja Dosham', _profile.kujaDosham ?? (_profile.isManglik != null ? (_profile.isManglik! ? 'Yes' : 'No') : 'Not Specified')),
        if (_profile.kuladevata != null)
          _buildRow('Kuladevata', _profile.kuladevata!),
        if (_profile.sandhyavandanam != null)
          _buildRow('Sandhyavandanam', _profile.sandhyavandanam!),
        if (_profile.dailyPooja != null)
          _buildRow('Daily Pooja', _profile.dailyPooja!),
        if (_profile.slokaChanting != null)
          _buildRow('Sloka Chanting', _profile.slokaChanting!),
        if (_profile.templeVisits != null)
          _buildRow('Temple Visits', _profile.templeVisits!),
        if (_profile.festivalParticipation != null)
          _buildRow('Festivals', _profile.festivalParticipation!),
        const SizedBox(height: 16),
        _buildAstrologyCompatibilityCard(),
      ],
    );
  }

  Widget _buildAstrologyCompatibilityCard() {
    final isUserMissing =
        _myProfile == null ||
        _myProfile!.rashiId == null ||
        _myProfile!.nakshatraId == null;

    final isCandidateMissing =
        _profile.rashiId == null || _profile.nakshatraId == null;

    final gunaScore = _gunaMilanScore;
    final isComplete = !isUserMissing && !isCandidateMissing && gunaScore != null;

    if (isComplete) {
      final String tierLabel;
      final String tierDescription;
      final Color tierColor;
      final Color tierBgColor;
      final Color tierBorderColor;
      final IconData tierIcon;

      if (gunaScore >= 33) {
        tierLabel = 'Ati-Uttama Compatibility 🌟';
        tierDescription = 'Exceptional, divine alignment across all 8 Vedic Koots for auspicious marriage.';
        tierColor = const Color(0xFFB58D3D);
        tierBgColor = const Color(0xFFFFF9EE);
        tierBorderColor = const Color(0xFFC99A4B);
        tierIcon = Icons.flare_rounded;
      } else if (gunaScore >= 25) {
        tierLabel = 'Uttama Compatibility ✨';
        tierDescription = 'Highly auspicious horoscope harmony for traditional Vedic marriage.';
        tierColor = const Color(0xFF065F46);
        tierBgColor = const Color(0xFFECFDF5);
        tierBorderColor = const Color(0xFFA7F3D0);
        tierIcon = Icons.auto_awesome_rounded;
      } else if (gunaScore >= 18) {
        tierLabel = 'Madhyama Compatibility (Acceptable)';
        tierDescription = 'Acceptable alignment across canonical Vedic Koots.';
        tierColor = const Color(0xFFB45309);
        tierBgColor = const Color(0xFFFFFBEB);
        tierBorderColor = const Color(0xFFFDE68A);
        tierIcon = Icons.check_circle_outline_rounded;
      } else {
        tierLabel = 'Low Compatibility / Varjya (Prohibited)';
        tierDescription = 'Challenging Ashta-Koota harmony. Traditional Vedic principles advise caution or remedial consultation.';
        tierColor = const Color(0xFF8B1E2D);
        tierBgColor = const Color(0xFFFDF2F2);
        tierBorderColor = const Color(0xFFFECACA);
        tierIcon = Icons.warning_amber_rounded;
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tierBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tierBorderColor.withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: tierBorderColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: tierBorderColor),
                    color: tierBgColor,
                  ),
                  child: Center(
                    child: Icon(
                      tierIcon,
                      color: tierColor,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF4A121A),
                              ),
                            ),
                            TextSpan(
                              text: '/ 36 Gunas',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF8C7A6B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        tierLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: tierColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tierDescription,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF6B5E55),
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }

    if (isCandidateMissing && !isUserMissing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
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
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFE6DC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_clock_rounded,
                    color: Color(0xFF8B1E2D),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Horoscope Details Locked 🔒',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4A121A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_profile.fullName} has not added their birth star yet.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF6B5E55),
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
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _hasSentHoroscopeRequest || _isSendingHoroscopeRequest
                    ? null
                    : _sendHoroscopeRequest,
                icon: _isSendingHoroscopeRequest
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _hasSentHoroscopeRequest
                            ? Icons.check_circle_rounded
                            : Icons.mail_outline_rounded,
                        size: 18,
                      ),
                label: Text(
                  _hasSentHoroscopeRequest
                      ? 'Horoscope Requested 📩'
                      : 'Request Horoscope from ${_profile.fullName}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasSentHoroscopeRequest
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF8B1E2D),
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

    // User is missing birth star
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEDD5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_motion_rounded,
                  color: Color(0xFFC2410C),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guna Milan Calculation Locked 🔒',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF9A3412),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Add your Birth Star & Rashi to calculate mutual 36-Guna compatibility.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF7C2D12),
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
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditReligionScreen(),
                  ),
                ).then((_) async {
                  final updatedMyProf = await HomeService.instance.getMyProfile();
                  if (mounted && updatedMyProf != null) {
                    setState(() {
                      _myProfile = updatedMyProf;
                      _gunaMilanScore = _calculateGunaMilanScore();
                    });
                  }
                });
              },
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: Text(
                'Fill My Astrology Details ✏️',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B1E2D),
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

  Widget _buildEducationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Education'),
        _buildRow(
          'Highest Education',
          _getLookupLabel(
            'education_levels',
            _profile.highestEducationId,
          ),
        ),
        _buildRow(
          'College / University',
          _profile.college ?? 'Not provided',
        ),
      ],
    );
  }

  Widget _buildCareerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Career & Work'),
        _buildRow(
          'Occupation',
          _getLookupLabel('occupations', _profile.occupationId),
        ),
        _buildRow('Company Name', _profile.company ?? 'Not provided'),
        _buildRow(
          'Work Location',
          _profile.workLocation ?? 'Not provided',
        ),
        if (_profile.workType != null)
          _buildRow('Work Type', _profile.workType!),
        if (_profile.careerPreference != null)
          _buildRow('Career Outlook', _profile.careerPreference!),
        _buildRow(
          'Annual Income',
          _getLookupLabel('annual_incomes', _profile.annualIncomeId),
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
          _getLookupLabel('family_types', _profile.familyTypeId),
        ),
        if (_profile.familyValues != null)
          _buildRow('Family Values', _profile.familyValues!),
        _buildRow('Father Name', _profile.fatherName ?? 'Not provided'),
        _buildRow(
          'Father Occupation',
          _profile.fatherOccupation ?? 'Not provided',
        ),
        _buildRow('Mother Name', _profile.motherName ?? 'Not provided'),
        _buildRow(
          'Mother Occupation',
          _profile.motherOccupation ?? 'Not provided',
        ),
        _buildRow(
          'No. of Brothers',
          _profile.brothersCount?.toString() ?? 'Not provided',
        ),
        _buildRow(
          'No. of Sisters',
          _profile.sistersCount?.toString() ?? 'Not provided',
        ),
        _buildRow('Native Place', _profile.nativePlace ?? 'Not provided'),
        if (_profile.familyDescription != null &&
            _profile.familyDescription!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'About Family',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF9A8A7A),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            child: Text(
              _profile.familyDescription!,
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

  Widget _buildLifestyleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Habits & Lifestyle'),
        _buildRow(
          'Diet',
          _getLookupLabel('food_preferences', _profile.foodPreferenceId),
        ),
        if (_profile.fitnessHabits != null)
          _buildRow('Fitness Habits', _profile.fitnessHabits!),
        if (_profile.personalityType != null)
          _buildRow('Personality', _profile.personalityType!),
        if (_profile.spiritualLevel != null)
          _buildRow('Spiritual Level', _profile.spiritualLevel!),
        _buildRow(
          'Smoking',
          _getLookupLabel('smoking_habits', _profile.smokingId),
        ),
        _buildRow(
          'Drinking',
          _getLookupLabel('drinking_habits', _profile.drinkingId),
        ),
        if (_profile.culturalInterests != null &&
            _profile.culturalInterests!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Cultural & Traditional Interests',
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
              children: _profile.culturalInterests!
                  .map(
                    (c) => Chip(
                      label: Text(c, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6E1732))),
                      backgroundColor: const Color(0xFFFBF4E9),
                      side: const BorderSide(color: Color(0xFFE2D6C7)),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        if (_profile.hobbies != null &&
            _profile.hobbies!.isNotEmpty) ...[
          const SizedBox(height: 12),
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
              children: _profile.hobbies!
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
        if (_profile.aboutMe != null &&
            _profile.aboutMe!.isNotEmpty) ...[
          const SizedBox(height: 12),
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
              _profile.aboutMe!,
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

  Widget _buildPreferencesSection() {
    if (_partnerPreference == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Partner Preferences'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'Open to all compatible Brahmin profiles.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF9A8A7A),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    }

    final p = _partnerPreference!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Partner Preferences'),
        _buildRow(
          'Age Range',
          p.minAge != null && p.maxAge != null
              ? '${p.minAge} - ${p.maxAge} years'
              : 'Doesn\'t Matter',
        ),
        _buildRow(
          'Height Range',
          p.minHeightInches != null && p.maxHeightInches != null
              ? '${p.minHeightInches! ~/ 12}\'${p.minHeightInches! % 12}" - ${p.maxHeightInches! ~/ 12}\'${p.maxHeightInches! % 12}"'
              : 'Doesn\'t Matter',
        ),
        if (p.kujaDoshamPreference != null)
          _buildRow('Kuja Dosham', p.kujaDoshamPreference!),
        if (p.horoscopeMatchingRequired != null)
          _buildRow('Horoscope Matching', p.horoscopeMatchingRequired!),
        _buildRow(
          'Marital Status',
          _getLookupLabelsList('marital_statuses', p.preferredMaritalStatusIds),
        ),
        _buildRow(
          'Mother Tongues',
          _getLookupLabelsList('mother_tongues', p.preferredMotherTongueIds),
        ),
        _buildRow(
          'Castes / Sub-castes',
          _getLookupLabelsList('castes', p.preferredCasteIds),
        ),
        _buildRow(
          'Dietary Habits',
          _getLookupLabelsList('food_preferences', p.preferredFoodIds),
        ),
        if (p.preferredCountryIds != null && p.preferredCountryIds!.isNotEmpty)
          _buildRow(
            'Preferred Countries',
            _getLookupLabelsList('countries', p.preferredCountryIds),
          ),
        if (p.marriageVision != null && p.marriageVision!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Marriage Vision',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF9A8A7A),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            child: Text(
              p.marriageVision!,
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

  void _openChatScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          profileId: widget.profile.id,
          name: widget.profile.fullName,
          photoUrl: widget.profile.profilePhotoUrl,
          subcaste: widget.profile.subCaste,
          isVerified: widget.profile.isVerified,
          isOnline: _profile.isOnline,
        ),
      ),
    );
  }

  Future<void> _handleDeclineInterest() async {
    if (_currentInterest == null) return;
    setState(() => _isSendingInterest = true);
    try {
      await _interestService.declineInterest(_currentInterest!.id);
      await _loadData();
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
    } finally {
      if (mounted) {
        setState(() => _isSendingInterest = false);
      }
    }
  }

  Future<void> _handleAcceptInterest() async {
    if (_currentInterest == null) return;
    setState(() => _isSendingInterest = true);
    try {
      await _interestService.acceptInterest(_currentInterest!.id);
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
              e is AppException ? e.message : 'Error accepting interest',
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
  }

  Future<void> _handleSendInterest() async {
    setState(() => _isSendingInterest = true);
    try {
      await _interestService.sendInterest(widget.profile.id);
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
        if (e is QuotaExceededException) {
          QuotaExhaustedSheet.show(
            context,
            tier: e.tier,
            limit: e.limit,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e is AppException ? e.message : 'Error sending interest',
              ),
              backgroundColor: const Color(0xFFFF3B30),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingInterest = false);
      }
    }
  }

  Widget _buildBottomBar() {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return const SizedBox.shrink();
    final currentUserId = (_myProfile != null && _myProfile!.id.isNotEmpty)
        ? _myProfile!.id
        : user.id;
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
                onPressed: _isSendingInterest ? null : _handleDeclineInterest,
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
                onPressed: _isSendingInterest ? null : _handleAcceptInterest,
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
    Color buttonColor = AppColors.primary;
    IconData buttonIcon = Icons.favorite_border_rounded;
    VoidCallback? action = _handleSendInterest;

    if (_currentInterest != null) {
      if (status == 'pending') {
        buttonText = 'Interest Sent';
        buttonColor = const Color(0xFFB58D3D);
        buttonIcon = Icons.hourglass_empty_rounded;
        action = null;
      } else if (status == 'accepted') {
        buttonText = 'Chat Now';
        buttonColor = const Color(0xFF10B981);
        buttonIcon = Icons.chat_bubble_rounded;
        action = _openChatScreen;
      } else if (status == 'declined') {
        buttonText = 'Declined';
        buttonColor = const Color(0xFF8E8E93);
        buttonIcon = Icons.block_rounded;
        action = null;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
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
          // 1. View Contact Button
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  HapticFeedback.selectionClick();
                  ContactUnlockDialog.show(
                    context,
                    targetProfileId: widget.profile.id,
                    targetProfileName: widget.profile.fullName,
                  );
                },
                icon: const Icon(Icons.phone_outlined, size: 20),
                label: Text(
                  'Contact',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6E1732),
                  side: const BorderSide(color: Color(0xFF6E1732), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 2. Primary Interest Action Button
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: (_isSendingInterest || action == null) ? null : action,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  disabledBackgroundColor: buttonColor.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 0,
                ),
                child: _isSendingInterest
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(buttonIcon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              buttonText,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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
  final int activeIndex;

  _SectionHeaderDelegate({required this.child, required this.activeIndex});

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
    return oldDelegate.activeIndex != activeIndex || oldDelegate.child != child;
  }
}
