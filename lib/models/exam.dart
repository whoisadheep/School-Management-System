import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Exam model representing an examination event for a class & section in an academic year
class Exam {
  final String id;
  final String examTypeId;
  final String name;
  final String className; // e.g. "Class 8" or "Grade 10"
  final String? section; // e.g. "A" or null for all sections
  final String academicYear;
  final DateTime startDate;
  final DateTime endDate;

  // Enriched field
  final String? examTypeName;

  const Exam({
    required this.id,
    required this.examTypeId,
    required this.name,
    required this.className,
    this.section,
    required this.academicYear,
    required this.startDate,
    required this.endDate,
    this.examTypeName,
  });

  factory Exam.create({
    required String examTypeId,
    required String name,
    required String className,
    String? section,
    required String academicYear,
    required DateTime startDate,
    required DateTime endDate,
    String? examTypeName,
  }) {
    return Exam(
      id: const Uuid().v4(),
      examTypeId: examTypeId,
      name: name,
      className: className,
      section: section,
      academicYear: academicYear,
      startDate: startDate,
      endDate: endDate,
      examTypeName: examTypeName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exam_type_id': examTypeId,
      'name': name,
      'class': className,
      'section': section,
      'academic_year': academicYear,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    };
  }

  factory Exam.fromMap(Map<String, dynamic> map) {
    return Exam(
      id: map['id'] as String,
      examTypeId: map['exam_type_id'] as String,
      name: map['name'] as String,
      className: (map['class'] as String?) ?? (map['grade_level'] as String?) ?? '',
      section: map['section'] as String?,
      academicYear: map['academic_year'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      examTypeName: map['exam_type_name'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory Exam.fromJson(String source) =>
      Exam.fromMap(json.decode(source) as Map<String, dynamic>);

  Exam copyWith({
    String? id,
    String? examTypeId,
    String? name,
    String? className,
    String? section,
    String? academicYear,
    DateTime? startDate,
    DateTime? endDate,
    String? examTypeName,
  }) {
    return Exam(
      id: id ?? this.id,
      examTypeId: examTypeId ?? this.examTypeId,
      name: name ?? this.name,
      className: className ?? this.className,
      section: section ?? this.section,
      academicYear: academicYear ?? this.academicYear,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      examTypeName: examTypeName ?? this.examTypeName,
    );
  }
}

/// Subject-level result entry in an exam
class SubjectResultItem {
  final String subject;
  final DateTime? examDate;
  final double maxMarks;
  final double passingMarks;
  final double? marksObtained;
  final bool isAbsent;
  final String grade;
  final double? gradePoint;
  final bool isPassed;
  final String? remarks;
  final String? teacherName;

  const SubjectResultItem({
    required this.subject,
    this.examDate,
    required this.maxMarks,
    required this.passingMarks,
    this.marksObtained,
    this.isAbsent = false,
    required this.grade,
    this.gradePoint,
    required this.isPassed,
    this.remarks,
    this.teacherName,
  });
}

/// Comprehensive exam result computation for a student
class ExamResultData {
  final String examId;
  final String examName;
  final String studentId;
  final String studentName;
  final String rollNumber;
  final String className;
  final String? section;
  final String academicYear;
  final List<SubjectResultItem> subjectResults;
  final double totalMarksObtained;
  final double totalMaxMarks;
  final double percentage;
  final String grade;
  final double? gradePoint;
  final bool isPassed;
  final int? rankInClass;
  final double? attendancePercent;

  const ExamResultData({
    required this.examId,
    required this.examName,
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.className,
    this.section,
    required this.academicYear,
    required this.subjectResults,
    required this.totalMarksObtained,
    required this.totalMaxMarks,
    required this.percentage,
    required this.grade,
    this.gradePoint,
    required this.isPassed,
    this.rankInClass,
    this.attendancePercent,
  });
}

/// Weighted term aggregation result across all exams in an academic year
class TermResultData {
  final String studentId;
  final String studentName;
  final String rollNumber;
  final String className;
  final String? section;
  final String academicYear;
  final List<ExamResultData> examResults;
  final double weightedPercentage;
  final String overallGrade;
  final double? overallGradePoint;
  final bool isPassed;

  const TermResultData({
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.className,
    this.section,
    required this.academicYear,
    required this.examResults,
    required this.weightedPercentage,
    required this.overallGrade,
    this.overallGradePoint,
    required this.isPassed,
  });
}

