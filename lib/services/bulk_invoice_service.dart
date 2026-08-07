import '../models/models.dart';
import 'database_service.dart';

class BulkInvoiceService {
  final DatabaseService _dbService;

  BulkInvoiceService({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  /// Generate fee invoices for all active students in a specific grade level
  Future<int> generateBulkInvoicesForGrade({
    required String gradeLevel,
    required double feeAmount,
    required DateTime dueDate,
    required String feeTitle,
  }) async {
    List<Student> targetStudents;
    if (gradeLevel == 'All Grades') {
      targetStudents = await _dbService.getAllStudents(activeOnly: true);
    } else {
      targetStudents = await _dbService.getStudentsByGrade(gradeLevel);
    }

    if (targetStudents.isEmpty) return 0;

    final List<Invoice> invoicesToCreate = [];
    for (final student in targetStudents) {
      final inv = Invoice.create(
        studentId: student.id,
        totalAmount: feeAmount,
        dueDate: dueDate,
        notes: feeTitle,
      );
      invoicesToCreate.add(inv);
    }

    await _dbService.insertInvoicesBatch(invoicesToCreate);
    return invoicesToCreate.length;
  }
}
