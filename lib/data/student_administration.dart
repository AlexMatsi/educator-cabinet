import '../models/contact.dart';
import '../models/student.dart';
import '../models/student_class.dart';
import '../models/student_data.dart';
import 'student_repository.dart';

class StudentValidationException implements Exception {
  const StudentValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class StableIdGenerator {
  String next(String kind);
}

class TimestampIdGenerator implements StableIdGenerator {
  TimestampIdGenerator({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  int _sequence = 0;
  @override
  String next(String kind) =>
      '$kind-${_now().microsecondsSinceEpoch}-${_sequence++}';
}

class StudentAdministration {
  StudentAdministration({
    required this.repository,
    required this.ids,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final StudentRepository repository;
  final StableIdGenerator ids;
  final DateTime Function() _now;

  Future<StudentData> createClass(StudentData current, String name) async {
    final clean = _required(name, 'Введіть назву класу.');
    final item = StudentClass(id: _uniqueId(current, 'class'), name: clean);
    return _save(StudentData(classes: [...current.classes, item], students: current.students));
  }

  Future<StudentData> renameClass(StudentData current, String id, String name) =>
      _save(StudentData(
        classes: current.classes
            .map((item) => item.id == id
                ? item.copyWith(name: _required(name, 'Введіть назву класу.'))
                : item)
            .toList(),
        students: current.students,
      ));

  Future<StudentData> archiveClass(StudentData current, String id) {
    if (current.students.any((student) => student.classId == id && !student.isArchived)) {
      throw const StudentValidationException(
        'Спочатку архівуйте або переведіть усіх активних учнів цього класу.',
      );
    }
    return _save(StudentData(
      classes: current.classes
          .map((item) => item.id == id ? item.copyWith(archivedAt: _now()) : item)
          .toList(),
      students: current.students,
    ));
  }

  Future<StudentData> restoreClass(StudentData current, String id) => _save(StudentData(
    classes: current.classes
        .map((item) => item.id == id ? item.copyWith(restore: true) : item)
        .toList(),
    students: current.students,
  ));

  Future<StudentData> createStudent(
    StudentData current, {
    required String fullName,
    required String classId,
    String room = '',
    String sport = '',
    String? phone,
    List<Contact> contacts = const [],
  }) async {
    _activeClass(current, classId);
    final student = Student(
      id: _uniqueId(current, 'student'),
      classId: classId,
      fullName: _required(fullName, 'Введіть ПІБ учня.'),
      room: room.trim(),
      sport: sport.trim(),
      phone: _optional(phone),
      contacts: contacts,
    );
    return _save(StudentData(classes: current.classes, students: [...current.students, student]));
  }

  Future<StudentData> updateStudent(StudentData current, Student changed) async {
    if (!current.students.any((item) => item.id == changed.id)) {
      throw const StudentValidationException('Картку учня не знайдено.');
    }
    _activeClass(current, changed.classId);
    final validated = changed.copyWith(
      fullName: _required(changed.fullName, 'Введіть ПІБ учня.'),
      room: changed.room.trim(), sport: changed.sport.trim(), phone: _optional(changed.phone),
    );
    return _save(StudentData(
      classes: current.classes,
      students: current.students.map((item) => item.id == changed.id ? validated : item).toList(),
    ));
  }

  Future<StudentData> archiveStudent(StudentData current, String id) => _save(StudentData(
    classes: current.classes,
    students: current.students
        .map((item) => item.id == id ? item.copyWith(archivedAt: _now()) : item)
        .toList(),
  ));

  Future<StudentData> restoreStudent(StudentData current, String id) {
    final student = current.students.firstWhere((item) => item.id == id);
    _activeClass(current, student.classId);
    return _save(StudentData(
      classes: current.classes,
      students: current.students
          .map((item) => item.id == id ? item.copyWith(restore: true) : item)
          .toList(),
    ));
  }

  Future<StudentData> _save(StudentData next) async {
    await repository.save(next);
    return next;
  }

  String _uniqueId(StudentData data, String kind) {
    final all = {...data.classes.map((e) => e.id), ...data.students.map((e) => e.id)};
    for (var attempt = 0; attempt < 100; attempt++) {
      final id = ids.next(kind);
      if (!all.contains(id)) return id;
    }
    throw const StudentValidationException('Не вдалося створити унікальний ID.');
  }

  void _activeClass(StudentData data, String id) {
    if (!data.classes.any((item) => item.id == id && !item.isArchived)) {
      throw const StudentValidationException('Оберіть активний клас.');
    }
  }

  String _required(String value, String message) {
    final clean = value.trim();
    if (clean.isEmpty) throw StudentValidationException(message);
    return clean;
  }

  String? _optional(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}
