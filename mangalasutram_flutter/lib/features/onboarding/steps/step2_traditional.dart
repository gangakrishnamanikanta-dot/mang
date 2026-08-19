import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../shared/widgets/apple_text_field.dart';
import '../../../shared/widgets/bottom_sheet_selector.dart';
import '../../../models/profile.dart'; // Ensure LookupOption is exported or imported appropriately.

class Step2Traditional extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onUpdate;
  final Map<String, List<LookupOption>>? lookupData;

  const Step2Traditional({
    super.key,
    required this.formData,
    required this.onUpdate,
    this.lookupData,
  });

  @override
  State<Step2Traditional> createState() => _Step2TraditionalState();
}

class _Step2TraditionalState extends State<Step2Traditional> {
  late TextEditingController _subCasteController;
  late TextEditingController _pravaraController;

  List<LookupOption> get _maritalStatuses =>
      widget.lookupData?['marital_statuses'] ?? [];
  List<LookupOption> get _motherTongues =>
      widget.lookupData?['mother_tongues'] ?? [];
  List<LookupOption> get _castes => widget.lookupData?['castes'] ?? [];
  List<LookupOption> get _gothrams => widget.lookupData?['gothrams'] ?? [];
  List<LookupOption> get _vedaShakhas =>
      widget.lookupData?['veda_shakhas'] ?? [];
  List<LookupOption> get _nakshatras => widget.lookupData?['nakshatras'] ?? [];
  List<LookupOption> get _rashis => widget.lookupData?['rashis'] ?? [];
  List<LookupOption> get _padas => widget.lookupData?['padas'] ?? [];

  @override
  void initState() {
    super.initState();
    _subCasteController = TextEditingController(
      text: widget.formData['sub_caste'] ?? '',
    );
    _pravaraController = TextEditingController(
      text: widget.formData['pravara'] ?? '',
    );
  }

  @override
  void dispose() {
    _subCasteController.dispose();
    _pravaraController.dispose();
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
            'Traditional Background',
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
            'These details are essential for finding culturally compatible matches.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8E8E93),
            ),
          ),

          const SizedBox(height: 8),

          _buildSectionLabel('Gothram'),
          _buildSelectField('Gothram', 'gothram_id', _gothrams),

          _buildSectionLabel('Pravara (Optional)'),
          AppleTextField(
            controller: _pravaraController,
            hintText: 'e.g. Harithasa, Koundinya...',
            onChanged: (val) => widget.formData['pravara'] = val,
          ),

          _buildSectionLabel('Veda Shakha'),
          _buildSelectField('Veda Shakha', 'veda_shakha_id', _vedaShakhas),

          _buildSectionLabel('Nakshatra'),
          _buildSelectField('Nakshatra', 'nakshatra_id', _nakshatras),

          _buildSectionLabel('Rashi'),
          _buildSelectField('Rashi', 'rashi_id', _rashis),

          _buildSectionLabel('Pada'),
          _buildSelectField('Pada', 'pada_id', _padas),

          _buildSectionLabel('Kuja Dosham / Manglik'),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<String>(
              backgroundColor: const Color(0xFFE5E5EA),
              thumbColor: Colors.white,
              groupValue: widget.formData['kuja_dosham'] ?? 'Don\'t Know',
              children: const {
                'Yes': Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Yes',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 15),
                  ),
                ),
                'No': Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 15),
                  ),
                ),
                'Don\'t Know': Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Don\'t Know',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 15),
                  ),
                ),
              },
              onValueChanged: (val) {
                if (val != null) {
                  setState(() {
                    widget.formData['kuja_dosham'] = val;
                    widget.onUpdate('kuja_dosham', val);
                  });
                }
              },
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
