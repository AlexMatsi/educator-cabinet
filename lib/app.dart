import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/student_repository.dart';
import 'data/student_administration.dart';
import 'models/student.dart';
import 'models/student_data.dart';
import 'services/contact_action.dart';
import 'widgets/student_detail.dart';
import 'widgets/student_list.dart';
import 'widgets/student_form.dart';

class EducatorCabinetApp extends StatelessWidget {
  const EducatorCabinetApp({
    required this.contactAction,
    required this.studentRepository,
    super.key,
  });
  final ContactAction contactAction;
  final StudentRepository studentRepository;

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
    home: StudentsScreen(
      contactAction: contactAction,
      studentRepository: studentRepository,
    ),
  );
}

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({
    required this.contactAction,
    required this.studentRepository,
    super.key,
  });
  final ContactAction contactAction;
  final StudentRepository studentRepository;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  StudentData? data;
  String? classId;
  String query = '';
  Student? selected;
  Object? loadError;
  late final StudentAdministration administration = StudentAdministration(
    repository: widget.studentRepository,
    ids: TimestampIdGenerator(),
  );

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      data = null;
      loadError = null;
    });
    try {
      final loaded = await widget.studentRepository.load();
      if (mounted) setState(() => data = loaded);
    } on Object catch (error) {
      if (mounted) setState(() => loadError = error);
    }
  }

  String className(String id) =>
      data!.classes.firstWhere((item) => item.id == id).name;

  void openStudent(Student student, bool wide) {
    if (wide) {
      setState(() => selected = student);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StudentDetail(
            student: student,
            className: className(student.classId),
            contactAction: widget.contactAction,
            onEdit: () =>
                _editStudent(student: student, closeDetailsOnSuccess: true),
            onArchive: () =>
                _confirmArchiveStudent(student, closeDetailsOnSuccess: true),
          ),
        ),
      );
    }
  }

  Future<bool> _commit(Future<StudentData> Function() operation) async {
    try {
      final saved = await operation();
      if (!mounted) return true;
      final activeClassIds = saved.classes
          .where((item) => !item.isArchived)
          .map((item) => item.id)
          .toSet();
      setState(() {
        data = saved;
        if (classId != null && !activeClassIds.contains(classId)) {
          classId = null;
        }
        final selectedId = selected?.id;
        selected = selectedId == null
            ? null
            : saved.students
                  .where((item) => item.id == selectedId && !item.isArchived)
                  .firstOrNull;
      });
      return true;
    } on Object catch (error) {
      if (!mounted) return false;
      final message = error is StudentValidationException
          ? error.message
          : 'Не вдалося зберегти зміни. Попередні дані залишено.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Повторити',
            onPressed: () => _commit(operation),
          ),
        ),
      );
      return false;
    }
  }

  Future<void> _editStudent({
    Student? student,
    bool closeDetailsOnSuccess = false,
  }) async {
    final active = data!.classes.where((item) => !item.isArchived).toList();
    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Спочатку створіть активний клас.')),
      );
      return;
    }
    final result = await Navigator.of(context).push<StudentFormResult>(
      MaterialPageRoute(
        builder: (_) => StudentForm(
          classes: active,
          student: student,
          nextContactId: () => administration.newContactId(data!),
        ),
      ),
    );
    if (result == null || !mounted) return;
    final saved = await _commit(
      () => result.isNew
          ? administration.createStudent(
              data!,
              fullName: result.student.fullName,
              classId: result.student.classId,
              room: result.student.room,
              sport: result.student.sport,
              phone: result.student.phone,
              contacts: result.student.contacts,
            )
          : administration.updateStudent(data!, result.student),
    );
    if (saved && closeDetailsOnSuccess && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Скасувати'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Підтвердити'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _confirmArchiveStudent(
    Student student, {
    bool closeDetailsOnSuccess = false,
  }) async {
    if (!await _confirm(
      'Архівувати учня?',
      'Учень зникне з активного списку, але запис можна буде відновити.',
    )) {
      return;
    }
    final saved = await _commit(
      () => administration.archiveStudent(data!, student.id),
    );
    if (saved && closeDetailsOnSuccess && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _manageClasses() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, refresh) => AlertDialog(
          title: const Text('Керування класами'),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: data!.classes
                  .map(
                    (item) => ListTile(
                      title: Text(item.name),
                      subtitle: Text(item.isArchived ? 'В архіві' : 'Активний'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'rename') {
                            final name = await _askName(
                              'Перейменувати клас',
                              item.name,
                            );
                            if (name != null) {
                              await _commit(
                                () => administration.renameClass(
                                  data!,
                                  item.id,
                                  name,
                                ),
                              );
                            }
                          }
                          if (action == 'archive' &&
                              await _confirm(
                                'Архівувати клас?',
                                'Клас можна буде відновити з архіву.',
                              )) {
                            await _commit(
                              () => administration.archiveClass(data!, item.id),
                            );
                          }
                          if (action == 'restore') {
                            await _commit(
                              () => administration.restoreClass(data!, item.id),
                            );
                          }
                          refresh(() {});
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Text('Перейменувати'),
                          ),
                          PopupMenuItem(
                            value: item.isArchived ? 'restore' : 'archive',
                            child: Text(
                              item.isArchived ? 'Відновити' : 'Архівувати',
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final name = await _askName('Новий клас', '');
                if (name != null) {
                  await _commit(() => administration.createClass(data!, name));
                  refresh(() {});
                }
              },
              child: const Text('Додати клас'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askName(String title, String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Назва класу'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _openArchive() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, refresh) {
          final archived = data!.students
              .where((item) => item.isArchived)
              .toList();
          return AlertDialog(
            title: const Text('Архів учнів'),
            content: SizedBox(
              width: 440,
              child: archived.isEmpty
                  ? const Text('Архів порожній')
                  : ListView(
                      shrinkWrap: true,
                      children: archived
                          .map(
                            (student) => ListTile(
                              title: Text(student.fullName),
                              subtitle: Text(
                                'Архівовано: ${student.archivedAt!.toLocal().toString().split(' ').first}',
                              ),
                              trailing: TextButton(
                                onPressed: () async {
                                  await _commit(
                                    () => administration.restoreStudent(
                                      data!,
                                      student.id,
                                    ),
                                  );
                                  refresh(() {});
                                },
                                child: const Text('Відновити'),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Закрити'),
              ),
            ],
          );
        },
      ),
    );
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
    body: loadError != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Не вдалося завантажити дані учнів. '
                    'Збережені дані не змінено.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('retry-student-load'),
                    onPressed: _loadStudents,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Спробувати ще раз'),
                  ),
                ],
              ),
            ),
          )
        : data == null
        ? const Center(child: CircularProgressIndicator())
        : LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 800;
              final list = StudentList(
                data: data!,
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
                onAddStudent: () => _editStudent(),
                onManageClasses: _manageClasses,
                onOpenArchive: _openArchive,
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
                                className: className(selected!.classId),
                                contactAction: widget.contactAction,
                                embedded: true,
                                onEdit: () => _editStudent(student: selected),
                                onArchive: () =>
                                    _confirmArchiveStudent(selected!),
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
