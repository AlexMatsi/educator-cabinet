class StudentClass {
  const StudentClass({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  factory StudentClass.fromJson(Map<String, Object?> json) => StudentClass(
    id: json.requiredString('id'),
    name: json.requiredString('name'),
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
}
