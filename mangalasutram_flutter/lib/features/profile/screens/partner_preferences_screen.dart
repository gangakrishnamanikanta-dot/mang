import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/profile_service.dart';
import '../../../models/partner_preference.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../auth/services/supabase_service.dart';
import '../../shared/services/lookup_service.dart';

class EditPartnerPreferencesScreen extends StatefulWidget {
  const EditPartnerPreferencesScreen({super.key});

  @override
  State<EditPartnerPreferencesScreen> createState() =>
      _EditPartnerPreferencesScreenState();
}

class _EditPartnerPreferencesScreenState
    extends State<EditPartnerPreferencesScreen> {
  final ProfileService _profileService = ProfileService();

  static const Color _burgundy = Color(0xFF6E1732);

  Map<String, dynamic> _prefs = {
    'min_age': 18,
    'max_age': 40,
    'min_height_inches': 60, // 5'0"
    'max_height_inches': 72, // 6'0"
    'kuja_dosham_preference': 'Doesn\'t Matter',
  };
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await _profileService.getPartnerPreferences();
    if (!mounted) return;
    if (prefs != null) {
      setState(() {
        _prefs = {
          'min_age': prefs.minAge ?? 18,
          'max_age': prefs.maxAge ?? 40,
          'min_height_inches': prefs.minHeightInches ?? 60,
          'max_height_inches': prefs.maxHeightInches ?? 72,
          'kuja_dosham_preference':
              prefs.kujaDoshamPreference ?? 'Doesn\'t Matter',
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
        };
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        _showError('Please log in again');
        return;
      }
      final prefModel = PartnerPreference(
        profileId: userId,
        minAge: _prefs['min_age'],
        maxAge: _prefs['max_age'],
        minHeightInches: _prefs['min_height_inches'],
        maxHeightInches: _prefs['max_height_inches'],
        kujaDoshamPreference: _prefs['kuja_dosham_preference'],
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
      );
      await _profileService.savePartnerPreferences(prefModel);
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      debugPrint('[PartnerPrefs save error]: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD32F2F),
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
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFD32F2F)),
    );
  }

  String _formatHeight(int inches) {
    final feet = inches ~/ 12;
    final remainingInches = inches % 12;
    return "$feet'$remainingInches\"";
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 16, right: 16),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C1C1E),
        ),
      ),
    );
  }

  Widget _buildIncomeTile() {
    final selectedId = _prefs['preferred_annual_income_id'] as int?;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: InkWell(
        onTap: () => _openIncomeBottomSheet(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Preferred Income',
                style: TextStyle(fontSize: 16, color: Color(0xFF1C1C1E)),
              ),
              Row(
                children: [
                  Text(
                    selectedId != null
                        ? 'Selected'
                        : 'Any',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFFC7C7CC),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openIncomeBottomSheet() async {
    final lookupOptions = await LookupService().fetchTable('annual_incomes');
    final options = lookupOptions
        .map((o) => {'id': o.id, 'label': o.label})
        .toList();
    final selectedId = _prefs['preferred_annual_income_id'] as int?;
    if (!mounted) return;
    final result = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SingleSelectSheet(
        title: 'Preferred Income',
        options: options,
        selectedId: selectedId,
      ),
    );
    if (result != null) _updatePref('preferred_annual_income_id', result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F1),
      appBar: AppBar(
        title: const Text(
          'Partner Preferences',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        backgroundColor: const Color(0xFFFBF8F1),
        elevation: 0,
        iconTheme: const IconThemeData(color: _burgundy),
        actions: [
          _saving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: _burgundy,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: _burgundy,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _burgundy))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40, left: 16, right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'BASIC PREFERENCES',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),

                  _buildSectionLabel('Age Range'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_prefs['min_age']} Yrs',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_prefs['max_age']} Yrs',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: RangeValues(
                      (_prefs['min_age'] as int).toDouble(),
                      (_prefs['max_age'] as int).toDouble(),
                    ),
                    min: 18,
                    max: 70,
                    divisions: 52,
                    activeColor: const Color(0xFFD32F2F),
                    onChanged: (RangeValues values) {
                      _updatePref('min_age', values.start.toInt());
                      _updatePref('max_age', values.end.toInt());
                    },
                  ),

                  _buildSectionLabel('Height Range'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatHeight(_prefs['min_height_inches'] as int),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatHeight(_prefs['max_height_inches'] as int),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: RangeValues(
                      (_prefs['min_height_inches'] as int).toDouble(),
                      (_prefs['max_height_inches'] as int).toDouble(),
                    ),
                    min: 48, // 4'0"
                    max: 84, // 7'0"
                    divisions: 36,
                    activeColor: const Color(0xFFD32F2F),
                    onChanged: (RangeValues values) {
                      _updatePref('min_height_inches', values.start.toInt());
                      _updatePref('max_height_inches', values.end.toInt());
                    },
                  ),

                  _buildMultiSelectTile(
                    label: 'Marital Status',
                    keyName: 'preferred_marital_status_ids',
                    tableName: 'marital_statuses',
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'CULTURAL PREFERENCES',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),

                  _buildMultiSelectTile(
                    label: 'Mother Tongue',
                    keyName: 'preferred_mother_tongue_ids',
                    tableName: 'mother_tongues',
                  ),

                  _buildMultiSelectTile(
                    label: 'Caste / Community',
                    keyName: 'preferred_caste_ids',
                    tableName: 'castes',
                  ),

                  _buildSectionLabel('Kuja Dosham / Manglik'),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<String>(
                      backgroundColor: const Color(0xFFE5E5EA),
                      thumbColor: Colors.white,
                      groupValue: _prefs['kuja_dosham_preference'],
                      children: const {
                        'Yes': Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Yes',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 14),
                          ),
                        ),
                        'No': Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 14),
                          ),
                        ),
                        'Doesn\'t Matter': Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Any',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 14),
                          ),
                        ),
                      },
                      onValueChanged: (val) {
                        if (val != null) {
                          _updatePref('kuja_dosham_preference', val);
                        }
                      },
                    ),
                  ),

                  _buildSectionLabel('Sagotra / Same Gothram'),
                  SwitchListTile(
                    title: const Text(
                      'Exclude same Gothram',
                      style: TextStyle(fontSize: 16, color: Color(0xFF1C1C1E)),
                    ),
                    subtitle: const Text(
                      'Profiles with the same family lineage will not appear in matches',
                      style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                    ),
                    value: _prefs['exclude_same_gotra'] as bool? ?? true,
                    activeColor: _burgundy,
                    onChanged: (val) {
                      _updatePref('exclude_same_gotra', val ?? true);
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'EDUCATION & CAREER',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),

                  _buildMultiSelectTile(
                    label: 'Education',
                    keyName: 'preferred_education_ids',
                    tableName: 'education_levels',
                  ),

                  _buildMultiSelectTile(
                    label: 'Occupation',
                    keyName: 'preferred_occupation_ids',
                    tableName: 'occupations',
                  ),

                  _buildSectionLabel('Annual Income'),
                  _buildIncomeTile(),

                  _buildMultiSelectTile(
                    label: 'Family Type',
                    keyName: 'preferred_family_type_ids',
                    tableName: 'family_types',
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'LIFESTYLE',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),

                  _buildMultiSelectTile(
                    label: 'Smoking',
                    keyName: 'preferred_smoking_ids',
                    tableName: 'smoking_habits',
                  ),

                  _buildMultiSelectTile(
                    label: 'Drinking',
                    keyName: 'preferred_drinking_ids',
                    tableName: 'drinking_habits',
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'LOCATION & ASTRO',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),

                  _buildSectionLabel('Location Preference'),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<String>(
                      backgroundColor: const Color(0xFFE5E5EA),
                      thumbColor: Colors.white,
                      groupValue: _prefs['location_preference'] ?? 'any',
                      children: const {
                        'same_city': Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Same City', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                        ),
                        'same_state': Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Same State', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                        ),
                        'same_country': Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Same Country', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                        ),
                        'any': Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Any', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                        ),
                      },
                      onValueChanged: (val) {
                        if (val != null) _updatePref('location_preference', val);
                      },
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'LIFESTYLE PREFERENCES',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),

                  _buildMultiSelectTile(
                    label: 'Food Preference',
                    keyName: 'preferred_food_ids',
                    tableName: 'food_preferences',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMultiSelectTile({
    required String label,
    required String keyName,
    required String tableName,
  }) {
    final List<int> selectedIds = List<int>.from(_prefs[keyName] ?? []);
    final displayValue = selectedIds.isEmpty
        ? 'Any'
        : '${selectedIds.length} Selected';

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: InkWell(
        onTap: () =>
            _openMultiSelectBottomSheet(label, keyName, tableName, selectedIds),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 16, color: Color(0xFF1C1C1E)),
              ),
              Row(
                children: [
                  Text(
                    displayValue,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFFC7C7CC),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMultiSelectBottomSheet(
    String title,
    String keyName,
    String tableName,
    List<int> initialSelected,
  ) async {
    final lookupOptions = await LookupService().fetchTable(tableName);
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
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF8E8E93), fontSize: 16),
                  ),
                ),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selected.toList()),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Color(0xFFD32F2F),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E5EA)),
          Expanded(
            child: ListView.builder(
              itemCount: widget.options.length,
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
                  title: Text(label, style: const TextStyle(fontSize: 16)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFFD32F2F))
                      : const Icon(
                          Icons.radio_button_unchecked,
                          color: Color(0xFFC7C7CC),
                        ),
                  onTap: () {
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
  int? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedId;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF8E8E93), fontSize: 16),
                  ),
                ),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Color(0xFFD32F2F),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E5EA)),
          Expanded(
            child: ListView.builder(
              itemCount: widget.options.length,
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
                  title: Text(label, style: const TextStyle(fontSize: 16)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFFD32F2F))
                      : const Icon(
                          Icons.radio_button_unchecked,
                          color: Color(0xFFC7C7CC),
                        ),
                  onTap: () {
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
