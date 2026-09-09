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

  String newContactId(StudentData current) => _uniqueId(current, 'contact');

  Future<StudentData> createClass(StudentData current, String name) async {
    final clean = _required(name, 'Введіть назву класу.');
    final item = StudentClass(id: _uniqueId(current, 'class'), name: clean);
    return _save(
      StudentData(
        classes: [...current.classes, item],
        students: current.students,
      ),
    );
  }

  Future<StudentData> renameClass(
    StudentData current,
    String id,
    String name,
  ) {
    _class(current, id);
    final clean = _required(name, 'Введіть назву класу.');
    return _save(
      StudentData(
        classes: current.classes
            .map((item) => item.id == id ? item.copyWith(name: clean) : item)
            .toList(growable: false),
        students: current.students,
      ),
    );
  }

  Future<StudentData> archiveClass(StudentData current, String id) {
    final target = _class(current, id);
    if (target.isArchived) {
      throw const StudentValidationException('Клас уже в архіві.');
    }
    if (current.students.any(
      (student) => student.classId == id && !student.isArchived,
    )) {
      throw const StudentValidationException(
        'Спочатку архівуйте або переведіть усіх активних учнів цього класу.',
      );
    }
    return _save(
      StudentData(
        classes: current.classes
            .map(
              (item) =>
                  item.id == id ? item.copyWith(archivedAt: _now()) : item,
            )
            .toList(growable: false),
        students: current.students,
      ),
    );
  }

  Future<StudentData> restoreClass(StudentData current, String id) {
    final target = _class(current, id);
    if (!target.isArchived) {
      throw const StudentValidationException('Клас уже активний.');
    }
    return _save(
      StudentData(
        classes: current.classes
            .map(
              (item) => item.id == id ? item.copyWith(restore: true) : item,
            )
            .toList(growable: false),
        students: current.students,
      ),
    );
  }

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
      contacts: _validatedContacts(contacts),
    );
    return _save(
      StudentData(
        classes: current.classes,
        students: [...current.students, student],
      ),
    );
  }

  Future<StudentData> updateStudent(
    StudentData current,
    Student changed,
  ) async {
    final existing = _student(current, changed.id);
    if (existing.isArchived) {
      throw const StudentValidationException(
        'Спочатку відновіть учня з архіву.',
      );
    }
    _activeClass(current, changed.classId);
    final normalizedPhone = _optional(changed.phone);
    final validated = changed.copyWith(
      fullName: _required(changed.fullName, 'Введіть ПІБ учня.'),
      room: changed.room.trim(),
      sport: changed.sport.trim(),
      phone: normalizedPhone,
      clearPhone: normalizedPhone == null,
      contacts: _validatedContacts(changed.contacts),
    );
    return _save(
      StudentData(
        classes: current.classes,
        students: current.students
            .map((item) => item.id == changed.id ? validated : item)
            .toList(growable: false),
      ),
    );
  }

  Future<StudentData> archiveStudent(StudentData current, String id) {
    final target = _student(current, id);
    if (target.isArchived) {
      throw const StudentValidationException('Учень уже в архіві.');
    }
    return _save(
      StudentData(
        classes: current.classes,
        students: current.students
            .map(
              (item) =>
                  item.id == id ? item.copyWith(archivedAt: _now()) : item,
            )
            .toList(growable: false),
      ),
    );
  }

  Future<StudentData> restoreStudent(StudentData current, String id) {
    final student = _student(current, id);
    if (!student.isArchived) {
      throw const StudentValidationException('Учень уже активний.');
    }
    _activeClass(current, student.classId);
    return _save(
      StudentData(
        classes: current.classes,
        students: current.students
            .map(
              (item) => item.id == id ? item.copyWith(restore: true) : item,
            )
            .toList(growable: false),
      ),
    );
  }

  Future<StudentData> _save(StudentData next) async {
    await repository.save(next);
    return next;
  }

  String _uniqueId(StudentData data, String kind) {
    final all = {
      ...data.classes.map((item) => item.id),
      ...data.students.map((item) => item.id),
      ...data.students.expand((item) => item.contacts).map((item) => item.id),
    };
    for (var attempt = 0; attempt < 100; attempt++) {
      final id = ids.next(kind);
      if (id.isNotEmpty && !all.contains(id)) return id;
    }
    throw const StudentValidationException(
      'Не вдалося створити унікальний ID.',
    );
  }

  StudentClass _class(StudentData data, String id) {
    try {
      return data.classes.firstWhere((item) => item.id == id);
    } on StateError {
      throw const StudentValidationException('Клас не знайдено.');
    }
  }

  Student _student(StudentData data, String id) {
    try {
      return data.students.firstWhere((item) => item.id == id);
    } on StateError {
      throw const StudentValidationException('Картку учня не знайдено.');
    }
  }

  void _activeClass(StudentData data, String id) {
    final target = _class(data, id);
    if (target.isArchived) {
      throw const StudentValidationException('Оберіть активний клас.');
    }
  }

  List<Contact> _validatedContacts(List<Contact> contacts) {
    final ids = <String>{};
    return contacts.map((contact) {
      final id = _required(contact.id, 'Контакт має некоректний ID.');
      if (!ids.add(id)) {
        throw const StudentValidationException(
          'Контакти мають повторювані ID.',
        );
      }
      return Contact(
        id: id,
        name: _required(contact.name, "Введіть ім'я контакту."),
        role: _required(contact.role, 'Введіть роль контакту.'),
        phone: _optional(contact.phone),
      );
    }).toList(growable: false);
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
