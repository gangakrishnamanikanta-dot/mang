import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../shared/services/lookup_service.dart';

class Step7PartnerPreferences extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onUpdate;

  const Step7PartnerPreferences({
    super.key,
    required this.formData,
    required this.onUpdate,
  });

  @override
  State<Step7PartnerPreferences> createState() =>
      _Step7PartnerPreferencesState();
}

class _Step7PartnerPreferencesState extends State<Step7PartnerPreferences> {
  late Map<String, dynamic> _prefs;

  @override
  void initState() {
    super.initState();
    // Initialize preferences map if not exists
    _prefs = widget.formData['preferences'] != null
        ? Map<String, dynamic>.from(widget.formData['preferences'])
        : {};

    // Ensure defaults for required sliders
    _prefs['min_age'] = _prefs['min_age'] ?? 18;
    _prefs['max_age'] = _prefs['max_age'] ?? 40;
    _prefs['min_height_inches'] = _prefs['min_height_inches'] ?? 60;
    _prefs['max_height_inches'] = _prefs['max_height_inches'] ?? 72;
    _prefs['kuja_dosham_preference'] =
        _prefs['kuja_dosham_preference'] ?? 'Doesn\'t Matter';

    // Trigger onUpdate initially so layout has it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onUpdate('preferences', _prefs);
    });
  }

  void _updatePref(String key, dynamic value) {
    setState(() {
      _prefs[key] = value;
      widget.onUpdate('preferences', _prefs);
    });
  }

  String _formatHeight(int inches) {
    final feet = inches ~/ 12;
    final remainingInches = inches % 12;
    return "$feet'$remainingInches\"";
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Partner Preferences',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Set your basic matching preferences. This helps us find the best compatible profiles for you.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8E8E93),
            ),
          ),

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

          const SizedBox(height: 24),
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
                if (val != null) _updatePref('kuja_dosham_preference', val);
              },
            ),
          ),

          const SizedBox(height: 24),
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

          const SizedBox(height: 40),
        ],
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
            color: const Color(0xFFF2F2F7),
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
                // Try to find the label key (it's the only other key besides 'id')
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
