import '../models/student_data.dart';

abstract interface class StudentRepository {
  Future<StudentData> load();

  Future<void> save(StudentData data);
}
