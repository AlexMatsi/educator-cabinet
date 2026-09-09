import '../models/student_data.dart';
import 'demo_repository.dart';
import 'encrypted_payload_cipher.dart';
import 'key_provider.dart';
import 'shared_preferences_student_repository.dart';
import 'student_data_codec.dart';
import 'student_repository.dart';

class EncryptedStudentRepository implements StudentRepository {
  EncryptedStudentRepository({
    required StudentLocalStore store,
    required KeyProvider keyProvider,
    PayloadCipher? cipher,
  }) : _store = store,
       _keyProvider = keyProvider,
       _cipher = cipher ?? AesGcmPayloadCipher();

  static const encryptedStorageKey = 'student_data_encrypted';
  static const plaintextStorageKey =
      SharedPreferencesStudentRepository.storageKey;

  final StudentLocalStore _store;
  final KeyProvider _keyProvider;
  final PayloadCipher _cipher;
  final StudentDataCodec _codec = const StudentDataCodec();

  @override
  Future<StudentData> load() async {
    final encrypted = _read(encryptedStorageKey);
    final plaintext = _read(plaintextStorageKey);
    if (encrypted != null) return _decryptDocument(encrypted);
    if (plaintext != null) return _migrate(plaintext);

    final key = await _createKey();
    await _writeEncrypted(DemoRepository.data, key);
    return DemoRepository.data;
  }

  @override
  Future<void> save(StudentData data) async {
    final key = await _requiredKey();
    await _writeEncrypted(data, key);
  }

  Future<StudentData> _decryptDocument(String envelope) async {
    final key = await _requiredKey();
    try {
      return _codec.decode(await _cipher.decrypt(envelope, key));
    } on EncryptedPayloadException catch (error) {
      throw StudentStorageException(error.message, error);
    } on FormatException catch (error) {
      throw StudentStorageException(
        'Розшифровані дані учнів пошкоджені або несумісні.',
        error,
      );
    }
  }

  Future<StudentData> _migrate(String plaintext) async {
    late final StudentData data;
    try {
      data = _codec.decode(plaintext);
    } on Object catch (error) {
      throw StudentStorageException(
        'Збережені дані учнів пошкоджені або несумісні.',
        error,
      );
    }
    final key = await _optionalKey() ?? await _createKey();
    await _writeEncrypted(data, key);
    final written = _read(encryptedStorageKey);
    if (written == null) {
      throw const StudentStorageException(
        'Не вдалося перевірити запис зашифрованих даних.',
      );
    }
    final verified = await _decryptDocument(written);
    if (_codec.encode(verified) != _codec.encode(data)) {
      throw const StudentStorageException(
        'Перевірка зашифрованих даних після міграції не вдалася.',
      );
    }
    try {
      final deleted = await _store.delete(plaintextStorageKey);
      if (!deleted) {
        throw const StudentStorageException(
          'Не вдалося видалити незашифровану копію після міграції.',
        );
      }
    } on StudentStorageException {
      rethrow;
    } on Object catch (error) {
      throw StudentStorageException(
        'Не вдалося видалити незашифровану копію після міграції.',
        error,
      );
    }
    return verified;
  }

  String? _read(String key) {
    try {
      return _store.read(key);
    } on Object catch (error) {
      throw StudentStorageException('Не вдалося прочитати дані учнів.', error);
    }
  }

  Future<List<int>> _requiredKey() async {
    final key = await _optionalKey();
    if (key == null) {
      throw const StudentStorageException(
        'Ключ шифрування втрачено. Збережені дані неможливо відкрити.',
      );
    }
    return key;
  }

  Future<List<int>?> _optionalKey() async {
    try {
      return await _keyProvider.read();
    } on KeyProviderException catch (error) {
      throw StudentStorageException(error.message, error);
    }
  }

  Future<List<int>> _createKey() async {
    try {
      return await _keyProvider.create();
    } on KeyProviderException catch (error) {
      throw StudentStorageException(error.message, error);
    }
  }

  Future<void> _writeEncrypted(StudentData data, List<int> key) async {
    try {
      final envelope = await _cipher.encrypt(_codec.encode(data), key);
      if (!await _store.write(encryptedStorageKey, envelope)) {
        throw const StudentStorageException(
          'Локальне сховище не підтвердило запис зашифрованих даних.',
        );
      }
    } on StudentStorageException {
      rethrow;
    } on Object catch (error) {
      throw StudentStorageException(
        'Не вдалося зберегти зашифровані дані учнів.',
        error,
      );
    }
  }
}
