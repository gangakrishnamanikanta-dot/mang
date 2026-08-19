import 'package:flutter/material.dart';
import '../../../shared/widgets/bottom_sheet_selector.dart';
import '../../../shared/widgets/apple_text_field.dart';
import '../../../models/profile.dart';

class Step3Education extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onUpdate;
  final Map<String, List<LookupOption>>? lookupData;

  const Step3Education({
    super.key,
    required this.formData,
    required this.onUpdate,
    this.lookupData,
  });

  @override
  State<Step3Education> createState() => _Step3EducationState();
}

class _Step3EducationState extends State<Step3Education> {
  late TextEditingController _collegeController;
  late TextEditingController _companyController;
  late TextEditingController _workLocationController;

  List<LookupOption> get _educations =>
      widget.lookupData?['education_levels'] ?? [];
  List<LookupOption> get _occupations =>
      widget.lookupData?['occupations'] ?? [];
  List<LookupOption> get _incomes => widget.lookupData?['annual_incomes'] ?? [];

  @override
  void initState() {
    super.initState();
    _collegeController = TextEditingController(
      text: widget.formData['college'] ?? '',
    );
    _companyController = TextEditingController(
      text: widget.formData['company'] ?? '',
    );
    _workLocationController = TextEditingController(
      text: widget.formData['work_location'] ?? '',
    );
  }

  @override
  void dispose() {
    _collegeController.dispose();
    _companyController.dispose();
    _workLocationController.dispose();
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
            'Education & Career',
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
            'Tell us about your professional background.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8E8E93),
            ),
          ),

          const SizedBox(height: 8),

          _buildSectionLabel('Highest Education'),
          _buildSelectField(
            'Highest Education',
            'highest_education_id',
            _educations,
          ),

          _buildSectionLabel('College / University'),
          AppleTextField(
            controller: _collegeController,
            hintText: 'e.g. IIT Bombay, Stanford...',
            onChanged: (val) => widget.formData['college'] = val,
          ),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE5E5EA)),
          const SizedBox(height: 4),

          _buildSectionLabel('Occupation'),
          _buildSelectField('Occupation', 'occupation_id', _occupations),

          _buildSectionLabel('Company Name (Optional)'),
          AppleTextField(
            controller: _companyController,
            hintText: 'e.g. Google, TCS, Self-Employed...',
            onChanged: (val) => widget.formData['company'] = val,
          ),

          _buildSectionLabel('Work Location'),
          AppleTextField(
            controller: _workLocationController,
            hintText: 'e.g. Hyderabad, Remote, New York...',
            onChanged: (val) => widget.formData['work_location'] = val,
          ),

          _buildSectionLabel('Annual Income'),
          _buildSelectField('Annual Income', 'annual_income_id', _incomes),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
