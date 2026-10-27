import 'package:flutter/material.dart';
import '../../../models/lookup_option.dart';
import '../widgets/luxury_dropdown_field.dart';
import '../widgets/luxury_selection_chip.dart';
import '../widgets/luxury_text_field.dart';

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

  List<LookupOption> get _educations => widget.lookupData?['education_levels'] ?? [];
  List<LookupOption> get _occupations => widget.lookupData?['occupations'] ?? [];
  List<LookupOption> get _incomes => widget.lookupData?['annual_incomes'] ?? [];

  static const List<String> _workTypeOptions = [
    'Work from Office',
    'Hybrid',
    'Remote / WFH',
    'Business / Self-Employed',
  ];

  static const List<String> _careerPreferenceOptions = [
    'Career-focused & Growth Oriented',
    'Balanced Career & Family Life',
    'Family-first & Flexible Hours',
  ];

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

  @override
  Widget build(BuildContext context) {
    // Education lookup label
    final educationId = widget.formData['highest_education_id'];
    final educationLabel = _educations.firstWhere(
      (o) => o.id == educationId,
      orElse: () => LookupOption(id: -1, label: ''),
    ).label;

    // Occupation lookup label
    final occupationId = widget.formData['occupation_id'];
    final occupationLabel = _occupations.firstWhere(
      (o) => o.id == occupationId,
      orElse: () => LookupOption(id: -1, label: ''),
    ).label;

    // Annual Income lookup label
    final incomeId = widget.formData['annual_income_id'];
    final incomeLabel = _incomes.firstWhere(
      (o) => o.id == incomeId,
      orElse: () => LookupOption(id: -1, label: ''),
    ).label;

    final selectedWorkType = widget.formData['work_type'] as String?;
    final selectedCareerPref = widget.formData['career_preference'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          const Text(
            'Education & Profession',
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
            'Your academic credentials and career journey',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8B7355),
            ),
          ),

          const SizedBox(height: 24),

          // 1. Highest Education (Searchable Dropdown)
          LuxuryDropdownField(
            label: 'Highest Education Qualification',
            placeholder: 'Select Qualification (e.g. B.Tech, MS, MBA, MBBS)',
            selectedValue: educationLabel.isNotEmpty ? educationLabel : null,
            isRequired: true,
            options: _educations,
            prefixIcon: const Icon(Icons.school_rounded, color: Color(0xFFC99A4B), size: 20),
            onSelected: (opt) {
              widget.onUpdate('highest_education_id', opt.id);
              setState(() {});
            },
          ),

          const SizedBox(height: 20),

          // 2. College / University
          LuxuryTextField(
            label: 'College / University',
            hintText: 'e.g. IIT Madras, BITS Pilani, Stanford, Osmania',
            controller: _collegeController,
            prefixIcon: const Icon(Icons.account_balance_rounded, color: Color(0xFFC99A4B), size: 20),
            onChanged: (val) => widget.onUpdate('college', val),
          ),

          const SizedBox(height: 20),

          // 3. Occupation (Searchable Dropdown)
          LuxuryDropdownField(
            label: 'Occupation / Sector',
            placeholder: 'Select Profession (e.g. Software Engineer, Doctor)',
            selectedValue: occupationLabel.isNotEmpty ? occupationLabel : null,
            isRequired: true,
            options: _occupations,
            prefixIcon: const Icon(Icons.work_rounded, color: Color(0xFFC99A4B), size: 20),
            onSelected: (opt) {
              widget.onUpdate('occupation_id', opt.id);
              setState(() {});
            },
          ),

          const SizedBox(height: 20),

          // 4. Company Name
          LuxuryTextField(
            label: 'Company / Employer (Optional)',
            hintText: 'e.g. Google, Microsoft, TCS, Deloitte, Self-Employed',
            controller: _companyController,
            prefixIcon: const Icon(Icons.business_rounded, color: Color(0xFFC99A4B), size: 20),
            onChanged: (val) => widget.onUpdate('company', val),
          ),

          const SizedBox(height: 20),

          // 5. Work Location
          LuxuryTextField(
            label: 'Work Location',
            hintText: 'e.g. Hyderabad, Bengaluru, San Jose CA, London',
            controller: _workLocationController,
            prefixIcon: const Icon(Icons.location_city_rounded, color: Color(0xFFC99A4B), size: 20),
            onChanged: (val) => widget.onUpdate('work_location', val),
          ),

          const SizedBox(height: 24),

          // 6. Annual Income (Searchable Dropdown)
          LuxuryDropdownField(
            label: 'Annual Income Range',
            placeholder: 'Select Annual Income',
            selectedValue: incomeLabel.isNotEmpty ? incomeLabel : null,
            options: _incomes,
            prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Color(0xFFC99A4B), size: 20),
            onSelected: (opt) {
              widget.onUpdate('annual_income_id', opt.id);
              setState(() {});
            },
          ),

          const SizedBox(height: 24),

          // 7. Work Arrangement (One-Tap Tactile Pills)
          const Text(
            'Work Arrangement',
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
            children: _workTypeOptions.map((opt) {
              final isSelected = selectedWorkType == opt;
              String? emoji;
              if (opt.contains('Office')) emoji = '🏢';
              if (opt.contains('Hybrid')) emoji = '🔄';
              if (opt.contains('Remote')) emoji = '💻';
              if (opt.contains('Business')) emoji = '💼';

              return LuxurySelectionChip(
                label: opt,
                isSelected: isSelected,
                emoji: emoji,
                onSelected: () {
                  widget.onUpdate('work_type', opt);
                  setState(() {});
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // 8. Career Preference (Tactile Pills)
          const Text(
            'Career & Life Balance Preference',
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
            children: _careerPreferenceOptions.map((opt) {
              final isSelected = selectedCareerPref == opt;
              return LuxurySelectionChip(
                label: opt,
                isSelected: isSelected,
                onSelected: () {
                  widget.onUpdate('career_preference', opt);
                  setState(() {});
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
