import 'package:flutter/material.dart';
import '../models/subscription_status.dart';

class PrimeVerifiedBadge extends StatelessWidget {
  final SubscriptionTier tier;
  final double size;
  final bool showLabel;

  const PrimeVerifiedBadge({
    super.key,
    required this.tier,
    this.size = 18,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    if (tier == SubscriptionTier.free) return const SizedBox.shrink();

    final isPrime = tier == SubscriptionTier.prime;

    // Bronze / Rose-Gold for Prime Lite, Radiant Gold for Prime VIP
    final color = isPrime ? const Color(0xFFD4AF37) : const Color(0xFFC8826A);

    if (!showLabel) {
      return Icon(
        Icons.verified_rounded,
        color: color,
        size: size,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.verified_rounded,
          color: color,
          size: size,
        ),
        const SizedBox(width: 4),
        Text(
          isPrime ? 'Prime VIP' : 'Prime Lite',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
