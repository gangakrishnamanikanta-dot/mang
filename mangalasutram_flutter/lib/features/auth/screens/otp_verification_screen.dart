import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../constants/theme.dart';
import '../../../shared/widgets/apple_scale_button.dart';
import 'widgets/auth_background.dart';
import '../services/supabase_service.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/exceptions/app_exception.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String contactInfo;
  final String? password;
  final String purpose;
  final bool isPhone;

  const OtpVerificationScreen({
    super.key,
    required this.contactInfo,
    this.password,
    this.purpose = 'signup',
    this.isPhone = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onPinChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  String _getOtpCode() {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _verifyOtp() async {
    final otpCode = _getOtpCode();
    if (otpCode.length != 6) return;

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!widget.isPhone && widget.purpose != 'login' && !emailRegex.hasMatch(widget.contactInfo)) {
      _showError('Invalid email format');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.isPhone) {
        try {
          await SupabaseService.client.auth.verifyOTP(
            phone: widget.contactInfo,
            token: otpCode,
            type: OtpType.sms,
          );
        } on AuthException catch (e) {
          _showError(_friendlyOtpMessage(e.message));
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        _showSuccess('Verification successful!');
        if (mounted) await context.read<AuthProvider>().refreshProfile();
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      final response = await SupabaseService.client.functions.invoke(
        'verify-otp',
        body: {'email': widget.contactInfo, 'code': otpCode, 'purpose': widget.purpose},
      );

      if (response.status == 429) {
        _showError('Too many attempts. Please wait a moment.');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (response.status != 200) {
        _showError(response.data?['error']?.toString() ?? 'Invalid or expired code');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (widget.purpose == 'signup') {
        final authProvider = context.read<AuthProvider>();
        final password = authProvider.tempPassword ?? widget.password;

        if (password == null) {
          _showError('Session expired. Please sign up again.');
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        try {
          final signupResponse = await SupabaseService.client.functions.invoke(
            'signup',
            body: {'email': widget.contactInfo, 'password': password},
          );

          if (signupResponse.status != 200) {
            final err = signupResponse.data is Map
                ? signupResponse.data['error']?.toString()
                : null;
            _showError(err ?? 'Failed to create account. Please try again.');
            authProvider.clearSessionState();
            if (mounted) setState(() => _isLoading = false);
            return;
          }

          final createdUser = signupResponse.data is Map
              ? signupResponse.data['user']
              : null;
          final userId = createdUser is Map ? createdUser['id'] : null;

          if (userId != null && widget.contactInfo.isNotEmpty) {
            await SupabaseService.client.from('profiles').upsert(
              {'id': userId, 'email': widget.contactInfo},
              onConflict: 'id',
              ignoreDuplicates: true,
            );
          }

          await SupabaseService.client.auth.signInWithPassword(
            email: widget.contactInfo,
            password: password,
          );

          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final welcomeName = (args?['name'] as String?)?.trim();

          // Clear temp password and reset profile flag immediately after signup
          authProvider.clearSessionState();

          if (welcomeName != null && welcomeName.isNotEmpty) {
            try {
              await SupabaseService.client.functions.invoke(
                'send-email',
                body: {
                  'to': widget.contactInfo,
                  'type': 'welcome',
                  'data': {
                    'name': welcomeName,
                    'email': widget.contactInfo,
                  },
                },
              );
            } catch (_) {}
          }

          authProvider.clearSessionState();
        } on AuthException catch (e) {
          _showError(_friendlyAuthMessage(e.message));
          authProvider.clearSessionState();
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      if (widget.purpose == 'reset_password') {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/reset-password',
            (route) => false,
            arguments: {'email': widget.contactInfo, 'code': otpCode},
          );
        }
        return;
      }

      _showSuccess('Verification successful!');
      if (mounted) await context.read<AuthProvider>().refreshProfile();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    try {
      if (widget.isPhone) {
        await SupabaseService.client.auth.signInWithOtp(phone: widget.contactInfo);
      } else {
        final response = await SupabaseService.client.functions.invoke(
          'send-otp',
          body: {'email': widget.contactInfo, 'purpose': widget.purpose},
        );

        if (response.status != 200) {
          throw ServerException(
            response.data?['error'] ?? 'Failed to resend code',
            'otp_error',
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new code has been sent'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } on AuthException catch (e) {
      _showError(_friendlyOtpMessage(e.message));
    } catch (_) {
      _showError('Failed to resend code. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  String _friendlyOtpMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('expired') || lower.contains('invalid')) {
      return 'Code expired. Request a new one.';
    }
    if (lower.contains('too many') || lower.contains('rate')) {
      return 'Too many attempts. Please wait and try again.';
    }
    return 'Invalid code. Please try again.';
  }

  String _friendlyAuthMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid') || lower.contains('unauthorized')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email first.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
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
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Color(0xFF6E1732),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Verification',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6E1732),
                        ),
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
                      Icon(
                        Icons.mark_email_read_rounded,
                        size: 56,
                        color: AppColors.gold,
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Enter Verification Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6E1732),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'We have sent a 6-digit code to ${widget.contactInfo}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8B7355),
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // OTP Input Fields
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          6,
                          (index) => SizedBox(
                            width: MediaQuery.of(context).size.width * 0.11,
                            height: 55,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F0E8),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE0D8CC),
                                ),
                              ),
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                textAlignVertical: TextAlignVertical.center,
                                maxLength: 1,
                                style: const TextStyle(
                                  color: Color(0xFF3E2723),
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: const InputDecoration(
                                  counterText: "",
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (val) => _onPinChanged(val, index),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Verify Button
                      AppleScaleButton(
                        onPressed: _isLoading ? null : _verifyOtp,
                        text: 'Verify Account',
                        color: AppColors.primary,
                        textColor: Colors.white,
                        hasShadow: true,
                      ),

                      const SizedBox(height: 24),

                      // Resend Code
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                _resendOtp();
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.gold,
                        ),
                        child: const Text(
                          "Didn't receive the code? Resend",
                          style: TextStyle(fontSize: 14),
                        ),
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
