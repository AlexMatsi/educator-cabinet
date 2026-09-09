import 'dart:convert';

import 'package:educator_cabinet/data/demo_repository.dart';
import 'package:educator_cabinet/data/student_data_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = StudentDataCodec();

  test('JSON round trip preserves all student data', () {
    final encoded = codec.encode(DemoRepository.data);
    final decoded = codec.decode(encoded);

    expect(codec.encode(decoded), encoded);
  });

  test('encoded data contains the current schema version', () {
    final json = jsonDecode(codec.encode(DemoRepository.data));

    expect(json['schemaVersion'], StudentDataCodec.schemaVersion);
  });

  test('schema v1 migrates without losing existing records', () {
    final legacy = jsonDecode(codec.encode(DemoRepository.data)) as Map<String, Object?>;
    legacy['schemaVersion'] = 1;
    for (final item in legacy['classes'] as List) {
      (item as Map).remove('archivedAt');
    }
    for (final item in legacy['students'] as List) {
      (item as Map).remove('archivedAt');
    }
    final decoded = codec.decode(jsonEncode(legacy));
    expect(decoded.classes.map((e) => e.id), DemoRepository.classes.map((e) => e.id));
    expect(decoded.students.map((e) => e.id), DemoRepository.students.map((e) => e.id));
    expect(decoded.students.every((e) => !e.isArchived), isTrue);
    expect(jsonDecode(codec.encode(decoded))['schemaVersion'], 2);
  });

  test('unknown schema version is rejected', () {
    final json = jsonDecode(codec.encode(DemoRepository.data));
    json['schemaVersion'] = StudentDataCodec.schemaVersion + 1;

    expect(() => codec.decode(jsonEncode(json)), throwsFormatException);
  });

  test('duplicate class and student IDs are rejected', () {
    final json = jsonDecode(codec.encode(DemoRepository.data));
    final classes = json['classes'] as List<Object?>;
    classes.add(classes.first);
    expect(() => codec.decode(jsonEncode(json)), throwsFormatException);

    final duplicateStudent = jsonDecode(codec.encode(DemoRepository.data));
    final students = duplicateStudent['students'] as List<Object?>;
    students.add(students.first);
    expect(
      () => codec.decode(jsonEncode(duplicateStudent)),
      throwsFormatException,
    );
  });

  test('student referencing an unknown class is rejected', () {
    final json = jsonDecode(codec.encode(DemoRepository.data));
    final students = json['students'] as List<Object?>;
    (students.first as Map<String, Object?>)['classId'] = 'missing-class';

    expect(() => codec.decode(jsonEncode(json)), throwsFormatException);
  });
}
