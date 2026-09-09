import 'dart:convert';

import '../models/student.dart';
import '../models/student_class.dart';
import '../models/student_data.dart';

class StudentDataCodec {
  const StudentDataCodec();

  static const schemaVersion = 2;

  bool requiresMigration(String source) {
    final value = jsonDecode(source);
    return value is Map<String, Object?> && value['schemaVersion'] == 1;
  }

  String encode(StudentData data) {
    _validateIntegrity(data);
    return jsonEncode({
      'schemaVersion': schemaVersion,
      'classes': data.classes.map((item) => item.toJson()).toList(),
      'students': data.students.map((item) => item.toJson()).toList(),
    });
  }

  StudentData decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, Object?>) {
      throw const FormatException('The stored student data is not an object.');
    }
    final version = value['schemaVersion'];
    if (version != 1 && version != schemaVersion) {
      throw const FormatException('Unsupported student data schema.');
    }
    try {
      final data = StudentData(
        classes: (value['classes'] as List<Object?>)
            .map((item) => StudentClass.fromJson(item as Map<String, Object?>))
            .toList(growable: false),
        students: (value['students'] as List<Object?>)
            .map((item) => Student.fromJson(item as Map<String, Object?>))
            .toList(growable: false),
      );
      _validateIntegrity(data);
      return data;
    } on TypeError catch (error) {
      throw FormatException('Invalid student data: $error');
    }
  }

  void _validateIntegrity(StudentData data) {
    final classIds = data.classes.map((item) => item.id).toList();
    final studentIds = data.students.map((item) => item.id).toList();
    if (classIds.toSet().length != classIds.length) {
      throw const FormatException('Student class IDs must be unique.');
    }
    if (studentIds.toSet().length != studentIds.length) {
      throw const FormatException('Student IDs must be unique.');
    }
    final contactIds = data.students
        .expand((student) => student.contacts)
        .map((contact) => contact.id)
        .toList();
    if (contactIds.toSet().length != contactIds.length) {
      throw const FormatException('Contact IDs must be unique.');
    }
    final knownClasses = classIds.toSet();
    if (data.students.any(
      (student) => !knownClasses.contains(student.classId),
    )) {
      throw const FormatException(
        'Every student must reference a known class.',
      );
    }
    final archivedClasses = data.classes
        .where((item) => item.isArchived)
        .map((item) => item.id)
        .toSet();
    if (data.students.any(
      (student) =>
          !student.isArchived && archivedClasses.contains(student.classId),
    )) {
      throw const FormatException(
        'Active students cannot reference archived classes.',
      );
    }
  }
}
