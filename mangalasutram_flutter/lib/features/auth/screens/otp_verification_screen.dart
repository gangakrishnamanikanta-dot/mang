import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../constants/theme.dart';
import '../../../shared/widgets/scale_button.dart';
import 'widgets/auth_background.dart';
import '../services/supabase_service.dart';
import '../providers/auth_provider.dart';
import '../../family/services/family_service.dart';
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
  bool _isResending = false;

  static const _resendCooldown = 60;
  int _resendSecondsLeft = _resendCooldown;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = _resendCooldown);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        t.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _clearAllOtpBoxes() {
    for (var c in _controllers) {
      c.clear();
    }
    if (_focusNodes.isNotEmpty) {
      _focusNodes[0].requestFocus();
    }
    setState(() {});
  }

  void _onPinChanged(String value, int index) {
    // 1. Handle multi-digit paste
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6; i++) {
        if (i < digits.length) {
          _controllers[i].text = digits[i];
        }
      }
      if (digits.length >= 6) {
        _focusNodes[5].requestFocus();
        _verifyOtp();
      } else if (digits.isNotEmpty) {
        _focusNodes[digits.length.clamp(0, 5)].requestFocus();
      }
      setState(() {});
      return;
    }

    // 2. Advance forward
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    // 3. Retreat backward if empty
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    // 4. Trigger verify if 6th digit entered
    if (value.isNotEmpty && index == 5) {
      final code = _getOtpCode();
      if (code.length == 6 && !_isLoading) {
        _verifyOtp();
      }
    }
    setState(() {});
  }

  String _getOtpCode() {
    return _controllers.map((c) => c.text.trim()).join();
  }

  Future<void> _verifyOtp() async {
    final otpCode = _getOtpCode();
    if (otpCode.length != 6) {
      _showError('Please enter all 6 digits of the verification code.');
      return;
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!widget.isPhone &&
        widget.purpose != 'login' &&
        !emailRegex.hasMatch(widget.contactInfo)) {
      _showError('Invalid email format');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final routeArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final welcomeName = (routeArgs?['name'] as String?)?.trim();
    final password = (routeArgs?['password'] as String?) ?? widget.password;

    final isGuardian = routeArgs?['is_guardian'] == true;
    final guardianRole = (routeArgs?['guardian_role'] as String?) ?? 'Parent';
    final familyCode = (routeArgs?['family_code'] as String?)?.trim();

    setState(() => _isLoading = true);

    try {
      if (widget.isPhone) {
        try {
          await SupabaseService.client.auth
              .verifyOTP(
                phone: widget.contactInfo,
                token: otpCode,
                type: OtpType.sms,
              )
              .timeout(const Duration(seconds: 15));
        } on AuthException catch (e) {
          _showError(_friendlyOtpMessage(e.message));
          _clearAllOtpBoxes();
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        _showSuccess('Verification successful!');
        if (mounted) await authProvider.refreshProfile();
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      // 1. Verify OTP with Supabase Edge Function
      final response = await SupabaseService.client.functions
          .invoke(
            'verify-otp',
            body: {
              'email': widget.contactInfo,
              'code': otpCode,
              'purpose': widget.purpose,
            },
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw const ServerException(
              'Verification timed out. Please check your connection.',
              'timeout',
            ),
          );

      if (response.status == 429) {
        _showError('Too many attempts. Please wait a moment.');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (response.status != 200) {
        final err =
            response.data is Map ? response.data['error']?.toString() : null;
        _showError(err ?? 'Invalid or expired verification code');
        _clearAllOtpBoxes();
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Handle Purpose: Signup
      if (widget.purpose == 'signup') {
        if (password == null || password.isEmpty) {
          _showError('Session expired. Please sign up again.');
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        try {
          AuthResponse authRes;
          try {
            authRes = await SupabaseService.client.auth.signUp(
              email: widget.contactInfo,
              password: password,
            );
          } on AuthException catch (e) {
            final msg = e.message.toLowerCase();
            if (msg.contains('already registered') ||
                msg.contains('already exists') ||
                msg.contains('user already registered')) {
              authRes = await SupabaseService.client.auth.signInWithPassword(
                email: widget.contactInfo,
                password: password,
              );
            } else {
              _showError(_friendlyAuthMessage(e.message));
              if (mounted) setState(() => _isLoading = false);
              return;
            }
          }

          final userId =
              authRes.user?.id ?? SupabaseService.client.auth.currentUser?.id;

          if (userId != null && widget.contactInfo.isNotEmpty) {
            await SupabaseService.client
                .from('profiles')
                .upsert(
                  {
                    'id': userId,
                    'email': widget.contactInfo,
                    if (welcomeName != null && welcomeName.isNotEmpty)
                      'full_name': welcomeName,
                    'account_type': isGuardian ? 'guardian' : 'candidate',
                  },
                  onConflict: 'id',
                )
                .timeout(const Duration(seconds: 10));

            // If guardian, automatically join the candidate's family circle
            if (isGuardian && familyCode != null && familyCode.isNotEmpty) {
              final joinRes = await FamilyService.instance.joinCircleWithResult(
                inviteCode: familyCode,
                role: guardianRole,
                displayName: welcomeName ?? guardianRole,
              );
              if (joinRes['success'] != true) {
                _showError(joinRes['message'] as String? ?? 'Unable to join family circle');
                if (mounted) setState(() => _isLoading = false);
                return;
              }
            }

            if (welcomeName != null && welcomeName.isNotEmpty) {
              try {
                await SupabaseService.client.functions
                    .invoke(
                      'send-email',
                      body: {
                        'to': widget.contactInfo,
                        'type': 'welcome',
                        'data': {
                          'name': welcomeName,
                          'email': widget.contactInfo,
                        },
                      },
                    )
                    .timeout(const Duration(seconds: 15));
              } catch (_) {}
            }
          }

          _showSuccess(isGuardian
              ? 'Verification successful! Welcome to your Family Circle.'
              : "Verification successful! Let's build your sacred profile.");

          if (mounted) {
            await authProvider.refreshProfile();
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }
          return;
        } on AuthException catch (e) {
          _showError(_friendlyAuthMessage(e.message));
          if (mounted) setState(() => _isLoading = false);
          return;
        } on TimeoutException {
          _showError(
              'Request timed out. Please check your connection and try again.');
          if (mounted) setState(() => _isLoading = false);
          return;
        } catch (e) {
          debugPrint('[Signup completion error]: $e');
          _showError('Failed to complete signup. Please try again.');
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      // 3. Handle Purpose: Reset Password
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
    } on ServerException catch (e) {
      _showError(e.message);
      _clearAllOtpBoxes();
    } catch (e) {
      debugPrint('[OTP Verify Error]: $e');
      _showError('Verification failed: ${e.toString()}');
      _clearAllOtpBoxes();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendSecondsLeft > 0) return;
    setState(() => _isResending = true);
    try {
      if (widget.isPhone) {
        await SupabaseService.client.auth
            .signInWithOtp(phone: widget.contactInfo)
            .timeout(const Duration(seconds: 20));
      } else {
        final response = await SupabaseService.client.functions
            .invoke(
              'send-otp',
              body: {'email': widget.contactInfo, 'purpose': widget.purpose},
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
            response.data?['error'] ?? 'Failed to resend code',
            'otp_error',
          );
        }
      }

      _startResendCooldown();

      if (mounted) {
        _showSuccess(
          widget.isPhone
              ? 'A new code has been sent to your mobile.'
              : 'A new 6-digit code has been sent to your email.',
        );
      }
    } on AuthException catch (e) {
      _showError(_friendlyOtpMessage(e.message));
    } on ServerException catch (e) {
      _showError(e.message);
    } on TimeoutException {
      _showError('Request timed out. Please check your connection.');
    } catch (_) {
      _showError('Failed to resend code. Please try again.');
    } finally {
      if (mounted) setState(() => _isResending = false);
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

  String _friendlyOtpMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('expired') || lower.contains('invalid')) {
      return 'Code expired or incorrect. Request a new one.';
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
    if (lower.contains('already registered') || lower.contains('already exists')) {
      return 'This account is already registered. Please log in.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoading || _isResending;
    final canResend = _resendSecondsLeft == 0 && !isBusy;

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
                        'Verification',
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
                const SizedBox(height: 24),
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
                        child: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(
                                  color: Color(0xFF6E1732),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(
                                Icons.mark_email_read_rounded,
                                size: 32,
                                color: AppColors.gold,
                              ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _isLoading ? 'Verifying Code...' : 'Enter 6-Digit Code',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6E1732),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          _isLoading
                              ? 'Securing your matrimonial account...'
                              : 'We have sent a verification code to\n${widget.contactInfo}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: const Color(0xFF8B7355),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // OTP 6 Boxes with keyboard listener for backspace and auto-paste
                      AutofillGroup(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            6,
                            (index) => SizedBox(
                              width: MediaQuery.of(context).size.width * 0.115,
                              height: 54,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F0E8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _controllers[index].text.isNotEmpty
                                        ? const Color(0xFF6E1732)
                                        : const Color(0xFFE0D8CC),
                                    width: _controllers[index].text.isNotEmpty
                                        ? 1.5
                                        : 1.0,
                                  ),
                                ),
                                child: Focus(
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent &&
                                        event.logicalKey ==
                                            LogicalKeyboardKey.backspace &&
                                        _controllers[index].text.isEmpty &&
                                        index > 0) {
                                      _focusNodes[index - 1].requestFocus();
                                      _controllers[index - 1].clear();
                                      setState(() {});
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: TextField(
                                    controller: _controllers[index],
                                    focusNode: _focusNodes[index],
                                    enabled: !isBusy,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    textAlignVertical: TextAlignVertical.center,
                                    autofillHints: const [
                                      AutofillHints.oneTimeCode
                                    ],
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF3E2723),
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: const InputDecoration(
                                      counterText: "",
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (val) =>
                                        _onPinChanged(val, index),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ScaleButton(
                        onPressed: isBusy ? null : _verifyOtp,
                        text: _isLoading ? 'Verifying...' : 'Verify Code',
                        isLoading: _isLoading,
                        color: AppColors.primary,
                        textColor: Colors.white,
                        hasShadow: true,
                      ),
                      const SizedBox(height: 20),
                      if (_isResending)
                        const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: AppColors.gold,
                            strokeWidth: 2,
                          ),
                        )
                      else if (_resendSecondsLeft > 0)
                        Text(
                          'Resend code in ${_resendSecondsLeft}s',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF8B7355),
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        TextButton(
                          onPressed: canResend
                              ? () {
                                  HapticFeedback.lightImpact();
                                  _resendOtp();
                                }
                              : null,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.gold,
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            "Didn't receive code? Resend",
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
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
