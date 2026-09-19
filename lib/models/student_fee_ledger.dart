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

/// Represents an aggregated summary of outstanding fee dues for a student in an academic session
class StudentFeeDuesSummary {
  final String studentId;
  final String studentName;
  final String? admissionNumber;
  final String? rollNumber;
  final String gradeLevel;
  final double totalDue;
  final double totalPaid;
  final double unpaidBalance;
  final int unpaidLedgerCount;
  final List<String> unpaidDetails; // e.g. ["Tuition Fee (April): ₹500"]

  const StudentFeeDuesSummary({
    required this.studentId,
    required this.studentName,
    this.admissionNumber,
    this.rollNumber,
    required this.gradeLevel,
    required this.totalDue,
    required this.totalPaid,
    required this.unpaidBalance,
    required this.unpaidLedgerCount,
    this.unpaidDetails = const [],
  });
}

/// Represents a consolidated fee item grouping multiple contiguous months
/// of the same fee head (e.g. "Tuition Fee" with "From April to June").
class ConsolidatedFeeItem {
  final String feeHeadId;
  final String feeHeadName;
  final String periodLabel;
  final double amountDue;
  final double amountPaid;
  final double remainingAmount;
  final DateTime dueDate;
  final LedgerStatus status;
  final bool isPastArrear;
  final List<StudentFeeLedger> originalLedgers;

  const ConsolidatedFeeItem({
    required this.feeHeadId,
    required this.feeHeadName,
    required this.periodLabel,
    required this.amountDue,
    required this.amountPaid,
    required this.remainingAmount,
    required this.dueDate,
    this.status = LedgerStatus.pending,
    this.isPastArrear = false,
    required this.originalLedgers,
  });

  /// Consolidates a list of StudentFeeLedger items by feeHeadId.
  /// If a student owes or paid Tuition Fee for April, May, June,
  /// this merges them into a single Tuition Fee item with period "From April to June".
  static List<ConsolidatedFeeItem> consolidate(
    List<StudentFeeLedger> ledgers, {
    int Function(String? monthLabel)? monthIndexResolver,
    int? currentFromMonthIndex,
  }) {
    if (ledgers.isEmpty) return [];

    // Group ledgers by feeHeadId
    final Map<String, List<StudentFeeLedger>> groups = {};
    for (final l in ledgers) {
      final key = l.feeHeadId;
      groups.putIfAbsent(key, () => []).add(l);
    }

    final List<ConsolidatedFeeItem> result = [];

    for (final entry in groups.entries) {
      final list = entry.value;
      if (list.isEmpty) continue;

      // Sort by due date
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      // Separate into past arrears and regular selection if resolver provided
      final List<StudentFeeLedger> arrears = [];
      final List<StudentFeeLedger> regular = [];

      if (monthIndexResolver != null && currentFromMonthIndex != null && currentFromMonthIndex >= 0) {
        for (final item in list) {
          final mIdx = monthIndexResolver(item.monthLabel);
          if (mIdx != -1 && mIdx < currentFromMonthIndex) {
            arrears.add(item);
          } else {
            regular.add(item);
          }
        }
      } else {
        regular.addAll(list);
      }

      if (arrears.isNotEmpty) {
        result.add(_buildConsolidated(arrears, isArrear: true));
      }
      if (regular.isNotEmpty) {
        result.add(_buildConsolidated(regular, isArrear: false));
      }
    }

    return result;
  }

  static ConsolidatedFeeItem _buildConsolidated(List<StudentFeeLedger> items, {required bool isArrear}) {
    final first = items.first;
    final headName = first.feeHeadName ?? first.feeHeadId;

    final double totalDue = items.fold(0.0, (sum, l) => sum + l.amountDue);
    final double totalPaid = items.fold(0.0, (sum, l) => sum + l.amountPaid);
    final double totalRemaining = items.fold(0.0, (sum, l) => sum + l.remainingAmount);
    final bool allPaid = items.every((l) => l.status == LedgerStatus.paid);
    final bool anyPartial = items.any((l) => l.status == LedgerStatus.partial);

    final LedgerStatus status = allPaid
        ? LedgerStatus.paid
        : (anyPartial ? LedgerStatus.partial : LedgerStatus.pending);

    // Build period label
    final monthLabels = items
        .map((l) => l.monthLabel)
        .where((m) => m != null && m.isNotEmpty)
        .cast<String>()
        .toList();

    String periodLabel;
    if (monthLabels.isEmpty) {
      periodLabel = 'Annual / One-Time';
    } else if (monthLabels.length == 1) {
      final m = shortMonth(monthLabels.first);
      periodLabel = isArrear ? '$m (Arrears)' : m;
    } else {
      final firstMonth = shortMonth(monthLabels.first);
      final lastMonth = shortMonth(monthLabels.last);
      if (firstMonth == lastMonth) {
        periodLabel = isArrear ? '$firstMonth (Arrears)' : firstMonth;
      } else {
        periodLabel = isArrear
            ? 'From $firstMonth to $lastMonth (Arrears)'
            : 'From $firstMonth to $lastMonth';
      }
    }

    return ConsolidatedFeeItem(
      feeHeadId: first.feeHeadId,
      feeHeadName: headName,
      periodLabel: periodLabel,
      amountDue: totalDue,
      amountPaid: totalPaid,
      remainingAmount: totalRemaining,
      dueDate: items.last.dueDate,
      status: status,
      isPastArrear: isArrear,
      originalLedgers: items,
    );
  }

  /// Converts a full or partial month name (e.g. "January", "April 2026")
  /// into standard short format: Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sept, Oct, Nov, Dec.
  static String shortMonth(String raw) {
    final clean = raw.trim().split(' ').first;
    final lower = clean.toLowerCase();
    if (lower.startsWith('jan')) return 'Jan';
    if (lower.startsWith('feb')) return 'Feb';
    if (lower.startsWith('mar')) return 'Mar';
    if (lower.startsWith('apr')) return 'Apr';
    if (lower.startsWith('may')) return 'May';
    if (lower.startsWith('jun')) return 'Jun';
    if (lower.startsWith('jul')) return 'Jul';
    if (lower.startsWith('aug')) return 'Aug';
    if (lower.startsWith('sep')) return 'Sept';
    if (lower.startsWith('oct')) return 'Oct';
    if (lower.startsWith('nov')) return 'Nov';
    if (lower.startsWith('dec')) return 'Dec';
    return clean;
  }
}
