import 'package:educator_cabinet/app.dart';
import 'package:educator_cabinet/models/contact.dart';
import 'package:educator_cabinet/models/student.dart';
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

void main() {
  testWidgets('class choice, search and card open the correct student', (tester) async {
    await tester.pumpWidget(EducatorCabinetApp(contactAction: RecordingContactAction()));
    expect(find.byType(ListTile), findsNWidgets(6));

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
    expect(tester.widget<FilledButton>(find.byKey(const Key('call-student'))).onPressed, isNull);
  });

  testWidgets('calls exactly the selected contact through the adapter', (tester) async {
    final action = RecordingContactAction();
    const student = Student(
      id: 'test-student', classId: 'test-class', fullName: 'Тестова Учениця', room: '1', sport: 'Тест', phone: '+380000000001',
      contacts: [Contact(id: 'test-adult', name: 'Тестова Представниця', role: 'Представниця', phone: '+380000000002')],
    );
    await tester.pumpWidget(MaterialApp(home: StudentDetail(student: student, className: 'Тест', contactAction: action)));
    await tester.tap(find.byKey(const Key('call-test-adult')));
    await tester.pump();
    expect(action.calls, ['+380000000002']);
  });
}
