import 'dart:convert';
import 'package:uuid/uuid.dart';

class StudentDiscount {
  final String id;
  final String studentId;
  final String discountTypeId;
  final String academicYear;
  final String? approvedBy;
  final String? remarks;
  final String? customName;
  final String? customKind; // 'percentage' or 'flat'
  final double? customValue;
  final String flatMode; // 'evenly' or 'earliest'

  const StudentDiscount({
    required this.id,
    required this.studentId,
    required this.discountTypeId,
    required this.academicYear,
    this.approvedBy,
    this.remarks,
    this.customName,
    this.customKind,
    this.customValue,
    this.flatMode = 'evenly',
  });

  factory StudentDiscount.create({
    required String studentId,
    required String discountTypeId,
    required String academicYear,
    String? approvedBy,
    String? remarks,
    String? customName,
    String? customKind,
    double? customValue,
    String flatMode = 'evenly',
  }) {
    return StudentDiscount(
      id: const Uuid().v4(),
      studentId: studentId,
      discountTypeId: discountTypeId,
      academicYear: academicYear,
      approvedBy: approvedBy,
      remarks: remarks,
      customName: customName,
      customKind: customKind,
      customValue: customValue,
      flatMode: flatMode,
    );
  }

  StudentDiscount copyWith({
    String? id,
    String? studentId,
    String? discountTypeId,
    String? academicYear,
    String? approvedBy,
    String? remarks,
    String? customName,
    String? customKind,
    double? customValue,
    String? flatMode,
  }) {
    return StudentDiscount(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      discountTypeId: discountTypeId ?? this.discountTypeId,
      academicYear: academicYear ?? this.academicYear,
      approvedBy: approvedBy ?? this.approvedBy,
      remarks: remarks ?? this.remarks,
      customName: customName ?? this.customName,
      customKind: customKind ?? this.customKind,
      customValue: customValue ?? this.customValue,
      flatMode: flatMode ?? this.flatMode,
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
      'custom_name': customName,
      'custom_kind': customKind,
      'custom_value': customValue,
      'flat_mode': flatMode,
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
      customName: map['custom_name'] as String?,
      customKind: map['custom_kind'] as String?,
      customValue: (map['custom_value'] as num?)?.toDouble(),
      flatMode: map['flat_mode'] as String? ?? 'evenly',
    );
  }

  String toJson() => json.encode(toMap());

  factory StudentDiscount.fromJson(String source) =>
      StudentDiscount.fromMap(json.decode(source) as Map<String, dynamic>);
}
