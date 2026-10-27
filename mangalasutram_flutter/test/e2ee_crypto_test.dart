import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E2EE Cryptographic Engine Tests', () {
    final x25519 = X25519();
    final aesGcm = AesGcm.with256bits();

    test('X25519 ECDH Key Agreement and AES-256-GCM Encryption/Decryption', () async {
      // 1. Generate Alice & Bob Keypairs
      final aliceKeyPair = await x25519.newKeyPair();
      final bobKeyPair = await x25519.newKeyPair();

      final alicePub = await aliceKeyPair.extractPublicKey();
      final bobPub = await bobKeyPair.extractPublicKey();

      // 2. Perform ECDH on Alice device with Bob's public key
      final aliceSharedSecret = await x25519.sharedSecretKey(
        keyPair: aliceKeyPair,
        remotePublicKey: bobPub,
      );

      // 3. Perform ECDH on Bob device with Alice's public key
      final bobSharedSecret = await x25519.sharedSecretKey(
        keyPair: bobKeyPair,
        remotePublicKey: alicePub,
      );

      // 4. Derive AES-256 keys via HKDF
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
      final aliceSessionKey = await hkdf.deriveKey(
        secretKey: aliceSharedSecret,
        nonce: utf8.encode('Mangalasutram_E2EE_v1'),
      );
      final bobSessionKey = await hkdf.deriveKey(
        secretKey: bobSharedSecret,
        nonce: utf8.encode('Mangalasutram_E2EE_v1'),
      );

      // 5. Encrypt on Alice device
      const plaintext = 'Namaskaram! Our families would like to connect.';
      final secretBox = await aesGcm.encrypt(
        utf8.encode(plaintext),
        secretKey: aliceSessionKey,
      );

      final ciphertextBase64 = base64Encode(secretBox.cipherText + secretBox.mac.bytes);
      final nonceBase64 = base64Encode(secretBox.nonce);

      expect(ciphertextBase64.isNotEmpty, true);
      expect(nonceBase64.isNotEmpty, true);

      // 6. Decrypt on Bob device
      final rawCipher = base64Decode(ciphertextBase64);
      final cipherText = rawCipher.sublist(0, rawCipher.length - 16);
      final macBytes = rawCipher.sublist(rawCipher.length - 16);

      final bobSecretBox = SecretBox(
        cipherText,
        nonce: base64Decode(nonceBase64),
        mac: Mac(macBytes),
      );

      final decryptedBytes = await aesGcm.decrypt(
        bobSecretBox,
        secretKey: bobSessionKey,
      );
      final decryptedText = utf8.decode(decryptedBytes);

      expect(decryptedText, equals(plaintext));
    });
  });
}
