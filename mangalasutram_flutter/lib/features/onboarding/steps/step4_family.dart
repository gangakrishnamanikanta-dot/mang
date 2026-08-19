import 'package:flutter/material.dart';
import '../../../shared/widgets/apple_text_field.dart';
import '../../../shared/widgets/bottom_sheet_selector.dart';
import '../../../models/profile.dart';

class Step4Family extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onUpdate;
  final Map<String, List<LookupOption>>? lookupData;

  const Step4Family({
    super.key,
    required this.formData,
    required this.onUpdate,
    this.lookupData,
  });

  @override
  State<Step4Family> createState() => _Step4FamilyState();
}

class _Step4FamilyState extends State<Step4Family> {
  late TextEditingController _fatherNameController;
  late TextEditingController _fatherOccController;
  late TextEditingController _motherNameController;
  late TextEditingController _motherOccController;
  late TextEditingController _nativePlaceController;

  List<LookupOption> get _familyTypes =>
      widget.lookupData?['family_types'] ?? [];

  final List<LookupOption> _siblingOptions = List.generate(
    11,
    (index) =>
        LookupOption(id: index, label: index == 0 ? 'None' : index.toString()),
  );

  @override
  void initState() {
    super.initState();
    _fatherNameController = TextEditingController(
      text: widget.formData['father_name'] ?? '',
    );
    _fatherOccController = TextEditingController(
      text: widget.formData['father_occupation'] ?? '',
    );
    _motherNameController = TextEditingController(
      text: widget.formData['mother_name'] ?? '',
    );
    _motherOccController = TextEditingController(
      text: widget.formData['mother_occupation'] ?? '',
    );
    _nativePlaceController = TextEditingController(
      text: widget.formData['native_place'] ?? '',
    );
  }

  @override
  void dispose() {
    _fatherNameController.dispose();
    _fatherOccController.dispose();
    _motherNameController.dispose();
    _motherOccController.dispose();
    _nativePlaceController.dispose();
    super.dispose();
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C1C1E),
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
      setState(() {});
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label),
        GestureDetector(
          onTap: () => _openSelector('Select $label', fieldKey, options),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5EA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayValue,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: currentId == null
                        ? const Color(0xFFC7C7CC)
                        : const Color(0xFF1C1C1E),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFC7C7CC)),
              ],
            ),
          ),
        ),
      ],
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
            'Family Details',
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
            'Help your matches understand your family background.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8E8E93),
            ),
          ),

          const SizedBox(height: 8),

          _buildSelectField('Family Type', 'family_type_id', _familyTypes),

          _buildSectionLabel('Father\'s Name'),
          AppleTextField(
            controller: _fatherNameController,
            hintText: 'Enter father\'s name',
            onChanged: (val) => widget.formData['father_name'] = val,
          ),

          _buildSectionLabel('Father\'s Occupation'),
          AppleTextField(
            controller: _fatherOccController,
            hintText: 'e.g. Business, Retired, Govt Employee...',
            onChanged: (val) => widget.formData['father_occupation'] = val,
          ),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE5E5EA)),
          const SizedBox(height: 8),

          _buildSectionLabel('Mother\'s Name'),
          AppleTextField(
            controller: _motherNameController,
            hintText: 'Enter mother\'s name',
            onChanged: (val) => widget.formData['mother_name'] = val,
          ),

          _buildSectionLabel('Mother\'s Occupation'),
          AppleTextField(
            controller: _motherOccController,
            hintText: 'e.g. Homemaker, Teacher...',
            onChanged: (val) => widget.formData['mother_occupation'] = val,
          ),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE5E5EA)),
          const SizedBox(height: 4),

          _buildSectionLabel('Brothers'),
          _buildSelectField('Brothers', 'brothers_count', _siblingOptions),

          _buildSectionLabel('Sisters'),
          _buildSelectField('Sisters', 'sisters_count', _siblingOptions),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE5E5EA)),
          const SizedBox(height: 4),

          _buildSectionLabel('Native Place'),
          AppleTextField(
            controller: _nativePlaceController,
            hintText: 'e.g. Rajahmundry, Vijayawada...',
            onChanged: (val) => widget.formData['native_place'] = val,
            prefixIcon: Icons.home_outlined,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
