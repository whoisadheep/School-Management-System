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
  final int totalStaff;
  final Map<String, int> classWiseStudentCount;
  final Map<String, double> feeHeadWiseCollection;
  final double collectionRate;
  final int todaysTransactionCount;
  final double yesterdaysCollections;
  final Map<String, int> genderDistribution;

  const DashboardMetrics({
    required this.totalRevenueCurrentYear,
    required this.pendingDues,
    required this.todaysCollections,
    required this.totalOperationalExpenses,
    required this.overdueInvoices,
    required this.totalStudents,
    required this.monthlyFinancials,
    required this.totalStaff,
    required this.classWiseStudentCount,
    required this.feeHeadWiseCollection,
    required this.collectionRate,
    required this.todaysTransactionCount,
    required this.yesterdaysCollections,
    required this.genderDistribution,
  });
}

/// Dashboard Analytics Riverpod Provider
final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  try {
    final dbService = ref.watch(databaseServiceProvider);
    final now = DateTime.now();
    const currentAcademicYear = '2024-2025';

    // 1. Total Revenue (Income entries in ledger + transactions)
    final ledgerSummary = await dbService.getLedgerSummary();
    final double totalRevenue = (ledgerSummary['total_income'] as num?)?.toDouble() ?? 0.0;
    final double totalExpenses = (ledgerSummary['total_expense'] as num?)?.toDouble() ?? 0.0;

    // 2. Pending dues and overdue invoices across student_fee_ledger AND invoices
    final allStudents = await dbService.getAllStudents(activeOnly: false);
    final studentsById = {for (final student in allStudents) student.id: student};

    final allInvoices = await dbService.getAllInvoices();
    double pendingSum = 0.0;
    final List<OverdueInvoiceInfo> overdueList = [];
    final Set<String> processedStudentIds = {};

    // A. Check student_fee_ledger entries
    try {
      final overdueLedgerRows = await dbService.getOverdueStudents(currentAcademicYear);
      for (final row in overdueLedgerRows) {
        final studentId = row['student_id'] as String;
        final student = studentsById[studentId];
        final overdueAmt = (row['total_overdue_amount'] as num).toDouble();
        final oldestDueStr = row['oldest_due_date'] as String?;
        final oldestDueDate = oldestDueStr != null ? DateTime.tryParse(oldestDueStr) ?? now : now;

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
    } catch (_) {}

    try {
      final ledgerSummaryMap = await dbService.rawDb.then((db) => db.rawQuery('''
        SELECT COALESCE(SUM(amount_due - amount_paid), 0.0) as pending
        FROM student_fee_ledger
        WHERE amount_paid < amount_due
      '''));
      if (ledgerSummaryMap.isNotEmpty) {
        pendingSum += (ledgerSummaryMap.first['pending'] as num).toDouble();
      }
    } catch (_) {}

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

    overdueList.sort((a, b) => a.invoice.dueDate.compareTo(b.invoice.dueDate));
    final top10OverdueInfo = overdueList.take(10).toList();

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

    final totalStudents = allStudents.where((student) => student.isActive).length;
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

    int totalStaff = 0;
    try {
      final staffCountResult = await dbService.rawDb.then((db) => db.rawQuery('SELECT COUNT(*) as total FROM staff WHERE is_active = 1'));
      if (staffCountResult.isNotEmpty) {
        totalStaff = (staffCountResult.first['total'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}

    Map<String, int> classWiseStudentCount = {};
    try {
      final classCountResult = await dbService.rawDb.then((db) => db.rawQuery('SELECT grade_level, COUNT(*) as count FROM students WHERE is_active = 1 AND grade_level IS NOT NULL GROUP BY grade_level ORDER BY grade_level'));
      for (final row in classCountResult) {
        final grade = row['grade_level'] as String?;
        final count = (row['count'] as num?)?.toInt() ?? 0;
        if (grade != null) {
          classWiseStudentCount[grade] = count;
        }
      }
    } catch (_) {}

    Map<String, double> feeHeadWiseCollection = {};
    try {
      final feeHeadResult = await dbService.rawDb.then((db) => db.rawQuery('''
        SELECT fh.name, COALESCE(SUM(sfl.amount_paid), 0.0) as collected
        FROM student_fee_ledger sfl
        JOIN fee_heads fh ON sfl.fee_head_id = fh.id
        WHERE sfl.academic_year = '2024-2025'
        GROUP BY fh.name
        ORDER BY collected DESC
      '''));
      for (final row in feeHeadResult) {
        final name = row['name'] as String?;
        final collected = (row['collected'] as num?)?.toDouble() ?? 0.0;
        if (name != null) {
          feeHeadWiseCollection[name] = collected;
        }
      }
    } catch (_) {}

    double collectionRate = 0.0;
    try {
      final rateResult = await dbService.rawDb.then((db) => db.rawQuery('''
        SELECT COALESCE(SUM(amount_due), 0) as total_due, COALESCE(SUM(amount_paid), 0) as total_paid
        FROM student_fee_ledger WHERE academic_year = '2024-2025'
      '''));
      if (rateResult.isNotEmpty) {
        final totalDue = (rateResult.first['total_due'] as num?)?.toDouble() ?? 0.0;
        final totalPaid = (rateResult.first['total_paid'] as num?)?.toDouble() ?? 0.0;
        if (totalDue > 0) {
          collectionRate = ((totalPaid / totalDue) * 100).clamp(0.0, 100.0);
        }
      }
    } catch (_) {}

    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final yesterdayEnd = todayStart;
    double yesterdaysCollections = 0.0;
    try {
      final yesterdayEntries = await dbService.getLedgerEntriesByDateRange(yesterdayStart, yesterdayEnd);
      for (final entry in yesterdayEntries) {
        if (entry.type == LedgerType.income) {
          yesterdaysCollections += entry.amount;
        }
      }
    } catch (_) {}

    int todaysTransactionCount = 0;
    try {
      final txResult = await dbService.rawDb.then((db) => db.rawQuery('''
        SELECT COUNT(*) as cnt FROM transactions WHERE timestamp >= ? AND timestamp < ?
      ''', [todayStart.toIso8601String(), todayEnd.toIso8601String()]));
      if (txResult.isNotEmpty) {
        todaysTransactionCount = (txResult.first['cnt'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}

    Map<String, int> genderDistribution = {};
    try {
      final genderResult = await dbService.rawDb.then((db) => db.rawQuery('''
        SELECT COALESCE(gender, 'Unknown') as g, COUNT(*) as c FROM students WHERE is_active = 1 GROUP BY g
      '''));
      for (final row in genderResult) {
        final g = row['g'] as String?;
        final c = (row['c'] as num?)?.toInt() ?? 0;
        if (g != null) {
          genderDistribution[g] = c;
        }
      }
    } catch (_) {}

    return DashboardMetrics(
      totalRevenueCurrentYear: totalRevenue,
      pendingDues: pendingSum,
      todaysCollections: todayIncome,
      totalOperationalExpenses: totalExpenses,
      overdueInvoices: top10OverdueInfo,
      totalStudents: totalStudents,
      monthlyFinancials: monthlyFinancials,
      totalStaff: totalStaff,
      classWiseStudentCount: classWiseStudentCount,
      feeHeadWiseCollection: feeHeadWiseCollection,
      collectionRate: collectionRate,
      todaysTransactionCount: todaysTransactionCount,
      yesterdaysCollections: yesterdaysCollections,
      genderDistribution: genderDistribution,
    );
  } catch (e) {
    final now = DateTime.now();
    return DashboardMetrics(
      totalRevenueCurrentYear: 0.0,
      pendingDues: 0.0,
      todaysCollections: 0.0,
      totalOperationalExpenses: 0.0,
      overdueInvoices: const [],
      totalStudents: 0,
      monthlyFinancials: [
        MonthlyFinancialData(month: _monthLabel(now.month), collections: 0.0, expenses: 0.0),
      ],
      totalStaff: 0,
      classWiseStudentCount: {},
      feeHeadWiseCollection: {},
      collectionRate: 0.0,
      todaysTransactionCount: 0,
      yesterdaysCollections: 0.0,
      genderDistribution: {},
    );
  }
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
