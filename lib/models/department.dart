import 'dart:convert';

class Department {
  final String id;
  final String name;
  final DateTime createdAt;

  const Department({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  Department copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
  }) {
    return Department(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Department.fromMap(Map<String, dynamic> map) {
    return Department(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory Department.fromJson(String source) => Department.fromMap(json.decode(source) as Map<String, dynamic>);
}
