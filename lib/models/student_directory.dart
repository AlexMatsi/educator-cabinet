import 'student.dart';
import 'student_class.dart';

class StudentDirectory {
  const StudentDirectory({required this.classes, required this.students});

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
      classes.firstWhere((studentClass) => studentClass.id == id).name;
}
