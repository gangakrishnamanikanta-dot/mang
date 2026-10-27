import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/supabase_service.dart';

/// Masks an FCM registration token to prevent sensitive credential leakage in logs.
/// Example: 'fcm_12345678abcdef...9999' -> 'fcm_1234...9999'
String maskFcmToken(String? token) {
  if (token == null || token.length < 12) return '***';
  return '${token.substring(0, 8)}...${token.substring(token.length - 4)}';
}

/// Abstract contract for device token lifecycle management via secure RPCs
abstract class DeviceTokenService {
  Future<String?> registerToken({
    required String fcmToken,
    required String platform,
    Map<String, dynamic>? deviceInfo,
  });

  Future<bool> removeToken({required String fcmToken});
}

/// Supabase RPC implementation of DeviceTokenService.
/// Note: Table public.device_tokens has zero direct client privileges (42501).
/// All mutations are strictly mediated through register_device_token and remove_device_token RPCs.
class SupabaseDeviceTokenService implements DeviceTokenService {
  final SupabaseClient? _clientOverride;
  String? _lastRegisteredToken;
  String? _lastRegisteredUserId;

  SupabaseDeviceTokenService({SupabaseClient? client})
      : _clientOverride = client;

  SupabaseClient get _client => _clientOverride ?? SupabaseService.client;

  @override
  Future<String?> registerToken({
    required String fcmToken,
    required String platform,
    Map<String, dynamic>? deviceInfo,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('[DeviceTokenService] Cannot register token: user is not authenticated.');
      return null;
    }

    // Avoid redundant duplicate RPC registration if already registered for this user
    if (_lastRegisteredToken == fcmToken && _lastRegisteredUserId == user.id) {
      debugPrint('[DeviceTokenService] Token ${maskFcmToken(fcmToken)} already registered for user ${user.id}.');
      return 'cached';
    }

    final cleanToken = fcmToken.trim();
    if (cleanToken.length < 32 || cleanToken.length > 512) {
      debugPrint('[DeviceTokenService] Invalid FCM token string length.');
      return null;
    }

    final cleanPlatform = platform.toLowerCase().trim();
    if (!['android', 'ios', 'web'].contains(cleanPlatform)) {
      debugPrint('[DeviceTokenService] Unsupported device platform: $cleanPlatform');
      return null;
    }

    try {
      final response = await _client.rpc(
        'register_device_token',
        params: {
          'p_fcm_token': cleanToken,
          'p_platform': cleanPlatform,
          'p_device_info': deviceInfo ?? {},
        },
      );

      final tokenId = response as String?;
      if (tokenId != null && tokenId.isNotEmpty) {
        _lastRegisteredToken = cleanToken;
        _lastRegisteredUserId = user.id;
        debugPrint('[DeviceTokenService] Successfully registered token ${maskFcmToken(cleanToken)} for user ${user.id} (Token ID: $tokenId).');
        return tokenId;
      }
      return null;
    } on PostgrestException catch (e) {
      // Handle undeployed migration gracefully (function not found 42883 or relation missing 42P01)
      if (e.code == '42883' || e.code == '42P01') {
        debugPrint('[DeviceTokenService] Backend migration 20261014000002 not yet deployed. Token registration staged safely: ${maskFcmToken(cleanToken)}.');
        return null;
      }
      debugPrint('[DeviceTokenService] PostgrestException during register_device_token: ${e.message} (${e.code})');
      return null;
    } catch (e) {
      debugPrint('[DeviceTokenService] Unexpected error during token registration: $e');
      return null;
    }
  }

  @override
  Future<bool> removeToken({required String fcmToken}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('[DeviceTokenService] Cannot remove token: user is signed out.');
      return false;
    }

    final cleanToken = fcmToken.trim();
    if (cleanToken.isEmpty) return false;

    try {
      final response = await _client.rpc(
        'remove_device_token',
        params: {
          'p_fcm_token': cleanToken,
        },
      );

      final success = response == true;
      if (success) {
        if (_lastRegisteredToken == cleanToken) {
          _lastRegisteredToken = null;
          _lastRegisteredUserId = null;
        }
        debugPrint('[DeviceTokenService] Successfully removed token ${maskFcmToken(cleanToken)}.');
      }
      return success;
    } on PostgrestException catch (e) {
      if (e.code == '42883' || e.code == '42P01') {
        debugPrint('[DeviceTokenService] Backend migration not yet deployed. Token removal skipped safely: ${maskFcmToken(cleanToken)}.');
        return false;
      }
      debugPrint('[DeviceTokenService] Error during remove_device_token: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[DeviceTokenService] Unexpected error removing token: $e');
      return false;
    }
  }
}
