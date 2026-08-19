import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../constants/theme.dart';
import '../../../shared/widgets/apple_scale_button.dart';
import 'widgets/auth_background.dart';
import '../services/supabase_service.dart';
import '../providers/auth_provider.dart';
import '../../../core/exceptions/app_exception.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (_isSubmitting) return;

    final password = _passwordCtrl.text.trim();
    final confirm = _confirmPasswordCtrl.text.trim();

    if (password.isEmpty) {
      _showError('Please enter a new password');
      return;
    }
    if (password.length < 8) {
      _showError('Password must be at least 8 characters');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match');
      return;
    }

    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final email = args?['email'] as String?;
    final code = args?['code'] as String?;

    if (email == null || code == null) {
      _showError('Session expired. Please request a new code.');
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final response = await SupabaseService.client.functions.invoke(
        'reset-password',
        body: {'email': email, 'code': code, 'new_password': password},
      );

      if (response.status != 200) {
        final err = response.data?['error']?.toString();
        if (err != null && err.toLowerCase().contains('expired')) {
          _showError('Code expired. Please request a new one.');
        } else if (err != null && err.toLowerCase().contains('invalid')) {
          _showError('Invalid or expired code.');
        } else {
          _showError(err ?? 'Failed to update password. Please try again.');
        }
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      _showSuccess('Password updated! Logging you in...');

      try {
        await SupabaseService.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (!mounted) return;
        await context.read<AuthProvider>().refreshProfile();
        _showSuccess('Welcome back!');
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } on AuthException catch (e) {
        _showError('Password updated. Please log in with your new password.');
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } catch (_) {
        _showError('Password updated. Please log in with your new password.');
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (_) {
      _showError('Something went wrong. Please try again.');
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
                        'Create New Password',
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
                      Icon(Icons.shield_rounded, size: 56, color: AppColors.gold),
                      const SizedBox(height: 20),

                      const Text(
                        'Secure Your Account',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF6E1732)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your new password must be different from previous used passwords.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Color(0xFF8B7355), height: 1.5),
                      ),

                      const SizedBox(height: 32),

                      // New Password
                      AuthTextField(
                        controller: _passwordCtrl,
                        hint: 'New Password',
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

                      const SizedBox(height: 16),

                      // Confirm Password
                      AuthTextField(
                        controller: _confirmPasswordCtrl,
                        hint: 'Confirm Password',
                        icon: Icons.lock_outline,
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.gold,
                            size: 22,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Update Button
                      AppleScaleButton(
                        onPressed: isBusy ? null : _handleUpdate,
                        text: 'Update Password',
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
