import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/plans_screen.dart';

class QuotaExhaustedSheet extends StatelessWidget {
  final String tier;
  final int limit;

  const QuotaExhaustedSheet({
    super.key,
    required this.tier,
    required this.limit,
  });

  static Future<void> show(BuildContext context, {required String tier, required int limit}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuotaExhaustedSheet(tier: tier, limit: limit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFree = tier.toLowerCase() == 'free';
    final nextTierName = isFree ? 'Prime Lite' : 'Prime VIP';
    final nextTierLimit = isFree ? 15 : 25;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Badge & Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF0F2),
              border: Border.all(color: const Color(0xFFFFD1D8), width: 1),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFF6E1732),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Daily Interest Limit Reached',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2B2118),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            'You have used all $limit interests allowed on the ${tier.toUpperCase()} plan today. Your quota resets at midnight.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF706053),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Benefit Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF4EE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEADBCE)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFFB89230), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Upgrade to $nextTierName to get:',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF3B2D22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBenefitItem('$nextTierLimit Daily Interests per day'),
                _buildBenefitItem(isFree ? 'Unlock 25 Verified Phone Numbers' : 'Unlock 60 Phone Numbers'),
                _buildBenefitItem('Access to ✨ PRIME Discovery Feed'),
                _buildBenefitItem(isFree ? 'Direct Chat with matches' : '🔥 3x Spotlight Recommendation Boost'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Primary Upgrade CTA
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PlansScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6E1732),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
              child: Text(
                'Upgrade to $nextTierName',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary Close Button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'I\'ll wait until tomorrow',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF8A7A6E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF4A3B30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
