import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/student_data.dart';

import 'encrypted_student_repository.dart';
import 'key_provider.dart';
import 'shared_preferences_student_repository.dart';
import 'student_repository.dart';

Future<StudentRepository> createStudentRepository() async {
  final preferences = await SharedPreferences.getInstance();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android)) {
    return EncryptedStudentRepository(
      store: SharedPreferencesLocalStore(preferences),
      keyProvider: SecureStorageKeyProvider(),
    );
  }

  // Web and unsupported desktop targets intentionally remain demo/plaintext.
  // This path does not claim equivalent protection to Keychain/Keystore.
  return SharedPreferencesStudentRepository(preferences: preferences);
}


class LazyStudentRepository implements StudentRepository {
  LazyStudentRepository(this._create);

  final Future<StudentRepository> Function() _create;
  Future<StudentRepository>? _repository;

  Future<StudentRepository> _getRepository() =>
      _repository ??= _create();

  @override
  Future<StudentData> load() async => (await _getRepository()).load();

  @override
  Future<void> save(StudentData data) async =>
      (await _getRepository()).save(data);
}
