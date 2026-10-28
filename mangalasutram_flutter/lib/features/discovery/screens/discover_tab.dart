import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/theme.dart';
import '../../../core/di.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../models/profile.dart';
import '../../auth/services/supabase_service.dart';
import '../../interests/services/interest_service.dart';
import '../../profile/screens/profile_detail_screen.dart';
import '../../subscription/models/subscription_status.dart';
import '../../subscription/screens/plans_screen.dart';
import '../../subscription/services/subscription_service.dart';
import '../../subscription/widgets/quota_exhausted_sheet.dart';
import '../../home/services/home_service.dart';
import '../../family/services/family_service.dart';

class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  final InterestService _interestService = getIt<InterestService>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cityFilterController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounceTimer;

  // Filter States
  String _searchQuery = '';
  String? _selectedSubcaste;
  String? _selectedCity;
  RangeValues _ageRange = const RangeValues(18, 60);

  // Profiles + Pagination
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = false;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  static const int _pageSize = 20;

  // Cached identity & race-condition cancellation token
  String? _cachedEffectiveUserId;
  int _searchRequestId = 0;

  SubscriptionTier _userTier = SubscriptionTier.free;

  final Set<String> _shortlistedIds = {};
  final Set<String> _sentInterestIds = {};

  // Dynamic subcastes from DB
  List<String> _subcasteChips = ['All'];
  bool _subcastesLoaded = false;

  bool get _hasActiveFilters =>
      (_selectedCity != null && _selectedCity!.trim().isNotEmpty) ||
      (_selectedSubcaste != null && _selectedSubcaste != 'All') ||
      (_ageRange.start > 18 || _ageRange.end < 60);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _cityFilterController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isFetchingMore &&
        _hasMore &&
        !_isLoading) {
      _fetchMoreProfiles();
    }
  }

  void _onSearchInputChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _searchQuery = val.trim());
        _resetAndSearch();
      }
    });
  }

  Future<void> _loadInitialData() async {
    // Resolve user & guardian/candidate identity ONCE here
    try {
      String? userId = SupabaseService.client.auth.currentUser?.id;
      if (userId != null) {
        final myProf = await getIt<HomeService>().getMyProfile();
        if (myProf?.accountType == 'guardian') {
          final cand = await FamilyService.instance.getGuardianActiveCandidate();
          if (cand != null && cand.candidateId.isNotEmpty) {
            userId = cand.candidateId;
          }
        }
      }
      _cachedEffectiveUserId = userId;
    } catch (e) {
      debugPrint('[DiscoverTab identity resolution error]: $e');
    }

    final results = await Future.wait([
      SubscriptionService.instance.getMyStatus(),
      _loadSubcastesFromDb(),
    ]);

    if (mounted) {
      final status = results[0] as SubscriptionStatus?;
      setState(() {
        _userTier = status?.tier ?? SubscriptionTier.free;
      });
    }
    _resetAndSearch();
  }

  Future<void> _loadSubcastesFromDb() async {
    try {
      final data = await SupabaseService.client
          .from('sub_castes')
          .select('sub_caste')
          .order('sub_caste');
      if (mounted) {
        setState(() {
          final list = (data as List)
              .map((e) => e['sub_caste']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();
          _subcasteChips = ['All', ...list];
          _subcastesLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('[DiscoverTab sub_castes load error]: $e');
      if (mounted) {
        setState(() {
          _subcasteChips = ['All'];
          _subcastesLoaded = true;
        });
      }
    }
  }

  void _resetAndSearch() {
    setState(() {
      _profiles.clear();
      _currentOffset = 0;
      _hasMore = true;
      _isLoading = true;
    });
    _performSearch(offset: 0, isReset: true);
  }

  Future<void> _fetchMoreProfiles() async {
    if (_isFetchingMore || !_hasMore) return;
    setState(() => _isFetchingMore = true);
    await _performSearch(offset: _currentOffset, isReset: false);
  }

  Future<void> _performSearch({required int offset, required bool isReset}) async {
    final int currentRequestId = ++_searchRequestId;
    String? userId = _cachedEffectiveUserId ?? SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() { _isLoading = false; _isFetchingMore = false; });
      return;
    }

    try {
      final subcasteFilter = (_selectedSubcaste == null || _selectedSubcaste == 'All')
          ? null
          : _selectedSubcaste;
      final cityFilter = (_selectedCity?.trim().isEmpty ?? true) ? null : _selectedCity?.trim();
      final queryParam = _searchQuery.isEmpty ? null : _searchQuery;

      final data = await SupabaseService.client.rpc(
        'search_discovery_profiles_v2',
        params: {
          'p_user_id': userId,
          'p_query': queryParam,
          'p_sub_caste': subcasteFilter,
          'p_min_age': _ageRange.start.round(),
          'p_max_age': _ageRange.end.round(),
          'p_city': cityFilter,
          'p_limit': _pageSize,
          'p_offset': offset,
        },
      );

      // Concurrency guard: if user initiated a newer query, drop this stale response
      if (currentRequestId != _searchRequestId) return;

      final newProfiles = data is List ? List<Map<String, dynamic>>.from(data) : <Map<String, dynamic>>[];

      if (isReset) {
        _loadSideData(userId);
      }

      if (mounted) {
        setState(() {
          if (isReset) {
            _profiles = newProfiles;
          } else {
            _profiles.addAll(newProfiles);
          }
          _currentOffset = offset + newProfiles.length;
          _hasMore = newProfiles.length == _pageSize;
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      debugPrint('[DiscoverTab Error]: $e');
      if (mounted && currentRequestId == _searchRequestId) {
        setState(() { _isLoading = false; _isFetchingMore = false; });
      }
    }
  }

  Future<void> _loadSideData(String userId) async {
    try {
      final results = await Future.wait([
        SupabaseService.client.from('shortlists').select('profile_id').eq('user_id', userId),
        SupabaseService.client.from('interests').select('receiver_profile_id').eq('sender_profile_id', userId),
      ]);

      if (mounted) {
        setState(() {
          _shortlistedIds.clear();
          for (final r in results[0]) {
            _shortlistedIds.add(r['profile_id'].toString());
          }
          _sentInterestIds.clear();
          for (final r in results[1]) {
            _sentInterestIds.add(r['receiver_profile_id'].toString());
          }
        });
      }
    } catch (e) {
      debugPrint('[DiscoverTab side data error]: $e');
    }
  }

  Future<void> _toggleShortlist(String profileId) async {
    final isShortlisted = _shortlistedIds.contains(profileId);
    setState(() {
      if (isShortlisted) {
        _shortlistedIds.remove(profileId);
      } else {
        _shortlistedIds.add(profileId);
      }
    });
    try {
      await SupabaseService.client.rpc('toggle_shortlist', params: {'p_target_id': profileId});
    } catch (_) {
      if (mounted) {
        setState(() {
          if (isShortlisted) {
            _shortlistedIds.add(profileId);
          } else {
            _shortlistedIds.remove(profileId);
          }
        });
      }
    }
  }

  Future<void> _sendInterest(String profileId, String name) async {
    if (_sentInterestIds.contains(profileId)) return;
    try {
      await _interestService.sendInterest(profileId);
      if (!mounted) return;
      setState(() => _sentInterestIds.add(profileId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Interest sent to $name! 🙏'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } on QuotaExceededException {
      if (mounted) QuotaExhaustedSheet.show(context, tier: _userTier.dbValue, limit: 3);
    } catch (e) {
      if (mounted) {
        final msg = e is AppException ? e.message : 'Already sent interest to this profile.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFF2B2118),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _openProfile(Map<String, dynamic> p) {
    final profile = Profile(
      id: p['id']?.toString() ?? '',
      fullName: p['full_name']?.toString() ?? 'Member Profile',
      gender: p['gender']?.toString() ?? '',
      dateOfBirth: p['date_of_birth']?.toString() ?? '',
      city: p['city']?.toString() ?? '',
      state: p['state']?.toString(),
      profilePhotoUrl: p['profile_photo_url']?.toString(),
      subCaste: p['sub_caste']?.toString(),
      isVerified: p['is_verified'] == true,
      highestEducationId: p['highest_education_id'] as int?,
      occupationId: p['occupation_id'] as int?,
      casteId: p['caste_id'] as int?,
      gothramId: p['gothram_id'] as int?,
      motherTongueId: p['mother_tongue_id'] as int?,
      nakshatraId: p['nakshatra_id'] as int?,
      rashiId: p['rashi_id'] as int?,
      padaId: p['pada_id'] as int?,
      heightInches: p['height_inches'] as int?,
      aboutMe: p['about_me'] as String?,
      maritalStatusId: p['marital_status_id'] as int?,
      annualIncomeId: p['annual_income_id'] as int?,
      email: '',
      createdAt: p['created_at']?.toString() ?? '',
      updatedAt: p['updated_at']?.toString() ?? p['created_at']?.toString() ?? '',
    );

    Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileDetailScreen(profile: profile)));
  }

  void _showFilterModal() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF8F2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filter Profiles',
                      style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF2B2118))),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              Text('Age Range: ${_ageRange.start.round()} - ${_ageRange.end.round()} yrs',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              RangeSlider(
                values: _ageRange,
                min: 18, max: 60, divisions: 42,
                activeColor: AppColors.primary,
                inactiveColor: const Color(0xFFEDE4DC),
                labels: RangeLabels('${_ageRange.start.round()}', '${_ageRange.end.round()}'),
                onChanged: (vals) {
                  setModalState(() => _ageRange = vals);
                  setState(() => _ageRange = vals);
                },
              ),
              const SizedBox(height: 12),
              Text('City / Location', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _cityFilterController,
                decoration: InputDecoration(
                  hintText: 'e.g. Hyderabad, Bangalore, Pune',
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5DDD5))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5DDD5))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (val) => _selectedCity = val,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD4AF37)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        setModalState(() {
                          _selectedCity = null;
                          _cityFilterController.clear();
                          _ageRange = const RangeValues(18, 60);
                        });
                        setState(() {
                          _selectedCity = null;
                          _ageRange = const RangeValues(18, 60);
                        });
                        Navigator.pop(ctx);
                        _resetAndSearch();
                      },
                      child: Text('Reset', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF8C6D23))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetAndSearch();
                      },
                      child: Text('Apply Filters',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedSubcaste = null;
      _selectedCity = null;
      _cityFilterController.clear();
      _ageRange = const RangeValues(18, 60);
    });
    _resetAndSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      // Dismiss keyboard on tap anywhere on scaffold
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchInputChanged,
                          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF2B2118)),
                          decoration: InputDecoration(
                            hintText: 'Search by Name, City, Subcaste...',
                            hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFA8988B)),
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchInputChanged('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _showFilterModal,
                      child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: _hasActiveFilters ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: _hasActiveFilters ? Colors.white : const Color(0xFF5A4D41),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Dynamic Subcaste Chips
              _buildSubcasteChips(),

              // Results Banner
              _buildResultsBanner(),

              // Profile List with Infinite Scroll
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _profiles.isEmpty
                        ? _buildEmptyState()
                        : _buildProfilesList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubcasteChips() {
    return SizedBox(
      height: 44,
      child: !_subcastesLoaded
          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: _subcasteChips.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final subcaste = _subcasteChips[index];
                final isSelected = (_selectedSubcaste == null && subcaste == 'All') ||
                    _selectedSubcaste == subcaste;
                return ChoiceChip(
                  label: Text(subcaste),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? AppColors.primary : const Color(0xFFE5DDD5)),
                  ),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF5A4D41),
                  ),
                  onSelected: (selected) {
                    setState(() => _selectedSubcaste = (selected && subcaste != 'All') ? subcaste : null);
                    _resetAndSearch();
                  },
                );
              },
            ),
    );
  }

  Widget _buildResultsBanner() {
    if (_isLoading) {
      return const SizedBox(height: 24);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_profiles.length} Profile${_profiles.length == 1 ? '' : 's'} Found',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8C7B6E), fontWeight: FontWeight.w600),
          ),
          if (_userTier == SubscriptionTier.free)
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFFD97706)),
                const SizedBox(width: 4),
                Text('Free cap: 10 results',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFD97706), fontWeight: FontWeight.w600)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildProfilesList() {
    final showPaywall = !_hasMore && _profiles.length >= 10 && _userTier == SubscriptionTier.free;
    final itemCount = _profiles.length + (_isFetchingMore ? 1 : 0) + (showPaywall ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == _profiles.length) {
          if (_isFetchingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            );
          }
          if (showPaywall) {
            return _buildTierPaywallCard();
          }
        }
        if (index >= _profiles.length) return const SizedBox.shrink();

        final p = _profiles[index];
        final profileId = p['id']?.toString() ?? '';
        return _buildProfileCard(p, _shortlistedIds.contains(profileId), _sentInterestIds.contains(profileId));
      },
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> p, bool isShortlisted, bool isInterestSent) {
    final name = p['full_name']?.toString() ?? 'Member';
    final age = p['age'] as int?;
    final city = p['city']?.toString().trim();
    final subcaste = p['sub_caste']?.toString().trim();
    final education = p['highest_education']?.toString().trim();
    final occupation = p['occupation']?.toString().trim();
    final photoUrl = p['profile_photo_url'] as String?;
    final isVerified = p['is_verified'] == true;
    final score = p['match_score'] as int?;
    final profileId = p['id']?.toString() ?? '';

    final List<String> line1Parts = [];
    if (age != null && age > 0) line1Parts.add('$age yrs');
    if (subcaste != null && subcaste.isNotEmpty) line1Parts.add(subcaste);
    final line1 = line1Parts.join(' • ');

    final List<String> line2Parts = [];
    if (education != null && education.isNotEmpty) line2Parts.add(education);
    if (occupation != null && occupation.isNotEmpty) line2Parts.add(occupation);
    final line2 = line2Parts.join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Tappable profile row
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => _openProfile(p),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFEDE4DC),
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null || photoUrl.isEmpty
                        ? const Icon(Icons.person, color: AppColors.primary, size: 32) : null,
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
                                name,
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF2B2118)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 15, color: Color(0xFFD97706)),
                            ],
                          ],
                        ),
                        if (line1.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            line1,
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF5A4D41), fontWeight: FontWeight.w500),
                          ),
                        ],
                        if (line2.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            line2,
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8C7B6E)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (city != null && city.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '📍 $city',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8C7B6E)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (score != null && score > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            '$score% Match',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      GestureDetector(
                        onTap: () => _toggleShortlist(profileId),
                        child: Icon(
                          isShortlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isShortlisted ? Colors.red : const Color(0xFFA8988B),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF7F3EE)))),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD4AF37)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => _openProfile(p),
                    child: Text('View Profile',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF8C6D23))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isInterestSent ? const Color(0xFFB58D3D) : AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: isInterestSent ? null : () => _sendInterest(profileId, name),
                    child: Text(
                      isInterestSent ? '✓ Sent' : 'Send Interest',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierPaywallCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6E1732), Color(0xFF4A0F22)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 36, color: Color(0xFFFDE68A)),
          const SizedBox(height: 8),
          Text('Unlock Unlimited Discovery',
              style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            'Free accounts show 10 profiles. Upgrade to Prime Lite (50) or Prime VIP (500+) to explore all verified Brahmin profiles.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4A853),
              foregroundColor: const Color(0xFF2B2118),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen())),
            child: Text('Upgrade to Prime', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No Profiles Found',
              style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2B2118)),
            ),
            const SizedBox(height: 6),
            Text(
              'Try widening your age, city or subcaste filters.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
            ),
            if (_hasActiveFilters || _searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Clear All Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _clearAllFilters,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
