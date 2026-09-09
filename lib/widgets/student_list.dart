import 'package:flutter/material.dart';

import '../models/student.dart';
import '../models/student_data.dart';

class StudentList extends StatelessWidget {
  const StudentList({
    required this.data,
    required this.selectedClassId,
    required this.query,
    required this.onClassChanged,
    required this.onQueryChanged,
    required this.onStudentTap,
    required this.onCall,
    this.selectedStudentId,
    super.key,
  });
  final StudentData data;
  final String? selectedClassId;
  final String query;
  final String? selectedStudentId;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Student> onStudentTap;
  final ValueChanged<Student> onCall;

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final students = data.students.where((student) {
      return (selectedClassId == null || student.classId == selectedClassId) &&
          (normalized.isEmpty ||
              student.fullName.toLowerCase().contains(normalized));
    }).toList(growable: false);
    String className(String id) =>
        data.classes.firstWhere((item) => item.id == id).name;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                key: const Key('class-selector'),
                initialValue: selectedClassId ?? 'all',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Клас',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('Усі мої класи'),
                  ),
                  ...data.classes.map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    onClassChanged(value == 'all' ? null : value),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('student-search'),
                onChanged: onQueryChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Пошук за ПІБ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: students.isEmpty
              ? const Center(child: Text('Учнів не знайдено'))
              : ListView.separated(
                  itemCount: students.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return ListTile(
                      key: Key('student-${student.id}'),
                      selected: student.id == selectedStudentId,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Text(student.fullName),
                      subtitle: Text(
                        '${className(student.classId)} • Кімната ${student.room}\n${student.sport}',
                      ),
                      isThreeLine: true,
                      onTap: () => onStudentTap(student),
                      trailing: IconButton(
                        icon: const Icon(Icons.phone_outlined),
                        tooltip: student.hasPhone
                            ? 'Зателефонувати учню'
                            : 'Номер не додано',
                        onPressed: student.hasPhone
                            ? () => onCall(student)
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
