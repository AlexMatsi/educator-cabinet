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
    id: json.requiredString('id'),
    name: json.requiredString('name'),
    role: json.requiredString('role'),
    phone: json.optionalString('phone'),
  );
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
