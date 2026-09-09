import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class EncryptedPayloadException implements Exception {
  const EncryptedPayloadException(this.kind, this.message, [this.cause]);

  final EncryptedPayloadError kind;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

enum EncryptedPayloadError { corruptEnvelope, unknownEnvelope, authentication }

abstract interface class PayloadCipher {
  Future<String> encrypt(String payload, List<int> key);

  Future<String> decrypt(String envelope, List<int> key);
}

class AesGcmPayloadCipher implements PayloadCipher {
  AesGcmPayloadCipher({AesGcm? algorithm})
    : _algorithm = algorithm ?? AesGcm.with256bits();

  static const envelopeVersion = 1;
  final AesGcm _algorithm;

  @override
  Future<String> encrypt(String payload, List<int> key) async {
    final box = await _algorithm.encrypt(
      utf8.encode(payload),
      secretKey: SecretKey(_validatedKey(key)),
    );
    return jsonEncode({
      'version': envelopeVersion,
      'algorithm': 'AES-256-GCM',
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  @override
  Future<String> decrypt(String envelope, List<int> key) async {
    late final Object? decoded;
    try {
      decoded = jsonDecode(envelope);
    } on Object catch (error) {
      throw EncryptedPayloadException(
        EncryptedPayloadError.corruptEnvelope,
        'Зашифровані дані пошкоджені.',
        error,
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const EncryptedPayloadException(
        EncryptedPayloadError.corruptEnvelope,
        'Зашифровані дані пошкоджені.',
      );
    }
    if (decoded['version'] != envelopeVersion ||
        decoded['algorithm'] != 'AES-256-GCM') {
      throw const EncryptedPayloadException(
        EncryptedPayloadError.unknownEnvelope,
        'Версія зашифрованих даних не підтримується.',
      );
    }
    try {
      final clear = await _algorithm.decrypt(
        SecretBox(
          base64Decode(decoded['ciphertext'] as String),
          nonce: base64Decode(decoded['nonce'] as String),
          mac: Mac(base64Decode(decoded['mac'] as String)),
        ),
        secretKey: SecretKey(_validatedKey(key)),
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError catch (error) {
      throw EncryptedPayloadException(
        EncryptedPayloadError.authentication,
        'Не вдалося підтвердити цілісність зашифрованих даних.',
        error,
      );
    } on EncryptedPayloadException {
      rethrow;
    } on Object catch (error) {
      throw EncryptedPayloadException(
        EncryptedPayloadError.corruptEnvelope,
        'Зашифровані дані пошкоджені.',
        error,
      );
    }
  }

  List<int> _validatedKey(List<int> key) {
    if (key.length != 32) {
      throw const EncryptedPayloadException(
        EncryptedPayloadError.authentication,
        'Ключ шифрування має некоректний формат.',
      );
    }
    return key;
  }
}
