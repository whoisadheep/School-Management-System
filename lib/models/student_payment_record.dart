import 'student_fee_ledger.dart';
import 'transaction.dart';

/// Represents a consolidated fee payment event (single or batch) made for a student,
/// linking transaction details, invoices, and the paid fee ledger entries.
class StudentPaymentRecord {
  final String transactionId;
  final String receiptNumber;
  final DateTime timestamp;
  final PaymentMethod paymentMethod;
  final double totalAmountPaid;
  final String academicYear;
  final String? notes;
  final List<StudentFeeLedger> paidLedgers;
  final List<String> invoiceIds;

  const StudentPaymentRecord({
    required this.transactionId,
    required this.receiptNumber,
    required this.timestamp,
    required this.paymentMethod,
    required this.totalAmountPaid,
    required this.academicYear,
    this.notes,
    this.paidLedgers = const [],
    this.invoiceIds = const [],
  });

  /// User-friendly summary of the fee heads and month labels covered in this payment
  String get feeHeadsSummary {
    if (paidLedgers.isEmpty) {
      return notes ?? 'Fee Payment';
    }
    final headLabels = paidLedgers.map((l) {
      final name = l.feeHeadName ?? l.feeHeadId;
      if (l.monthLabel != null && l.monthLabel!.isNotEmpty) {
        return '$name (${l.monthLabel})';
      }
      return name;
    }).toSet().toList();
    return headLabels.join(', ');
  }
}
