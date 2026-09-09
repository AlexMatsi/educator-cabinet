import 'package:educator_cabinet/data/demo_repository.dart';
import 'package:educator_cabinet/data/student_administration.dart';
import 'package:educator_cabinet/data/student_repository.dart';
import 'package:educator_cabinet/models/contact.dart';
import 'package:educator_cabinet/models/student_data.dart';
import 'package:flutter_test/flutter_test.dart';

class SequenceIds implements StableIdGenerator {
  SequenceIds(this.values);
  final List<String> values;
  @override
  String next(String kind) => values.removeAt(0);
}

class MemoryRepository implements StudentRepository {
  MemoryRepository(this.value, {this.fail = false});
  StudentData value;
  bool fail;
  @override
  Future<StudentData> load() async => value;
  @override
  Future<void> save(StudentData data) async {
    if (fail) throw StateError('disk full');
    value = data;
  }
}

void main() {
  final archivedAt = DateTime.utc(2026, 9, 9);

  test('class create and rename preserve a unique stable ID', () async {
    final repository = MemoryRepository(DemoRepository.data);
    final admin = StudentAdministration(
      repository: repository,
      ids: SequenceIds(['class-lighthouse', 'class-new']),
    );
    var data = await admin.createClass(repository.value, ' 10-А ');
    final id = data.classes.last.id;
    expect(id, 'class-new');
    data = await admin.renameClass(data, id, '10-Б');
    expect(
      data.classes.last,
      predicate((item) => item.id == id && item.name == '10-Б'),
    );
  });

  test('student create, edit and transfer preserve ID and contacts', () async {
    final repository = MemoryRepository(DemoRepository.data);
    final admin = StudentAdministration(
      repository: repository,
      ids: SequenceIds(['student-new']),
    );
    var data = await admin.createStudent(
      repository.value,
      fullName: 'Тестова Учениця',
      classId: 'class-lighthouse',
      contacts: const [
        Contact(
          id: 'adult-1',
          name: 'Тестова Мама',
          role: 'Мама',
          phone: '+380000000000',
        ),
      ],
    );
    final student = data.students.last;
    data = await admin.updateStudent(
      data,
      student.copyWith(fullName: 'Нове Ім’я', classId: 'class-horizon'),
    );
    expect(data.students.last.id, student.id);
    expect(data.students.last.classId, 'class-horizon');
    expect(data.students.last.contacts.single.phone, '+380000000000');
  });

  test('student archive records date and restore clears it', () async {
    final repository = MemoryRepository(DemoRepository.data);
    final admin = StudentAdministration(
      repository: repository,
      ids: SequenceIds([]),
      now: () => archivedAt,
    );
    var data = await admin.archiveStudent(
      repository.value,
      DemoRepository.students.first.id,
    );
    expect(data.students.first.archivedAt, archivedAt);
    data = await admin.restoreStudent(data, data.students.first.id);
    expect(data.students.first.archivedAt, isNull);
  });

  test('class with active students cannot be archived', () async {
    final repository = MemoryRepository(DemoRepository.data);
    final admin = StudentAdministration(
      repository: repository,
      ids: SequenceIds([]),
    );
    await expectLater(
      admin.archiveClass(repository.value, 'class-lighthouse'),
      throwsA(isA<StudentValidationException>()),
    );
  });

  test('required fields and active class are validated', () async {
    final repository = MemoryRepository(DemoRepository.data);
    final admin = StudentAdministration(
      repository: repository,
      ids: SequenceIds(['student-new']),
    );
    await expectLater(
      admin.createStudent(
        repository.value,
        fullName: ' ',
        classId: 'class-lighthouse',
      ),
      throwsA(isA<StudentValidationException>()),
    );
    await expectLater(
      admin.createStudent(
        repository.value,
        fullName: 'Ім’я',
        classId: 'missing',
      ),
      throwsA(isA<StudentValidationException>()),
    );
  });

  test('write failure does not replace confirmed state', () async {
    final confirmed = DemoRepository.data;
    final repository = MemoryRepository(confirmed, fail: true);
    final admin = StudentAdministration(
      repository: repository,
      ids: SequenceIds(['class-new']),
    );
    await expectLater(admin.createClass(confirmed, '10-А'), throwsStateError);
    expect(repository.value, same(confirmed));
  });

  test('unknown records and duplicate contact IDs are rejected', () async {
    final repository = MemoryRepository(DemoRepository.data);
    final admin = StudentAdministration(
      repository: repository,
      ids: SequenceIds(['student-new']),
    );
    await expectLater(
      admin.renameClass(repository.value, 'missing', '10-А'),
      throwsA(isA<StudentValidationException>()),
    );
    await expectLater(
      admin.archiveStudent(repository.value, 'missing'),
      throwsA(isA<StudentValidationException>()),
    );
    await expectLater(
      admin.createStudent(
        repository.value,
        fullName: 'Тестова Учениця',
        classId: 'class-lighthouse',
        contacts: const [
          Contact(id: 'same', name: 'Перша', role: 'Мама'),
          Contact(id: 'same', name: 'Друга', role: 'Тренерка'),
        ],
      ),
      throwsA(isA<StudentValidationException>()),
    );
  });

  test('generated contact ID is stable and skips existing IDs', () {
    final repository = MemoryRepository(DemoRepository.data);
    final admin = StudentAdministration(
      repository: repository,
      ids: SequenceIds(['class-lighthouse', 'contact-new']),
    );

    expect(admin.newContactId(repository.value), 'contact-new');
  });
}
