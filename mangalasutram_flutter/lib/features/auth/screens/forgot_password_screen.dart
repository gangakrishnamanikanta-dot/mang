import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../constants/theme.dart';
import '../../../shared/widgets/apple_scale_button.dart';
import 'widgets/auth_background.dart';
import '../services/supabase_service.dart';
import 'package:provider/provider.dart';
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
      _showError('Please enter your email');
      return;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.client.functions.invoke(
        'send-otp',
        body: {'email': email, 'purpose': 'reset_password'},
      );

      if (!mounted) return;
      _showSuccess('Check your inbox for the reset code');
      Navigator.pushNamed(
        context,
        '/otp-verification',
        arguments: {'email': email, 'purpose': 'reset_password'},
      );
    } on AuthException catch (e) {
      _showError(_friendlyAuthMessage(e.message));
    } catch (_) {
      _showError('Could not send code. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFD32F2F)),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF2E7D32)),
    );
  }

  String _friendlyAuthMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('user not found') || lower.contains('no user')) {
      return 'No account found with this email.';
    }
    if (lower.contains('too many') || lower.contains('rate')) {
      return 'Too many attempts. Please wait and try again.';
    }
    return 'Could not send code. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isSubmitting;
    return Scaffold(
      body: SafeArea(
        child: AuthBackground(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Back Button & Title
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF6E1732)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Forgot Password',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF6E1732)),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),

                const SizedBox(height: 32),

                // White Card
                AuthCard(
                  child: Column(
                    children: [
                      Icon(Icons.lock_reset_rounded, size: 56, color: AppColors.gold),
                      const SizedBox(height: 20),

                      const Text(
                        'Reset Your Password',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF6E1732)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your registered email. We will send you a verification code to reset your password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Color(0xFF8B7355), height: 1.5),
                      ),
                      const SizedBox(height: 24),

                      AuthTextField(
                        controller: _emailCtrl,
                        hint: 'enter your email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 24),

                      AppleScaleButton(
                        onPressed: isBusy ? null : _sendResetCode,
                        text: 'Send Code',
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
