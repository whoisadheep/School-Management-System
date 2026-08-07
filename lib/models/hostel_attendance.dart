import 'dart:convert';

class HostelAttendance {
  final String id;
  final String studentId;
  final String date;
  final String status;
  final String markedBy;

  const HostelAttendance({
    required this.id,
    required this.studentId,
    required this.date,
    required this.status,
    required this.markedBy,
  });

  HostelAttendance copyWith({
    String? id,
    String? studentId,
    String? date,
    String? status,
    String? markedBy,
  }) {
    return HostelAttendance(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      date: date ?? this.date,
      status: status ?? this.status,
      markedBy: markedBy ?? this.markedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'date': date,
      'status': status,
      'marked_by': markedBy,
    };
  }

  factory HostelAttendance.fromMap(Map<String, dynamic> map) {
    return HostelAttendance(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      date: map['date'] as String,
      status: map['status'] as String,
      markedBy: map['marked_by'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory HostelAttendance.fromJson(String source) =>
      HostelAttendance.fromMap(json.decode(source) as Map<String, dynamic>);
}
