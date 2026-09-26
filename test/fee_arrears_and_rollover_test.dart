import 'dart:ffi';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/core/database/database_helper.dart';
import 'package:school_management_system/services/database_service.dart';
import 'package:school_management_system/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    open.overrideFor(OperatingSystem.linux, () => DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0'));
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;

    final tempDb = File('/tmp/Eduvia/school_management.db');
    if (tempDb.existsSync()) {
      try {
        tempDb.deleteSync();
      } catch (_) {}
    }

    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    });
  });

  group('Fee Arrears Calculation & Model Tests', () {
    test('StudentFeeLedger partial payment retains exact remaining balance', () {
      final ledger = StudentFeeLedger.create(
        studentId: 'student-test-1',
        feeHeadId: 'fh-tuition',
        academicYear: '2026-2027',
        amountDue: 2500.0,
        dueDate: DateTime(2026, 4, 10),
        feeHeadName: 'Tuition Fee',
        monthLabel: 'April',
      );

      expect(ledger.amountDue, 2500.0);
      expect(ledger.amountPaid, 0.0);
      expect(ledger.remainingAmount, 2500.0);

      // Parent pays 2000
      final partial = ledger.copyWith(
        amountPaid: 2000.0,
        status: LedgerStatus.partial,
      );

      expect(partial.amountPaid, 2000.0);
      expect(partial.remainingAmount, 500.0);
      expect(partial.status, LedgerStatus.partial);
    });

    test('StudentFeeDuesSummary correctly models outstanding dues breakdown', () {
      const summary = StudentFeeDuesSummary(
        studentId: 's-100',
        studentName: 'Rahul Sharma',
        admissionNumber: 'ADM-101',
        rollNumber: '12',
        gradeLevel: 'Class 5',
        totalDue: 2500.0,
        totalPaid: 2000.0,
        unpaidBalance: 500.0,
        unpaidLedgerCount: 1,
        unpaidDetails: ['Tuition Fee (April): ₹500'],
      );

      expect(summary.studentName, 'Rahul Sharma');
      expect(summary.unpaidBalance, 500.0);
      expect(summary.unpaidDetails.first, contains('₹500'));
    });
  });

  group('Database Arrears & Promotion Rollover Tests', () {
    test('End-of-Session fee clearance summary & promotion rollover workflow', () async {
      final dbHelper = DatabaseHelper();
      final dbService = DatabaseService(dbHelper: dbHelper);
      final db = await dbHelper.database;

      // 1. Create a student
      const studentId = 'test-student-arrears-1';
      await db.insert('students', {
        'id': studentId,
        'name': 'Aarav Gupta',
        'admission_number': 'ADM-999',
        'roll_number': '25',
        'grade_level': 'Class 5',
        'is_active': 1,
        'is_alumni': 0,
        'current_balance': 500.0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // 2. Insert partial April dues (2500 due, 2000 paid => 500 remaining)
      const aprilLedgerId = 'test-ledger-april-1';
      await db.insert('student_fee_ledger', {
        'id': aprilLedgerId,
        'student_id': studentId,
        'fee_head_id': 'fh-tuition',
        'academic_year': '2026-2027',
        'amount_due': 2500.0,
        'amount_paid': 2000.0,
        'due_date': '2026-04-10T00:00:00.000',
        'status': 'partial',
        'month_label': 'April',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // 3. Insert May dues (2500 due, 0 paid => 2500 remaining)
      const mayLedgerId = 'test-ledger-may-1';
      await db.insert('student_fee_ledger', {
        'id': mayLedgerId,
        'student_id': studentId,
        'fee_head_id': 'fh-tuition',
        'academic_year': '2026-2027',
        'amount_due': 2500.0,
        'amount_paid': 0.0,
        'due_date': '2026-05-10T00:00:00.000',
        'status': 'pending',
        'month_label': 'May',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // 4. Test getStudentsUnpaidDuesSummary: must detect both April (500) and May (2500) => 3000 total!
      final duesSummary = await dbService.getStudentsUnpaidDuesSummary(
        studentIds: [studentId],
        academicYear: '2026-2027',
      );

      expect(duesSummary.containsKey(studentId), true);
      final studentDues = duesSummary[studentId]!;
      expect(studentDues.unpaidBalance, 3000.0);
      expect(studentDues.unpaidLedgerCount, 2);

      // 5. Test multi-month payment: paying 3000 should clear April (500) and May (2500)
      final updatedLedgers = await dbService.recordMultiMonthPayment(
        studentId: studentId,
        academicYear: '2026-2027',
        ledgerIds: [aprilLedgerId, mayLedgerId],
        paymentMethod: PaymentMethod.cash,
        paidAmount: 3000.0,
      );

      expect(updatedLedgers.length, 2);
      expect(updatedLedgers[0].status, LedgerStatus.paid);
      expect(updatedLedgers[0].amountPaid, 2500.0);
      expect(updatedLedgers[1].status, LedgerStatus.paid);
      expect(updatedLedgers[1].amountPaid, 2500.0);

      // 6. Test Promotion Arrears Rollover:
      // Create a student who still has an uncleared balance of 500 at end of session
      const student2Id = 'test-student-rollover-2';
      await db.insert('students', {
        'id': student2Id,
        'name': 'Simran Kaur',
        'admission_number': 'ADM-888',
        'roll_number': '08',
        'grade_level': 'Class 5',
        'is_active': 1,
        'is_alumni': 0,
        'current_balance': 500.0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      const uncollectedLedgerId = 'test-ledger-uncollected-2';
      await db.insert('student_fee_ledger', {
        'id': uncollectedLedgerId,
        'student_id': student2Id,
        'fee_head_id': 'fh-tuition',
        'academic_year': '2026-2027',
        'amount_due': 2500.0,
        'amount_paid': 2000.0,
        'due_date': '2027-03-10T00:00:00.000',
        'status': 'partial',
        'month_label': 'March',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Execute promotion with rollover into 2027-2028
      await dbService.promoteStudentsWithArrearsRollover(
        studentIds: [student2Id],
        targetGrade: 'Class 6',
        fromAcademicYear: '2026-2027',
        toAcademicYear: '2027-2028',
        rolloverArrears: true,
      );

      // Verify student was promoted
      final studentAfter = await dbService.getStudentById(student2Id);
      expect(studentAfter?.gradeLevel, 'Class 6');

      // Verify new session has a Previous Session Arrears ledger entry of 500
      final newYearLedgers = await dbService.getStudentFeeLedger(student2Id, '2027-2028');
      final arrearsLedger = newYearLedgers.firstWhere(
        (l) => l.feeHeadId == 'fh-previous-arrears',
      );
      expect(arrearsLedger.amountDue, 500.0);
      expect(arrearsLedger.amountPaid, 0.0);
      expect(arrearsLedger.remainingAmount, 500.0);
      expect(arrearsLedger.status, LedgerStatus.pending);
      expect(arrearsLedger.monthLabel, contains('Arrears (2026-2027)'));

      // Verify old session ledger entry was settled with rollover tag
      final oldYearLedgers = await dbService.getStudentFeeLedger(student2Id, '2026-2027');
      final oldLedger = oldYearLedgers.firstWhere((l) => l.id == uncollectedLedgerId);
      expect(oldLedger.status, LedgerStatus.paid);
      expect(oldLedger.amountPaid, 2500.0);
      expect(oldLedger.monthLabel, contains('Rolled over to 2027-2028'));
    });
  });
}
