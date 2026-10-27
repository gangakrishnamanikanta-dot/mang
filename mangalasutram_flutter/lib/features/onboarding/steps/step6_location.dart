import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../models/lookup_option.dart';
import '../widgets/luxury_dropdown_field.dart';
import '../widgets/luxury_selection_chip.dart';
import '../widgets/luxury_text_field.dart';

class Step6Location extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onUpdate;
  final Map<String, List<LookupOption>>? lookupData;

  const Step6Location({
    super.key,
    required this.formData,
    required this.onUpdate,
    this.lookupData,
  });

  @override
  State<Step6Location> createState() => _Step6LocationState();
}

class _Step6LocationState extends State<Step6Location> {
  late TextEditingController _stateController;
  late TextEditingController _cityController;

  List<LookupOption> get _countries => widget.lookupData?['countries'] ?? [];
  List<LookupOption> get _visibilityOptions =>
      widget.lookupData?['profile_visibility_options'] ?? [];

  static const List<String> _citizenshipOptions = [
    'Indian Citizen 🇮🇳',
    'US Citizen / PR 🇺🇸',
    'H-1B / Work Visa 🇺🇸',
    'UK Citizen / PR 🇬🇧',
    'Canadian Citizen / PR 🇨🇦',
    'Australian PR 🇦🇺',
    'Other Country',
  ];

  static const List<String> _residenceStatusOptions = [
    'Own House 🏡',
    'Rented Apartment 🏢',
    'Living with Family 👨‍👩‍👦',
  ];

  late bool _hideMobile;
  late bool _hideEmail;
  late bool _showHoroscope;

  @override
  void initState() {
    super.initState();
    _stateController = TextEditingController(
      text: widget.formData['state'] ?? '',
    );
    _cityController = TextEditingController(
      text: widget.formData['city'] ?? '',
    );
    _hideMobile = widget.formData['hide_mobile'] ?? true;
    _hideEmail = widget.formData['hide_email'] ?? true;
    _showHoroscope = widget.formData['show_horoscope'] ?? false;
  }

  @override
  void dispose() {
    _stateController.dispose();
    _cityController.dispose();
    super.dispose();
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

  Widget _buildPrivacyToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C1810),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF8B7355),
                ),
              ),
            ],
          ),
        ),
        CupertinoSwitch(
          value: value,
          activeTrackColor: const Color(0xFF6E1732),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final countryId = widget.formData['country_id'];
    final countryLabel = _countries.firstWhere(
      (o) => o.id == countryId,
      orElse: () => LookupOption(id: -1, label: ''),
    ).label;

    final visibilityId = widget.formData['profile_visibility_id'];
    final visibilityLabel = _visibilityOptions.firstWhere(
      (o) => o.id == visibilityId,
      orElse: () => LookupOption(id: -1, label: ''),
    ).label;

    final selectedCitizenship = widget.formData['citizenship_status'] as String?;
    final selectedResidenceStatus = widget.formData['residential_status'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          const Text(
            'Current Location & Privacy',
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
            'Where you currently reside and your contact privacy settings',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8B7355),
            ),
          ),

          const SizedBox(height: 24),

          // Card 1: Current Residence Location
          _buildSectionContainer(
            title: 'Current Residence',
            icon: Icons.public_rounded,
            children: [
              LuxuryDropdownField(
                label: 'Country of Residence',
                placeholder: 'Select Country (e.g. India, USA, UK)',
                selectedValue: countryLabel.isNotEmpty ? countryLabel : null,
                isRequired: true,
                options: _countries,
                prefixIcon: const Icon(Icons.flag_rounded, color: Color(0xFFC99A4B), size: 20),
                onSelected: (opt) {
                  widget.onUpdate('country_id', opt.id);
                  setState(() {});
                },
              ),

              const SizedBox(height: 18),

              LuxuryTextField(
                label: 'State / Province',
                hintText: 'e.g. Telangana, Karnataka, California, Texas',
                controller: _stateController,
                isRequired: true,
                prefixIcon: const Icon(Icons.map_rounded, color: Color(0xFFC99A4B), size: 20),
                onChanged: (val) => widget.onUpdate('state', val),
              ),

              const SizedBox(height: 18),

              LuxuryTextField(
                label: 'City of Residence',
                hintText: 'e.g. Hyderabad, Bengaluru, San Francisco',
                controller: _cityController,
                isRequired: true,
                prefixIcon: const Icon(Icons.location_city_rounded, color: Color(0xFFC99A4B), size: 20),
                onChanged: (val) => widget.onUpdate('city', val),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Card 2: Citizenship & Housing
          _buildSectionContainer(
            title: 'Citizenship & Housing',
            icon: Icons.home_rounded,
            children: [
              const Text(
                'Citizenship / Visa Status',
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
                children: _citizenshipOptions.map((opt) {
                  final isSelected = selectedCitizenship == opt;
                  return LuxurySelectionChip(
                    label: opt,
                    isSelected: isSelected,
                    onSelected: () {
                      widget.onUpdate('citizenship_status', opt);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              const Text(
                'Residential Status',
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
                children: _residenceStatusOptions.map((opt) {
                  final isSelected = selectedResidenceStatus == opt;
                  return LuxurySelectionChip(
                    label: opt,
                    isSelected: isSelected,
                    onSelected: () {
                      widget.onUpdate('residential_status', opt);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Card 3: Privacy & Security Controls
          _buildSectionContainer(
            title: 'Privacy & Contact Shields',
            icon: Icons.shield_rounded,
            children: [
              if (_visibilityOptions.isNotEmpty) ...[
                LuxuryDropdownField(
                  label: 'Profile Visibility',
                  placeholder: 'Select Profile Visibility',
                  selectedValue: visibilityLabel.isNotEmpty ? visibilityLabel : null,
                  options: _visibilityOptions,
                  prefixIcon: const Icon(Icons.visibility_rounded, color: Color(0xFFC99A4B), size: 20),
                  onSelected: (opt) {
                    widget.onUpdate('profile_visibility_id', opt.id);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 18),
                const Divider(color: Color(0xFFF0EAE1), height: 1),
                const SizedBox(height: 18),
              ],

              _buildPrivacyToggle(
                title: 'Protect Phone Number',
                subtitle: 'Visible only to matches whose request you accept',
                value: _hideMobile,
                onChanged: (val) {
                  setState(() => _hideMobile = val);
                  widget.onUpdate('hide_mobile', val);
                },
              ),

              const SizedBox(height: 16),
              const Divider(color: Color(0xFFF0EAE1), height: 1),
              const SizedBox(height: 16),

              _buildPrivacyToggle(
                title: 'Protect Email Address',
                subtitle: 'Keep your email masked from public search',
                value: _hideEmail,
                onChanged: (val) {
                  setState(() => _hideEmail = val);
                  widget.onUpdate('hide_email', val);
                },
              ),

              const SizedBox(height: 16),
              const Divider(color: Color(0xFFF0EAE1), height: 1),
              const SizedBox(height: 16),

              _buildPrivacyToggle(
                title: 'Show Horoscope to Matches Only',
                subtitle: 'Astrology charts shown after mutual interest',
                value: _showHoroscope,
                onChanged: (val) {
                  setState(() => _showHoroscope = val);
                  widget.onUpdate('show_horoscope', val);
                },
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
