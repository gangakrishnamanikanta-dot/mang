import 'package:flutter/material.dart';
import '../../../shared/widgets/bottom_sheet_selector.dart';
import '../../../models/profile.dart';

class Step5Lifestyle extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onUpdate;
  final Map<String, List<LookupOption>>? lookupData;

  const Step5Lifestyle({
    super.key,
    required this.formData,
    required this.onUpdate,
    this.lookupData,
  });

  @override
  State<Step5Lifestyle> createState() => _Step5LifestyleState();
}

class _Step5LifestyleState extends State<Step5Lifestyle> {
  late TextEditingController _aboutMeController;

  List<LookupOption> get _foodOptions =>
      widget.lookupData?['food_preferences'] ?? [];
  List<LookupOption> get _smokingOptions =>
      widget.lookupData?['smoking_habits'] ?? [];
  List<LookupOption> get _drinkingOptions =>
      widget.lookupData?['drinking_habits'] ?? [];

  @override
  void initState() {
    super.initState();
    _aboutMeController = TextEditingController(
      text: widget.formData['about_me'] ?? '',
    );
  }

  @override
  void dispose() {
    _aboutMeController.dispose();
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
            'Lifestyle & Habits',
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
            'Share a bit about your lifestyle to find a compatible partner.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8E8E93),
            ),
          ),

          const SizedBox(height: 8),

          _buildSectionLabel('Food Preference'),
          _buildSelectField(
            'Food Preference',
            'food_preference_id',
            _foodOptions,
          ),

          _buildSectionLabel('Smoking Habit'),
          _buildSelectField('Smoking Habit', 'smoking_id', _smokingOptions),

          _buildSectionLabel('Drinking Habit'),
          _buildSelectField('Drinking Habit', 'drinking_id', _drinkingOptions),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE5E5EA)),
          const SizedBox(height: 8),

          _buildSectionLabel('About Me'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 1.0),
            ),
            child: TextField(
              controller: _aboutMeController,
              maxLines: 4,
              maxLength: 500,
              onChanged: (val) => widget.formData['about_me'] = val,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 17,
                color: Color(0xFF1C1C1E),
              ),
              decoration: const InputDecoration(
                hintText:
                    'Tell us a little bit about yourself, your hobbies, and what you are looking for in a partner...',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  color: Color(0xFF8E8E93),
                ),
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
