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
    this.archivedAt,
  });

  final String id;
  final String classId;
  final String fullName;
  final String room;
  final String sport;
  final String? phone;
  final List<Contact> contacts;
  final DateTime? archivedAt;

  bool get hasPhone => phone?.trim().isNotEmpty ?? false;
  bool get isArchived => archivedAt != null;

  Student copyWith({
    String? classId,
    String? fullName,
    String? room,
    String? sport,
    String? phone,
    bool clearPhone = false,
    List<Contact>? contacts,
    DateTime? archivedAt,
    bool restore = false,
  }) => Student(
    id: id,
    classId: classId ?? this.classId,
    fullName: fullName ?? this.fullName,
    room: room ?? this.room,
    sport: sport ?? this.sport,
    phone: clearPhone ? null : phone ?? this.phone,
    contacts: contacts ?? this.contacts,
    archivedAt: restore ? null : archivedAt ?? this.archivedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'classId': classId,
    'fullName': fullName,
    'room': room,
    'sport': sport,
    'phone': phone,
    'contacts': contacts.map((contact) => contact.toJson()).toList(),
    'archivedAt': archivedAt?.toIso8601String(),
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
    archivedAt: json['archivedAt'] == null
        ? null
        : DateTime.parse(json['archivedAt'] as String),
  );
}
