import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../constants/theme.dart';
import '../../../shared/widgets/apple_scale_button.dart';
import 'widgets/auth_background.dart';
import '../../../core/di.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../providers/auth_provider.dart';
import '../../../core/exceptions/app_exception.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final AuthService _authService = getIt<AuthService>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_isSubmitting) return;

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }
    if (email.isEmpty) {
      _showError('Please enter your email');
      return;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }
    if (password.isEmpty) {
      _showError('Please enter a password');
      return;
    }
    if (password.length < 8) {
      _showError('Password must be at least 8 characters');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final authProvider = context.read<AuthProvider>();
      authProvider.setTempPassword(password);

      final response = await SupabaseService.client.functions.invoke(
        'send-otp',
        body: {'email': email, 'purpose': 'signup'},
      );

      if (response.status != 200) {
        throw ServerException(
          response.data?['error'] ?? 'Failed to send verification code',
          'otp_error',
        );
      }

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/otp-verification',
        arguments: {'email': email, 'purpose': 'signup', 'name': name},
      );
    } on ServerException catch (e) {
      _showError(e.message);
    } on AuthException catch (e) {
      _showError(_friendlyAuthMessage(e.message));
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await _authService.signInWithGoogle();
      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();
      _showSuccess('Account created!');
    } on AuthException catch (e) {
      _showError(_friendlyAuthMessage(e.message));
    } on AppException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Google sign-up failed. Please try again.');
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
    if (lower.contains('already registered') || lower.contains('already exists')) {
      return 'This email is already registered. Try logging in instead.';
    }
    if (lower.contains('invalid') || lower.contains('bad request')) {
      return 'Please check your information and try again.';
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
                      AuthTextField(
                        controller: _nameCtrl,
                        hint: 'enter your name',
                        icon: Icons.person_outline,
                        keyboardType: TextInputType.name,
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 28),
                      AppleScaleButton(
                        onPressed: isBusy ? null : _handleRegister,
                        text: 'Register',
                        color: AppColors.primary,
                        textColor: Colors.white,
                        hasShadow: true,
                      ),
                      const SizedBox(height: 16),
                      _buildGoogleButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? ", style: TextStyle(color: Color(0xFF8B7355), fontSize: 14)),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Login', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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

  Widget _buildGoogleButton() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0D8CC)),
      ),
      child: TextButton.icon(
        onPressed: _isSubmitting ? null : _handleGoogleSignUp,
        icon: Image.asset('assets/images/google_logo.png', height: 24, width: 24, fit: BoxFit.contain),
        label: const Text(
          'Continue with Google',
          style: TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}
