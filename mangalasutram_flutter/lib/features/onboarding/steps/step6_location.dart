import 'package:flutter/material.dart';
import '../../../shared/widgets/apple_text_field.dart';
import '../../../shared/widgets/bottom_sheet_selector.dart';
import '../../../models/profile.dart';

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

  bool _hideMobile = true;
  bool _hideEmail = true;
  bool _showHoroscope = false;

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

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8E8E93),
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Future<void> _openSelector(
    String title,
    String fieldKey,
    List<LookupOption> options,
  ) async {
    final currentId = widget.formData[fieldKey];
    LookupOption? selected;
    if (currentId != null) {
      try {
        selected = options.firstWhere((o) => o.id == currentId);
      } catch (_) {}
    }

    final result = await BottomSheetSelector.show(
      context: context,
      title: title,
      options: options,
      selectedOption: selected,
    );

    if (result != null) {
      widget.onUpdate(fieldKey, result.id);
    }
  }

  Widget _buildSelectField(
    String label,
    String fieldKey,
    List<LookupOption> options,
  ) {
    final currentId = widget.formData[fieldKey];
    String displayValue = 'Select...';
    if (currentId != null) {
      try {
        displayValue = options.firstWhere((o) => o.id == currentId).label;
      } catch (_) {}
    }

    final hasValue = displayValue != 'Select...';

    return GestureDetector(
      onTap: () => _openSelector(label, fieldKey, options),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                displayValue,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: hasValue
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFF8E8E93),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.unfold_more, color: Color(0xFF8E8E93), size: 20),
          ],
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
            'Current Location',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Where are you currently residing?',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8E8E93),
            ),
          ),

          const SizedBox(height: 16),

          _buildSectionLabel('Country'),
          _buildSelectField('Country', 'country_id', _countries),

          _buildSectionLabel('State / Province'),
          AppleTextField(
            controller: _stateController,
            hintText: 'Enter your State (e.g. Maharashtra)',
            prefixIcon: Icons.map_outlined,
            onChanged: (val) => widget.formData['state'] = val,
          ),
          _buildSectionLabel('City'),
          AppleTextField(
            controller: _cityController,
            hintText: 'Enter your City (e.g. Mumbai)',
            prefixIcon: Icons.location_city_outlined,
            onChanged: (val) => widget.formData['city'] = val,
          ),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE5E5EA)),
          const SizedBox(height: 8),

          const Text(
            'Privacy Settings',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionLabel('Profile Visibility'),
          _buildSelectField(
            'Visibility',
            'profile_visibility_id',
            _visibilityOptions,
          ),

          const SizedBox(height: 16),

          SwitchListTile.adaptive(
            title: const Text(
              'Hide Mobile Number',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: const Text(
              'Only Premium members can see it',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            value: _hideMobile,
            activeTrackColor: const Color(0xFF8B1818),
            onChanged: (val) {
              setState(() => _hideMobile = val);
              widget.onUpdate('hide_mobile', val);
            },
          ),
          SwitchListTile.adaptive(
            title: const Text(
              'Hide Email Address',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
            value: _hideEmail,
            activeTrackColor: const Color(0xFF8B1818),
            onChanged: (val) {
              setState(() => _hideEmail = val);
              widget.onUpdate('hide_email', val);
            },
          ),
          SwitchListTile.adaptive(
            title: const Text(
              'Show Horoscope to all',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
            value: _showHoroscope,
            activeTrackColor: const Color(0xFF8B1818),
            onChanged: (val) {
              setState(() => _showHoroscope = val);
              widget.onUpdate('show_horoscope', val);
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
