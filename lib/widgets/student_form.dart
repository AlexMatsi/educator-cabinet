import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../models/student.dart';
import '../models/student_class.dart';

class StudentFormResult {
  const StudentFormResult({required this.student, required this.isNew});

  final Student student;
  final bool isNew;
}

class StudentForm extends StatefulWidget {
  const StudentForm({
    required this.classes,
    required this.nextContactId,
    this.student,
    super.key,
  });

  final List<StudentClass> classes;
  final String Function() nextContactId;
  final Student? student;

  @override
  State<StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<StudentForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController room;
  late final TextEditingController sport;
  late final TextEditingController phone;
  late String classId;
  late List<Contact> contacts;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    name = TextEditingController(text: student?.fullName);
    room = TextEditingController(text: student?.room);
    sport = TextEditingController(text: student?.sport);
    phone = TextEditingController(text: student?.phone);
    classId = student?.classId ?? widget.classes.first.id;
    contacts = [...?student?.contacts];
  }

  @override
  void dispose() {
    name.dispose();
    room.dispose();
    sport.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _editContact([Contact? existing]) async {
    final result = await showDialog<Contact>(
      context: context,
      builder: (_) => _ContactDialog(
        id: existing?.id ?? widget.nextContactId(),
        contact: existing,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final index = contacts.indexWhere((item) => item.id == result.id);
      if (index < 0) {
        contacts.add(result);
      } else {
        contacts[index] = result;
      }
    });
  }

  void _removeContact(Contact contact) {
    setState(() => contacts.removeWhere((item) => item.id == contact.id));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.student == null ? 'Новий учень' : 'Редагування учня'),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            key: const Key('student-name-field'),
            controller: name,
            decoration: const InputDecoration(
              labelText: 'ПІБ *',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Введіть ПІБ учня'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('student-class-field'),
            initialValue: classId,
            decoration: const InputDecoration(
              labelText: 'Клас *',
              border: OutlineInputBorder(),
            ),
            items: widget.classes
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) classId = value;
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: sport,
            decoration: const InputDecoration(
              labelText: 'Спорт',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: room,
            decoration: const InputDecoration(
              labelText: 'Кімната',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Телефон учня',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Контакти дорослих',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...contacts.map(
            (item) => ListTile(
              title: Text(item.name),
              subtitle: Text(
                '${item.role} • ${item.phone ?? 'Номер не додано'}',
              ),
              onTap: () => _editContact(item),
              trailing: IconButton(
                key: Key('remove-contact-${item.id}'),
                tooltip: 'Видалити контакт',
                onPressed: () => _removeContact(item),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
          OutlinedButton.icon(
            key: const Key('add-contact'),
            onPressed: _editContact,
            icon: const Icon(Icons.add),
            label: const Text('Додати контакт'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('save-student'),
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              final cleanPhone = phone.text.trim();
              Navigator.pop(
                context,
                StudentFormResult(
                  isNew: widget.student == null,
                  student: Student(
                    id: widget.student?.id ?? '',
                    classId: classId,
                    fullName: name.text.trim(),
                    room: room.text.trim(),
                    sport: sport.text.trim(),
                    phone: cleanPhone.isEmpty ? null : cleanPhone,
                    contacts: List.unmodifiable(contacts),
                    archivedAt: widget.student?.archivedAt,
                  ),
                ),
              );
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    ),
  );
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({required this.id, this.contact});

  final String id;
  final Contact? contact;

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.contact?.name);
  late final role = TextEditingController(text: widget.contact?.role);
  late final phone = TextEditingController(text: widget.contact?.phone);

  @override
  void dispose() {
    name.dispose();
    role.dispose();
    phone.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Контакт дорослого'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('contact-name-field'),
              controller: name,
              decoration: const InputDecoration(labelText: "Ім'я"),
              validator: (value) => _required(value, "Введіть ім'я контакту"),
            ),
            TextFormField(
              key: const Key('contact-role-field'),
              controller: role,
              decoration: const InputDecoration(labelText: 'Роль / зв’язок'),
              validator: (value) => _required(value, 'Введіть роль контакту'),
            ),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Телефон'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Скасувати'),
      ),
      FilledButton(
        key: const Key('save-contact'),
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          final cleanPhone = phone.text.trim();
          Navigator.pop(
            context,
            Contact(
              id: widget.id,
              name: name.text.trim(),
              role: role.text.trim(),
              phone: cleanPhone.isEmpty ? null : cleanPhone,
            ),
          );
        },
        child: const Text('Готово'),
      ),
    ],
  );
}
