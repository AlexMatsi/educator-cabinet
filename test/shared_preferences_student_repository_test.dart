import 'dart:convert';

import 'package:educator_cabinet/data/demo_repository.dart';
import 'package:educator_cabinet/data/shared_preferences_student_repository.dart';
import 'package:educator_cabinet/data/student_data_codec.dart';
import 'package:educator_cabinet/models/student_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeStore implements StudentLocalStore {
  FakeStore({
    this.value,
    this.readError,
    this.writeError,
    this.writeResult = true,
  });

  String? value;
  Object? readError;
  Object? writeError;
  bool writeResult;
  int writes = 0;

  @override
  String? read(String key) {
    if (readError case final error?) throw error;
    return value;
  }

  @override
  Future<bool> write(String key, String value) async {
    writes++;
    if (writeError case final error?) throw error;
    if (writeResult) this.value = value;
    return writeResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const codec = StudentDataCodec();

  test('preferences preserve edited and empty data after reopening', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final first = SharedPreferencesStudentRepository(preferences: preferences);
    await first.load();
    final edited = StudentData(
      classes: DemoRepository.classes,
      students: [DemoRepository.students.first],
    );
    await first.save(edited);
    await preferences.reload();
    final reopened = SharedPreferencesStudentRepository(
      preferences: preferences,
    );
    expect(codec.encode(await reopened.load()), codec.encode(edited));
    await reopened.save(const StudentData.empty());
    await preferences.reload();
    final empty = SharedPreferencesStudentRepository(preferences: preferences);
    expect((await empty.load()).students, isEmpty);
    expect((await empty.load()).classes, isEmpty);
  });

  test('saved data is read back unchanged', () async {
    final store = FakeStore();
    final repository = SharedPreferencesStudentRepository.withStore(
      store: store,
    );
    await repository.save(DemoRepository.data);

    expect(
      codec.encode(await repository.load()),
      codec.encode(DemoRepository.data),
    );
  });

  test('legacy schema is persisted as version 2 after loading', () async {
    final legacy = jsonDecode(codec.encode(DemoRepository.data));
    legacy['schemaVersion'] = 1;
    for (final item in legacy['classes'] as List) {
      (item as Map).remove('archivedAt');
    }
    for (final item in legacy['students'] as List) {
      (item as Map).remove('archivedAt');
    }
    final store = FakeStore(value: jsonEncode(legacy));
    final repository = SharedPreferencesStudentRepository.withStore(
      store: store,
    );

    final loaded = await repository.load();

    expect(loaded.students, hasLength(DemoRepository.students.length));
    expect(store.writes, 1);
    expect(jsonDecode(store.value!)['schemaVersion'], 2);
  });

  test('an absent document is seeded once', () async {
    final store = FakeStore();
    final repository = SharedPreferencesStudentRepository.withStore(
      store: store,
    );

    expect((await repository.load()).students, hasLength(6));
    expect(store.writes, 1);
    await repository.load();
    expect(store.writes, 1);
  });

  test('saved empty data is not seeded', () async {
    final store = FakeStore(value: codec.encode(const StudentData.empty()));
    final repository = SharedPreferencesStudentRepository.withStore(
      store: store,
    );

    final loaded = await repository.load();

    expect(loaded.students, isEmpty);
    expect(loaded.classes, isEmpty);
    expect(store.writes, 0);
  });

  test('read exception is reported', () async {
    final repository = SharedPreferencesStudentRepository.withStore(
      store: FakeStore(readError: StateError('unavailable')),
    );

    await expectLater(
      repository.load(),
      throwsA(isA<StudentStorageException>()),
    );
  });

  test('write exception and false result are reported', () async {
    final throwing = SharedPreferencesStudentRepository.withStore(
      store: FakeStore(writeError: StateError('full')),
    );
    final rejecting = SharedPreferencesStudentRepository.withStore(
      store: FakeStore(writeResult: false),
    );

    await expectLater(
      throwing.save(DemoRepository.data),
      throwsA(isA<StudentStorageException>()),
    );
    await expectLater(
      rejecting.save(DemoRepository.data),
      throwsA(isA<StudentStorageException>()),
    );
  });

  test('failed initial seed is not returned as loaded data', () async {
    final repository = SharedPreferencesStudentRepository.withStore(
      store: FakeStore(writeResult: false),
    );

    await expectLater(
      repository.load(),
      throwsA(isA<StudentStorageException>()),
    );
  });

  test('damaged and unknown-schema documents remain unchanged', () async {
    for (final original in [
      '{damaged',
      '{"schemaVersion":999,"classes":[],"students":[]}',
    ]) {
      final store = FakeStore(value: original);
      final repository = SharedPreferencesStudentRepository.withStore(
        store: store,
      );

      await expectLater(
        repository.load(),
        throwsA(isA<StudentStorageException>()),
      );
      expect(store.value, original);
      expect(store.writes, 0);
    }
  });

  test('storage initialization can be retried', () async {
    final store = FakeStore(value: codec.encode(const StudentData.empty()));
    var attempts = 0;
    final repository = SharedPreferencesStudentRepository.withStore(
      storeFactory: () async {
        if (attempts++ == 0) throw StateError('temporarily unavailable');
        return store;
      },
    );

    await expectLater(
      repository.load(),
      throwsA(isA<StudentStorageException>()),
    );
    expect((await repository.load()).students, isEmpty);
    expect(attempts, 2);
  });
}