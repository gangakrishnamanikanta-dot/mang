import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../config/env.dart';

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

/// Enterprise-grade MSG91 OTP Widget (v5) Service
/// Directly handles mobile widget routing, redirect resolution, retry and verification.
class Msg91OtpService {
  Msg91OtpService._();
  static final Msg91OtpService instance = Msg91OtpService._();

  static const String _sendOtpUrl =
      'https://control.msg91.com/api/v5/widget/sendOtpMobile';
  static const String _retryOtpUrl =
      'https://control.msg91.com/api/v5/widget/retryOtp';
  static const String _verifyOtpUrl =
      'https://control.msg91.com/api/v5/widget/verifyOtp';

  String get _widgetId => Env.msg91WidgetId;
  String get _tokenAuth => Env.msg91AuthToken;

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

  /// Sends 6-digit SMS OTP via MSG91 Mobile Widget
  Future<Msg91OtpResult> sendOtp(String phone) async {
    final identifier = formatIndianPhoneNumber(phone);
    if (!RegExp(r'^91[6-9]\d{9}$').hasMatch(identifier)) {
      return const Msg91OtpResult(
        isSuccess: false,
        message: 'Please enter a valid 10-digit Indian mobile number.',
      );
    }

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse(_sendOtpUrl);
      final request = await client.postUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final payload = jsonEncode({
        'widgetId': _widgetId,
        'tokenAuth': _tokenAuth,
        'identifier': identifier,
      });
      request.write(payload);

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      // Check for 302 Redirect to otpwidget.msg91.com
      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectLocation = response.headers.value(HttpHeaders.locationHeader);
        if (redirectLocation != null && redirectLocation.isNotEmpty) {
          final redirectUri = Uri.parse(redirectLocation);
          final redirectReq = await client.getUrl(redirectUri);
          final redirectRes = await redirectReq.close();
          final redirectBody = await redirectRes.transform(utf8.decoder).join();
          return _parseOtpResponse(redirectRes.statusCode, redirectBody);
        }
      }

      return _parseOtpResponse(response.statusCode, body);
    } on SocketException {
      return const Msg91OtpResult(
        isSuccess: false,
        message: 'Cannot reach SMS server. Please check your internet connection.',
      );
    } catch (e) {
      debugPrint('[Msg91OtpService.sendOtp error]: $e');
      return Msg91OtpResult(
        isSuccess: false,
        message: 'Failed to deliver SMS OTP: ${e.toString()}',
      );
    } finally {
      client?.close();
    }
  }

  /// Resends / retries OTP on SMS channel
  Future<Msg91OtpResult> retryOtp({
    required String reqId,
    int retryChannel = 11, // 11 = SMS
  }) async {
    if (reqId.isEmpty) {
      return const Msg91OtpResult(
        isSuccess: false,
        message: 'Invalid OTP session. Please request a new code.',
      );
    }

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse(_retryOtpUrl);
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final payload = jsonEncode({
        'widgetId': _widgetId,
        'tokenAuth': _tokenAuth,
        'reqId': reqId,
        'retryChannel': retryChannel,
      });
      request.write(payload);

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      return _parseOtpResponse(response.statusCode, body);
    } on SocketException {
      return const Msg91OtpResult(
        isSuccess: false,
        message: 'Cannot connect to SMS server. Please check your connection.',
      );
    } catch (e) {
      debugPrint('[Msg91OtpService.retryOtp error]: $e');
      return Msg91OtpResult(
        isSuccess: false,
        message: 'Resend failed: ${e.toString()}',
      );
    } finally {
      client?.close();
    }
  }

  /// Verifies 6-digit OTP code against MSG91 widget session
  Future<Msg91VerifyResult> verifyOtp({
    required String reqId,
    required String otp,
  }) async {
    final cleanOtp = otp.trim();
    if (cleanOtp.length != 6) {
      return const Msg91VerifyResult(
        isValid: false,
        message: 'Please enter all 6 digits of the OTP.',
      );
    }

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse(_verifyOtpUrl);
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final payload = jsonEncode({
        'widgetId': _widgetId,
        'tokenAuth': _tokenAuth,
        'reqId': reqId,
        'otp': cleanOtp,
      });
      request.write(payload);

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      try {
        final data = jsonDecode(body) as Map<String, dynamic>;
        final type = data['type']?.toString().toLowerCase();
        final message = data['message']?.toString() ?? '';

        if (type == 'success' || message.toLowerCase().contains('success')) {
          return Msg91VerifyResult(
            isValid: true,
            message: 'OTP verified successfully.',
            token: data['jwtToken']?.toString() ?? message,
          );
        } else {
          return Msg91VerifyResult(
            isValid: false,
            message: message.isNotEmpty ? message : 'Invalid or expired OTP.',
          );
        }
      } catch (_) {
        if (response.statusCode == 200) {
          return const Msg91VerifyResult(
            isValid: true,
            message: 'OTP verified successfully.',
          );
        }
        return Msg91VerifyResult(
          isValid: false,
          message: 'Verification failed with status ${response.statusCode}.',
        );
      }
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
    } finally {
      client?.close();
    }
  }

  Msg91OtpResult _parseOtpResponse(int statusCode, String rawBody) {
    try {
      final json = jsonDecode(rawBody) as Map<String, dynamic>;
      final type = json['type']?.toString().toLowerCase();
      final message = json['message']?.toString() ?? '';

      if (type == 'success' || statusCode == 200) {
        return Msg91OtpResult(
          isSuccess: true,
          reqId: message.isNotEmpty ? message : null,
          message: 'OTP sent successfully via SMS.',
        );
      } else {
        return Msg91OtpResult(
          isSuccess: false,
          message: message.isNotEmpty ? message : 'Failed to send OTP.',
        );
      }
    } catch (_) {
      if (statusCode == 200) {
        return const Msg91OtpResult(
          isSuccess: true,
          message: 'OTP sent successfully.',
        );
      }
      return Msg91OtpResult(
        isSuccess: false,
        message: 'SMS provider responded with HTTP $statusCode.',
      );
    }
  }
}
