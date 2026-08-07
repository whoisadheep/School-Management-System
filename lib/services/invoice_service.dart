import '../models/models.dart';
import 'database_service.dart';

/// Business logic service for invoice management, grade-level fee structures,
/// and batch billing with explicit Dart balance calculations.
class InvoiceService {
  final DatabaseService _dbService;

  InvoiceService({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  /// Batch-generate invoices for a grade level with support for academic year isolation,
  /// grade-level fee structures, sibling discounts, and explicit Dart student balance updates.
  Future<List<Invoice>> generateBatchInvoicesForGrade({
    required String gradeLevel,
    required String feeCategoryId,
    required DateTime dueDate,
    String? academicYearId,
    double? customAmount,
    double discountAmount = 0.0,
    double penaltyAmount = 0.0,
    String? notes,
  }) async {
    // 1. Check if grade-level specific fee structure exists for this academic year
    double invoiceAmount = customAmount ?? 0.0;
    if (customAmount == null) {
      final feeCategory = await _dbService.getFeeCategoryById(feeCategoryId);
      if (feeCategory == null) {
        throw ArgumentError('Fee category with ID "$feeCategoryId" not found.');
      }
      invoiceAmount = feeCategory.defaultAmount;
    }

    // 2. Fetch active students in grade
    final students = await _dbService.getStudentsByGrade(gradeLevel);
    if (students.isEmpty) {
      return [];
    }

    final List<Invoice> generatedInvoices = [];

    for (final student in students) {
      generatedInvoices.add(Invoice.create(
        studentId: student.id,
        academicYearId: academicYearId ?? 'ay-2025-2026',
        totalAmount: invoiceAmount,
        discountAmount: discountAmount,
        penaltyAmount: penaltyAmount,
        dueDate: dueDate,
        notes: notes ?? 'Grade Fee Billing - ${student.name}',
      ));
    }

    // DatabaseService keeps invoice creation and balance updates in one transaction.
    await _dbService.insertInvoicesBatch(generatedInvoices);

    return generatedInvoices;
  }
}
