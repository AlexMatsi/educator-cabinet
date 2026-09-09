import '../models/student_directory.dart';

abstract interface class StudentRepository {
  Future<StudentDirectory> load();

  Future<void> replaceAll(StudentDirectory directory);
}
