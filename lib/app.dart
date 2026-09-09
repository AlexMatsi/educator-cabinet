import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/student_repository.dart';
import 'models/student.dart';
import 'models/student_directory.dart';
import 'services/contact_action.dart';
import 'widgets/student_detail.dart';
import 'widgets/student_list.dart';

class EducatorCabinetApp extends StatelessWidget {
  const EducatorCabinetApp({
    required this.contactAction,
    required this.repository,
    super.key,
  });
  final ContactAction contactAction;
  final StudentRepository repository;

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
    home: StudentsScreen(contactAction: contactAction, repository: repository),
  );
}

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({
    required this.contactAction,
    required this.repository,
    super.key,
  });
  final ContactAction contactAction;
  final StudentRepository repository;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  StudentDirectory? directory;
  String? storageError;
  String? classId;
  String query = '';
  Student? selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => storageError = null);
    try {
      final loaded = await widget.repository.load();
      if (!mounted) return;
      setState(() => directory = loaded);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        storageError =
            'Не вдалося завантажити локальні дані. Перевірте сховище та спробуйте ще раз.';
      });
    }
  }

  void openStudent(Student student, bool wide) {
    if (wide) {
      setState(() => selected = student);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StudentDetail(
            student: student,
            className: directory!.className(student.classId),
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
    body: directory == null
        ? _StorageStatus(error: storageError, onRetry: _load)
        : LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 800;
              final list = StudentList(
                directory: directory!,
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
                                className: directory!.className(
                                  selected!.classId,
                                ),
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

class _StorageStatus extends StatelessWidget {
  const _StorageStatus({required this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: error == null
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Завантажуємо локальні дані…'),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_outlined, size: 48),
                const SizedBox(height: 16),
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Спробувати ще раз'),
                ),
              ],
            ),
    ),
  );
}
