import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/models/invoice.dart';

void main() {
  test('Invoice.copyWith preserves billing fields that are not replaced', () {
    final invoice = Invoice.create(
      studentId: 'student-1',
      academicYearId: 'year-1',
      totalAmount: 1000,
      discountAmount: 100,
      penaltyAmount: 25,
      dueDate: DateTime(2026, 8, 31),
    );

    final updated = invoice.copyWith(status: InvoiceStatus.partial);

    expect(updated.academicYearId, 'year-1');
    expect(updated.discountAmount, 100);
    expect(updated.penaltyAmount, 25);
    expect(updated.netAmount, 925);
  });
}
