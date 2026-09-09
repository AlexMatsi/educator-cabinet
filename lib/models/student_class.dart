class StudentClass {
  const StudentClass({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  factory StudentClass.fromJson(Map<String, Object?> json) => StudentClass(
    id: json['id'] as String,
    name: json['name'] as String,
  );
}
