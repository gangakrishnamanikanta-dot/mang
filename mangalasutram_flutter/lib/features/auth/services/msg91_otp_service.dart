import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Response models for MSG91 OTP interactions
class Msg91OtpResult {
  final bool isSuccess;
  final String? reqId;
  final String message;

  const Msg91OtpResult({
    required this.isSuccess,
    this.reqId,
    required this.message,
  });
}

class Msg91VerifyResult {
  final bool isValid;
  final String message;
  final String? token;

  const Msg91VerifyResult({
    required this.isValid,
    required this.message,
    this.token,
  });
}

/// Enterprise-grade MSG91 Phone Auth Service
/// Routes all OTP dispatch, retry, and verification through the secure
/// Supabase Edge Function ('phone-auth') to keep API master secrets protected
/// and strictly enforce server-side rate-limiting.
class Msg91OtpService {
  Msg91OtpService._();
  static final Msg91OtpService instance = Msg91OtpService._();

  /// Sanitizes phone numbers into canonical Indian format: 91XXXXXXXXXX
  String formatIndianPhoneNumber(String rawPhone) {
    String clean = rawPhone.replaceAll(RegExp(r'[\s\-()+]'), '');
    if (clean.startsWith('0')) clean = clean.substring(1);
    if (clean.startsWith('91') && clean.length == 12) {
      return clean;
    }
    if (clean.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) {
      return '91$clean';
    }
    return clean;
  }

  /// Extracts 10-digit canonical mobile number from any format
  String getClean10Digit(String rawPhone) {
    final formatted = formatIndianPhoneNumber(rawPhone);
    if (formatted.startsWith('91') && formatted.length == 12) {
      return formatted.substring(2);
    }
    return formatted;
  }

  /// Sends 6-digit SMS OTP via the secure server-side phone-auth Edge Function
  Future<Msg91OtpResult> sendOtp(String phone) async {
    final cleanPhone = getClean10Digit(phone);
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleanPhone)) {
      return const Msg91OtpResult(
        isSuccess: false,
        message: 'Please enter a valid 10-digit Indian mobile number.',
      );
    }

    try {
      final res = await SupabaseService.client.functions
          .invoke(
            'phone-auth',
            body: {
              'action': 'send',
              'phone': cleanPhone,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (res.status == 429) {
        final err = res.data is Map ? res.data['error']?.toString() : null;
        return Msg91OtpResult(
          isSuccess: false,
          message: err ?? 'Too many OTP requests. Please wait a moment.',
        );
      }

      if (res.status != 200 || res.data == null) {
        final err = res.data is Map ? res.data['error']?.toString() : null;
        return Msg91OtpResult(
          isSuccess: false,
          message: err ?? 'Failed to deliver SMS OTP. Please try again.',
        );
      }

      final data = res.data is Map ? res.data as Map : {};
      final reqId = data['reqId']?.toString();
      final msg = data['message']?.toString() ?? 'OTP sent successfully via SMS.';

      return Msg91OtpResult(
        isSuccess: true,
        reqId: reqId,
        message: msg,
      );
    } on TimeoutException {
      return const Msg91OtpResult(
        isSuccess: false,
        message: 'SMS request timed out. Please check your internet connection.',
      );
    } on SocketException {
      return const Msg91OtpResult(
        isSuccess: false,
        message: 'Cannot reach server. Please check your internet connection.',
      );
    } catch (e) {
      debugPrint('[Msg91OtpService.sendOtp error]: $e');
      return Msg91OtpResult(
        isSuccess: false,
        message: 'Failed to dispatch SMS OTP: ${e.toString()}',
      );
    }
  }

  /// Resends / retries OTP on SMS channel via the secure server-side Edge Function
  Future<Msg91OtpResult> retryOtp({
    required String reqId,
    String? phone,
    int retryChannel = 11, // 11 = SMS
  }) async {
    if (reqId.isEmpty) {
      return const Msg91OtpResult(
        isSuccess: false,
        message: 'Invalid OTP session. Please request a new code.',
      );
    }

    try {
      final res = await SupabaseService.client.functions
          .invoke(
            'phone-auth',
            body: {
              'action': 'resend',
              'reqId': reqId,
              'phone': phone != null ? getClean10Digit(phone) : '9999999999',
              'retryChannel': retryChannel,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (res.status != 200 || res.data == null) {
        final err = res.data is Map ? res.data['error']?.toString() : null;
        return Msg91OtpResult(
          isSuccess: false,
          message: err ?? 'Resend failed. Please request a new OTP.',
        );
      }

      final data = res.data is Map ? res.data as Map : {};
      return Msg91OtpResult(
        isSuccess: true,
        reqId: data['reqId']?.toString() ?? reqId,
        message: data['message']?.toString() ?? 'OTP resent successfully.',
      );
    } on TimeoutException {
      return const Msg91OtpResult(
        isSuccess: false,
        message: 'Resend request timed out. Please check your connection.',
      );
    } on SocketException {
      return const Msg91OtpResult(
        isSuccess: false,
        message: 'Cannot connect to server. Please check your connection.',
      );
    } catch (e) {
      debugPrint('[Msg91OtpService.retryOtp error]: $e');
      return Msg91OtpResult(
        isSuccess: false,
        message: 'Resend failed: ${e.toString()}',
      );
    }
  }

  /// Verifies 6-digit OTP code against MSG91 widget session
  Future<Msg91VerifyResult> verifyOtp({
    required String reqId,
    required String otp,
    String? phone,
  }) async {
    final cleanOtp = otp.trim();
    if (cleanOtp.length != 6) {
      return const Msg91VerifyResult(
        isValid: false,
        message: 'Please enter all 6 digits of the OTP.',
      );
    }

    try {
      final res = await SupabaseService.client.functions
          .invoke(
            'phone-auth',
            body: {
              'action': 'verify',
              'reqId': reqId,
              'otp': cleanOtp,
              'phone': phone != null ? getClean10Digit(phone) : '9999999999',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (res.status == 429) {
        return const Msg91VerifyResult(
          isValid: false,
          message: 'Too many attempts. Please wait 10 minutes before retrying.',
        );
      }

      if (res.status != 200 || res.data == null) {
        final err = res.data is Map ? res.data['error']?.toString() : null;
        return Msg91VerifyResult(
          isValid: false,
          message: err ?? 'Invalid or expired OTP. Please try again.',
        );
      }

      final data = res.data is Map ? res.data as Map : {};
      final token = data['token']?.toString();

      return Msg91VerifyResult(
        isValid: true,
        message: 'OTP verified successfully.',
        token: token,
      );
    } on TimeoutException {
      return const Msg91VerifyResult(
        isValid: false,
        message: 'Verification request timed out. Please check your connection.',
      );
    } on SocketException {
      return const Msg91VerifyResult(
        isValid: false,
        message: 'Network error. Please check your internet connection.',
      );
    } catch (e) {
      debugPrint('[Msg91OtpService.verifyOtp error]: $e');
      return Msg91VerifyResult(
        isValid: false,
        message: 'Verification failed: ${e.toString()}',
      );
    }
  }
}
