import 'package:flutter/material.dart';
import '../../../models/lookup_option.dart';
import '../../../shared/widgets/bottom_sheet_selector.dart';

class LuxuryDropdownField extends StatelessWidget {
  final String label;
  final String? placeholder;
  final String? selectedValue;
  final List<LookupOption> options;
  final ValueChanged<LookupOption> onSelected;
  final Widget? prefixIcon;
  final bool isRequired;

  const LuxuryDropdownField({
    super.key,
    required this.label,
    this.placeholder,
    this.selectedValue,
    required this.options,
    required this.onSelected,
    this.prefixIcon,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasValue = selectedValue != null && selectedValue!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
            if (isRequired)
              const Text(
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
          onTap: () async {
            FocusScope.of(context).unfocus();
            LookupOption? currentOption;
            if (hasValue) {
              try {
                currentOption = options.firstWhere((o) => o.label == selectedValue);
              } catch (_) {}
            }

            final result = await BottomSheetSelector.show(
              context: context,
              title: 'Select $label',
              options: options,
              selectedOption: currentOption,
            );

            if (result != null) {
              onSelected(result);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasValue ? const Color(0xFFC99A4B) : const Color(0xFFE5DDD0),
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
                if (prefixIcon != null) ...[
                  prefixIcon!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    hasValue ? selectedValue! : (placeholder ?? 'Select $label'),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                      color: hasValue ? const Color(0xFF2C1810) : const Color(0xFFB0A294),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF8B7355),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
