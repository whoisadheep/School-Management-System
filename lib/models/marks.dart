import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Marks model representing a student's marks/attendance for a specific exam subject
class Marks {
  final String id;
  final String examSubjectId;
  final String studentId;
  final double? marksObtained;
  final bool isAbsent;
  final String? remarks;
  final String? enteredBy;
  final DateTime enteredAt;

  // Enriched fields for roster & report card display
  final String? studentName;
  final String? rollNumber;
  final String? gradeLevel;
  final String? section;
  final String? subject;
  final double? maxMarks;
  final double? passingMarks;
  final String? examName;

  const Marks({
    required this.id,
    required this.examSubjectId,
    required this.studentId,
    this.marksObtained,
    this.isAbsent = false,
    this.remarks,
    this.enteredBy,
    required this.enteredAt,
    this.studentName,
    this.rollNumber,
    this.gradeLevel,
    this.section,
    this.subject,
    this.maxMarks,
    this.passingMarks,
    this.examName,
  });

  factory Marks.create({
    required String examSubjectId,
    required String studentId,
    double? marksObtained,
    bool isAbsent = false,
    String? remarks,
    String? enteredBy,
    DateTime? enteredAt,
    String? studentName,
    String? rollNumber,
    String? gradeLevel,
    String? section,
    String? subject,
    double? maxMarks,
    double? passingMarks,
    String? examName,
  }) {
    final now = DateTime.now();
    return Marks(
      id: const Uuid().v4(),
      examSubjectId: examSubjectId,
      studentId: studentId,
      marksObtained: marksObtained,
      isAbsent: isAbsent,
      remarks: remarks,
      enteredBy: enteredBy,
      enteredAt: enteredAt ?? now,
      studentName: studentName,
      rollNumber: rollNumber,
      gradeLevel: gradeLevel,
      section: section,
      subject: subject,
      maxMarks: maxMarks,
      passingMarks: passingMarks,
      examName: examName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exam_subject_id': examSubjectId,
      'student_id': studentId,
      'marks_obtained': marksObtained,
      'is_absent': isAbsent ? 1 : 0,
      'remarks': remarks,
      'entered_by': enteredBy,
      'entered_at': enteredAt.toIso8601String(),
    };
  }

  factory Marks.fromMap(Map<String, dynamic> map) {
    return Marks(
      id: map['id'] as String,
      examSubjectId: map['exam_subject_id'] as String,
      studentId: map['student_id'] as String,
      marksObtained: map['marks_obtained'] != null
          ? (map['marks_obtained'] as num).toDouble()
          : null,
      isAbsent: (map['is_absent'] as int?) == 1 || map['is_absent'] == true,
      remarks: map['remarks'] as String?,
      enteredBy: map['entered_by'] as String?,
      enteredAt: map['entered_at'] != null
          ? DateTime.tryParse(map['entered_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      studentName: map['student_name'] as String?,
      rollNumber: map['roll_number'] as String?,
      gradeLevel: map['grade_level'] as String?,
      section: map['section'] as String?,
      subject: map['subject'] as String?,
      maxMarks: map['max_marks'] != null ? (map['max_marks'] as num).toDouble() : null,
      passingMarks: map['passing_marks'] != null ? (map['passing_marks'] as num).toDouble() : null,
      examName: map['exam_name'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory Marks.fromJson(String source) =>
      Marks.fromMap(json.decode(source) as Map<String, dynamic>);

  bool get isPassed {
    if (isAbsent) return false;
    if (marksObtained == null || passingMarks == null) return false;
    return marksObtained! >= passingMarks!;
  }

  Marks copyWith({
    String? id,
    String? examSubjectId,
    String? studentId,
    double? marksObtained,
    bool? isAbsent,
    String? remarks,
    String? enteredBy,
    DateTime? enteredAt,
    String? studentName,
    String? rollNumber,
    String? gradeLevel,
    String? section,
    String? subject,
    double? maxMarks,
    double? passingMarks,
    String? examName,
  }) {
    return Marks(
      id: id ?? this.id,
      examSubjectId: examSubjectId ?? this.examSubjectId,
      studentId: studentId ?? this.studentId,
      marksObtained: marksObtained ?? this.marksObtained,
      isAbsent: isAbsent ?? this.isAbsent,
      remarks: remarks ?? this.remarks,
      enteredBy: enteredBy ?? this.enteredBy,
      enteredAt: enteredAt ?? this.enteredAt,
      studentName: studentName ?? this.studentName,
      rollNumber: rollNumber ?? this.rollNumber,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      section: section ?? this.section,
      subject: subject ?? this.subject,
      maxMarks: maxMarks ?? this.maxMarks,
      passingMarks: passingMarks ?? this.passingMarks,
      examName: examName ?? this.examName,
    );
  }
}
