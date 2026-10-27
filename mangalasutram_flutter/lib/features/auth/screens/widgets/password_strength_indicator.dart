import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum PasswordStrength { none, weak, fair, strong }

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  PasswordStrength get strength {
    if (password.isEmpty) return PasswordStrength.none;
    if (password.length < 8) return PasswordStrength.weak;

    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    int criteriaMet = (hasUpper ? 1 : 0) +
        (hasLower ? 1 : 0) +
        (hasDigit ? 1 : 0) +
        (hasSpecial ? 1 : 0);

    if (password.length >= 8 && criteriaMet >= 3) {
      return PasswordStrength.strong;
    } else if (password.length >= 8 && criteriaMet >= 1) {
      return PasswordStrength.fair;
    }
    return PasswordStrength.weak;
  }

  Color _getColor(PasswordStrength s) {
    switch (s) {
      case PasswordStrength.strong:
        return const Color(0xFF2E7D32); // Emerald green
      case PasswordStrength.fair:
        return const Color(0xFFC99A4B); // Temple Gold / Amber
      case PasswordStrength.weak:
        return const Color(0xFFD32F2F); // Crimson
      case PasswordStrength.none:
        return Colors.transparent;
    }
  }

  String _getLabel(PasswordStrength s) {
    switch (s) {
      case PasswordStrength.strong:
        return 'Strong password';
      case PasswordStrength.fair:
        return 'Moderate (add numbers / symbols)';
      case PasswordStrength.weak:
        return 'Weak (minimum 8 characters)';
      case PasswordStrength.none:
        return '';
    }
  }

  double _getFraction(PasswordStrength s) {
    switch (s) {
      case PasswordStrength.strong:
        return 1.0;
      case PasswordStrength.fair:
        return 0.66;
      case PasswordStrength.weak:
        return 0.33;
      case PasswordStrength.none:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final currentStrength = strength;
    final color = _getColor(currentStrength);
    final fraction = _getFraction(currentStrength);
    final label = _getLabel(currentStrength);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    backgroundColor: const Color(0xFFE0D8CC),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
