import 'dart:io';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => message;

  /// Safe factory mapping to translate generic/technical exceptions into safe AppExceptions
  factory AppException.from(dynamic e) {
    if (e is AppException) return e;

    if (e is SocketException || e is TimeoutException) {
      return const NetworkException(
        'Unable to connect. Please check your internet connection and try again.',
      );
    }

    if (e is AuthException) {
      return AppAuthException(e.message);
    }

    if (e is PostgrestException) {
      if (e.code == '23505') {
        return const ServerException(
          'This record already exists. Please try again or check your input.',
          'duplicate',
        );
      }
      if (e.code == '42501') {
        return const AppAuthException(
          'You don\'t have permission to perform this action.',
        );
      }
      return const ServerException(
        'Something went wrong. Please try again.',
        'db_error',
      );
    }

    // Generic safe fallback
    return const ServerException(
      'Something went wrong. Please try again.',
      'unknown_error',
    );
  }
}

class NetworkException extends AppException {
  const NetworkException([String message = 'Network connection failed.'])
    : super(message, 'network_error');
}

class AppAuthException extends AppException {
  const AppAuthException([String message = 'Authentication failed.'])
    : super(message, 'auth_error');
}

class ValidationException extends AppException {
  const ValidationException([
    String message = 'Please check the information entered.',
  ]) : super(message, 'validation_error');
}

class ServerException extends AppException {
  const ServerException([
    super.message = 'A server error occurred.',
    super.code = 'server_error',
  ]);
}
