import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../config/env.dart';

class SecureLocalStorage extends LocalStorage {
  static const _sessionKey = 'supabase_secure_session_key';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => await _storage.containsKey(key: _sessionKey);

  @override
  Future<String?> accessToken() async => await _storage.read(key: _sessionKey);

  @override
  Future<void> removePersistedSession() async => await _storage.delete(key: _sessionKey);

  @override
  Future<void> persistSession(String value) async => await _storage.write(key: _sessionKey, value: value);
}

class SupabaseService {
  static Future<void> initialize() async {
    Env.validate();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureLocalStorage(),
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
