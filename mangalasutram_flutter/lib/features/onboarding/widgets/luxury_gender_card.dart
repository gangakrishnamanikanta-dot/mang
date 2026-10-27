import 'package:flutter/material.dart';

class LuxuryGenderCard extends StatelessWidget {
  final String title;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const LuxuryGenderCard({
    super.key,
    required this.title,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Feedback.forTap(context);
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFFC99A4B) : const Color(0xFFE5DDD0),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFC99A4B).withValues(alpha: 0.20),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: const Color(0xFF6E1732).withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF6E1732) : const Color(0xFF4A3B32),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Color(0xFFC99A4B),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
