import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6E1732); // Burgundy / Crimson
  static const secondary = Color(0xFFC99A4B); // Gold
  static const gold = Color(0xFFC99A4B); // Gold alias
  static const background = Color(0xFFFFFDF8); // Cream
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1E1E1E);
  static const textSecondary = Color(0xFF8A8A8A);
  static const border = Color(0xFFECE7E0);
  static const divider = Color(0xFFECE7E0);
  static const success = Color(0xFF00C853);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFDC2626);
  static const overlay = Color(0x80000000);
  static const goldCTA = Color(0xFFD4A853);
  static const matchGradientStart = Color(0xFFD32F2F);
  static const matchGradientEnd = Color(0xFFFF6D00);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class AppTypography {
  static const String fontFamily = 'Inter';
  static const String serifFamily = 'Playfair Display';

  static const TextStyle heading = TextStyle(
    fontFamily: serifFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 40,
    letterSpacing: 0,
  );

  static const TextStyle subheading = TextStyle(
    fontFamily: serifFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 24,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20,
  );

  static const TextStyle small = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16,
  );
}

class AppBorderRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const full = 9999.0;
}

class AppShadows {
  static const sm = <BoxShadow>[
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  static const md = <BoxShadow>[
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  static const lg = <BoxShadow>[
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];
}
