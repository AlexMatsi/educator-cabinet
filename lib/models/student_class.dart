class StudentClass {
  const StudentClass({required this.id, required this.name, this.archivedAt});

  final String id;
  final String name;
  final DateTime? archivedAt;
  bool get isArchived => archivedAt != null;

  StudentClass copyWith({
    String? name,
    DateTime? archivedAt,
    bool restore = false,
  }) => StudentClass(
    id: id,
    name: name ?? this.name,
    archivedAt: restore ? null : archivedAt ?? this.archivedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'archivedAt': archivedAt?.toIso8601String(),
  };

  factory StudentClass.fromJson(Map<String, Object?> json) => StudentClass(
    id: json['id'] as String,
    name: json['name'] as String,
    archivedAt: json['archivedAt'] == null
        ? null
        : DateTime.parse(json['archivedAt'] as String),
  );
}
