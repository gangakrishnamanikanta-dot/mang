import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../auth/services/supabase_service.dart';

class E2eeCryptoService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final X25519 _x25519 = X25519();
  final AesGcm _aesGcm = AesGcm.with256bits();

  static const String _privKeyPrefix = 'e2ee_x25519_private_key_';
  static const String _pubKeyPrefix = 'e2ee_x25519_public_key_';

  SimpleKeyPair? _myKeyPair;
  final Map<String, SecretKey> _sessionKeyCache = {};

  /// Clears in-memory keys and session key cache upon sign out
  void clearKeys() {
    _myKeyPair = null;
    _sessionKeyCache.clear();
    debugPrint('[E2eeCryptoService] In-memory keys and session key cache cleared');
  }

  /// Initializes or loads local X25519 identity keypair and ensures it's published to Supabase
  Future<void> initializeKeys() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    final privKeyName = '$_privKeyPrefix$userId';
    final pubKeyName = '$_pubKeyPrefix$userId';

    try {
      // Check user-scoped key first, with fallback to legacy key
      var savedPriv = await _storage.read(key: privKeyName);
      var savedPub = await _storage.read(key: pubKeyName);

      if (savedPriv == null || savedPub == null) {
        savedPriv = await _storage.read(key: 'e2ee_x25519_private_key');
        savedPub = await _storage.read(key: 'e2ee_x25519_public_key');
        if (savedPriv != null && savedPub != null) {
          // Migrate to user-scoped key
          await _storage.write(key: privKeyName, value: savedPriv);
          await _storage.write(key: pubKeyName, value: savedPub);
        }
      }

      if (savedPriv != null && savedPub != null) {
        final privBytes = base64Decode(savedPriv);
        final pubBytes = base64Decode(savedPub);
        _myKeyPair = SimpleKeyPairData(
          privBytes,
          publicKey: SimplePublicKey(pubBytes, type: KeyPairType.x25519),
          type: KeyPairType.x25519,
        );
      } else {
        // Generate fresh X25519 keypair
        _myKeyPair = await _x25519.newKeyPair();
        final privBytes = await _myKeyPair!.extractPrivateKeyBytes();
        final pubKey = await _myKeyPair!.extractPublicKey();

        await _storage.write(key: privKeyName, value: base64Encode(privBytes));
        await _storage.write(key: pubKeyName, value: base64Encode(pubKey.bytes));
      }

      // Publish/sync public key to Supabase
      final pubKey = await _myKeyPair!.extractPublicKey();
      final pubKeyBase64 = base64Encode(pubKey.bytes);
      await SupabaseService.client.rpc('set_user_public_key', params: {
        'p_public_key': pubKeyBase64,
      });
    } catch (e) {
      debugPrint('[E2eeCryptoService] Key initialization error: $e');
    }
  }

  /// Derives a deterministic MVP room key based on the conversation ID to allow multi-device Family Room reading
  Future<SecretKey> _getRoomKey(String conversationId) async {
    if (_sessionKeyCache.containsKey(conversationId)) {
      return _sessionKeyCache[conversationId]!;
    }
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );
    final derivedKey = await hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode('Mangalasutram_MVP_Room_Secret_2026')),
      nonce: utf8.encode(conversationId),
    );
    _sessionKeyCache[conversationId] = derivedKey;
    return derivedKey;
  }

  /// Encrypts plaintext message into Base64 ciphertext and nonce using MVP Room Key
  Future<Map<String, String>> encryptMessage({
    required String conversationId,
    required String plaintext,
  }) async {
    try {
      final sessionKey = await _getRoomKey(conversationId);

      final secretBox = await _aesGcm.encrypt(
        utf8.encode(plaintext),
        secretKey: sessionKey,
      );

      final combinedCiphertext = base64Encode(secretBox.cipherText + secretBox.mac.bytes);
      final nonceBase64 = base64Encode(secretBox.nonce);

      return {
        'ciphertext': 'e2ee:$combinedCiphertext',
        'nonce': nonceBase64,
      };
    } catch (e) {
      debugPrint('[E2eeCryptoService] Encryption error: $e');
      return {'ciphertext': plaintext, 'nonce': ''};
    }
  }

  /// Decrypts Base64 ciphertext into UTF-8 plaintext using MVP Room Key
  Future<String> decryptMessage({
    required String conversationId,
    required String ciphertext,
    required String nonce,
  }) async {
    if (!ciphertext.startsWith('e2ee:') || nonce.isEmpty) {
      return ciphertext; // Return raw text for system notifications / unencrypted legacy rows
    }

    try {
      final sessionKey = await _getRoomKey(conversationId);

      final rawCipher = ciphertext.substring(5);
      final cipherWithMac = base64Decode(rawCipher);
      final nonceBytes = base64Decode(nonce);

      if (cipherWithMac.length < 16) {
        return '🔒 [Corrupted Message]';
      }

      final cipherText = cipherWithMac.sublist(0, cipherWithMac.length - 16);
      final macBytes = cipherWithMac.sublist(cipherWithMac.length - 16);

      final secretBox = SecretBox(
        cipherText,
        nonce: nonceBytes,
        mac: Mac(macBytes),
      );

      final decryptedBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: sessionKey,
      );

      return utf8.decode(decryptedBytes);
    } catch (e) {
      debugPrint('[E2eeCryptoService] Decryption error from $conversationId: $e');
      return '🔒 [Encrypted Message]';
    }
  }
}
