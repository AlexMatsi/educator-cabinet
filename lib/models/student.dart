import 'contact.dart';

class Student {
  const Student({
    required this.id,
    required this.classId,
    required this.fullName,
    required this.room,
    required this.sport,
    required this.contacts,
    this.phone,
  });

  final String id;
  final String classId;
  final String fullName;
  final String room;
  final String sport;
  final String? phone;
  final List<Contact> contacts;

  bool get hasPhone => phone?.trim().isNotEmpty ?? false;
}
