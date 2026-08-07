import 'dart:convert';
import 'package:uuid/uuid.dart';

/// GradeScale model defining percentage thresholds, letter grades, and grade points
class GradeScale {
  final String id;
  final String academicYear;
  final double minPercent;
  final double maxPercent;
  final String grade; // e.g. "A+", "A", "B", "F"
  final double? gradePoint; // e.g. 4.0, 3.5, 0.0

  const GradeScale({
    required this.id,
    required this.academicYear,
    required this.minPercent,
    required this.maxPercent,
    required this.grade,
    this.gradePoint,
  });

  factory GradeScale.create({
    required String academicYear,
    required double minPercent,
    required double maxPercent,
    required String grade,
    double? gradePoint,
  }) {
    return GradeScale(
      id: const Uuid().v4(),
      academicYear: academicYear,
      minPercent: minPercent,
      maxPercent: maxPercent,
      grade: grade,
      gradePoint: gradePoint,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'academic_year': academicYear,
      'min_percent': minPercent,
      'max_percent': maxPercent,
      'grade': grade,
      'grade_point': gradePoint,
    };
  }

  factory GradeScale.fromMap(Map<String, dynamic> map) {
    return GradeScale(
      id: map['id'] as String,
      academicYear: (map['academic_year'] as String?) ?? '2024-2025',
      minPercent: (map['min_percent'] as num).toDouble(),
      maxPercent: (map['max_percent'] as num).toDouble(),
      grade: map['grade'] as String,
      gradePoint: map['grade_point'] != null ? (map['grade_point'] as num).toDouble() : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory GradeScale.fromJson(String source) =>
      GradeScale.fromMap(json.decode(source) as Map<String, dynamic>);

  GradeScale copyWith({
    String? id,
    String? academicYear,
    double? minPercent,
    double? maxPercent,
    String? grade,
    double? gradePoint,
  }) {
    return GradeScale(
      id: id ?? this.id,
      academicYear: academicYear ?? this.academicYear,
      minPercent: minPercent ?? this.minPercent,
      maxPercent: maxPercent ?? this.maxPercent,
      grade: grade ?? this.grade,
      gradePoint: gradePoint ?? this.gradePoint,
    );
  }
}
