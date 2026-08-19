import 'package:flutter/material.dart';

/// Match percentage badge positioned on the top-right corner of profile photos.
/// Shows red-to-orange gradient like the image (e.g. "35%").
class MatchBadge extends StatelessWidget {
  const MatchBadge({super.key, required this.percentage, this.size = 38});

  final int percentage;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFFD32F2F), Color(0xFFFF6D00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$percentage%',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
      ),
    );
  }
}
