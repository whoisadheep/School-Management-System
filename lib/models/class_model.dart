import 'dart:convert';

class ClassModel {
  final String id;
  final String name; // e.g. "Class 8" or "Grade 10"
  final String? academicYear;
  final int? capacity;
  final DateTime createdAt;

  const ClassModel({
    required this.id,
    required this.name,
    this.academicYear,
    this.capacity,
    required this.createdAt,
  });

  ClassModel copyWith({
    String? id,
    String? name,
    String? academicYear,
    int? capacity,
    DateTime? createdAt,
  }) {
    return ClassModel(
      id: id ?? this.id,
      name: name ?? this.name,
      academicYear: academicYear ?? this.academicYear,
      capacity: capacity ?? this.capacity,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'academic_year': academicYear,
      'capacity': capacity,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ClassModel.fromMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'] as String,
      name: map['name'] as String,
      academicYear: map['academic_year'] as String?,
      capacity: map['capacity'] as int?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory ClassModel.fromJson(String source) =>
      ClassModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
