import 'student.dart';
import 'student_class.dart';

class StudentData {
  const StudentData({required this.classes, required this.students});

  const StudentData.empty() : classes = const [], students = const [];

  final List<StudentClass> classes;
  final List<Student> students;
}
