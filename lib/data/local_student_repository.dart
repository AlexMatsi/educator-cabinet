import 'dart:convert';

import '../models/contact.dart';
import '../models/student.dart';
import '../models/student_class.dart';
import '../models/student_directory.dart';
import 'demo_repository.dart';
import 'key_value_store.dart';
import 'student_repository.dart';

class StorageException implements Exception {
  const StorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class LocalStudentRepository implements StudentRepository {
  LocalStudentRepository(this._store);

  static const storageKey = 'student_directory';
  static const currentSchemaVersion = 1;

  final KeyValueStore _store;

  @override
  Future<StudentDirectory> load() async {
    final String? stored;
    try {
      stored = await _store.read(storageKey);
    } catch (error) {
      throw StorageException('Не вдалося прочитати локальні дані.', error);
    }

    if (stored == null) {
      final directory = DemoRepository.directory;
      await replaceAll(directory);
      return directory;
    }

    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('The root value is not an object.');
      }
      final migrated = _migrate(decoded);
      return _decodeDirectory(migrated);
    } catch (error) {
      if (error is StorageException) rethrow;
      throw StorageException(
        'Локальні дані пошкоджені або мають непідтримувану версію.',
        error,
      );
    }
  }

  @override
  Future<void> replaceAll(StudentDirectory directory) async {
    final encoded = jsonEncode(_encodeDirectory(directory));
    try {
      await _store.write(storageKey, encoded);
    } catch (error) {
      throw StorageException('Не вдалося зберегти локальні дані.', error);
    }
  }

  Map<String, dynamic> _migrate(Map<String, dynamic> document) {
    final version = document['schemaVersion'];
    if (version is! int || version < 1 || version > currentSchemaVersion) {
      throw FormatException('Unsupported schema version: $version');
    }

    var migrated = document;
    var nextVersion = version;
    while (nextVersion < currentSchemaVersion) {
      migrated = _migrationFrom(nextVersion)(migrated);
      nextVersion++;
    }
    return migrated;
  }

  Map<String, dynamic> Function(Map<String, dynamic>) _migrationFrom(
    int version,
  ) => switch (version) {
    _ => throw FormatException('No migration from schema version $version.'),
  };

  Map<String, dynamic> _encodeDirectory(StudentDirectory directory) => {
    'schemaVersion': currentSchemaVersion,
    'classes': directory.classes
        .map((item) => {'id': item.id, 'name': item.name})
        .toList(growable: false),
    'students': directory.students
        .map(
          (student) => {
            'id': student.id,
            'classId': student.classId,
            'fullName': student.fullName,
            'room': student.room,
            'sport': student.sport,
            'phone': student.phone,
            'contacts': student.contacts
                .map(
                  (contact) => {
                    'id': contact.id,
                    'name': contact.name,
                    'role': contact.role,
                    'phone': contact.phone,
                  },
                )
                .toList(growable: false),
          },
        )
        .toList(growable: false),
  };

  StudentDirectory _decodeDirectory(Map<String, dynamic> document) {
    final classesJson = document['classes'] as List<dynamic>;
    final studentsJson = document['students'] as List<dynamic>;
    final classes = classesJson.map((value) {
      final item = value as Map<String, dynamic>;
      return StudentClass(id: item['id'] as String, name: item['name'] as String);
    }).toList(growable: false);
    final classIds = classes.map((item) => item.id).toSet();
    final students = studentsJson.map((value) {
      final item = value as Map<String, dynamic>;
      final classId = item['classId'] as String;
      if (!classIds.contains(classId)) {
        throw FormatException('Unknown class: $classId');
      }
      return Student(
        id: item['id'] as String,
        classId: classId,
        fullName: item['fullName'] as String,
        room: item['room'] as String,
        sport: item['sport'] as String,
        phone: item['phone'] as String?,
        contacts: (item['contacts'] as List<dynamic>).map((value) {
          final contact = value as Map<String, dynamic>;
          return Contact(
            id: contact['id'] as String,
            name: contact['name'] as String,
            role: contact['role'] as String,
            phone: contact['phone'] as String?,
          );
        }).toList(growable: false),
      );
    }).toList(growable: false);
    return StudentDirectory(classes: classes, students: students);
  }
}
