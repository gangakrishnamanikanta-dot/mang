import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../constants/theme.dart';
import '../../../shared/widgets/scale_button.dart';
import 'widgets/auth_background.dart';
import 'widgets/password_strength_indicator.dart';
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
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _declaredAge18 = false;
  bool _isSubmitting = false;
  bool _isGuardian = false;
  String _selectedGuardianRole = 'Father';

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _familyCodeCtrl = TextEditingController();
  final AuthService _authService = getIt<AuthService>();

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _familyCodeCtrl.dispose();
    super.dispose();
  }

  void _showLegalDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF6E1732),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: const Color(0xFF4A3E39),
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: Text(
              'I Understand',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (_isSubmitting) return;

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final confirmPassword = _confirmPasswordCtrl.text.trim();

    if (name.isEmpty) {
      _showError('Please enter your full name');
      return;
    }
    if (email.isEmpty) {
      _showError('Please enter your email address');
      return;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }
    if (password.isEmpty) {
      _showError('Please enter a secure password');
      return;
    }
    if (password.length < 8) {
      _showError('Password must be at least 8 characters long');
      return;
    }
    if (password != confirmPassword) {
      _showError('Passwords do not match. Please re-check.');
      return;
    }
    if (_isGuardian) {
      final code = _familyCodeCtrl.text.trim();
      if (code.isEmpty) {
        _showError('Please enter your candidate\'s 6-character Family Code');
        return;
      }
      if (code.length < 5) {
        _showError('Please enter a valid Family Code (e.g. MANG-XXXX)');
        return;
      }
    }
    if (!_agreedToTerms) {
      _showError('Please agree to the Terms & Conditions and Privacy Policy');
      return;
    }
    if (!_declaredAge18) {
      _showError('You must be 18 years or older to register');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await SupabaseService.client.functions
          .invoke(
            'send-otp',
            body: {'email': email, 'purpose': 'signup'},
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw const ServerException(
              'Request timed out. Please check your internet connection.',
              'timeout',
            ),
          );

      if (response.status != 200) {
        throw ServerException(
          response.data?['error'] ?? 'Failed to send verification code',
          'otp_error',
        );
      }

      if (!mounted) return;
      _showSuccess('Verification code sent to $email');
      Navigator.pushNamed(
        context,
        '/otp-verification',
        arguments: {
          'email': email,
          'purpose': 'signup',
          'name': name,
          'password': password,
          'consented_at': DateTime.now().toUtc().toIso8601String(),
          'is_guardian': _isGuardian,
          'guardian_role': _selectedGuardianRole,
          'family_code': _familyCodeCtrl.text.trim().toUpperCase(),
        },
      );
    } on ServerException catch (e) {
      _showError(e.message);
    } on AuthException catch (e) {
      _showError(_friendlyAuthMessage(e.message));
    } catch (e, stackTrace) {
      debugPrint('[Signup Screen Error]: $e\n$stackTrace');
      _showError('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    if (_isSubmitting) return;
    if (!_agreedToTerms || !_declaredAge18) {
      _showError('Please accept the terms and age declaration to proceed.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _authService.signInWithGoogle();
      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();
      _showSuccess('Account created successfully!');
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
    if (lower.contains('already registered') || lower.contains('already exists')) {
      return 'This email is already registered. Please log in instead.';
    }
    if (lower.contains('invalid') || lower.contains('bad request')) {
      return 'Please check your information and try again.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final logoHeight = (screenHeight * 0.20).clamp(130.0, 190.0);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AuthBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: logoHeight,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold, width: 1.5),
                          color: AppColors.primary.withValues(alpha: 0.07),
                        ),
                        child: const Center(
                          child: Icon(Icons.auto_awesome, color: AppColors.gold, size: 32),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                AuthCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          _isGuardian ? 'Guardian Registration' : 'Create Sacred Profile',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6E1732),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Vedic Role Selector
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6EFE6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2D6C5)),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isGuardian = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !_isGuardian ? const Color(0xFF6E1732) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '👰 Candidate (Self)',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: !_isGuardian ? Colors.white : const Color(0xFF6D635B),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isGuardian = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isGuardian ? const Color(0xFF6E1732) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '🪔 Parent / Guardian',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: _isGuardian ? Colors.white : const Color(0xFF6D635B),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_isGuardian) ...[
                        // Guardian Role Picker Chips
                        Text(
                          'Your Relationship to Candidate:',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6E1732),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['Father', 'Mother', 'Brother', 'Sister', 'Relative', 'Guardian'].map((role) {
                              final isSelected = _selectedGuardianRole == role;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(
                                    role,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? Colors.white : const Color(0xFF6D635B),
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFF6E1732),
                                  backgroundColor: const Color(0xFFF7F2EB),
                                  side: BorderSide(
                                    color: isSelected ? const Color(0xFF6E1732) : const Color(0xFFE2D6C5),
                                  ),
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedGuardianRole = role);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Family Invite Code
                        AuthTextField(
                          controller: _familyCodeCtrl,
                          hint: 'Family Code (e.g. MANG-ABCD)',
                          icon: Icons.vpn_key_outlined,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Enter the 6-character code shared by your son/daughter from their Family Room.',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8C7B6E)),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      AuthTextField(
                        controller: _nameCtrl,
                        hint: _isGuardian ? 'Guardian Full Name' : 'Full Name',
                        icon: Icons.person_outline,
                        keyboardType: TextInputType.name,
                      ),
                      const SizedBox(height: 10),
                      AuthTextField(
                        controller: _emailCtrl,
                        hint: 'Email Address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 10),
                      AuthTextField(
                        controller: _passwordCtrl,
                        hint: 'Create Password',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.gold,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      PasswordStrengthIndicator(password: _passwordCtrl.text),
                      const SizedBox(height: 10),
                      AuthTextField(
                        controller: _confirmPasswordCtrl,
                        hint: 'Confirm Password',
                        icon: Icons.lock_outline,
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.gold,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Age 18+ and Terms & Conditions agreement
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreedToTerms,
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) {
                                setState(() {
                                  _agreedToTerms = val ?? false;
                                  _declaredAge18 = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'I am 18+ and agree to the ',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: const Color(0xFF4A3E39),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _showLegalDialog(
                                    'Terms & Conditions',
                                    'By creating an account on Mangalasutram, you confirm you are seeking a genuine matrimonial relationship in accordance with traditional Vedic principles. Misrepresentation, inappropriate content, harassment, or commercial use is strictly prohibited and subject to immediate account termination.',
                                  ),
                                  child: Text(
                                    'Terms',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                Text(
                                  ' & ',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: const Color(0xFF4A3E39),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _showLegalDialog(
                                    'Privacy Policy',
                                    'Mangalasutram respects your privacy. Your personal information, horoscope details, and contact numbers are protected with enterprise-grade encryption and access controls. We never sell your personal data to third parties.',
                                  ),
                                  child: Text(
                                    'Privacy',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      SizedBox(
                        height: 46,
                        child: ScaleButton(
                          onPressed: _isSubmitting ? null : _handleRegister,
                          text: 'Register',
                          isLoading: _isSubmitting,
                          color: AppColors.primary,
                          textColor: Colors.white,
                          hasShadow: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Color(0xFFE0D8CC), thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'Or register with',
                              style: GoogleFonts.inter(color: const Color(0xFFB0A090), fontSize: 13),
                            ),
                          ),
                          const Expanded(child: Divider(color: Color(0xFFE0D8CC), thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildGoogleButton(),
                    ],
                  ),
                ),
                const Spacer(flex: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: GoogleFonts.inter(color: const Color(0xFF8B7355), fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Login',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ],
    ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE0D8CC)),
      ),
      child: InkWell(
        onTap: _isSubmitting ? null : _handleGoogleSignUp,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/google_logo.png',
                height: 18,
                width: 18,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.g_mobiledata, size: 22),
              ),
              const SizedBox(width: 8),
              Text(
                'Continue with Google',
                style: GoogleFonts.inter(
                  color: const Color(0xFF3E2723),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
