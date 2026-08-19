import 'package:flutter/material.dart';

/// Green verified badge with white checkmark.
/// Shown on profiles that have is_verified=true (set by admin).
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF00C853), // Green
      ),
      child: Icon(Icons.check, size: size * 0.65, color: Colors.white),
    );
  }
}
