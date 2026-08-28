import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Defines what each class/section owes per fee head per academic year
class FeeStructure {
  final String id;
  final String? feeHeadId;
  final String feeCategoryId;
  final String className;
  final String? sectionName;
  final String academicYear;
  final double amount;
  final int? dueDayOfMonth;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeeStructure({
    required this.id,
    this.feeHeadId,
    required this.feeCategoryId,
    required this.className,
    this.sectionName,
    required this.academicYear,
    required this.amount,
    this.dueDayOfMonth,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeeStructure.create({
    required String feeHeadId,
    required String className,
    String? sectionName,
    required String academicYear,
    required double amount,
    int? dueDayOfMonth,
  }) {
    final now = DateTime.now();
    return FeeStructure(
      id: const Uuid().v4(),
      feeHeadId: feeHeadId,
      feeCategoryId: feeHeadId,
      className: className,
      sectionName: sectionName,
      academicYear: academicYear,
      amount: amount,
      dueDayOfMonth: dueDayOfMonth,
      createdAt: now,
      updatedAt: now,
    );
  }

  FeeStructure copyWith({
    String? id,
    String? feeHeadId,
    String? feeCategoryId,
    String? className,
    String? sectionName,
    String? academicYear,
    double? amount,
    int? dueDayOfMonth,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeeStructure(
      id: id ?? this.id,
      feeHeadId: feeHeadId ?? this.feeHeadId,
      feeCategoryId: feeCategoryId ?? this.feeCategoryId,
      className: className ?? this.className,
      sectionName: sectionName ?? this.sectionName,
      academicYear: academicYear ?? this.academicYear,
      amount: amount ?? this.amount,
      dueDayOfMonth: dueDayOfMonth ?? this.dueDayOfMonth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FeeStructure.fromMap(Map<String, dynamic> map) {
    return FeeStructure(
      id: map['id'] as String,
      feeHeadId: (map['fee_head_id'] as String?) ?? (map['fee_category_id'] as String?),
      feeCategoryId: (map['fee_category_id'] as String?) ?? (map['fee_head_id'] as String?) ?? '',
      className: (map['class'] as String?) ?? (map['grade_level'] as String?) ?? '',
      sectionName: map['section'] as String?,
      academicYear: (map['academic_year'] as String?) ?? (map['academic_year_id'] as String?) ?? '2024-2025',
      amount: (map['amount'] as num).toDouble(),
      dueDayOfMonth: map['due_day_of_month'] as int?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fee_head_id': feeHeadId,
      'fee_category_id': feeCategoryId,
      'class': className,
      'grade_level': className,
      'section': sectionName,
      'academic_year': academicYear,
      'academic_year_id': academicYear.startsWith('ay-') ? academicYear : 'ay-$academicYear',
      'amount': amount,
      'due_day_of_month': dueDayOfMonth,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String toJson() => json.encode(toMap());

  factory FeeStructure.fromJson(String source) =>
      FeeStructure.fromMap(json.decode(source) as Map<String, dynamic>);

  // Legacy getters for backward compatibility
  String get gradeLevel => className;
  String get academicYearId => academicYear;
}

/// Breakdown of net payable fee for a student per fee head after applying discounts
class StudentNetFeeBreakdown {
  final String feeHeadId;
  final String feeHeadName;
  final String frequency;
  final double baseAmount;
  final double discountAmount;
  final double netPayable;

  const StudentNetFeeBreakdown({
    required this.feeHeadId,
    required this.feeHeadName,
    required this.frequency,
    required this.baseAmount,
    required this.discountAmount,
    required this.netPayable,
  });
}
