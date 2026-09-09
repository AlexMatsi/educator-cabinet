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

  Map<String, Object?> toJson() => {
    'id': id,
    'classId': classId,
    'fullName': fullName,
    'room': room,
    'sport': sport,
    'phone': phone,
    'contacts': contacts.map((contact) => contact.toJson()).toList(),
  };

  factory Student.fromJson(Map<String, Object?> json) => Student(
    id: json['id'] as String,
    classId: json['classId'] as String,
    fullName: json['fullName'] as String,
    room: json['room'] as String,
    sport: json['sport'] as String,
    phone: json['phone'] as String?,
    contacts: (json['contacts'] as List<Object?>)
        .map((item) => Contact.fromJson(item as Map<String, Object?>))
        .toList(growable: false),
  );
}
