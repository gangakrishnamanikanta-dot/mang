import 'package:flutter/material.dart';

class OnboardingProgressHeader extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onBack;

  const OnboardingProgressHeader({
    super.key,
    required this.currentStep,
    this.totalSteps = 8,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = (currentStep + 1) / totalSteps;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: Color(0xFF6E1732),
                  ),
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else
                const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'STEP ${currentStep + 1} OF $totalSteps',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: Color(0xFFC99A4B),
                  ),
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
          const SizedBox(height: 12),

          // Animated Glowing Vedic Gold Progress Bar
          Stack(
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFEADBCE),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOutCubic,
                    height: 4,
                    width: constraints.maxWidth * progress,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC99A4B), Color(0xFFE5C07B)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC99A4B).withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
