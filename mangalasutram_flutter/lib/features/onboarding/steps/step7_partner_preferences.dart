import 'package:flutter/material.dart';
import '../widgets/luxury_selection_chip.dart';
import '../widgets/luxury_text_field.dart';

class Step7PartnerPreferences extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onUpdate;

  const Step7PartnerPreferences({
    super.key,
    required this.formData,
    required this.onUpdate,
  });

  @override
  State<Step7PartnerPreferences> createState() => _Step7PartnerPreferencesState();
}

class _Step7PartnerPreferencesState extends State<Step7PartnerPreferences> {
  late Map<String, dynamic> _prefs;
  late TextEditingController _visionController;

  static const List<String> _doshamPreferences = [
    'No Dosham Only',
    'Kuja Dosham Acceptable',
    'Doesn\'t Matter',
  ];

  static const List<String> _horoscopePreferences = [
    'Strict (Guna Milan 18+)',
    'Preferred',
    'Not Essential',
  ];

  static const List<String> _maritalStatusPrefs = [
    'Never Married',
    'Divorced',
    'Widowed',
    'Doesn\'t Matter',
  ];

  static const List<String> _foodPrefs = [
    'Pure Vegetarian 🌿',
    'Vegetarian 🥗',
    'Doesn\'t Matter',
  ];

  @override
  void initState() {
    super.initState();
    _prefs = widget.formData['preferences'] != null
        ? Map<String, dynamic>.from(widget.formData['preferences'])
        : {};

    _prefs['min_age'] = _prefs['min_age'] ?? 21;
    _prefs['max_age'] = _prefs['max_age'] ?? 32;
    _prefs['min_height_inches'] = _prefs['min_height_inches'] ?? 58;
    _prefs['max_height_inches'] = _prefs['max_height_inches'] ?? 72;
    _prefs['kuja_dosham_preference'] =
        _prefs['kuja_dosham_preference'] ?? 'Doesn\'t Matter';
    _prefs['horoscope_matching_required'] =
        _prefs['horoscope_matching_required'] ?? 'Preferred';
    _prefs['marital_status_pref'] =
        _prefs['marital_status_pref'] ?? 'Never Married';
    _prefs['food_pref'] = _prefs['food_pref'] ?? 'Pure Vegetarian 🌿';

    _visionController = TextEditingController(
      text: _prefs['marriage_vision'] ?? '',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onUpdate('preferences', _prefs);
    });
  }

  @override
  void dispose() {
    _visionController.dispose();
    super.dispose();
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
    return "$feet'$remainingInches\" (${(inches * 2.54).round()} cm)";
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEADBCE), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6E1732).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFFC99A4B)),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6E1732),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minAge = (_prefs['min_age'] as int).toDouble();
    final maxAge = (_prefs['max_age'] as int).toDouble();
    final minHeight = (_prefs['min_height_inches'] as int).toDouble();
    final maxHeight = (_prefs['max_height_inches'] as int).toDouble();

    final selectedDosham = _prefs['kuja_dosham_preference'] as String?;
    final selectedHoro = _prefs['horoscope_matching_required'] as String?;
    final selectedMarital = _prefs['marital_status_pref'] as String?;
    final selectedFood = _prefs['food_pref'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          const Text(
            'Ideal Partner Preferences',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6E1732),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Guide our Vedic matching engine to find your ideal life companion',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8B7355),
            ),
          ),

          const SizedBox(height: 24),

          // Card 1: Age & Height Criteria
          _buildSectionContainer(
            title: 'Age & Physical Criteria',
            icon: Icons.tune_rounded,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Preferred Age Range',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3E2723),
                    ),
                  ),
                  Text(
                    '${minAge.toInt()} – ${maxAge.toInt()} Years',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6E1732),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF6E1732),
                  inactiveTrackColor: const Color(0xFFEADBCE),
                  thumbColor: const Color(0xFFC99A4B),
                  overlayColor: const Color(0xFFC99A4B).withValues(alpha: 0.2),
                  trackHeight: 4,
                ),
                child: RangeSlider(
                  values: RangeValues(minAge, maxAge),
                  min: 18,
                  max: 60,
                  divisions: 42,
                  onChanged: (values) {
                    _updatePref('min_age', values.start.toInt());
                    _updatePref('max_age', values.end.toInt());
                  },
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Preferred Height Range',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3E2723),
                    ),
                  ),
                  Text(
                    '${_formatHeight(minHeight.toInt())} – ${_formatHeight(maxHeight.toInt())}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6E1732),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF6E1732),
                  inactiveTrackColor: const Color(0xFFEADBCE),
                  thumbColor: const Color(0xFFC99A4B),
                  overlayColor: const Color(0xFFC99A4B).withValues(alpha: 0.2),
                  trackHeight: 4,
                ),
                child: RangeSlider(
                  values: RangeValues(minHeight, maxHeight),
                  min: 48,
                  max: 84,
                  divisions: 36,
                  onChanged: (values) {
                    _updatePref('min_height_inches', values.start.toInt());
                    _updatePref('max_height_inches', values.end.toInt());
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Card 2: Astrological Alignment
          _buildSectionContainer(
            title: 'Astrological Preferences',
            icon: Icons.auto_awesome_rounded,
            children: [
              const Text(
                'Kuja Dosham / Manglik Preference',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _doshamPreferences.map((opt) {
                  final isSelected = selectedDosham == opt;
                  return LuxurySelectionChip(
                    label: opt,
                    isSelected: isSelected,
                    onSelected: () => _updatePref('kuja_dosham_preference', opt),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              const Text(
                'Horoscope / Guna Milan Importance',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _horoscopePreferences.map((opt) {
                  final isSelected = selectedHoro == opt;
                  return LuxurySelectionChip(
                    label: opt,
                    isSelected: isSelected,
                    onSelected: () => _updatePref('horoscope_matching_required', opt),
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),

              // Sagotra Exemption Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF8F1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC99A4B).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_rounded, size: 18, color: Color(0xFFC99A4B)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sagotra Exclusion: Profiles sharing the same Gothram are automatically filtered out per Vedic traditions.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF6E1732),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Card 3: Marital & Lifestyle Preferences
          _buildSectionContainer(
            title: 'Marital & Lifestyle Preferences',
            icon: Icons.favorite_rounded,
            children: [
              const Text(
                'Marital Status',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _maritalStatusPrefs.map((opt) {
                  final isSelected = selectedMarital == opt;
                  return LuxurySelectionChip(
                    label: opt,
                    isSelected: isSelected,
                    onSelected: () => _updatePref('marital_status_pref', opt),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              const Text(
                'Dietary Expectation',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _foodPrefs.map((opt) {
                  final isSelected = selectedFood == opt;
                  return LuxurySelectionChip(
                    label: opt,
                    isSelected: isSelected,
                    onSelected: () => _updatePref('food_pref', opt),
                  );
                }).toList(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Card 4: Marriage Vision
          _buildSectionContainer(
            title: 'Marriage Vision',
            icon: Icons.spa_rounded,
            children: [
              LuxuryTextField(
                label: 'Expectations & Vision (Optional)',
                hintText: 'What qualities and life goals are you seeking in your life partner?',
                controller: _visionController,
                maxLines: 3,
                onChanged: (val) => _updatePref('marriage_vision', val),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
