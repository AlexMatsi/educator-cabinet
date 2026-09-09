import 'dart:convert';

import 'package:educator_cabinet/data/demo_repository.dart';
import 'package:educator_cabinet/data/key_value_store.dart';
import 'package:educator_cabinet/data/local_student_repository.dart';
import 'package:educator_cabinet/models/contact.dart';
import 'package:educator_cabinet/models/student.dart';
import 'package:educator_cabinet/models/student_class.dart';
import 'package:educator_cabinet/models/student_directory.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStore implements KeyValueStore {
  String? value;
  Object? readError;
  Object? writeError;
  int writes = 0;

  @override
  Future<String?> read(String key) async {
    if (readError != null) throw readError!;
    return value;
  }

  @override
  Future<void> write(String key, String newValue) async {
    if (writeError != null) throw writeError!;
    writes++;
    value = newValue;
  }
}

void main() {
  test('seeds once and reopens without duplicating demo records', () async {
    final store = MemoryStore();
    final first = await LocalStudentRepository(store).load();
    final reopened = await LocalStudentRepository(store).load();

    expect(first.students, hasLength(6));
    expect(reopened.students, hasLength(6));
    expect(reopened.students.map((item) => item.id).toSet(), hasLength(6));
    expect(store.writes, 1);
  });

  test('persists classes, students and nested contacts across reopen', () async {
    final store = MemoryStore();
    final repository = LocalStudentRepository(store);
    const changed = StudentDirectory(
      classes: [StudentClass(id: 'class-test', name: '10-Т')],
      students: [
        Student(
          id: 'student-test',
          classId: 'class-test',
          fullName: 'Леся Тестова',
          room: '7',
          sport: 'Шахи',
          phone: '+380000000001',
          contacts: [
            Contact(
              id: 'contact-test',
              name: 'Олена Тестова',
              role: 'Представниця',
              phone: '+380000000002',
            ),
          ],
        ),
      ],
    );

    await repository.replaceAll(changed);
    final reopened = await LocalStudentRepository(store).load();

    expect(reopened.classes.single.name, '10-Т');
    expect(reopened.students.single.fullName, 'Леся Тестова');
    expect(reopened.students.single.contacts.single.name, 'Олена Тестова');
    expect(store.writes, 1);
  });

  test('does not replace malformed data with demo data', () async {
    final store = MemoryStore()..value = '{broken';

    await expectLater(
      LocalStudentRepository(store).load(),
      throwsA(isA<StorageException>()),
    );
    expect(store.value, '{broken');
    expect(store.writes, 0);
  });

  test('does not write when reading storage fails', () async {
    final store = MemoryStore()..readError = Exception('read failed');

    await expectLater(
      LocalStudentRepository(store).load(),
      throwsA(isA<StorageException>()),
    );
    expect(store.writes, 0);
  });

  test('failed write leaves the previously stored document untouched', () async {
    final store = MemoryStore();
    await LocalStudentRepository(store).replaceAll(DemoRepository.directory);
    final original = store.value;
    store.writeError = Exception('write failed');

    await expectLater(
      LocalStudentRepository(
        store,
      ).replaceAll(const StudentDirectory(classes: [], students: [])),
      throwsA(isA<StorageException>()),
    );
    expect(store.value, original);
  });

  test('rejects a future schema without overwriting it', () async {
    final store = MemoryStore()
      ..value = jsonEncode({
        'schemaVersion': LocalStudentRepository.currentSchemaVersion + 1,
        'classes': <Object>[],
        'students': <Object>[],
      });
    final original = store.value;

    await expectLater(
      LocalStudentRepository(store).load(),
      throwsA(isA<StorageException>()),
    );
    expect(store.value, original);
    expect(store.writes, 0);
  });
}
