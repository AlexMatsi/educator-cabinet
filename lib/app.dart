import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/demo_repository.dart';
import 'models/student.dart';
import 'services/contact_action.dart';
import 'widgets/student_detail.dart';
import 'widgets/student_list.dart';

class EducatorCabinetApp extends StatelessWidget {
  const EducatorCabinetApp({required this.contactAction, super.key});
  final ContactAction contactAction;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Кабінет вихователя',
    locale: const Locale('uk'),
    supportedLocales: const [Locale('uk')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    debugShowCheckedModeBanner: false,
    themeMode: ThemeMode.system,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xff356859),
      brightness: Brightness.light,
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorSchemeSeed: const Color(0xff79b8a4),
      brightness: Brightness.dark,
      useMaterial3: true,
    ),
    home: StudentsScreen(contactAction: contactAction),
  );
}

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({required this.contactAction, super.key});
  final ContactAction contactAction;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final repository = const DemoRepository();
  String? classId;
  String query = '';
  Student? selected;

  void openStudent(Student student, bool wide) {
    if (wide) {
      setState(() => selected = student);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StudentDetail(
            student: student,
            className: repository.className(student.classId),
            contactAction: widget.contactAction,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Учні'),
      actions: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text('ДЕМО', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        final list = StudentList(
          repository: repository,
          selectedClassId: classId,
          query: query,
          selectedStudentId: selected?.id,
          onClassChanged: (value) => setState(() {
            classId = value;
            selected = null;
          }),
          onQueryChanged: (value) => setState(() => query = value),
          onStudentTap: (student) => openStudent(student, wide),
          onCall: (student) => _call(student.phone, student.hasPhone),
        );
        if (!wide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: list,
            ),
          );
        }
        return Row(
          children: [
            Expanded(child: list),
            const VerticalDivider(width: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: selected == null
                      ? const Text('Оберіть учня, щоб відкрити картку')
                      : StudentDetail(
                          student: selected!,
                          className: repository.className(selected!.classId),
                          contactAction: widget.contactAction,
                          embedded: true,
                        ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _call(String? phone, bool enabled) async {
    if (!enabled || phone == null) return;
    final result = await widget.contactAction.call(phone);
    if (!mounted || result == ContactActionResult.openedDialer) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(contactActionMessage(result))));
  }
}
