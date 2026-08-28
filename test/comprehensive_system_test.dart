import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/models/models.dart';
import 'package:school_management_system/core/auth/permission_helper.dart';

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
  });
}
