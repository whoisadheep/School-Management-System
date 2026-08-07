import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'database_service.dart';

class PaymentResult {
  final Transaction transaction;
  final LedgerEntry ledgerEntry;
  final Invoice updatedInvoice;

  const PaymentResult({
    required this.transaction,
    required this.ledgerEntry,
    required this.updatedInvoice,
  });
}

/// PaymentService handling fee payments, explicit Dart balance calculations,
/// partial payment allocations, and ledger logging inside atomic SQLite transactions.
class PaymentService {
  final DatabaseService _dbService;

  PaymentService({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  /// Process fee payment for an invoice with explicit Dart business logic.
  ///
  /// Steps inside a single atomic SQLite transaction:
  /// 1. Fetch invoice & student record.
  /// 2. Calculate new total paid on invoice, accounting for discount and late penalty.
  /// 3. Determine new invoice status ('paid', 'partial', 'pending').
  /// 4. Deduct payment amount from student's current_balance.
  /// 5. Record transaction row.
  /// 6. Log corresponding 'income' entry in ledger_entries.
  Future<PaymentResult> processPayment({
    required String invoiceId,
    required double amountPaid,
    required PaymentMethod paymentMethod,
    String? referenceNumber,
    String? ledgerCategory,
    String currentUserId = 'usr-admin-001',
  }) async {
    if (amountPaid <= 0) {
      throw ArgumentError('Payment amount must be greater than 0.');
    }

    final db = await _dbService.rawDb;

    late Transaction transaction;
    late LedgerEntry ledgerEntry;
    late Invoice updatedInvoice;

    await db.transaction((txn) async {
      // 1. Fetch invoice
      final invoiceMaps = await txn.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );
      if (invoiceMaps.isEmpty) {
        throw ArgumentError('Invoice with ID "$invoiceId" not found.');
      }
      final invoice = Invoice.fromMap(invoiceMaps.first);
      if (invoice.status == InvoiceStatus.cancelled) {
        throw StateError('Cancelled invoices cannot receive payments.');
      }

      // 2. Fetch student
      final studentMaps = await txn.query(
        'students',
        where: 'id = ?',
        whereArgs: [invoice.studentId],
        limit: 1,
      );
      if (studentMaps.isEmpty) {
        throw ArgumentError(
            'Student with ID "${invoice.studentId}" not found.');
      }
      final student = Student.fromMap(studentMaps.first);

      // 3. Ensure the payment cannot exceed the amount still owed.
      final priorPayments = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount_paid), 0) AS total FROM transactions WHERE invoice_id = ?',
        [invoiceId],
      );
      final totalPaidBefore = (priorPayments.first['total'] as num).toDouble();
      final remainingAmount = invoice.netAmount - totalPaidBefore;
      if (remainingAmount <= 0) {
        throw StateError('This invoice has already been paid in full.');
      }
      if (amountPaid > remainingAmount + 0.000001) {
        throw ArgumentError(
            'Payment exceeds the remaining balance of ₹${remainingAmount.toStringAsFixed(2)}.');
      }

      // 4. Create Transaction object
      transaction = Transaction.create(
        invoiceId: invoiceId,
        amountPaid: amountPaid,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
      );

      await txn.insert('transactions', transaction.toMap());

      // 5. Calculate total payments received for this invoice including this transaction
      final sumResult = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount_paid), 0) as total FROM transactions WHERE invoice_id = ?',
        [invoiceId],
      );
      final double totalPaidSoFar =
          (sumResult.first['total'] as num).toDouble();

      // Net invoice amount = totalAmount - discountAmount + penaltyAmount
      final double netInvoiceAmount = invoice.netAmount;

      // 6. Determine new invoice status
      InvoiceStatus newStatus = InvoiceStatus.pending;
      if (totalPaidSoFar >= netInvoiceAmount) {
        newStatus = InvoiceStatus.paid;
      } else if (totalPaidSoFar > 0) {
        newStatus = InvoiceStatus.partial;
      }

      final String nowIso = DateTime.now().toIso8601String();

      // 7. Update Invoice record
      await txn.update(
        'invoices',
        {
          'status': newStatus.name,
          'updated_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      updatedInvoice = invoice.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );

      // 8. Update Student Balance (explicit Dart business rule)
      final double newBalance = student.currentBalance - amountPaid;
      await txn.update(
        'students',
        {
          'current_balance': newBalance,
          'updated_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [student.id],
      );

      // 9. Create Ledger Entry for Income
      ledgerEntry = LedgerEntry.create(
        date: transaction.timestamp,
        type: LedgerType.income,
        category: ledgerCategory ?? 'Fee Collection',
        amount: amountPaid,
        description:
            'Payment for ${student.name} (Invoice #${invoice.id.substring(0, 8)}) via ${paymentMethod.displayName}',
        referenceId: transaction.id,
      );

      await txn.insert('ledger_entries', ledgerEntry.toMap());

      // 10. Write Audit Log
      final auditLog = AuditLog(
        id: const Uuid().v4(),
        adminUserId: currentUserId,
        actionType: 'create', // Because it's recording a payment
        module: 'Fees',
        entityType: 'Transaction',
        entityId: transaction.id,
        description: 'Recorded payment of ₹$amountPaid for Student: ${student.name} (Invoice #${invoice.id.substring(0, 8)})',
        timestamp: DateTime.now(),
      );
      await txn.insert('audit_logs', auditLog.toMap());
    });

    return PaymentResult(
      transaction: transaction,
      ledgerEntry: ledgerEntry,
      updatedInvoice: updatedInvoice,
    );
  }
}
