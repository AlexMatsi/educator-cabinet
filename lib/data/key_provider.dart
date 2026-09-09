import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyProviderException implements Exception {
  const KeyProviderException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

abstract interface class KeyProvider {
  Future<List<int>?> read();

  Future<List<int>> create();
}

class SecureStorageKeyProvider implements KeyProvider {
  SecureStorageKeyProvider({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
            aOptions: AndroidOptions(),
          );

  static const storageKey = 'student_data_encryption_key_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<List<int>?> read() async {
    try {
      final encoded = await _storage.read(key: storageKey);
      if (encoded == null) return null;
      final key = base64Decode(encoded);
      if (key.length != 32) throw const FormatException('Invalid key length');
      return key;
    } on Object catch (error) {
      throw KeyProviderException(
        'Не вдалося прочитати ключ із захищеного сховища.',
        error,
      );
    }
  }

  @override
  Future<List<int>> create() async {
    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256));
    try {
      await _storage.write(key: storageKey, value: base64Encode(key));
      final verified = await read();
      if (verified == null || !_same(verified, key)) {
        throw StateError('Secure storage did not preserve the key');
      }
      return key;
    } on KeyProviderException {
      rethrow;
    } on Object catch (error) {
      throw KeyProviderException(
        'Не вдалося зберегти ключ у захищеному сховищі.',
        error,
      );
    }
  }

  bool _same(List<int> left, List<int> right) {
    var difference = left.length ^ right.length;
    for (var index = 0; index < left.length && index < right.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}
