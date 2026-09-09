import '../models/contact.dart';
import '../models/student.dart';
import '../models/student_class.dart';
import '../models/student_data.dart';

class DemoRepository {
  const DemoRepository();

  static const classes = <StudentClass>[
    StudentClass(id: 'class-lighthouse', name: '9-А'),
    StudentClass(id: 'class-horizon', name: '9-В'),
  ];

  static const students = <Student>[
    Student(
      id: 'student-sun-01',
      classId: 'class-lighthouse',
      fullName: 'Марія Весняна',
      room: '101',
      sport: 'Волейбол',
      contacts: [
        Contact(
          id: 'adult-sun-01',
          name: 'Олена Весняна',
          role: 'Представниця',
        ),
      ],
    ),
    Student(
      id: 'student-sun-02',
      classId: 'class-lighthouse',
      fullName: 'Данило Зоряний',
      room: '103',
      sport: 'Плавання',
      contacts: [
        Contact(id: 'adult-sun-02', name: 'Тарас Зоряний', role: 'Представник'),
      ],
    ),
    Student(
      id: 'student-sun-03',
      classId: 'class-lighthouse',
      fullName: 'Софія Мрійлива',
      room: '105',
      sport: 'Легка атлетика',
      contacts: [
        Contact(
          id: 'adult-sun-03',
          name: 'Ірина Мрійлива',
          role: 'Представниця',
        ),
      ],
    ),
    Student(
      id: 'student-sky-01',
      classId: 'class-horizon',
      fullName: 'Максим Калиновий',
      room: '202',
      sport: 'Футбол',
      contacts: [
        Contact(
          id: 'adult-sky-01',
          name: 'Петро Калиновий',
          role: 'Представник',
        ),
      ],
    ),
    Student(
      id: 'student-sky-02',
      classId: 'class-horizon',
      fullName: 'Анна Джерельна',
      room: '204',
      sport: 'Теніс',
      contacts: [
        Contact(
          id: 'adult-sky-02',
          name: 'Наталія Джерельна',
          role: 'Представниця',
        ),
        Contact(id: 'coach-sky-02', name: 'Олег Спортивний', role: 'Тренер'),
      ],
    ),
    Student(
      id: 'student-sky-03',
      classId: 'class-horizon',
      fullName: 'Лев Барвінковий',
      room: '206',
      sport: 'Баскетбол',
      contacts: [
        Contact(
          id: 'adult-sky-03',
          name: 'Катерина Барвінкова',
          role: 'Представниця',
        ),
      ],
    ),
  ];

  static const data = StudentData(classes: classes, students: students);

  List<Student> findStudents({String? classId, String query = ''}) {
    final normalized = query.trim().toLowerCase();
    return students
        .where((student) {
          return (classId == null || student.classId == classId) &&
              (normalized.isEmpty ||
                  student.fullName.toLowerCase().contains(normalized));
        })
        .toList(growable: false);
  }

  String className(String id) =>
      classes.firstWhere((item) => item.id == id).name;
}
