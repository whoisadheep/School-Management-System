import 'package:uuid/uuid.dart';

class AcademicYear {
  final String id;
  final String name; // e.g. "2025-2026"
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AcademicYear({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.isCurrent = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AcademicYear.create({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    bool isCurrent = false,
  }) {
    final now = DateTime.now();
    return AcademicYear(
      id: const Uuid().v4(),
      name: name,
      startDate: startDate,
      endDate: endDate,
      isCurrent: isCurrent,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory AcademicYear.fromMap(Map<String, dynamic> map) {
    return AcademicYear(
      id: map['id'] as String,
      name: map['name'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      isCurrent: (map['is_current'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_current': isCurrent ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
