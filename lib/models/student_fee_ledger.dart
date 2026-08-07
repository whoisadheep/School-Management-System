import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Status of an individual fee ledger entry
enum LedgerStatus {
  pending,
  partial,
  paid,
  overdue;

  static LedgerStatus fromString(String value) {
    return LedgerStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LedgerStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case LedgerStatus.pending:
        return 'Pending';
      case LedgerStatus.partial:
        return 'Partial';
      case LedgerStatus.paid:
        return 'Paid';
      case LedgerStatus.overdue:
        return 'Overdue';
    }
  }
}

/// Represents a single fee obligation for a student per fee head in an academic year
class StudentFeeLedger {
  final String id;
  final String studentId;
  final String feeHeadId;
  final String academicYear;
  final double amountDue;
  final double amountPaid;
  final DateTime dueDate;
  final LedgerStatus status;
  final String? feeHeadName;
  final String? frequency;
  final String? monthLabel; // e.g. "April 2026"
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentFeeLedger({
    required this.id,
    required this.studentId,
    required this.feeHeadId,
    required this.academicYear,
    required this.amountDue,
    this.amountPaid = 0.0,
    required this.dueDate,
    this.status = LedgerStatus.pending,
    this.feeHeadName,
    this.frequency,
    this.monthLabel,
    required this.createdAt,
    required this.updatedAt,
  });

  double get remainingAmount => amountDue - amountPaid;

  factory StudentFeeLedger.create({
    required String studentId,
    required String feeHeadId,
    required String academicYear,
    required double amountDue,
    required DateTime dueDate,
    String? feeHeadName,
    String? frequency,
    String? monthLabel,
  }) {
    final now = DateTime.now();
    return StudentFeeLedger(
      id: const Uuid().v4(),
      studentId: studentId,
      feeHeadId: feeHeadId,
      academicYear: academicYear,
      amountDue: amountDue,
      amountPaid: 0.0,
      dueDate: dueDate,
      status: LedgerStatus.pending,
      feeHeadName: feeHeadName,
      frequency: frequency,
      monthLabel: monthLabel,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory StudentFeeLedger.fromMap(Map<String, dynamic> map) {
    return StudentFeeLedger(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      feeHeadId: map['fee_head_id'] as String,
      academicYear: map['academic_year'] as String,
      amountDue: (map['amount_due'] as num).toDouble(),
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0.0,
      dueDate: DateTime.parse(map['due_date'] as String),
      status: LedgerStatus.fromString(map['status'] as String? ?? 'pending'),
      feeHeadName: map['fee_head_name'] as String?,
      frequency: map['frequency'] as String?,
      monthLabel: map['month_label'] as String?,
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
      'student_id': studentId,
      'fee_head_id': feeHeadId,
      'academic_year': academicYear,
      'amount_due': amountDue,
      'amount_paid': amountPaid,
      'due_date': dueDate.toIso8601String(),
      'status': status.name,
      'month_label': monthLabel,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String toJson() => json.encode(toMap());

  factory StudentFeeLedger.fromJson(String source) =>
      StudentFeeLedger.fromMap(json.decode(source) as Map<String, dynamic>);

  StudentFeeLedger copyWith({
    String? id,
    String? studentId,
    String? feeHeadId,
    String? academicYear,
    double? amountDue,
    double? amountPaid,
    DateTime? dueDate,
    LedgerStatus? status,
    String? feeHeadName,
    String? frequency,
    String? monthLabel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentFeeLedger(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      feeHeadId: feeHeadId ?? this.feeHeadId,
      academicYear: academicYear ?? this.academicYear,
      amountDue: amountDue ?? this.amountDue,
      amountPaid: amountPaid ?? this.amountPaid,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      feeHeadName: feeHeadName ?? this.feeHeadName,
      frequency: frequency ?? this.frequency,
      monthLabel: monthLabel ?? this.monthLabel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'StudentFeeLedger(id: $id, studentId: $studentId, feeHeadId: $feeHeadId, '
        'amountDue: $amountDue, amountPaid: $amountPaid, status: ${status.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentFeeLedger && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
