import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../models/student.dart';
import '../services/contact_action.dart';

class StudentDetail extends StatelessWidget {
  const StudentDetail({required this.student, required this.className, required this.contactAction, this.embedded = false, super.key});
  final Student student;
  final String className;
  final ContactAction contactAction;
  final bool embedded;

  Future<void> _call(BuildContext context, String phone) async {
    final result = await contactAction.call(phone);
    if (!context.mounted || result != ContactActionResult.copied) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Телефонний застосунок недоступний. Номер скопійовано.')));
  }

  @override
  Widget build(BuildContext context) {
    final content = ListView(padding: const EdgeInsets.all(20), children: [
      Text(student.fullName, key: const Key('student-full-name'), style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8), Text('$className • Кімната ${student.room} • ${student.sport}'),
      const SizedBox(height: 20), Text(student.hasPhone ? student.phone! : 'Номер не додано', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8), FilledButton.icon(key: const Key('call-student'), icon: const Icon(Icons.phone), label: const Text('Зателефонувати учню'), onPressed: student.hasPhone ? () => _call(context, student.phone!) : null),
      const SizedBox(height: 28), Text('Контактні особи', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8),
      ...student.contacts.map((contact) => _ContactTile(contact: contact, onCall: contact.hasPhone ? () => _call(context, contact.phone!) : null)),
    ]);
    return embedded ? content : Scaffold(appBar: AppBar(title: const Text('Картка учня')), body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: content)));
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onCall});
  final Contact contact;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) => Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), title: Text(contact.name), subtitle: Text('${contact.role}\n${contact.hasPhone ? contact.phone : 'Номер не додано'}'), isThreeLine: true, trailing: IconButton(key: Key('call-${contact.id}'), tooltip: contact.hasPhone ? 'Зателефонувати: ${contact.name}' : 'Номер не додано', icon: const Icon(Icons.phone_outlined), onPressed: onCall)));
}
