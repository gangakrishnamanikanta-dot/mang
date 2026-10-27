import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../constants/theme.dart';
import '../../../shared/widgets/scale_button.dart';
import 'widgets/auth_background.dart';
import 'widgets/password_strength_indicator.dart';
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
  void initState() {
    super.initState();
    _passwordCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

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

    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final email = args?['email'] as String?;
    final code = args?['code'] as String?;

    if (email == null || code == null) {
      _showError('Session expired. Please request a new code.');
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final response = await SupabaseService.client.functions
          .invoke(
            'reset-password',
            body: {'email': email, 'code': code, 'new_password': password},
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw const ServerException(
              'Request timed out. Please check your connection.',
              'timeout',
            ),
          );

      if (response.status != 200) {
        final err = response.data?['error']?.toString();
        if (err != null && err.toLowerCase().contains('expired')) {
          _showError('Verification code expired. Please request a new one.');
        } else if (err != null && err.toLowerCase().contains('invalid')) {
          _showError('Invalid verification code.');
        } else {
          _showError(err ?? 'Failed to update password. Please try again.');
        }
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      _showSuccess('Password updated successfully! Logging you in...');

      try {
        await SupabaseService.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (!mounted) return;
        await context.read<AuthProvider>().refreshProfile();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
        }
      } catch (_) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      }
    } on ServerException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Something went wrong. Please try again.');
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
                        'Set New Password',
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
                          Icons.shield_rounded,
                          size: 32,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Secure Your Account',
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
                          'Your new password must be at least 8 characters and different from previous passwords.',
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
                        controller: _passwordCtrl,
                        hint: 'New Password',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.gold,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      PasswordStrengthIndicator(password: _passwordCtrl.text),
                      const SizedBox(height: 14),
                      AuthTextField(
                        controller: _confirmPasswordCtrl,
                        hint: 'Confirm New Password',
                        icon: Icons.lock_outline,
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.gold,
                            size: 20,
                          ),
                          onPressed: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                        ),
                      ),
                      const SizedBox(height: 28),
                      ScaleButton(
                        onPressed: isBusy ? null : _handleUpdate,
                        text: isBusy ? 'Updating...' : 'Update Password',
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
