import 'dart:convert';
import 'package:uuid/uuid.dart';

class StudentDiscount {
  final String id;
  final String studentId;
  final String discountTypeId;
  final String academicYear;
  final String? approvedBy;
  final String? remarks;

  const StudentDiscount({
    required this.id,
    required this.studentId,
    required this.discountTypeId,
    required this.academicYear,
    this.approvedBy,
    this.remarks,
  });

  factory StudentDiscount.create({
    required String studentId,
    required String discountTypeId,
    required String academicYear,
    String? approvedBy,
    String? remarks,
  }) {
    return StudentDiscount(
      id: const Uuid().v4(),
      studentId: studentId,
      discountTypeId: discountTypeId,
      academicYear: academicYear,
      approvedBy: approvedBy,
      remarks: remarks,
    );
  }

  StudentDiscount copyWith({
    String? id,
    String? studentId,
    String? discountTypeId,
    String? academicYear,
    String? approvedBy,
    String? remarks,
  }) {
    return StudentDiscount(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      discountTypeId: discountTypeId ?? this.discountTypeId,
      academicYear: academicYear ?? this.academicYear,
      approvedBy: approvedBy ?? this.approvedBy,
      remarks: remarks ?? this.remarks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'discount_type_id': discountTypeId,
      'academic_year': academicYear,
      'approved_by': approvedBy,
      'remarks': remarks,
    };
  }

  factory StudentDiscount.fromMap(Map<String, dynamic> map) {
    return StudentDiscount(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      discountTypeId: map['discount_type_id'] as String,
      academicYear: map['academic_year'] as String,
      approvedBy: map['approved_by'] as String?,
      remarks: map['remarks'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory StudentDiscount.fromJson(String source) =>
      StudentDiscount.fromMap(json.decode(source) as Map<String, dynamic>);
}
