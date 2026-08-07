import 'dart:convert';

class ClassTeacherAssignment {
  final String id;
  final String staffId;
  final String classAssigned;
  final String section;
  final String academicYear;

  const ClassTeacherAssignment({
    required this.id,
    required this.staffId,
    required this.classAssigned,
    required this.section,
    required this.academicYear,
  });

  ClassTeacherAssignment copyWith({
    String? id,
    String? staffId,
    String? classAssigned,
    String? section,
    String? academicYear,
  }) {
    return ClassTeacherAssignment(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      classAssigned: classAssigned ?? this.classAssigned,
      section: section ?? this.section,
      academicYear: academicYear ?? this.academicYear,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staff_id': staffId,
      'class': classAssigned,
      'section': section,
      'academic_year': academicYear,
    };
  }

  factory ClassTeacherAssignment.fromMap(Map<String, dynamic> map) {
    return ClassTeacherAssignment(
      id: map['id'] as String,
      staffId: map['staff_id'] as String,
      classAssigned: map['class'] as String,
      section: map['section'] as String,
      academicYear: map['academic_year'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ClassTeacherAssignment.fromJson(String source) =>
      ClassTeacherAssignment.fromMap(json.decode(source) as Map<String, dynamic>);
}
