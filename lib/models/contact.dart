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
}
