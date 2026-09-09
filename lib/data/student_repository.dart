import 'dart:convert';

import '../models/student.dart';
import '../models/student_class.dart';
import 'demo_repository.dart';
import 'local_key_value_store.dart';

abstract interface class StudentRepository {
  Future<StudentData> load();
  Future<void> save(StudentData data);
}

class StudentData {
  const StudentData({required this.classes, required this.students});

  final List<StudentClass> classes;
  final List<Student> students;

  List<Student> findStudents({String? classId, String query = ''}) {
    final normalized = query.trim().toLowerCase();
    return students
        .where(
          (student) =>
              (classId == null || student.classId == classId) &&
              (normalized.isEmpty ||
                  student.fullName.toLowerCase().contains(normalized)),
        )
        .toList(growable: false);
  }

  String className(String id) =>
      classes.firstWhere((item) => item.id == id).name;
}

class LocalStudentRepository implements StudentRepository {
  LocalStudentRepository(this._store, {StudentData? demoData})
    : _demoData = demoData ??
          const StudentData(
            classes: DemoRepository.classes,
            students: DemoRepository.students,
          );

  static const storageKey = 'educator_cabinet.student_data';
  static const schemaVersion = 1;

  final LocalKeyValueStore _store;
  final StudentData _demoData;

  @override
  Future<StudentData> load() async {
    final raw = await _store.read(storageKey);
    if (raw != null) return _decode(raw);

    // Only an absent key may be seeded. A read/decode failure must never be
    // mistaken for an empty store, otherwise existing records could be replaced.
    await save(_demoData);
    return _demoData;
  }

  @override
  Future<void> save(StudentData data) => _store.write(storageKey, _encode(data));

  String _encode(StudentData data) => jsonEncode({
    'schemaVersion': schemaVersion,
    'classes': data.classes.map((item) => item.toJson()).toList(),
    'students': data.students.map((item) => item.toJson()).toList(),
  });

  StudentData _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Кореневий JSON не є об’єктом.');
      final json = Map<String, Object?>.from(decoded);
      final version = json['schemaVersion'];
      if (version != schemaVersion) {
        throw UnsupportedError('Непідтримувана версія схеми: $version.');
      }
      return StudentData(
        classes: _objects(json['classes'], 'classes')
            .map(StudentClass.fromJson)
            .toList(growable: false),
        students: _objects(json['students'], 'students')
            .map(Student.fromJson)
            .toList(growable: false),
      );
    } on FormatException {
      rethrow;
    } on UnsupportedError {
      rethrow;
    } catch (error) {
      throw FormatException('Не вдалося прочитати локальні дані: $error');
    }
  }

  List<Map<String, Object?>> _objects(Object? value, String field) {
    if (value is! List) throw FormatException('Поле "$field" має містити список.');
    return value.map((item) {
      if (item is! Map) throw FormatException('Поле "$field" містить не об’єкт.');
      return Map<String, Object?>.from(item);
    }).toList(growable: false);
  }
}

class DemoStudentRepository implements StudentRepository {
  const DemoStudentRepository();

  static const _data = StudentData(
    classes: DemoRepository.classes,
    students: DemoRepository.students,
  );

  @override
  Future<StudentData> load() async => _data;

  @override
  Future<void> save(StudentData data) async {}
}
