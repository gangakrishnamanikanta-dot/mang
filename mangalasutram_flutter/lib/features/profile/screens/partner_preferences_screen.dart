import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/di.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../models/lookup_option.dart';
import '../../../models/partner_preference.dart';
import '../../auth/services/supabase_service.dart';
import '../../home/services/home_service.dart';
import '../../shared/services/lookup_service.dart';
import '../services/profile_service.dart';

class EditPartnerPreferencesScreen extends StatefulWidget {
  const EditPartnerPreferencesScreen({super.key});

  @override
  State<EditPartnerPreferencesScreen> createState() =>
      _EditPartnerPreferencesScreenState();
}

class _EditPartnerPreferencesScreenState
    extends State<EditPartnerPreferencesScreen> {
  final ProfileService _profileService = getIt<ProfileService>();
  final LookupService _lookupService = LookupService();

  static const Color _burgundy = Color(0xFF6E1732);
  static const Color _gold = Color(0xFFC99A4B);
  static const Color _bgCream = Color(0xFFFBF8F1);

  final TextEditingController _marriageVisionCtrl = TextEditingController();
  Map<String, List<LookupOption>>? _lookupData;

  Map<String, dynamic> _prefs = {
    'min_age': 21,
    'max_age': 34,
    'min_height_inches': 60, // 5'0"
    'max_height_inches': 72, // 6'0"
    'kuja_dosham_preference': 'Doesn\'t Matter',
    'horoscope_matching_required': 'Preferred',
    'exclude_same_gotra': true,
    'location_preference': 'any',
  };
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _marriageVisionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _profileService.getPartnerPreferences(),
      _lookupService.fetchAllProfileLookups(),
    ]);
    if (!mounted) return;

    final prefs = results[0] as PartnerPreference?;
    _lookupData = results[1] as Map<String, List<LookupOption>>?;

    if (prefs != null) {
      _marriageVisionCtrl.text = prefs.marriageVision ?? '';
      setState(() {
        _prefs = {
          'min_age': prefs.minAge ?? 21,
          'max_age': prefs.maxAge ?? 34,
          'min_height_inches': prefs.minHeightInches ?? 60,
          'max_height_inches': prefs.maxHeightInches ?? 72,
          'kuja_dosham_preference':
              prefs.kujaDoshamPreference ?? 'Doesn\'t Matter',
          'horoscope_matching_required':
              prefs.horoscopeMatchingRequired ?? 'Preferred',
          'exclude_same_gotra': prefs.excludeSameGotra ?? true,
          'preferred_education_ids': prefs.preferredEducationIds,
          'preferred_occupation_ids': prefs.preferredOccupationIds,
          'preferred_family_type_ids': prefs.preferredFamilyTypeIds,
          'preferred_smoking_ids': prefs.preferredSmokingIds,
          'preferred_drinking_ids': prefs.preferredDrinkingIds,
          'location_preference': prefs.locationPreference ?? 'any',
          'preferred_annual_income_id': prefs.preferredAnnualIncomeId,
          'preferred_marital_status_ids': prefs.preferredMaritalStatusIds,
          'preferred_mother_tongue_ids': prefs.preferredMotherTongueIds,
          'preferred_caste_ids': prefs.preferredCasteIds,
          'preferred_food_ids': prefs.preferredFoodIds,
          'preferred_country_ids': prefs.preferredCountryIds,
        };
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        _showError('Please log in again');
        return;
      }
      final visionTrim = _marriageVisionCtrl.text.trim();
      final prefModel = PartnerPreference(
        profileId: userId,
        minAge: _prefs['min_age'],
        maxAge: _prefs['max_age'],
        minHeightInches: _prefs['min_height_inches'],
        maxHeightInches: _prefs['max_height_inches'],
        kujaDoshamPreference: _prefs['kuja_dosham_preference'],
        horoscopeMatchingRequired: _prefs['horoscope_matching_required'],
        excludeSameGotra: _prefs['exclude_same_gotra'] as bool? ?? true,
        preferredEducationIds: _prefs['preferred_education_ids'],
        preferredOccupationIds: _prefs['preferred_occupation_ids'],
        preferredFamilyTypeIds: _prefs['preferred_family_type_ids'],
        preferredSmokingIds: _prefs['preferred_smoking_ids'],
        preferredDrinkingIds: _prefs['preferred_drinking_ids'],
        locationPreference: _prefs['location_preference'],
        preferredAnnualIncomeId: _prefs['preferred_annual_income_id'],
        preferredMaritalStatusIds: _prefs['preferred_marital_status_ids'],
        preferredMotherTongueIds: _prefs['preferred_mother_tongue_ids'],
        preferredCasteIds: _prefs['preferred_caste_ids'],
        preferredFoodIds: _prefs['preferred_food_ids'],
        preferredCountryIds: _prefs['preferred_country_ids'],
        marriageVision: visionTrim.isNotEmpty ? visionTrim : null,
      );
      await _profileService.savePartnerPreferences(prefModel);
      HomeService.instance.forceRefreshMyMatches().catchError((_) {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Partner preferences saved. Refreshing your matches...',
              style: GoogleFonts.inter(fontSize: 12.5),
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e, st) {
      debugPrint('[PartnerPrefs save error]: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Text(
              e is AppException
                  ? e.message
                  : 'Save failed: ${e.toString().substring(0, e.toString().length.clamp(0, 120))}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _updatePref(String key, dynamic value) {
    setState(() {
      _prefs[key] = value;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFC62828)),
    );
  }

  String _formatHeight(int inches) {
    final feet = inches ~/ 12;
    final remainingInches = inches % 12;
    return "$feet'$remainingInches\"";
  }

  String _multiSelectSummary(String tableName, List<int> selectedIds) {
    if (selectedIds.isEmpty) return 'Any';
    final opts = _lookupData?[tableName] ?? [];
    if (selectedIds.length == 1 && opts.isNotEmpty) {
      try {
        return opts.firstWhere((o) => o.id == selectedIds.first).label;
      } catch (_) {}
    }
    return '${selectedIds.length} Selected';
  }

  String _singleSelectSummary(String tableName, int? selectedId) {
    if (selectedId == null) return 'Any';
    final opts = _lookupData?[tableName] ?? [];
    try {
      return opts.firstWhere((o) => o.id == selectedId).label;
    } catch (_) {
      return 'Selected';
    }
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    String? footer,
  }) {
    final List<Widget> rows = [];
    for (int i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(
          const Divider(
            height: 0.5,
            thickness: 0.5,
            indent: 16,
            color: Color(0xFFEDE7DF),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 30, bottom: 7, top: 22),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: const Color(0xFF7A6A5E),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6DFD5), width: 0.7),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.018),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(children: rows),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(left: 30, right: 24, top: 6),
            child: Text(
              footer,
              style: GoogleFonts.inter(
                color: const Color(0xFF8C7E72),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMultiSelectRow({
    required String label,
    required String keyName,
    required String tableName,
  }) {
    final List<int> selectedIds = List<int>.from(_prefs[keyName] ?? []);
    final bool hasSelection = selectedIds.isNotEmpty;
    final displayValue = _multiSelectSummary(tableName, selectedIds);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          FocusScope.of(context).unfocus();
          HapticFeedback.selectionClick();
          _openMultiSelectBottomSheet(label, keyName, tableName, selectedIds);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13.5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: const Color(0xFF1C1917),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  displayValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight:
                        hasSelection ? FontWeight.w600 : FontWeight.w400,
                    color: hasSelection ? _burgundy : const Color(0xFF8C7E72),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                CupertinoIcons.chevron_forward,
                color: Color(0xFFC4B9AE),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeRow() {
    final selectedId = _prefs['preferred_annual_income_id'] as int?;
    final hasSelection = selectedId != null;
    final displayValue = _singleSelectSummary('annual_incomes', selectedId);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          FocusScope.of(context).unfocus();
          HapticFeedback.selectionClick();
          _openIncomeBottomSheet();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13.5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Minimum Annual Income',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: const Color(0xFF1C1917),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  displayValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight:
                        hasSelection ? FontWeight.w600 : FontWeight.w400,
                    color: hasSelection ? _burgundy : const Color(0xFF8C7E72),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                CupertinoIcons.chevron_forward,
                color: Color(0xFFC4B9AE),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openIncomeBottomSheet() async {
    FocusScope.of(context).unfocus();
    final lookupOptions = _lookupData?['annual_incomes'] ?? [];
    final options = lookupOptions
        .map((o) => {'id': o.id, 'label': o.label})
        .toList();

    if (!mounted) return;

    final result = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SingleSelectSheet(
        title: 'Minimum Annual Income',
        options: options,
        selectedId: _prefs['preferred_annual_income_id'] as int?,
      ),
    );

    if (result != null || _prefs['preferred_annual_income_id'] != null) {
      _updatePref('preferred_annual_income_id', result);
    }
  }

  Future<void> _openMultiSelectBottomSheet(
    String title,
    String keyName,
    String tableName,
    List<int> initialSelected,
  ) async {
    FocusScope.of(context).unfocus();
    final lookupOptions = _lookupData?[tableName] ?? [];
    final options = lookupOptions
        .map((o) => {'id': o.id, 'label': o.label})
        .toList();

    if (!mounted) return;

    final result = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MultiSelectSheet(
        title: title,
        options: options,
        initialSelected: initialSelected,
      ),
    );

    if (result != null) {
      _updatePref(keyName, result);
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
          'Partner Preferences',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF2B0912),
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          _saving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: _burgundy,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: Text(
                    'Save',
                    style: GoogleFonts.inter(
                      color: _burgundy,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _burgundy))
          : ListView(
              padding: const EdgeInsets.only(bottom: 48),
              children: [
                // ── Section 1: Basic Criteria (Age, Height, Marital Status) ──
                _buildSection(
                  title: 'Age, Height & Status',
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Preferred Age',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.2,
                                  color: const Color(0xFF1C1917),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBF7F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _gold.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  '${_prefs['min_age']} – ${_prefs['max_age']} yrs',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _burgundy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: _burgundy,
                              inactiveTrackColor: const Color(0xFFE8DFD3),
                              thumbColor: _burgundy,
                              overlayColor: _burgundy.withValues(alpha: 0.12),
                              trackHeight: 3.5,
                            ),
                            child: RangeSlider(
                              values: RangeValues(
                                (_prefs['min_age'] as int)
                                    .clamp(18, 70)
                                    .toDouble(),
                                (_prefs['max_age'] as int)
                                    .clamp(18, 70)
                                    .toDouble(),
                              ),
                              min: 18,
                              max: 70,
                              divisions: 52,
                              onChanged: (RangeValues values) {
                                _updatePref('min_age', values.start.toInt());
                                _updatePref('max_age', values.end.toInt());
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Preferred Height',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.2,
                                  color: const Color(0xFF1C1917),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBF7F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _gold.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  '${_formatHeight(_prefs['min_height_inches'] as int)} – ${_formatHeight(_prefs['max_height_inches'] as int)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _burgundy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: _burgundy,
                              inactiveTrackColor: const Color(0xFFE8DFD3),
                              thumbColor: _burgundy,
                              overlayColor: _burgundy.withValues(alpha: 0.12),
                              trackHeight: 3.5,
                            ),
                            child: RangeSlider(
                              values: RangeValues(
                                (_prefs['min_height_inches'] as int)
                                    .clamp(48, 84)
                                    .toDouble(),
                                (_prefs['max_height_inches'] as int)
                                    .clamp(48, 84)
                                    .toDouble(),
                              ),
                              min: 48,
                              max: 84,
                              divisions: 36,
                              onChanged: (RangeValues values) {
                                _updatePref(
                                  'min_height_inches',
                                  values.start.toInt(),
                                );
                                _updatePref(
                                  'max_height_inches',
                                  values.end.toInt(),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildMultiSelectRow(
                      label: 'Marital Status',
                      keyName: 'preferred_marital_status_ids',
                      tableName: 'marital_statuses',
                    ),
                  ],
                ),

                // ── Section 2: Vedic & Cultural Criteria ──
                _buildSection(
                  title: 'Vedic & Cultural Criteria',
                  footer:
                      'Sagotra protection automatically filters out candidates sharing your exact Gothram.',
                  children: [
                    _buildMultiSelectRow(
                      label: 'Mother Tongue',
                      keyName: 'preferred_mother_tongue_ids',
                      tableName: 'mother_tongues',
                    ),
                    _buildMultiSelectRow(
                      label: 'Caste / Community',
                      keyName: 'preferred_caste_ids',
                      tableName: 'castes',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Exclude Same Gothram',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.2,
                                    color: const Color(0xFF1C1917),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Prevent Sagotra matches automatically',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: const Color(0xFF7A6A5E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            value:
                                _prefs['exclude_same_gotra'] as bool? ?? true,
                            activeTrackColor: _burgundy,
                            onChanged: (val) {
                              HapticFeedback.lightImpact();
                              _updatePref('exclude_same_gotra', val);
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Horoscope / Guna Milan Matching',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.2,
                              color: const Color(0xFF1C1917),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoSlidingSegmentedControl<String>(
                              backgroundColor: const Color(0xFFEDE6DC),
                              thumbColor: Colors.white,
                              groupValue:
                                  const {
                                    'Mandatory',
                                    'Preferred',
                                    'Optional',
                                  }.contains(
                                    _prefs['horoscope_matching_required'],
                                  )
                                  ? _prefs['horoscope_matching_required']
                                        as String
                                  : 'Preferred',
                              children: {
                                'Mandatory': Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Mandatory',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                'Preferred': Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Preferred',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                'Optional': Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Optional',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              },
                              onValueChanged: (val) {
                                if (val != null) {
                                  HapticFeedback.selectionClick();
                                  _updatePref(
                                    'horoscope_matching_required',
                                    val,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kuja Dosham / Manglik',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.2,
                              color: const Color(0xFF1C1917),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoSlidingSegmentedControl<String>(
                              backgroundColor: const Color(0xFFEDE6DC),
                              thumbColor: Colors.white,
                              groupValue:
                                  _prefs['kuja_dosham_preference'] ??
                                  'Doesn\'t Matter',
                              children: {
                                'Yes': Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Yes',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                'No': Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'No',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                'Doesn\'t Matter': Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Doesn\'t Matter',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              },
                              onValueChanged: (val) {
                                if (val != null) {
                                  HapticFeedback.selectionClick();
                                  _updatePref('kuja_dosham_preference', val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Section 3: Education, Career & Family ──
                _buildSection(
                  title: 'Education, Career & Family',
                  children: [
                    _buildMultiSelectRow(
                      label: 'Highest Education',
                      keyName: 'preferred_education_ids',
                      tableName: 'education_levels',
                    ),
                    _buildMultiSelectRow(
                      label: 'Occupation',
                      keyName: 'preferred_occupation_ids',
                      tableName: 'occupations',
                    ),
                    _buildIncomeRow(),
                    _buildMultiSelectRow(
                      label: 'Family Type',
                      keyName: 'preferred_family_type_ids',
                      tableName: 'family_types',
                    ),
                  ],
                ),

                // ── Section 4: Lifestyle & Location ──
                _buildSection(
                  title: 'Lifestyle & Location',
                  children: [
                    _buildMultiSelectRow(
                      label: 'Dietary Preference',
                      keyName: 'preferred_food_ids',
                      tableName: 'food_preferences',
                    ),
                    _buildMultiSelectRow(
                      label: 'Smoking Habits',
                      keyName: 'preferred_smoking_ids',
                      tableName: 'smoking_habits',
                    ),
                    _buildMultiSelectRow(
                      label: 'Drinking Habits',
                      keyName: 'preferred_drinking_ids',
                      tableName: 'drinking_habits',
                    ),
                    _buildMultiSelectRow(
                      label: 'Preferred Countries',
                      keyName: 'preferred_country_ids',
                      tableName: 'countries',
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location Proximity',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.2,
                              color: const Color(0xFF1C1917),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoSlidingSegmentedControl<String>(
                              backgroundColor: const Color(0xFFEDE6DC),
                              thumbColor: Colors.white,
                              groupValue:
                                  _prefs['location_preference'] ?? 'any',
                              children: {
                                'same_city': Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'City',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                'same_state': Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'State',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                'same_country': Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Country',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                'any': Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Any',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              },
                              onValueChanged: (val) {
                                if (val != null) {
                                  HapticFeedback.selectionClick();
                                  _updatePref('location_preference', val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Section 5: Marriage Vision & Expectations ──
                _buildSection(
                  title: 'Marriage Vision & Expectations',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What You Value in a Partner',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1C1917),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _marriageVisionCtrl,
                            maxLines: 4,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              color: const Color(0xFF2C2520),
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Share your expectations for family life, shared values, and companionship...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFFB8AEA4),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _MultiSelectSheet extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> options;
  final List<int> initialSelected;

  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.initialSelected,
  });

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  static const Color _burgundy = Color(0xFF6E1732);
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Color(0xFFFBF8F1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD8CFC4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() => _selected.clear());
                  },
                  child: Text(
                    'Any / Clear',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7A6A5E),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  widget.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2B0912),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selected.toList()),
                  child: Text(
                    'Done',
                    style: GoogleFonts.inter(
                      color: _burgundy,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEDE7DF)),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: widget.options.length,
              separatorBuilder: (_, _) => const Divider(
                height: 0.5,
                thickness: 0.5,
                color: Color(0xFFEDE7DF),
              ),
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final id = option['id'] as int;
                final labelKey = option.keys.firstWhere(
                  (k) => k != 'id',
                  orElse: () => '',
                );
                final label = option[labelKey]?.toString() ?? 'Unknown';
                final isSelected = _selected.contains(id);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: const Color(0xFF1C1917),
                    ),
                  ),
                  trailing: Icon(
                    isSelected
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    color: isSelected ? _burgundy : const Color(0xFFC4B9AE),
                    size: 22,
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (isSelected) {
                        _selected.remove(id);
                      } else {
                        _selected.add(id);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SingleSelectSheet extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> options;
  final int? selectedId;

  const _SingleSelectSheet({
    required this.title,
    required this.options,
    this.selectedId,
  });

  @override
  State<_SingleSelectSheet> createState() => _SingleSelectSheetState();
}

class _SingleSelectSheetState extends State<_SingleSelectSheet> {
  static const Color _burgundy = Color(0xFF6E1732);
  int? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedId;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Color(0xFFFBF8F1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD8CFC4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text(
                    'Any / Clear',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7A6A5E),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  widget.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2B0912),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: Text(
                    'Done',
                    style: GoogleFonts.inter(
                      color: _burgundy,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEDE7DF)),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: widget.options.length,
              separatorBuilder: (_, _) => const Divider(
                height: 0.5,
                thickness: 0.5,
                color: Color(0xFFEDE7DF),
              ),
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final id = option['id'] as int;
                final labelKey = option.keys.firstWhere(
                  (k) => k != 'id',
                  orElse: () => '',
                );
                final label = option[labelKey]?.toString() ?? 'Unknown';
                final isSelected = _selected == id;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: const Color(0xFF1C1917),
                    ),
                  ),
                  trailing: Icon(
                    isSelected
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    color: isSelected ? _burgundy : const Color(0xFFC4B9AE),
                    size: 22,
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selected = isSelected ? null : id;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
