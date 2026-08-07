import 'dart:convert';

class Outpass {
  final String id;
  final String studentId;
  final String reason;
  final String outDate;
  final String expectedReturnDate;
  final String? actualReturnDate;
  final String? approvedBy;
  final String status;

  const Outpass({
    required this.id,
    required this.studentId,
    required this.reason,
    required this.outDate,
    required this.expectedReturnDate,
    this.actualReturnDate,
    this.approvedBy,
    required this.status,
  });

  Outpass copyWith({
    String? id,
    String? studentId,
    String? reason,
    String? outDate,
    String? expectedReturnDate,
    String? actualReturnDate,
    String? approvedBy,
    String? status,
  }) {
    return Outpass(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      reason: reason ?? this.reason,
      outDate: outDate ?? this.outDate,
      expectedReturnDate: expectedReturnDate ?? this.expectedReturnDate,
      actualReturnDate: actualReturnDate ?? this.actualReturnDate,
      approvedBy: approvedBy ?? this.approvedBy,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'reason': reason,
      'out_date': outDate,
      'expected_return_date': expectedReturnDate,
      'actual_return_date': actualReturnDate,
      'approved_by': approvedBy,
      'status': status,
    };
  }

  factory Outpass.fromMap(Map<String, dynamic> map) {
    return Outpass(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      reason: map['reason'] as String,
      outDate: map['out_date'] as String,
      expectedReturnDate: map['expected_return_date'] as String,
      actualReturnDate: map['actual_return_date'] as String?,
      approvedBy: map['approved_by'] as String?,
      status: map['status'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory Outpass.fromJson(String source) =>
      Outpass.fromMap(json.decode(source) as Map<String, dynamic>);
}
