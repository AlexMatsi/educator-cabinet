import 'dart:convert';

import 'package:educator_cabinet/data/local_key_value_store.dart';
import 'package:educator_cabinet/data/student_repository.dart';
import 'package:educator_cabinet/models/contact.dart';
import 'package:educator_cabinet/models/student.dart';
import 'package:educator_cabinet/models/student_class.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStore implements LocalKeyValueStore {
  MemoryStore([this.value]);

  String? value;
  int writes = 0;
  Object? readError;
  Object? writeError;

  @override
  Future<String?> read(String key) async {
    if (readError != null) throw readError!;
    return value;
  }

  @override
  Future<void> write(String key, String nextValue) async {
    writes++;
    if (writeError != null) throw writeError!;
    value = nextValue;
  }
}

const testData = StudentData(
  classes: [StudentClass(id: 'class-1', name: 'Тестовий клас')],
  students: [
    Student(
      id: 'student-1',
      classId: 'class-1',
      fullName: 'Синтетична Учениця',
      room: '101',
      sport: 'Тестування',
      contacts: [
        Contact(id: 'contact-1', name: 'Синтетичний Контакт', role: 'Представник'),
      ],
    ),
  ],
);

void main() {
  test('creates storage once and reopens classes, students and contacts', () async {
    final store = MemoryStore();
    final first = LocalStudentRepository(store, demoData: testData);

    final created = await first.load();
    expect(created.classes.single.name, 'Тестовий клас');
    expect(created.students.single.contacts.single.name, 'Синтетичний Контакт');
    expect(store.writes, 1);

    final reopened = await LocalStudentRepository(store, demoData: const StudentData(classes: [], students: [])).load();
    expect(reopened.classes.single.id, 'class-1');
    expect(reopened.students.single.id, 'student-1');
    expect(reopened.students.single.contacts.single.role, 'Представник');
    expect(store.writes, 1, reason: 'existing data must not be seeded again');
  });

  test('saves changes to classes, students and contacts', () async {
    final store = MemoryStore();
    final repository = LocalStudentRepository(store, demoData: testData);
    await repository.save(testData);

    final json = jsonDecode(store.value!) as Map<String, dynamic>;
    expect(json['schemaVersion'], LocalStudentRepository.schemaVersion);
    expect(json['classes'][0]['name'], 'Тестовий клас');
    expect(json['students'][0]['fullName'], 'Синтетична Учениця');
    expect(json['students'][0]['contacts'][0]['name'], 'Синтетичний Контакт');
  });

  test('does not overwrite corrupted JSON or an unknown schema version', () async {
    for (final raw in ['{broken', '{"schemaVersion": 99, "classes": [], "students": []}']) {
      final store = MemoryStore(raw);
      final repository = LocalStudentRepository(store, demoData: testData);
      await expectLater(repository.load(), throwsA(anything));
      expect(store.value, raw);
      expect(store.writes, 0);
    }
  });

  test('does not replace data when reading or writing fails', () async {
    final existing = '{"schemaVersion": 1, "classes": [], "students": []}';
    final readStore = MemoryStore(existing)..readError = StateError('read failed');
    await expectLater(LocalStudentRepository(readStore, demoData: testData).load(), throwsA(isA<StateError>()));
    expect(readStore.value, existing);
    expect(readStore.writes, 0);

    final writeStore = MemoryStore(existing)..writeError = StateError('write failed');
    final repository = LocalStudentRepository(writeStore, demoData: testData);
    await expectLater(repository.save(testData), throwsA(isA<StateError>()));
    expect(writeStore.value, existing);
  });
}
