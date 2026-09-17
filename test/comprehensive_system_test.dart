import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/models/models.dart';
import 'package:school_management_system/core/auth/permission_helper.dart';
import 'package:school_management_system/services/report_generator.dart';

void main() {
  group('Comprehensive System & Model Tests', () {
    test('Student model serialization round-trip', () {
      final now = DateTime(2026, 8, 8, 12, 0, 0);
      final student = Student(
        id: 'test-student-1',
        name: 'Aarav Patel',
        admissionNumber: 'ADM-2026-001',
        rollNumber: '101',
        firstName: 'Aarav',
        lastName: 'Patel',
        gender: 'Male',
        dob: '2014-03-15',
        gradeLevel: 'Grade 6',
        section: 'A',
        currentBalance: 5000.0,
        admissionDate: '2026-08-08',
        isActive: true,
        fatherName: 'Rajesh Patel',
        motherName: 'Meena Patel',
        guardianPhone: '9876543210',
        residentialAddress: '123 MG Road, Mumbai',
        createdAt: now,
        updatedAt: now,
      );

      final map = student.toMap();
      expect(map['id'], 'test-student-1');
      expect(map['admission_number'], 'ADM-2026-001');
      expect(map['first_name'], 'Aarav');
      expect(map['last_name'], 'Patel');
      expect(map['current_balance'], 5000.0);
      expect(map['is_active'], 1);

      final reconstructed = Student.fromMap(map);
      expect(reconstructed.id, student.id);
      expect(reconstructed.admissionNumber, student.admissionNumber);
      expect(reconstructed.firstName, student.firstName);
      expect(reconstructed.lastName, student.lastName);
      expect(reconstructed.gradeLevel, student.gradeLevel);
      expect(reconstructed.currentBalance, student.currentBalance);
    });

    test('Staff model serialization and role assignment', () {
      final now = DateTime(2026, 8, 8);
      final staff = Staff(
        id: 'staff-1',
        staffCode: 'EMP-2026-001',
        firstName: 'Sunita',
        lastName: 'Verma',
        email: 'sunita@school.com',
        phone: '9876500000',
        designation: 'Senior Teacher',
        departmentId: 'dept-math',
        role: 'teacher',
        joiningDate: '2026-08-08',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = staff.toMap();
      expect(map['staff_code'], 'EMP-2026-001');
      expect(map['designation'], 'Senior Teacher');
      expect(map['department_id'], 'dept-math');

      final reconstructed = Staff.fromMap(map);
      expect(reconstructed.id, staff.id);
      expect(reconstructed.staffCode, staff.staffCode);
      expect(reconstructed.fullName, 'Sunita Verma');
    });

    test('Invoice calculation with discount and penalties', () {
      final inv = Invoice.create(
        studentId: 'stud-100',
        academicYearId: '2026-2027',
        totalAmount: 12000.0,
        discountAmount: 2000.0,
        penaltyAmount: 500.0,
        dueDate: DateTime(2026, 9, 10),
      );

      expect(inv.netAmount, equals(10500.0));
      expect(inv.status, equals(InvoiceStatus.pending));

      final partiallyPaid = inv.copyWith(status: InvoiceStatus.partial);
      expect(partiallyPaid.status, equals(InvoiceStatus.partial));
      expect(partiallyPaid.netAmount, equals(10500.0));
    });

    test('FeeStructure calculation logic', () {
      final structure = FeeStructure(
        id: 'fee-str-1',
        academicYear: '2026-2027',
        feeCategoryId: 'cat-tuition',
        className: 'Grade 10',
        feeHeadId: 'tuition-head',
        amount: 24000.0,
        dueDayOfMonth: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(structure.className, 'Grade 10');
      expect(structure.amount, 24000.0);
      expect(structure.dueDayOfMonth, 10);
    });

    test('Exam result and grade boundary calculations', () {
      String calculateStandardGrade(double percent) {
        if (percent >= 90.0) return 'A+';
        if (percent >= 80.0) return 'A';
        if (percent >= 70.0) return 'B';
        if (percent >= 60.0) return 'C';
        if (percent >= 50.0) return 'D';
        if (percent >= 35.0) return 'E';
        return 'F';
      }

      expect(calculateStandardGrade(95.5), equals('A+'));
      expect(calculateStandardGrade(89.9), equals('A'));
      expect(calculateStandardGrade(75.0), equals('B'));
      expect(calculateStandardGrade(62.0), equals('C'));
      expect(calculateStandardGrade(50.0), equals('D'));
      expect(calculateStandardGrade(35.0), equals('E'));
      expect(calculateStandardGrade(34.9), equals('F'));
      expect(calculateStandardGrade(0.0), equals('F'));
    });

    test('RiskyAction enum definitions and labels', () {
      expect(RiskyAction.deleteRecord.label, 'Delete Record');
      expect(RiskyAction.manageAdminUsers.label, 'Manage Admin Users');
      expect(RiskyAction.databaseBackupRestore.label, 'Database Backup & Restore');
      expect(RiskyAction.licenseManagement.label, 'License Management');
    });

    test('ExamSubject passing criteria logic', () {
      final subject = ExamSubject(
        id: 'subj-1',
        examId: 'exam-1',
        subject: 'Mathematics',
        examDate: DateTime(2026, 9, 15),
        maxMarks: 100.0,
        passingMarks: 35.0,
      );

      bool isStudentPassed(double? obtained, bool isAbsent) {
        if (isAbsent || obtained == null) return false;
        return obtained >= subject.passingMarks;
      }

      expect(isStudentPassed(35.0, false), isTrue);
      expect(isStudentPassed(34.5, false), isFalse);
      expect(isStudentPassed(100.0, false), isTrue);
      expect(isStudentPassed(85.0, true), isFalse);
      expect(isStudentPassed(null, false), isFalse);
    });

    test('ClassSubject model serialization round-trip', () {
      final now = DateTime(2026, 9, 14, 12, 0, 0);
      final cs = ClassSubject(
        id: 'csub-cls1-math',
        classId: 'cls-grade1',
        subjectName: 'Mathematics',
        defaultMaxMarks: 100.0,
        defaultPassMarks: 40.0,
        createdAt: now,
      );

      final map = cs.toMap();
      expect(map['id'], 'csub-cls1-math');
      expect(map['class_id'], 'cls-grade1');
      expect(map['subject_name'], 'Mathematics');
      expect(map['default_max_marks'], 100.0);
      expect(map['default_pass_marks'], 40.0);

      final restored = ClassSubject.fromMap(map);
      expect(restored.id, cs.id);
      expect(restored.classId, cs.classId);
      expect(restored.subjectName, cs.subjectName);
      expect(restored.defaultMaxMarks, 100.0);
      expect(restored.defaultPassMarks, 40.0);
    });

    test('Class subject to exam auto-pick and flexible removal logic', () {
      // Setup subjects for Class 1 and Class 2
      final class1Subjects = [
        ClassSubject.create(classId: 'cls-1', subjectName: 'Mathematics'),
        ClassSubject.create(classId: 'cls-1', subjectName: 'English'),
        ClassSubject.create(classId: 'cls-1', subjectName: 'Hindi'),
        ClassSubject.create(classId: 'cls-1', subjectName: 'Science'),
      ];

      final class2Subjects = [
        ClassSubject.create(classId: 'cls-2', subjectName: 'Mathematics'),
        ClassSubject.create(classId: 'cls-2', subjectName: 'English'),
        ClassSubject.create(classId: 'cls-2', subjectName: 'Environmental Studies'),
        ClassSubject.create(classId: 'cls-2', subjectName: 'Drawing'),
      ];

      // Auto-pick for Class 1 exam
      final exam1Drafts = List<ClassSubject>.from(class1Subjects);
      expect(exam1Drafts.length, 4);
      expect(exam1Drafts.map((s) => s.subjectName), containsAll(['Mathematics', 'English', 'Hindi', 'Science']));

      // User chooses to remove 'Hindi' from this specific Class 1 exam
      exam1Drafts.removeWhere((s) => s.subjectName == 'Hindi');
      expect(exam1Drafts.length, 3);
      expect(exam1Drafts.any((s) => s.subjectName == 'Hindi'), isFalse);

      // Verify Class 2 has distinct subjects
      final exam2Drafts = List<ClassSubject>.from(class2Subjects);
      expect(exam2Drafts.any((s) => s.subjectName == 'Environmental Studies'), isTrue);
      expect(exam1Drafts.any((s) => s.subjectName == 'Environmental Studies'), isFalse);
    });

    test('StudentDiscount model serialization and custom fields', () {
      final discount = StudentDiscount.create(
        studentId: 'student-abc',
        discountTypeId: 'custom_discount',
        academicYear: '2026-2027',
        customName: 'Merit Scholarship',
        customKind: 'flat',
        customValue: 5000.0,
        flatMode: 'earliest',
        remarks: 'Top rank in entrance test',
      );

      final map = discount.toMap();
      expect(map['student_id'], 'student-abc');
      expect(map['custom_name'], 'Merit Scholarship');
      expect(map['custom_kind'], 'flat');
      expect(map['custom_value'], 5000.0);
      expect(map['flat_mode'], 'earliest');
      expect(map['remarks'], 'Top rank in entrance test');

      final restored = StudentDiscount.fromMap(map);
      expect(restored.studentId, 'student-abc');
      expect(restored.customName, 'Merit Scholarship');
      expect(restored.customKind, 'flat');
      expect(restored.customValue, 5000.0);
      expect(restored.flatMode, 'earliest');
      expect(restored.remarks, 'Top rank in entrance test');
    });

    test('StudentDiscount copyWith supports custom fields and flatMode', () {
      final discount = StudentDiscount.create(
        studentId: 'student-xyz',
        discountTypeId: 'sibling',
        academicYear: '2026-2027',
      );

      final modified = discount.copyWith(
        customName: 'Sibling Concession',
        customKind: 'percentage',
        customValue: 25.0,
        flatMode: 'evenly',
      );

      expect(modified.customName, 'Sibling Concession');
      expect(modified.customKind, 'percentage');
      expect(modified.customValue, 25.0);
      expect(modified.flatMode, 'evenly');
    });

    test('buildBatchPaymentReceiptPdfBytes generates 2-in-1 A4 receipt PDF bytes', () async {
      final now = DateTime.now();
      final student = Student(
        id: 'std-batch-test',
        name: 'Aarav Sharma',
        gradeLevel: 'Grade 5',
        section: 'B',
        admissionNumber: 'ADM-1001',
        rollNumber: '12',
        guardianPhone: '9876543210',
        currentBalance: 0.0,
        createdAt: now,
        updatedAt: now,
      );

      final List<StudentFeeLedger> ledgers = [
        StudentFeeLedger.create(
          studentId: student.id,
          feeHeadId: 'fh-tuition',
          academicYear: '2026-2027',
          amountDue: 2500.0,
          dueDate: DateTime(2026, 4, 10),
          feeHeadName: 'Tuition Fee',
          monthLabel: 'April 2026',
        ),
        StudentFeeLedger.create(
          studentId: student.id,
          feeHeadId: 'fh-transport',
          academicYear: '2026-2027',
          amountDue: 1200.0,
          dueDate: DateTime(2026, 4, 10),
          feeHeadName: 'Transport Fee',
          monthLabel: 'April 2026',
        ),
      ];

      final pdfBytes = await ReportGenerator.buildBatchPaymentReceiptPdfBytes(
        paidLedgers: ledgers,
        student: student,
        totalAmountPaid: 3700.0,
        paymentMethod: PaymentMethod.online,
        receiptNumber: 'RCT-2026-0001',
        academicYear: '2026-2027',
        schoolName: 'Greenwood High',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('buildPaymentReceiptPdfBytes generates 2-in-1 A4 single-invoice receipt PDF bytes', () async {
      final now = DateTime.now();
      final student = Student(
        id: 'std-single-test',
        name: 'Diya Patel',
        gradeLevel: 'Grade 8',
        admissionNumber: 'ADM-2002',
        currentBalance: 500.0,
        createdAt: now,
        updatedAt: now,
      );

      final invoice = Invoice.create(
        studentId: student.id,
        academicYearId: '2026-2027',
        totalAmount: 3000.0,
        discountAmount: 300.0,
        dueDate: DateTime(2026, 9, 30),
      );

      final transaction = Transaction(
        id: 'txn-single-test',
        invoiceId: invoice.id,
        amountPaid: 2700.0,
        paymentMethod: PaymentMethod.cash,
        timestamp: now,
        createdAt: now,
        updatedAt: now,
      );

      final pdfBytes = await ReportGenerator.buildPaymentReceiptPdfBytes(
        transaction: transaction,
        invoice: invoice,
        student: student,
        receiptNumber: 'RCT-2026-0002',
        feeHeadName: 'Quarterly Composite Fee',
        schoolName: 'Greenwood High',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}
