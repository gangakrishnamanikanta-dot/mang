import 'package:flutter/material.dart';
import '../../../models/lookup_option.dart';
import '../widgets/luxury_dropdown_field.dart';
import '../widgets/luxury_selection_chip.dart';
import '../widgets/luxury_text_field.dart';

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
  late TextEditingController _familyDescController;

  List<LookupOption> get _familyTypes => widget.lookupData?['family_types'] ?? [];

  static const List<String> _familyValuesOptions = [
    'Traditional & Orthodox',
    'Traditional Modern',
    'Moderate & Cultured',
    'Liberal',
  ];

  static const List<int> _siblingCounts = [0, 1, 2, 3];

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
    _familyDescController = TextEditingController(
      text: widget.formData['family_description'] ?? '',
    );
  }

  @override
  void dispose() {
    _fatherNameController.dispose();
    _fatherOccController.dispose();
    _motherNameController.dispose();
    _motherOccController.dispose();
    _nativePlaceController.dispose();
    _familyDescController.dispose();
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

  Widget _buildSiblingSelector({
    required String label,
    required int selectedCount,
    required ValueChanged<int> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3E2723),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: _siblingCounts.map((count) {
            final isSelected = selectedCount == count;
            final String text = count == 0
                ? 'None'
                : count == 3
                    ? '3+'
                    : count.toString();
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => onSelect(count),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF6E1732) : const Color(0xFFF9F6F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFC99A4B) : const Color(0xFFE2D8C8),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF6E1732).withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      text,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF4A3B32),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyTypeId = widget.formData['family_type_id'];
    final familyTypeLabel = _familyTypes.firstWhere(
      (o) => o.id == familyTypeId,
      orElse: () => LookupOption(id: -1, label: ''),
    ).label;

    final selectedFamilyValues = widget.formData['family_values'] as String?;
    final brothersCount = widget.formData['brothers_count'] as int? ?? 0;
    final sistersCount = widget.formData['sisters_count'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          const Text(
            'Family Lineage & Roots',
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
            'Your family culture, heritage, and values',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8B7355),
            ),
          ),

          const SizedBox(height: 24),

          // Card 1: Family Culture & Type
          _buildSectionContainer(
            title: 'Family Culture & Type',
            icon: Icons.temple_hindu_rounded,
            children: [
              const Text(
                'Family Values',
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
                children: _familyValuesOptions.map((opt) {
                  final isSelected = selectedFamilyValues == opt;
                  return LuxurySelectionChip(
                    label: opt,
                    isSelected: isSelected,
                    onSelected: () {
                      widget.onUpdate('family_values', opt);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              if (_familyTypes.isNotEmpty) ...[
                const SizedBox(height: 18),
                LuxuryDropdownField(
                  label: 'Family Type',
                  placeholder: 'Select Family Type (e.g. Nuclear, Joint)',
                  selectedValue: familyTypeLabel.isNotEmpty ? familyTypeLabel : null,
                  options: _familyTypes,
                  prefixIcon: const Icon(Icons.home_work_rounded, color: Color(0xFFC99A4B), size: 20),
                  onSelected: (opt) {
                    widget.onUpdate('family_type_id', opt.id);
                    setState(() {});
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // Card 2: Parents' Information
          _buildSectionContainer(
            title: 'Parents\' Information',
            icon: Icons.people_alt_rounded,
            children: [
              LuxuryTextField(
                label: 'Father\'s Name',
                hintText: 'Enter father\'s full name',
                controller: _fatherNameController,
                prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFFC99A4B), size: 20),
                onChanged: (val) => widget.onUpdate('father_name', val),
              ),
              const SizedBox(height: 16),
              LuxuryTextField(
                label: 'Father\'s Occupation',
                hintText: 'e.g. Retired Govt Officer, Business, Engineer',
                controller: _fatherOccController,
                prefixIcon: const Icon(Icons.work_outline_rounded, color: Color(0xFFC99A4B), size: 20),
                onChanged: (val) => widget.onUpdate('father_occupation', val),
              ),
              const SizedBox(height: 18),
              const Divider(color: Color(0xFFF0EAE1), height: 1),
              const SizedBox(height: 18),
              LuxuryTextField(
                label: 'Mother\'s Name',
                hintText: 'Enter mother\'s full name',
                controller: _motherNameController,
                prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFFC99A4B), size: 20),
                onChanged: (val) => widget.onUpdate('mother_name', val),
              ),
              const SizedBox(height: 16),
              LuxuryTextField(
                label: 'Mother\'s Occupation',
                hintText: 'e.g. Homemaker, Teacher, Doctor',
                controller: _motherOccController,
                prefixIcon: const Icon(Icons.work_outline_rounded, color: Color(0xFFC99A4B), size: 20),
                onChanged: (val) => widget.onUpdate('mother_occupation', val),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Card 3: Siblings
          _buildSectionContainer(
            title: 'Siblings',
            icon: Icons.family_restroom_rounded,
            children: [
              _buildSiblingSelector(
                label: 'Brothers',
                selectedCount: brothersCount,
                onSelect: (count) {
                  widget.onUpdate('brothers_count', count);
                  setState(() {});
                },
              ),
              const SizedBox(height: 18),
              _buildSiblingSelector(
                label: 'Sisters',
                selectedCount: sistersCount,
                onSelect: (count) {
                  widget.onUpdate('sisters_count', count);
                  setState(() {});
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Card 4: Ancestral Roots & Background
          _buildSectionContainer(
            title: 'Ancestral Roots',
            icon: Icons.location_on_rounded,
            children: [
              LuxuryTextField(
                label: 'Native Place / Ancestral Town',
                hintText: 'e.g. Rajahmundry, Thanjavur, Palakkad, Udupi',
                controller: _nativePlaceController,
                prefixIcon: const Icon(Icons.pin_drop_rounded, color: Color(0xFFC99A4B), size: 20),
                onChanged: (val) => widget.onUpdate('native_place', val),
              ),
              const SizedBox(height: 16),
              LuxuryTextField(
                label: 'About Family (Optional)',
                hintText: 'Briefly describe your family background and traditions...',
                controller: _familyDescController,
                maxLines: 3,
                onChanged: (val) => widget.onUpdate('family_description', val),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
