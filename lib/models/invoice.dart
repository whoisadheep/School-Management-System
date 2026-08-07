import 'package:uuid/uuid.dart';

/// Invoice payment status
enum InvoiceStatus {
  pending,
  paid,
  overdue,
  partial,
  cancelled;

  static InvoiceStatus fromString(String value) {
    return InvoiceStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => InvoiceStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case InvoiceStatus.pending:
        return 'Pending';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
      case InvoiceStatus.partial:
        return 'Partial';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class Invoice {
  final String id;
  final String studentId;
  final String? academicYearId;
  final double totalAmount;
  final double discountAmount;
  final double penaltyAmount;
  final DateTime dueDate;
  final InvoiceStatus status;
  final String? ledgerId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Invoice({
    required this.id,
    required this.studentId,
    this.academicYearId,
    required this.totalAmount,
    this.discountAmount = 0.0,
    this.penaltyAmount = 0.0,
    required this.dueDate,
    this.status = InvoiceStatus.pending,
    this.ledgerId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Net amount payable after applying discounts and late penalties
  double get netAmount => totalAmount - discountAmount + penaltyAmount;

  factory Invoice.create({
    required String studentId,
    String? academicYearId,
    required double totalAmount,
    double discountAmount = 0.0,
    double penaltyAmount = 0.0,
    required DateTime dueDate,
    String? ledgerId,
    String? notes,
  }) {
    final now = DateTime.now();
    return Invoice(
      id: const Uuid().v4(),
      studentId: studentId,
      academicYearId: academicYearId,
      totalAmount: totalAmount,
      discountAmount: discountAmount,
      penaltyAmount: penaltyAmount,
      dueDate: dueDate,
      status: InvoiceStatus.pending,
      ledgerId: ledgerId,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Deserialize from SQLite row
  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      academicYearId: map['academic_year_id'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      penaltyAmount: (map['penalty_amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: DateTime.parse(map['due_date'] as String),
      status: InvoiceStatus.fromString(map['status'] as String),
      ledgerId: map['ledger_id'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Serialize to SQLite row
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'academic_year_id': academicYearId,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'penalty_amount': penaltyAmount,
      'due_date': dueDate.toIso8601String(),
      'status': status.name,
      'ledger_id': ledgerId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Invoice copyWith({
    String? id,
    String? studentId,
    String? academicYearId,
    double? totalAmount,
    double? discountAmount,
    double? penaltyAmount,
    DateTime? dueDate,
    InvoiceStatus? status,
    String? ledgerId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      academicYearId: academicYearId ?? this.academicYearId,
      totalAmount: totalAmount ?? this.totalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      penaltyAmount: penaltyAmount ?? this.penaltyAmount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      ledgerId: ledgerId ?? this.ledgerId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Whether this invoice is past due and still unpaid
  bool get isPastDue =>
      dueDate.isBefore(DateTime.now()) && status == InvoiceStatus.pending;

  @override
  String toString() {
    return 'Invoice(id: $id, studentId: $studentId, totalAmount: $totalAmount, '
        'dueDate: $dueDate, status: ${status.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Invoice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
