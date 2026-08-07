import 'dart:convert';
import 'package:uuid/uuid.dart';

/// ExamSubject model representing a subject paper within an exam
class ExamSubject {
  final String id;
  final String examId;
  final String subject;
  final DateTime examDate;
  final double maxMarks;
  final double passingMarks;
  final String? staffId; // Teacher responsible for paper/marks entry

  // Enriched fields
  final String? staffName;
  final String? examName;

  const ExamSubject({
    required this.id,
    required this.examId,
    required this.subject,
    required this.examDate,
    required this.maxMarks,
    required this.passingMarks,
    this.staffId,
    this.staffName,
    this.examName,
  });

  factory ExamSubject.create({
    required String examId,
    required String subject,
    required DateTime examDate,
    required double maxMarks,
    required double passingMarks,
    String? staffId,
    String? staffName,
    String? examName,
  }) {
    return ExamSubject(
      id: const Uuid().v4(),
      examId: examId,
      subject: subject,
      examDate: examDate,
      maxMarks: maxMarks,
      passingMarks: passingMarks,
      staffId: staffId,
      staffName: staffName,
      examName: examName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exam_id': examId,
      'subject': subject,
      'exam_date': examDate.toIso8601String(),
      'max_marks': maxMarks,
      'passing_marks': passingMarks,
      'staff_id': staffId,
    };
  }

  factory ExamSubject.fromMap(Map<String, dynamic> map) {
    return ExamSubject(
      id: map['id'] as String,
      examId: map['exam_id'] as String,
      subject: map['subject'] as String,
      examDate: DateTime.parse(map['exam_date'] as String),
      maxMarks: (map['max_marks'] as num).toDouble(),
      passingMarks: (map['passing_marks'] as num).toDouble(),
      staffId: map['staff_id'] as String?,
      staffName: map['staff_name'] as String?,
      examName: map['exam_name'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory ExamSubject.fromJson(String source) =>
      ExamSubject.fromMap(json.decode(source) as Map<String, dynamic>);

  ExamSubject copyWith({
    String? id,
    String? examId,
    String? subject,
    DateTime? examDate,
    double? maxMarks,
    double? passingMarks,
    String? staffId,
    String? staffName,
    String? examName,
  }) {
    return ExamSubject(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      subject: subject ?? this.subject,
      examDate: examDate ?? this.examDate,
      maxMarks: maxMarks ?? this.maxMarks,
      passingMarks: passingMarks ?? this.passingMarks,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      examName: examName ?? this.examName,
    );
  }
}
