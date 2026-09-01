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
      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'] as String) ?? DateTime(2024, 6, 1)
          : DateTime(2024, 6, 1),
      endDate: map['end_date'] != null
          ? DateTime.tryParse(map['end_date'] as String) ?? DateTime(2025, 4, 30)
          : DateTime(2025, 4, 30),
      isCurrent: (map['is_current'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
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
