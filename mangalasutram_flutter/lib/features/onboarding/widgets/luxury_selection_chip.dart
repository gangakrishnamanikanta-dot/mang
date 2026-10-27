import 'package:flutter/material.dart';

class LuxurySelectionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final IconData? icon;
  final String? emoji;

  const LuxurySelectionChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.icon,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Feedback.forTap(context);
        onSelected();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6E1732) : Colors.white,
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF6E1732), Color(0xFF8B1E3F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(20),
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
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
            ] else if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFFC99A4B) : const Color(0xFF8B7355),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF3E2B20),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.check_rounded,
                size: 15,
                color: Color(0xFFC99A4B),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
