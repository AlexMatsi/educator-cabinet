import 'dart:convert';

import '../models/student.dart';
import '../models/student_class.dart';
import '../models/student_data.dart';

class StudentDataCodec {
  const StudentDataCodec();

  static const schemaVersion = 1;

  String encode(StudentData data) => jsonEncode({
    'schemaVersion': schemaVersion,
    'classes': data.classes.map((item) => item.toJson()).toList(),
    'students': data.students.map((item) => item.toJson()).toList(),
  });

  StudentData decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, Object?>) {
      throw const FormatException('The stored student data is not an object.');
    }
    if (value['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported student data schema.');
    }
    try {
      return StudentData(
        classes: (value['classes'] as List<Object?>)
            .map(
              (item) => StudentClass.fromJson(item as Map<String, Object?>),
            )
            .toList(growable: false),
        students: (value['students'] as List<Object?>)
            .map((item) => Student.fromJson(item as Map<String, Object?>))
            .toList(growable: false),
      );
    } on TypeError catch (error) {
      throw FormatException('Invalid student data: $error');
    }
  }
}
