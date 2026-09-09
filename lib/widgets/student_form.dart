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
  const StudentForm({required this.classes, this.student, super.key});
  final List<StudentClass> classes;
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
    name.dispose(); room.dispose(); sport.dispose(); phone.dispose();
    super.dispose();
  }

  Future<void> _contact([Contact? existing]) async {
    final result = await showDialog<Contact>(
      context: context,
      builder: (_) => _ContactDialog(contact: existing),
    );
    if (result == null) return;
    setState(() {
      final index = contacts.indexWhere((item) => item.id == result.id);
      if (index < 0) contacts.add(result); else contacts[index] = result;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.student == null ? 'Новий учень' : 'Редагування учня')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            key: const Key('student-name-field'), controller: name,
            decoration: const InputDecoration(labelText: 'ПІБ *', border: OutlineInputBorder()),
            validator: (value) => value == null || value.trim().isEmpty ? 'Введіть ПІБ учня' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('student-class-field'), initialValue: classId,
            decoration: const InputDecoration(labelText: 'Клас *', border: OutlineInputBorder()),
            items: widget.classes.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
            onChanged: (value) => classId = value!,
          ),
          const SizedBox(height: 12),
          TextField(controller: sport, decoration: const InputDecoration(labelText: 'Спорт', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: room, decoration: const InputDecoration(labelText: 'Кімната', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Телефон учня', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          Text('Контакти дорослих', style: Theme.of(context).textTheme.titleMedium),
          ...contacts.map((item) => ListTile(
            title: Text(item.name), subtitle: Text('${item.role} • ${item.phone ?? 'Номер не додано'}'),
            trailing: const Icon(Icons.edit_outlined), onTap: () => _contact(item),
          )),
          OutlinedButton.icon(onPressed: _contact, icon: const Icon(Icons.add), label: const Text('Додати контакт')),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('save-student'),
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              Navigator.pop(context, StudentFormResult(
                isNew: widget.student == null,
                student: Student(
                  id: widget.student?.id ?? '', classId: classId, fullName: name.text,
                  room: room.text, sport: sport.text, phone: phone.text, contacts: contacts,
                  archivedAt: widget.student?.archivedAt,
                ),
              ));
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    ),
  );
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({this.contact});
  final Contact? contact;
  @override State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late final name = TextEditingController(text: widget.contact?.name);
  late final role = TextEditingController(text: widget.contact?.role);
  late final phone = TextEditingController(text: widget.contact?.phone);
  @override void dispose() { name.dispose(); role.dispose(); phone.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(
    title: const Text('Контакт дорослого'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: "Ім'я")),
      TextField(controller: role, decoration: const InputDecoration(labelText: 'Роль / зв’язок')),
      TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Телефон')),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')), FilledButton(
      onPressed: () {
        if (name.text.trim().isEmpty || role.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Введіть ім'я та роль контакту.")));
          return;
        }
        Navigator.pop(context, Contact(
          id: widget.contact?.id ?? 'contact-${DateTime.now().microsecondsSinceEpoch}', name: name.text.trim(), role: role.text.trim(),
          phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
        ));
      }, child: const Text('Готово'))],
  );
}
