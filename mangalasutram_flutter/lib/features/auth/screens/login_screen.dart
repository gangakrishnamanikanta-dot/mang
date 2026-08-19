import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../constants/theme.dart';
import '../../../shared/widgets/apple_scale_button.dart';
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

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final AuthService _authService = getIt<AuthService>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _toggleMode(bool isEmail) {
    if (_isEmailMode == isEmail) return;
    setState(() => _isEmailMode = isEmail);
    HapticFeedback.selectionClick();
  }

  Future<void> _handleLogin() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    if (_isEmailMode) {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();
      if (email.isEmpty || password.isEmpty) {
        _showError('Please enter email and password');
        return;
      }
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
      if (!emailRegex.hasMatch(email)) {
        _showError('Please enter a valid email address');
        return;
      }

      try {
        await SupabaseService.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (!mounted) return;
        _showSuccess('Welcome back!');
        await context.read<AuthProvider>().refreshProfile();
      } on AuthException catch (e) {
        _showError(_friendlyAuthMessage(e.message));
      } on AppException catch (e) {
        _showError(e.message);
      } catch (_) {
        _showError('Something went wrong. Please try again.');
      }
    } else {
      final phone = _phoneCtrl.text.trim();
      if (phone.isEmpty) {
        _showError('Please enter your phone number');
        return;
      }
      if (phone.length < 10) {
        _showError('Please enter a valid phone number');
        return;
      }

      try {
        await SupabaseService.client.auth.signInWithOtp(phone: phone);
        if (!mounted) return;
        _showSuccess('OTP sent to your phone!');
        Navigator.pushNamed(
          context,
          '/otp-verification',
          arguments: {'phone': phone, 'purpose': 'login'},
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
      _showSuccess('Welcome!');
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
    if (lower.contains('invalid login credentials') || lower.contains('invalid')) {
      return 'Incorrect email or password';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email first';
    }
    if (lower.contains('too many requests') || lower.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again';
    }
    if (lower.contains('user not found')) {
      return 'No account found with this email';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isSubmitting;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AuthBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.favorite_rounded, color: AppColors.gold, size: 80);
                    },
                  ),
                ),
                const SizedBox(height: 0),
                AuthCard(
                  child: Column(
                    children: [
                      _buildToggle(),
                      const SizedBox(height: 20),
                      if (_isEmailMode) ...[
                        AuthTextField(
                          controller: _emailCtrl,
                          hint: 'enter your email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _passwordCtrl,
                          hint: 'enter your password',
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
                            child: const Text('Forgot Password?', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                      ] else ...[
                        AuthTextField(
                          controller: _phoneCtrl,
                          hint: 'enter your mobile',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                      const SizedBox(height: 28),
                      AppleScaleButton(
                        onPressed: isBusy ? null : _handleLogin,
                        text: _isEmailMode ? 'Login' : 'Send OTP',
                        color: AppColors.primary,
                        textColor: Colors.white,
                        hasShadow: true,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: Divider(color: const Color(0xFFE0D8CC), thickness: 1)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Or login with', style: TextStyle(color: Color(0xFFB0A090), fontSize: 13)),
                          ),
                          Expanded(child: Divider(color: const Color(0xFFE0D8CC), thickness: 1)),
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
                    const Text("New to Mangalasutram? ", style: TextStyle(color: Color(0xFF8B7355), fontSize: 14)),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Register Now', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ],
                ),
              ],
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
                  style: TextStyle(
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
                  style: TextStyle(
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
        icon: Image.asset('assets/images/google_logo.png', height: 24, width: 24, fit: BoxFit.contain),
        label: const Text(
          'Continue with Google',
          style: TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}
