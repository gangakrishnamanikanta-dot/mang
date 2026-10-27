import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../constants/theme.dart';
import '../../../shared/widgets/scale_button.dart';
import 'widgets/auth_background.dart';
import '../services/supabase_service.dart';
import '../../../core/exceptions/app_exception.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetCode() async {
    if (_isSubmitting) return;

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email address');
      return;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await SupabaseService.client.functions
          .invoke(
            'send-otp',
            body: {'email': email, 'purpose': 'reset_password'},
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw const ServerException(
              'Request timed out. Please check your connection.',
              'timeout',
            ),
          );

      if (response.status != 200) {
        throw ServerException(
          response.data?['error'] ?? 'Failed to send reset code',
          'otp_error',
        );
      }

      if (!mounted) return;
      _showSuccess('Verification code sent to $email');
      Navigator.pushNamed(
        context,
        '/otp-verification',
        arguments: {'email': email, 'purpose': 'reset_password'},
      );
    } on ServerException catch (e) {
      _showError(e.message);
    } on AuthException catch (e) {
      _showError(_friendlyAuthMessage(e.message));
    } catch (_) {
      _showError('Could not send reset code. Please try again.');
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

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  String _friendlyAuthMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('user not found') || lower.contains('no user')) {
      return 'If an account exists with this email, a reset code has been sent.';
    }
    if (lower.contains('too many') || lower.contains('rate')) {
      return 'Too many attempts. Please wait and try again.';
    }
    return 'Could not send reset code. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isSubmitting;
    return Scaffold(
      body: SafeArea(
        child: AuthBackground(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF6E1732),
                        size: 20,
                      ),
                      onPressed: isBusy ? null : () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Forgot Password',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6E1732),
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 28),
                AuthCard(
                  child: Column(
                    children: [
                      Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.08),
                          border: Border.all(color: AppColors.gold, width: 1.2),
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          size: 32,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Reset Your Password',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6E1732),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Enter your registered email address to receive a secure password reset code.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: const Color(0xFF8B7355),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      AuthTextField(
                        controller: _emailCtrl,
                        hint: 'Registered Email Address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 24),
                      ScaleButton(
                        onPressed: isBusy ? null : _sendResetCode,
                        text: isBusy ? 'Sending...' : 'Send Reset Code',
                        isLoading: isBusy,
                        color: AppColors.primary,
                        textColor: Colors.white,
                        hasShadow: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
