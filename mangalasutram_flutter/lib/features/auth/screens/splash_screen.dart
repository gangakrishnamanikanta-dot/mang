import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Main entrance animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Gold divider pulse (repeating)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFFAF6F0),
        child: Center(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo with luxury circular fallback
                      Image.asset(
                        'assets/images/logo.png',
                        height: 130,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.gold,
                                width: 1.5,
                              ),
                              color: AppColors.primary.withValues(alpha: 0.07),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.auto_awesome,
                                color: AppColors.gold,
                                size: 48,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      // App name - Playfair Display (luxury serif)
                      Text(
                        'MANGALASUTRAM',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3.0,
                          color: const Color(0xFF6E1732),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Animated gold divider that breathes
                      AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          final pulse = _shimmerController.value;
                          return Container(
                            width: 52 + (pulse * 24),
                            height: 1.5,
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(
                                alpha: 0.55 + (pulse * 0.45),
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      // Subtitle - Inter (clean sans)
                      Text(
                        'Sacred Matrimony',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          letterSpacing: 2.8,
                          color: AppColors.gold,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
