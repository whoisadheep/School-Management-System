import 'dart:convert';

class StudentAttendance {
  final String id;
  final String studentId;
  final String className; // "class" is a reserved keyword in Dart
  final String section;
  final String date;
  final String status;
  final String markedBy;
  final String markedAt;
  final String? remarks;
  final String? correctedBy;
  final String? correctedAt;

  const StudentAttendance({
    required this.id,
    required this.studentId,
    required this.className,
    required this.section,
    required this.date,
    required this.status,
    required this.markedBy,
    required this.markedAt,
    this.remarks,
    this.correctedBy,
    this.correctedAt,
  });

  StudentAttendance copyWith({
    String? id,
    String? studentId,
    String? className,
    String? section,
    String? date,
    String? status,
    String? markedBy,
    String? markedAt,
    String? remarks,
    String? correctedBy,
    String? correctedAt,
  }) {
    return StudentAttendance(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      className: className ?? this.className,
      section: section ?? this.section,
      date: date ?? this.date,
      status: status ?? this.status,
      markedBy: markedBy ?? this.markedBy,
      markedAt: markedAt ?? this.markedAt,
      remarks: remarks ?? this.remarks,
      correctedBy: correctedBy ?? this.correctedBy,
      correctedAt: correctedAt ?? this.correctedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'class': className,
      'section': section,
      'date': date,
      'status': status,
      'marked_by': markedBy,
      'marked_at': markedAt,
      'remarks': remarks,
      'corrected_by': correctedBy,
      'corrected_at': correctedAt,
    };
  }

  factory StudentAttendance.fromMap(Map<String, dynamic> map) {
    return StudentAttendance(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      className: map['class'] as String,
      section: map['section'] as String,
      date: map['date'] as String,
      status: map['status'] as String,
      markedBy: map['marked_by'] as String,
      markedAt: map['marked_at'] as String,
      remarks: map['remarks'] as String?,
      correctedBy: map['corrected_by'] as String?,
      correctedAt: map['corrected_at'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory StudentAttendance.fromJson(String source) =>
      StudentAttendance.fromMap(json.decode(source) as Map<String, dynamic>);
}
