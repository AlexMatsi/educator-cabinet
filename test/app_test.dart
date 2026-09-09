import 'package:educator_cabinet/app.dart';
import 'package:educator_cabinet/data/demo_repository.dart';
import 'package:educator_cabinet/data/student_repository.dart';
import 'package:educator_cabinet/models/contact.dart';
import 'package:educator_cabinet/models/student.dart';
import 'package:educator_cabinet/models/student_data.dart';
import 'package:educator_cabinet/services/contact_action.dart';
import 'package:educator_cabinet/widgets/student_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingContactAction implements ContactAction {
  final calls = <String>[];
  @override
  Future<ContactActionResult> call(String phone) async {
    calls.add(phone);
    return ContactActionResult.openedDialer;
  }
}

class MemoryStudentRepository implements StudentRepository {
  @override
  Future<StudentData> load() async => DemoRepository.data;

  @override
  Future<void> save(StudentData data) async {}
}

EducatorCabinetApp testApp(ContactAction action) => EducatorCabinetApp(
  contactAction: action,
  studentRepository: MemoryStudentRepository(),
);

void main() {
  testWidgets('class choice, search and card open the correct student', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(RecordingContactAction()));
    await tester.pumpAndSettle();
    expect(find.text('Усі мої класи'), findsOneWidget);
    expect(find.text('Марія Весняна'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Лев Барвінковий'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Лев Барвінковий'), findsOneWidget);

    await tester.tap(find.byKey(const Key('class-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9-В').last);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(3));

    await tester.enterText(find.byKey(const Key('student-search')), 'Джер');
    await tester.pump();
    expect(find.text('Анна Джерельна'), findsOneWidget);
    await tester.tap(find.text('Анна Джерельна'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('student-full-name')), findsOneWidget);
    expect(find.text('Номер не додано'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('call-student')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('calls exactly the selected contact through the adapter', (
    tester,
  ) async {
    final action = RecordingContactAction();
    const student = Student(
      id: 'test-student',
      classId: 'test-class',
      fullName: 'Тестова Учениця',
      room: '1',
      sport: 'Тест',
      phone: '+380000000001',
      contacts: [
        Contact(
          id: 'test-adult',
          name: 'Тестова Представниця',
          role: 'Представниця',
          phone: '+380000000002',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StudentDetail(
          student: student,
          className: 'Тест',
          contactAction: action,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('call-test-adult')));
    await tester.pump();
    expect(action.calls, ['+380000000002']);
    await tester.tap(find.byKey(const Key('call-student')));
    await tester.pump();
    expect(action.calls, ['+380000000002', '+380000000001']);
  });
  testWidgets('phone layout and enlarged text remain usable', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(testApp(RecordingContactAction()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Марія Весняна'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('student-full-name')), findsOneWidget);
    expect(find.byTooltip('Назад'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('class selector returns to all classes', (tester) async {
    await tester.pumpWidget(testApp(RecordingContactAction()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('class-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9-В').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('class-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Усі мої класи').last);
    await tester.pumpAndSettle();
    expect(find.text('Марія Весняна'), findsOneWidget);
    expect(find.text('Усі мої класи'), findsOneWidget);
  });
}
