import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'services_provider.dart';

class OverdueInvoiceInfo {
  final Invoice invoice;
  final Student? student;

  const OverdueInvoiceInfo({required this.invoice, this.student});
}

class MonthlyFinancialData {
  final String month;
  final double collections;
  final double expenses;

  const MonthlyFinancialData({
    required this.month,
    required this.collections,
    required this.expenses,
  });
}

class DashboardMetrics {
  final double totalRevenueCurrentYear;
  final double pendingDues;
  final double todaysCollections;
  final double totalOperationalExpenses;
  final List<OverdueInvoiceInfo> overdueInvoices;
  final int totalStudents;
  final List<MonthlyFinancialData> monthlyFinancials;

  const DashboardMetrics({
    required this.totalRevenueCurrentYear,
    required this.pendingDues,
    required this.todaysCollections,
    required this.totalOperationalExpenses,
    required this.overdueInvoices,
    required this.totalStudents,
    required this.monthlyFinancials,
  });
}

/// Dashboard Analytics Riverpod Provider
final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  final now = DateTime.now();
  const currentAcademicYear = '2024-2025';

  // 1. Total Revenue (Income entries in ledger + transactions)
  final ledgerSummary = await dbService.getLedgerSummary();
  final double totalRevenue = ledgerSummary['total_income'] ?? 0.0;
  final double totalExpenses = ledgerSummary['total_expense'] ?? 0.0;

  // 2. Pending dues and overdue invoices across student_fee_ledger AND invoices
  final allStudents = await dbService.getAllStudents(activeOnly: false);
  final studentsById = {for (final student in allStudents) student.id: student};

  final allInvoices = await dbService.getAllInvoices();
  double pendingSum = 0.0;
  final List<OverdueInvoiceInfo> overdueList = [];
  final Set<String> processedStudentIds = {};

  // A. Check student_fee_ledger entries
  final overdueLedgerRows = await dbService.getOverdueStudents(currentAcademicYear);
  for (final row in overdueLedgerRows) {
    final studentId = row['student_id'] as String;
    final student = studentsById[studentId];
    final overdueAmt = (row['total_overdue_amount'] as num).toDouble();
    final oldestDueStr = row['oldest_due_date'] as String?;
    final oldestDueDate = oldestDueStr != null ? DateTime.tryParse(oldestDueStr) ?? now : now;

    // Create synthetic Invoice representation for overdue card
    final syntheticInvoice = Invoice(
      id: 'sfl-overdue-$studentId',
      studentId: studentId,
      academicYearId: currentAcademicYear,
      totalAmount: overdueAmt,
      dueDate: oldestDueDate,
      status: InvoiceStatus.overdue,
      createdAt: oldestDueDate,
      updatedAt: now,
    );

    overdueList.add(OverdueInvoiceInfo(
      invoice: syntheticInvoice,
      student: student,
    ));
    processedStudentIds.add(studentId);
  }

  // Calculate overall pending dues from student_fee_ledger
  final ledgerSummaryMap = await dbService.rawDb.then((db) => db.rawQuery('''
    SELECT COALESCE(SUM(amount_due - amount_paid), 0.0) as pending
    FROM student_fee_ledger
    WHERE amount_paid < amount_due
  '''));
  if (ledgerSummaryMap.isNotEmpty) {
    pendingSum += (ledgerSummaryMap.first['pending'] as num).toDouble();
  }

  // B. Check traditional invoices table for any not linked to ledger
  for (final inv in allInvoices) {
    final isOpen = inv.status == InvoiceStatus.pending ||
        inv.status == InvoiceStatus.partial ||
        inv.status == InvoiceStatus.overdue;
    if (!isOpen) continue;

    final transactions = await dbService.getTransactionsByInvoiceId(inv.id);
    final paidAmount = transactions.fold<double>(
      0,
      (total, transaction) => total + transaction.amountPaid,
    );
    final remaining = (inv.netAmount - paidAmount).clamp(0.0, double.infinity);

    // Only add to pendingSum if not already covered by student_fee_ledger
    if (inv.ledgerId == null && remaining > 0) {
      pendingSum += remaining;
    }

    if ((inv.status == InvoiceStatus.overdue || inv.dueDate.isBefore(now)) &&
        !processedStudentIds.contains(inv.studentId)) {
      overdueList.add(OverdueInvoiceInfo(
        invoice: inv,
        student: studentsById[inv.studentId],
      ));
    }
  }

  // Sort top overdue items by due date ascending (most overdue first)
  overdueList.sort((a, b) => a.invoice.dueDate.compareTo(b.invoice.dueDate));
  final top10OverdueInfo = overdueList.take(10).toList();

  // 3. Today's Collections (from ledger entries + transactions)
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));
  final todayEntries =
      await dbService.getLedgerEntriesByDateRange(todayStart, todayEnd);
  double todayIncome = 0.0;
  for (final entry in todayEntries) {
    if (entry.type == LedgerType.income) {
      todayIncome += entry.amount;
    }
  }

  // 4. Total Active Students
  final totalStudents = allStudents.where((student) => student.isActive).length;

  // 5. Monthly financial trend for the most recent six calendar months
  final allLedgerEntries = await dbService.getAllLedgerEntries();
  final List<MonthlyFinancialData> monthlyFinancials = [];
  for (int i = 5; i >= 0; i--) {
    final monthStart = DateTime(now.year, now.month - i, 1);
    double monthIncome = 0.0;
    double monthExpense = 0.0;

    for (final entry in allLedgerEntries) {
      if (entry.date.year == monthStart.year &&
          entry.date.month == monthStart.month) {
        if (entry.type == LedgerType.income) {
          monthIncome += entry.amount;
        } else {
          monthExpense += entry.amount;
        }
      }
    }

    monthlyFinancials.add(MonthlyFinancialData(
      month: _monthLabel(monthStart.month),
      collections: monthIncome,
      expenses: monthExpense,
    ));
  }

  return DashboardMetrics(
    totalRevenueCurrentYear: totalRevenue,
    pendingDues: pendingSum,
    todaysCollections: todayIncome,
    totalOperationalExpenses: totalExpenses,
    overdueInvoices: top10OverdueInfo,
    totalStudents: totalStudents,
    monthlyFinancials: monthlyFinancials,
  );
});

String _monthLabel(int month) {
  const monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return monthNames[month - 1];
}
