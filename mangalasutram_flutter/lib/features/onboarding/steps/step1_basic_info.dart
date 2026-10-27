import 'package:flutter/material.dart';
import '../../../shared/widgets/bottom_sheet_selector.dart';
import '../../../shared/widgets/luxury_date_picker.dart';
import '../../../models/lookup_option.dart';
import '../widgets/luxury_selection_chip.dart';
import '../widgets/luxury_gender_card.dart';
import '../widgets/luxury_text_field.dart';
import '../widgets/luxury_multi_photo_picker.dart';

class Step1BasicInfo extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onUpdate;
  final Map<String, List<LookupOption>>? lookupData;

  const Step1BasicInfo({
    super.key,
    required this.formData,
    required this.onUpdate,
    this.lookupData,
  });

  @override
  State<Step1BasicInfo> createState() => _Step1BasicInfoState();
}

class _Step1BasicInfoState extends State<Step1BasicInfo> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _subCasteController;

  final List<LookupOption> _heightOptions = List.generate(48, (index) {
    final inches = 48 + index;
    final ft = inches ~/ 12;
    final ins = inches % 12;
    return LookupOption(id: inches, label: "$ft'$ins\" (${(inches * 2.54).round()} cm)");
  });

  final List<String> _createdForOptions = [
    'Self',
    'Son',
    'Daughter',
    'Brother',
    'Sister',
    'Relative',
    'Friend',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.formData['full_name'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.formData['phone'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.formData['email'] ?? '',
    );
    _subCasteController = TextEditingController(
      text: widget.formData['sub_caste'] ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _subCasteController.dispose();
    super.dispose();
  }

  int? _calculateAge(String? dobStr) {
    if (dobStr == null || dobStr.isEmpty) return null;
    try {
      final dob = DateTime.parse(dobStr.split('T')[0]);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age > 0 ? age : null;
    } catch (_) {
      return null;
    }
  }

  void _pickDateOfBirth() async {
    FocusScope.of(context).unfocus();
    DateTime? initialDate;
    final currentStr = widget.formData['date_of_birth'] as String?;
    if (currentStr != null && currentStr.isNotEmpty) {
      try {
        initialDate = DateTime.parse(currentStr.split('T')[0]);
      } catch (_) {}
    }

    final gender = widget.formData['gender']?.toString().toLowerCase();
    final minAge = gender == 'male' ? 21 : 18;

    final picked = await LuxuryDatePicker.show(
      context: context,
      initialDate: initialDate,
      minimumAge: minAge,
      title: gender == 'male' ? 'Select Date of Birth (21+ for Groom)' : 'Select Date of Birth (18+ for Bride)',
    );

    if (picked != null) {
      final formatted =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      widget.onUpdate('date_of_birth', formatted);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedGender = widget.formData['gender']?.toString();
    final selectedCreatedFor = widget.formData['created_for']?.toString() ?? 'Self';
    final dob = widget.formData['date_of_birth'] as String?;
    final age = _calculateAge(dob);

    // Height lookup label
    final heightInches = widget.formData['height_inches'];
    final heightLabel = _heightOptions.firstWhere(
      (opt) => opt.id == heightInches,
      orElse: () => LookupOption(id: -1, label: 'Select Height'),
    ).label;

    // Mother Tongue lookup label
    final motherTongues = widget.lookupData?['mother_tongues'] ?? [];
    final selectedMotherTongueId = widget.formData['mother_tongue_id'];
    final motherTongueLabel = motherTongues.firstWhere(
      (opt) => opt.id == selectedMotherTongueId,
      orElse: () => LookupOption(id: -1, label: 'Select Mother Tongue'),
    ).label;

    // Caste lookup label
    final castes = widget.lookupData?['castes'] ?? [];
    final selectedCasteId = widget.formData['caste_id'];
    final casteLabel = castes.firstWhere(
      (opt) => opt.id == selectedCasteId,
      orElse: () => LookupOption(id: -1, label: 'Select Caste'),
    ).label;

    // Marital Status options
    final maritalStatuses = widget.lookupData?['marital_statuses'] ?? [];
    final selectedMaritalStatusId = widget.formData['marital_status_id'];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Screen Title
          const Text(
            'Sacred Identity',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6E1732),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Begin your journey towards a sacred union',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8B7355),
            ),
          ),
          const SizedBox(height: 20),

          // 1. Auspicious Luxury Multi-Photo Manager (1 Main + 5 Additional Gallery Photos)
          LuxuryMultiPhotoPicker(
            mainPhotoUrl: widget.formData['profile_photo_url']?.toString(),
            additionalPhotoUrls: List<String>.from(
              widget.formData['additional_photo_urls'] ?? [],
            ),
            onPhotosChanged: (mainUrl, additionalUrls) {
              widget.onUpdate('profile_photo_url', mainUrl);
              widget.onUpdate('additional_photo_urls', additionalUrls);
              setState(() {});
            },
          ),

          const SizedBox(height: 28),

          // 2. Profile Created For (One-Tap Tactile Pills)
          const Text(
            'Profile Created For',
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
            children: _createdForOptions.map((opt) {
              final isSelected = selectedCreatedFor.toLowerCase() == opt.toLowerCase();
              return LuxurySelectionChip(
                label: opt,
                isSelected: isSelected,
                onSelected: () => widget.onUpdate('created_for', opt),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // 3. Gender (Twin Elevated Cards)
          const Text(
            'Gender',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3E2723),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              LuxuryGenderCard(
                title: 'Groom',
                emoji: '🤵',
                isSelected: selectedGender == 'Male',
                onTap: () => widget.onUpdate('gender', 'Male'),
              ),
              const SizedBox(width: 12),
              LuxuryGenderCard(
                title: 'Bride',
                emoji: '👰',
                isSelected: selectedGender == 'Female',
                onTap: () => widget.onUpdate('gender', 'Female'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 4. Full Name (Luxury Clean Input)
          LuxuryTextField(
            label: 'Full Name',
            hintText: 'Enter your full name',
            controller: _nameController,
            isRequired: true,
            prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFC99A4B), size: 20),
            onChanged: (val) => widget.onUpdate('full_name', val),
          ),

          const SizedBox(height: 20),

          // 5. Date of Birth (Luxury Cupertino Card)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Date of Birth',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3E2723),
                    ),
                  ),
                  Text(
                    ' *',
                    style: TextStyle(
                      color: Color(0xFFC99A4B),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDateOfBirth,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: dob != null ? const Color(0xFFC99A4B) : const Color(0xFFE5DDD0),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                        color: Color(0xFFC99A4B),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (dob != null && dob.isNotEmpty)
                              ? (age != null ? '$dob  (Age: $age Yrs)' : dob)
                              : 'Select Date of Birth',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: dob != null ? FontWeight.w600 : FontWeight.w400,
                            color: dob != null ? const Color(0xFF2C1810) : const Color(0xFFB0A294),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF8B7355),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 6. Height (Tactile Selector)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Height',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E2723),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  FocusScope.of(context).unfocus();
                  final selected = _heightOptions.firstWhere(
                    (o) => o.id == heightInches,
                    orElse: () => _heightOptions[17],
                  );
                  final result = await BottomSheetSelector.show(
                    context: context,
                    title: 'Select Height',
                    options: _heightOptions,
                    selectedOption: selected,
                  );
                  if (result != null) {
                    widget.onUpdate('height_inches', result.id);
                    setState(() {});
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: heightInches != null ? const Color(0xFFC99A4B) : const Color(0xFFE5DDD0),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.straighten_rounded, size: 20, color: Color(0xFFC99A4B)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          heightInches != null ? heightLabel : 'Select Height',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: heightInches != null ? FontWeight.w600 : FontWeight.w400,
                            color: heightInches != null ? const Color(0xFF2C1810) : const Color(0xFFB0A294),
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF8B7355)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 7. Marital Status (Tactile Selection Chips)
          if (maritalStatuses.isNotEmpty) ...[
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
              children: maritalStatuses.map((opt) {
                final isSelected = selectedMaritalStatusId == opt.id;
                return LuxurySelectionChip(
                  label: opt.label,
                  isSelected: isSelected,
                  onSelected: () {
                    widget.onUpdate('marital_status_id', opt.id);
                    setState(() {});
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // 8. Mother Tongue & Caste (Clean Selectors)
          if (motherTongues.isNotEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mother Tongue',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    FocusScope.of(context).unfocus();
                    final selected = motherTongues.firstWhere(
                      (o) => o.id == selectedMotherTongueId,
                      orElse: () => LookupOption(id: -1, label: ''),
                    );
                    final result = await BottomSheetSelector.show(
                      context: context,
                      title: 'Select Mother Tongue',
                      options: motherTongues,
                      selectedOption: selected.id == -1 ? null : selected,
                    );
                    if (result != null) {
                      widget.onUpdate('mother_tongue_id', result.id);
                      setState(() {});
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5DDD0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.language_rounded, size: 20, color: Color(0xFFC99A4B)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedMotherTongueId != null ? motherTongueLabel : 'Select Mother Tongue',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: selectedMotherTongueId != null ? FontWeight.w600 : FontWeight.w400,
                              color: selectedMotherTongueId != null ? const Color(0xFF2C1810) : const Color(0xFFB0A294),
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF8B7355)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          if (castes.isNotEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Caste / Community',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    FocusScope.of(context).unfocus();
                    final selected = castes.firstWhere(
                      (o) => o.id == selectedCasteId,
                      orElse: () => LookupOption(id: -1, label: ''),
                    );
                    final result = await BottomSheetSelector.show(
                      context: context,
                      title: 'Select Caste',
                      options: castes,
                      selectedOption: selected.id == -1 ? null : selected,
                    );
                    if (result != null) {
                      widget.onUpdate('caste_id', result.id);
                      setState(() {});
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5DDD0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.temple_hindu_rounded, size: 20, color: Color(0xFFC99A4B)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedCasteId != null ? casteLabel : 'Select Caste',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: selectedCasteId != null ? FontWeight.w600 : FontWeight.w400,
                              color: selectedCasteId != null ? const Color(0xFF2C1810) : const Color(0xFFB0A294),
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF8B7355)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          LuxuryTextField(
            label: 'Sub Caste (Optional)',
            hintText: 'e.g. Niyogi, Vaidiki, Vadakalai, Smartha',
            controller: _subCasteController,
            prefixIcon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFC99A4B), size: 20),
            onChanged: (val) => widget.onUpdate('sub_caste', val),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
