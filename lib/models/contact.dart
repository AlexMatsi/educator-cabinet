class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.role,
    this.phone,
  });

  final String id;
  final String name;
  final String role;
  final String? phone;

  bool get hasPhone => phone?.trim().isNotEmpty ?? false;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'phone': phone,
  };

  factory Contact.fromJson(Map<String, Object?> json) => Contact(
    id: json['id'] as String,
    name: json['name'] as String,
    role: json['role'] as String,
    phone: json['phone'] as String?,
  );
}
