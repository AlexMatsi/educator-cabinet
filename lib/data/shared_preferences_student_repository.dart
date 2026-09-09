import 'package:shared_preferences/shared_preferences.dart';

import '../models/student_data.dart';
import 'demo_repository.dart';
import 'student_data_codec.dart';
import 'student_repository.dart';

class StudentStorageException implements Exception {
  const StudentStorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

abstract interface class StudentLocalStore {
  String? read(String key);

  Future<bool> write(String key, String value);

  Future<bool> delete(String key);
}

class SharedPreferencesLocalStore implements StudentLocalStore {
  const SharedPreferencesLocalStore(this.preferences);

  final SharedPreferences preferences;

  @override
  String? read(String key) => preferences.getString(key);

  @override
  Future<bool> write(String key, String value) =>
      preferences.setString(key, value);

  @override
  Future<bool> delete(String key) => preferences.remove(key);
}

class SharedPreferencesStudentRepository implements StudentRepository {
  SharedPreferencesStudentRepository({required SharedPreferences? preferences})
    : _store = preferences == null
          ? null
          : SharedPreferencesLocalStore(preferences),
      _storeFactory = _defaultStoreFactory;

  SharedPreferencesStudentRepository.withStore({
    StudentLocalStore? store,
    Future<StudentLocalStore> Function()? storeFactory,
  }) : _store = store,
       _storeFactory = storeFactory ?? _defaultStoreFactory;

  static const storageKey = 'student_data';

  StudentLocalStore? _store;
  final Future<StudentLocalStore> Function() _storeFactory;
  final StudentDataCodec _codec = const StudentDataCodec();

  static Future<StudentLocalStore> _defaultStoreFactory() async =>
      SharedPreferencesLocalStore(await SharedPreferences.getInstance());

  static Future<SharedPreferencesStudentRepository> create() async =>
      SharedPreferencesStudentRepository.withStore();

  Future<StudentLocalStore> _availableStore() async {
    final current = _store;
    if (current != null) return current;
    try {
      return _store = await _storeFactory();
    } catch (error) {
      throw StudentStorageException(
        'Не вдалося відкрити локальне сховище.',
        error,
      );
    }
  }

  @override
  Future<StudentData> load() async {
    final store = await _availableStore();
    late final String? stored;
    try {
      stored = store.read(storageKey);
    } catch (error) {
      throw StudentStorageException('Не вдалося прочитати дані учнів.', error);
    }
    if (stored == null) {
      final demo = DemoRepository.data;
      await save(demo);
      return demo;
    }
    try {
      final requiresMigration = _codec.requiresMigration(stored);
      final decoded = _codec.decode(stored);
      if (requiresMigration) await save(decoded);
      return decoded;
    } on FormatException catch (error) {
      throw StudentStorageException(
        'Збережені дані учнів пошкоджені або несумісні.',
        error,
      );
    } on Object catch (error) {
      throw StudentStorageException('Не вдалося прочитати дані учнів.', error);
    }
  }

  @override
  Future<void> save(StudentData data) async {
    final store = await _availableStore();
    try {
      final saved = await store.write(storageKey, _codec.encode(data));
      if (!saved) {
        throw const StudentStorageException(
          'Локальне сховище не підтвердило запис даних.',
        );
      }
    } on StudentStorageException {
      rethrow;
    } on Object catch (error) {
      throw StudentStorageException('Не вдалося зберегти дані учнів.', error);
    }
  }
}
