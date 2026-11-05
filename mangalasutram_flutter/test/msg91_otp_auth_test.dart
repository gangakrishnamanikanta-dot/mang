import 'package:flutter_test/flutter_test.dart';
import 'package:mangalasutram/features/auth/services/msg91_otp_service.dart';

void main() {
  group('Msg91OtpService Phone Formatting & Validation Tests', () {
    final service = Msg91OtpService.instance;

    test('Canonical Indian phone number formatting handles all valid inputs', () {
      expect(service.formatIndianPhoneNumber('9876543210'), '919876543210');
      expect(service.formatIndianPhoneNumber('09876543210'), '919876543210');
      expect(service.formatIndianPhoneNumber('+919876543210'), '919876543210');
      expect(service.formatIndianPhoneNumber('+91 98765 43210'), '919876543210');
      expect(service.formatIndianPhoneNumber('+91-98765-43210'), '919876543210');
      expect(service.formatIndianPhoneNumber('919876543210'), '919876543210');
    });

    test('Rejects invalid phone numbers gracefully', () async {
      final res1 = await service.sendOtp('12345');
      expect(res1.isSuccess, isFalse);
      expect(res1.message, contains('valid 10-digit'));

      final res2 = await service.sendOtp('abcdefghij');
      expect(res2.isSuccess, isFalse);

      final res3 = await service.sendOtp('5123456789'); // Indian mobile starts with 6-9
      expect(res3.isSuccess, isFalse);
    });

    test('Verifies OTP length requirements', () async {
      final resShort = await service.verifyOtp(reqId: 'dummy_req', otp: '123');
      expect(resShort.isValid, isFalse);
      expect(resShort.message, contains('6 digits'));

      final resLong = await service.verifyOtp(reqId: 'dummy_req', otp: '1234567');
      expect(resLong.isValid, isFalse);
      expect(resLong.message, contains('6 digits'));
    });

    test('Requires valid reqId for retryOtp', () async {
      final res = await service.retryOtp(reqId: '');
      expect(res.isSuccess, isFalse);
      expect(res.message, contains('Invalid OTP session'));
    });
  });
}
