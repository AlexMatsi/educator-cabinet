import 'package:educator_cabinet/data/demo_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const repository = DemoRepository();

  test('demo source contains two classes and six stable student records', () {
    expect(DemoRepository.classes, hasLength(2));
    expect(DemoRepository.students, hasLength(6));
    expect(
      DemoRepository.students.map((student) => student.id).toSet(),
      hasLength(6),
    );
    expect(
      DemoRepository.students.every((student) => !student.hasPhone),
      isTrue,
    );
    expect(
      DemoRepository.students
          .expand((student) => student.contacts)
          .every((contact) => !contact.hasPhone),
      isTrue,
    );
  });

  test('filters by class and case-insensitive name fragment', () {
    expect(repository.findStudents(classId: 'class-horizon'), hasLength(3));
    expect(repository.findStudents(query: 'ДЖЕР'), hasLength(1));
    expect(
      repository.findStudents(classId: 'class-lighthouse', query: 'ДЖЕР'),
      isEmpty,
    );
  });
}
