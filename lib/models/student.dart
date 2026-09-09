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

  factory Student.fromJson(Map<String, Object?> json) {
    final contacts = json['contacts'];
    if (contacts is! List) {
      throw const FormatException('Поле "contacts" має містити список.');
    }
    return Student(
      id: json.requiredString('id'),
      classId: json.requiredString('classId'),
      fullName: json.requiredString('fullName'),
      room: json.requiredString('room'),
      sport: json.requiredString('sport'),
      phone: json.optionalString('phone'),
      contacts: contacts.map((item) => Contact.fromJson(item.jsonObject())).toList(),
    );
  }
}

extension on Map<String, Object?> {
  String requiredString(String key) {
    final value = this[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Поле "$key" має містити непорожній рядок.');
    }
    return value;
  }

  String? optionalString(String key) {
    final value = this[key];
    if (value != null && value is! String) {
      throw FormatException('Поле "$key" має містити рядок або null.');
    }
    return value as String?;
  }
}

extension on Object? {
  Map<String, Object?> jsonObject() {
    if (this case final Map<dynamic, dynamic> value) {
      return Map<String, Object?>.from(value);
    }
    throw const FormatException('Елемент JSON має містити об’єкт.');
  }
}
