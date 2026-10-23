import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../constants/theme.dart';
import '../../../shared/widgets/scale_button.dart';
import '../providers/auth_provider.dart';
import 'widgets/auth_background.dart';
import '../../../core/di.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../../../core/exceptions/app_exception.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isEmailMode = true;
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  // Rate-limit countdown
  int _rateLimitSecondsLeft = 0;
  Timer? _rateLimitTimer;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final AuthService _authService = getIt<AuthService>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _rateLimitTimer?.cancel();
    super.dispose();
  }

  void _toggleMode(bool isEmail) {
    if (_isEmailMode == isEmail) return;
    setState(() => _isEmailMode = isEmail);
    HapticFeedback.selectionClick();
  }

  void _startRateLimitCountdown(int seconds) {
    _rateLimitTimer?.cancel();
    setState(() => _rateLimitSecondsLeft = seconds);
    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_rateLimitSecondsLeft <= 1) {
        t.cancel();
        setState(() => _rateLimitSecondsLeft = 0);
      } else {
        setState(() => _rateLimitSecondsLeft--);
      }
    });
  }

  Future<void> _handleLogin() async {
    if (_isSubmitting) return;
    if (_rateLimitSecondsLeft > 0) return;
    setState(() => _isSubmitting = true);

    if (_isEmailMode) {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();
      if (email.isEmpty || password.isEmpty) {
        _showError('Please enter email and password');
        setState(() => _isSubmitting = false);
        return;
      }
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
      if (!emailRegex.hasMatch(email)) {
        _showError('Please enter a valid email address');
        setState(() => _isSubmitting = false);
        return;
      }

      try {
        await SupabaseService.client.auth
            .signInWithPassword(email: email, password: password)
            .timeout(const Duration(seconds: 15));
        if (!mounted) return;
        final auth = context.read<AuthProvider>();
        await auth.refreshProfile();
        if (auth.hasError && auth.errorMessage != null) {
          _showError(auth.errorMessage!);
        }
      } on AuthException catch (e) {
        final msg = _friendlyAuthMessage(e.message);
        _showError(msg);
        if (msg.contains('wait') || msg.contains('attempts')) {
          _startRateLimitCountdown(30);
        }
      } on AppException catch (e) {
        _showError(e.message);
      } catch (_) {
        _showError('Something went wrong. Please try again.');
      }
    } else {
      final rawPhone = _phoneCtrl.text.trim();
      if (rawPhone.isEmpty) {
        _showError('Please enter your phone number');
        setState(() => _isSubmitting = false);
        return;
      }

      String cleanPhone = rawPhone.replaceAll(RegExp(r'[\s\-()]'), '');
      if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
      if (cleanPhone.startsWith('+91')) {
        cleanPhone = cleanPhone.substring(3);
      } else if (cleanPhone.startsWith('91') && cleanPhone.length == 12) {
        cleanPhone = cleanPhone.substring(2);
      }

      final indianPhoneRegex = RegExp(r'^[6-9]\d{9}$');
      if (!indianPhoneRegex.hasMatch(cleanPhone)) {
        _showError('Please enter a valid 10-digit Indian mobile number');
        setState(() => _isSubmitting = false);
        return;
      }

      final formattedPhone = '+91$cleanPhone';
      try {
        await SupabaseService.client.auth
            .signInWithOtp(phone: formattedPhone)
            .timeout(const Duration(seconds: 15));
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          '/otp-verification',
          arguments: {'phone': formattedPhone, 'purpose': 'login'},
        );
      } on AuthException catch (e) {
        _showError(_friendlyAuthMessage(e.message));
      } catch (_) {
        _showError('Failed to send OTP. Please try again.');
      }
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await _authService.signInWithGoogle();
      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();
    } on AuthException catch (e) {
      _showError(_friendlyAuthMessage(e.message));
    } on AppException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  String _friendlyAuthMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials') || lower.contains('invalid')) {
      return 'Incorrect email or password';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email first';
    }
    if (lower.contains('too many requests') || lower.contains('rate limit')) {
      return 'Too many attempts. Please wait and try again';
    }
    if (lower.contains('user not found')) {
      return 'Incorrect email or password';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final logoHeight = (screenHeight * 0.22).clamp(120.0, 200.0);

    return Scaffold(
      // KEY FIX: keyboard scrolls the page instead of hiding inputs
      resizeToAvoidBottomInset: true,
      body: AuthBackground(
        child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: screenHeight * 0.04),
                // Responsive logo
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: logoHeight,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold, width: 1.5),
                          color: AppColors.primary.withValues(alpha: 0.07),
                        ),
                        child: const Center(
                          child: Icon(Icons.auto_awesome, color: AppColors.gold, size: 36),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                AuthCard(
                  child: Column(
                    children: [
                      _buildToggle(),
                      const SizedBox(height: 20),
                      if (_isEmailMode) ...[
                        AuthTextField(
                          controller: _emailCtrl,
                          hint: 'Enter your email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _passwordCtrl,
                          hint: 'Enter your password',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.gold,
                              size: 22,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.gold,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Forgot Password?',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ] else ...[
                        AuthTextField(
                          controller: _phoneCtrl,
                          hint: 'Enter your mobile number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Rate limit warning
                      if (_rateLimitSecondsLeft > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFD32F2F)),
                              const SizedBox(width: 6),
                              Text(
                                'Try again in ${_rateLimitSecondsLeft}s',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFFD32F2F),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                      ScaleButton(
                        onPressed: (_isSubmitting || _rateLimitSecondsLeft > 0) ? null : _handleLogin,
                        text: _isEmailMode ? 'Login' : 'Send OTP',
                        isLoading: _isSubmitting,
                        color: AppColors.primary,
                        textColor: Colors.white,
                        hasShadow: true,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Color(0xFFE0D8CC), thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Or login with',
                              style: GoogleFonts.inter(color: const Color(0xFFB0A090), fontSize: 13),
                            ),
                          ),
                          const Expanded(child: Divider(color: Color(0xFFE0D8CC), thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildGoogleButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'New to Mangalasutram? ',
                      style: GoogleFonts.inter(color: const Color(0xFF8B7355), fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Register Now',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildToggle() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleMode(true),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isEmailMode ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Email',
                  style: GoogleFonts.inter(
                    color: _isEmailMode ? Colors.white : const Color(0xFF8B7355),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleMode(false),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: !_isEmailMode ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Mobile',
                  style: GoogleFonts.inter(
                    color: !_isEmailMode ? Colors.white : const Color(0xFF8B7355),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0D8CC)),
      ),
      child: TextButton.icon(
        onPressed: _isSubmitting ? null : _handleGoogleSignIn,
        icon: Image.asset(
          'assets/images/google_logo.png',
          height: 22,
          width: 22,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24),
        ),
        label: Text(
          'Continue with Google',
          style: GoogleFonts.inter(
            color: const Color(0xFF3E2723),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
