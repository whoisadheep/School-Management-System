import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../services/services.dart';
import '../models/models.dart';
import '../services/assistant_service.dart';

/// DatabaseService Provider
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final currentAdmin = ref.watch(authProvider).currentAdmin;
  return DatabaseService(currentAdminId: currentAdmin?.id);
});

/// InvoiceService Provider
final invoiceServiceProvider = Provider<InvoiceService>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return InvoiceService(dbService: dbService);
});

/// PaymentService Provider
final paymentServiceProvider = Provider<PaymentService>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return PaymentService(dbService: dbService);
});

/// Ledger Summary Provider (Total Income, Total Expense, Net Balance)
final ledgerSummaryProvider = FutureProvider<Map<String, double>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getLedgerSummary();
});

/// All Students Provider
final studentsListProvider = FutureProvider<List<Student>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllStudents();
});

/// All Invoices Provider
final invoicesListProvider = FutureProvider<List<Invoice>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllInvoices();
});

/// Fee Categories Provider
final feeCategoriesListProvider = FutureProvider<List<FeeCategory>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllFeeCategories();
});

/// All Staff Provider
final staffListProvider = FutureProvider<List<Staff>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllStaff(page: 0, pageSize: 10000, activeOnly: false);
});

/// All Departments Provider
final departmentListProvider = FutureProvider<List<Department>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllDepartments();
});

/// Staff Subjects Provider (requires staffId)
final staffSubjectsProvider = FutureProvider.family<List<StaffSubjectAssignment>, String>((ref, staffId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getStaffSubjects(staffId);
});

/// Staff Documents Provider (requires staffId)
final staffDocumentsProvider = FutureProvider.family<List<StaffDocument>, String>((ref, staffId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getStaffDocuments(staffId);
});

/// Salary Components Provider (requires staffId)
final salaryComponentsProvider = FutureProvider.family<List<SalaryComponent>, String>((ref, staffId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getSalaryComponents(staffId);
});

/// Student Documents Provider (requires studentId)
final studentDocumentsProvider = FutureProvider.family<List<StudentDocument>, String>((ref, studentId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getStudentDocuments(studentId);
});

/// Phase 1: Class Teacher In-Charge Assignment Provider (requires staffId)
final classTeacherAssignmentProvider = FutureProvider.family<ClassTeacherAssignment?, String>((ref, staffId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getClassTeacherAssignment(staffId);
});

/// Phase 1: Teacher Weekly Workload Provider (requires staffId)
final teacherWorkloadProvider = FutureProvider.family<int, String>((ref, staffId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getTeacherWeeklyWorkload(staffId);
});

/// Phase 2: Staff Timetable Provider (requires staffId)
final staffTimetableProvider = FutureProvider.family<List<TimetableEntry>, String>((ref, staffId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getTimetableForStaff(staffId);
});

/// Phase 3: Monthly Attendance Parameter Class
class MonthlyAttendanceParam {
  final String staffId;
  final int month;
  final int year;

  const MonthlyAttendanceParam({
    required this.staffId,
    required this.month,
    required this.year,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyAttendanceParam &&
          runtimeType == other.runtimeType &&
          staffId == other.staffId &&
          month == other.month &&
          year == other.year;

  @override
  int get hashCode => staffId.hashCode ^ month.hashCode ^ year.hashCode;
}

/// Phase 3: Teacher Monthly Attendance Summary Provider
final teacherMonthlyAttendanceSummaryProvider = FutureProvider.family<TeacherAttendanceSummary, MonthlyAttendanceParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getMonthlyAttendanceSummary(param.staffId, param.month, param.year);
});

/// Phase 3: Teacher Monthly Attendance Records Provider
final teacherMonthlyAttendanceRecordsProvider = FutureProvider.family<List<TeacherAttendance>, MonthlyAttendanceParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getTeacherMonthlyAttendanceRecords(param.staffId, param.month, param.year);
});

/// Phase 4: Leave Types Provider
final leaveTypesProvider = FutureProvider<List<LeaveType>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllLeaveTypes();
});

/// Phase 4: Staff Leave Applications Provider (requires staffId)
final staffLeaveApplicationsProvider = FutureProvider.family<List<LeaveApplication>, String>((ref, staffId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getLeaveApplicationsForStaff(staffId);
});

/// Phase 4: All Pending Leave Applications Provider (Admin)
final pendingLeaveApplicationsProvider = FutureProvider<List<LeaveApplication>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllPendingLeaveApplications();
});

/// Staff & Year Parameter Class for Leave Balance
class StaffYearParam {
  final String staffId;
  final int year;

  const StaffYearParam({required this.staffId, required this.year});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffYearParam &&
          runtimeType == other.runtimeType &&
          staffId == other.staffId &&
          year == other.year;

  @override
  int get hashCode => staffId.hashCode ^ year.hashCode;
}

/// Phase 4: Staff Leave Balance Provider
final staffLeaveBalanceProvider = FutureProvider.family<List<LeaveBalance>, StaffYearParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getStaffLeaveBalances(param.staffId, param.year);
});

/// Phase 5: Substitutions For Date Provider
final substitutionsForDateProvider = FutureProvider.family<List<Substitution>, String>((ref, date) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getSubstitutionsForDate(date);
});

/// Phase 6: Staff Exam Duty Provider
final staffExamDutiesProvider = FutureProvider.family<List<ExamDuty>, String>((ref, staffId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getExamDutiesForStaff(staffId);
});

/// Phase 6: All Exam Duties Provider
final allExamDutiesProvider = FutureProvider<List<ExamDuty>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllExamDuties();
});

/// Phase 7: Staff User & RBAC Permissions Provider
final staffUserProvider = FutureProvider.family<User?, String>((ref, staffId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getUserByStaffId(staffId);
});

/// Phase 8: All Circulars Provider
final allCircularsProvider = FutureProvider<List<Circular>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllCirculars();
});

/// Staff & Dept Parameter Class for Circulars
class StaffDeptParam {
  final String staffId;
  final String? departmentId;

  const StaffDeptParam({required this.staffId, this.departmentId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffDeptParam &&
          runtimeType == other.runtimeType &&
          staffId == other.staffId &&
          departmentId == other.departmentId;

  @override
  int get hashCode => staffId.hashCode ^ (departmentId?.hashCode ?? 0);
}

/// Phase 8: Staff Circulars Provider
final staffCircularsProvider = FutureProvider.family<List<Circular>, StaffDeptParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getCircularsForStaff(param.staffId, param.departmentId);
});

/// Phase 9: Staff Appraisals Provider
final staffAppraisalsProvider = FutureProvider.family<List<Appraisal>, String>((ref, staffId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAppraisalsForStaff(staffId);
});

/// Phase 10: Staff Trainings Provider
final staffTrainingsProvider = FutureProvider.family<List<Training>, String>((ref, staffId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getTrainingsForStaff(staffId);
});

/// Phase 2: Class List Provider
final classListProvider = FutureProvider<List<ClassModel>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllClasses();
});

/// Phase 2: Sections For Class Provider
final sectionsForClassProvider = FutureProvider.family<List<Section>, String>((ref, classId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getSectionsForClass(classId);
});

/// Phase 2: Section Student Count Provider
final sectionStudentCountProvider = FutureProvider.family<int, String>((ref, sectionId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getStudentCountForSection(sectionId);
});

// ============================================================================
// FEE HEADS & STRUCTURE CONFIGURATION PROVIDERS (PHASE 1)
// ============================================================================

final feeHeadsProvider = FutureProvider<List<FeeHead>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllFeeHeads();
});

/// All classes provider
final classesProvider = FutureProvider<List<ClassModel>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllClasses();
});

class ClassYearParam {
  final String className;
  final String academicYear;
  const ClassYearParam({required this.className, required this.academicYear});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassYearParam &&
          runtimeType == other.runtimeType &&
          className == other.className &&
          academicYear == other.academicYear;

  @override
  int get hashCode => className.hashCode ^ academicYear.hashCode;
}

final feeStructuresForClassProvider = FutureProvider.family<List<FeeStructure>, ClassYearParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getFeeStructuresForClass(param.className, param.academicYear);
});

// ============================================================================
// DISCOUNTS & SCHOLARSHIPS PROVIDERS (PHASE 2)
// ============================================================================

final discountTypesProvider = FutureProvider<List<DiscountType>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllDiscountTypes();
});

class StudentYearParam {
  final String studentId;
  final String academicYear;
  const StudentYearParam({required this.studentId, required this.academicYear});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentYearParam &&
          runtimeType == other.runtimeType &&
          studentId == other.studentId &&
          academicYear == other.academicYear;

  @override
  int get hashCode => studentId.hashCode ^ academicYear.hashCode;
}

final studentDiscountsProvider = FutureProvider.family<List<StudentDiscount>, StudentYearParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getDiscountsForStudent(param.studentId, param.academicYear);
});

class StudentClassYearParam {
  final String studentId;
  final String className;
  final String academicYear;
  const StudentClassYearParam({
    required this.studentId,
    required this.className,
    required this.academicYear,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentClassYearParam &&
          runtimeType == other.runtimeType &&
          studentId == other.studentId &&
          className == other.className &&
          academicYear == other.academicYear;

  @override
  int get hashCode => studentId.hashCode ^ className.hashCode ^ academicYear.hashCode;
}

final studentNetFeeBreakdownProvider = FutureProvider.family<List<StudentNetFeeBreakdown>, StudentClassYearParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getStudentNetPayableFees(param.studentId, param.className, param.academicYear);
});

// ============================================================================
// STUDENT FEE LEDGER PROVIDERS (PHASE 3)
// ============================================================================

/// Student Fee Ledger Provider — returns all ledger entries for a student + academic year
final studentFeeLedgerProvider = FutureProvider.family.autoDispose<List<StudentFeeLedger>, StudentYearParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getStudentFeeLedger(param.studentId, param.academicYear);
});

/// Student Ledger Summary Provider — returns {total_due, total_paid, total_overdue}
final studentLedgerSummaryProvider = FutureProvider.family.autoDispose<Map<String, double>, StudentYearParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getStudentLedgerSummary(param.studentId, param.academicYear);
});
// ============================================================================
// FEE REPORTING PROVIDERS (PHASE 4)
// ============================================================================

class ClassWiseDuesParam {
  final String academicYear;
  final String? feeHeadId;

  const ClassWiseDuesParam({required this.academicYear, this.feeHeadId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClassWiseDuesParam &&
          other.academicYear == academicYear &&
          other.feeHeadId == feeHeadId);

  @override
  int get hashCode => academicYear.hashCode ^ feeHeadId.hashCode;
}

/// Class-wise dues summary provider
final classWiseDuesSummaryProvider = FutureProvider.family<List<Map<String, dynamic>>, ClassWiseDuesParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getClassWiseDuesSummary(param.academicYear, feeHeadId: param.feeHeadId);
});

/// Overdue students list provider
final overdueStudentsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, academicYear) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getOverdueStudents(academicYear);
});

class CollectionFilterParam {
  final String academicYear;
  final DateTime? startDate;
  final DateTime? endDate;

  const CollectionFilterParam({
    required this.academicYear,
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionFilterParam &&
          runtimeType == other.runtimeType &&
          academicYear == other.academicYear &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => academicYear.hashCode ^ (startDate?.hashCode ?? 0) ^ (endDate?.hashCode ?? 0);
}

/// Collection breakdown by fee head provider
final collectionSummaryByFeeHeadProvider = FutureProvider.family<List<Map<String, dynamic>>, CollectionFilterParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getCollectionSummaryByFeeHead(
    param.academicYear,
    startDate: param.startDate,
    endDate: param.endDate,
  );
});

// ============================================================================
// TRANSPORT MANAGEMENT PROVIDERS (PHASE 2 & 3)
// ============================================================================

/// Provider for list of all vehicles
final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllVehicles();
});

/// Provider for list of drivers (staff with role = 'driver')
final driversListProvider = FutureProvider<List<Staff>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getDrivers();
});

/// Provider for vehicles requiring insurance or fitness renewal within 30 days
final vehiclesNeedingRenewalProvider = FutureProvider<List<Vehicle>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getVehiclesNeedingRenewal();
});

/// Provider for all transport routes
final routesListProvider = FutureProvider<List<Route>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllRoutes();
});

/// Provider for driver manifest / route with assigned students
final routeWithStudentsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, routeId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getRouteWithStudents(routeId);
});

/// Provider for Fleet Overview statistics and occupancy
final fleetOverviewProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getFleetOverview();
});

/// Provider for a specific student's transport details
final studentTransportProvider = FutureProvider.family<StudentTransport?, StudentYearParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getStudentTransport(param.studentId, param.academicYear);
});

// ============================================================================
// EXAMINATION & MARKS PROVIDERS (PHASE 1 & PHASE 2)
// ============================================================================

/// Provider for list of all exam types
final examTypesProvider = FutureProvider<List<ExamType>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllExamTypes();
});

class ExamClassYearParam {
  final String? className;
  final String? academicYear;

  const ExamClassYearParam({
    this.className,
    this.academicYear,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamClassYearParam &&
          runtimeType == other.runtimeType &&
          className == other.className &&
          academicYear == other.academicYear;

  @override
  int get hashCode => (className?.hashCode ?? 0) ^ (academicYear?.hashCode ?? 0);
}

/// Provider for list of exams filtered by class and academic year
final examsProvider = FutureProvider.family<List<Exam>, ExamClassYearParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllExams(
    className: param.className,
    academicYear: param.academicYear,
  );
});

/// Provider for list of exam subjects for an exam
final examSubjectsProvider = FutureProvider.family<List<ExamSubject>, String>((ref, examId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getExamSubjects(examId);
});

/// Provider for marks sheet roster of an exam subject
final marksSheetProvider = FutureProvider.family<List<Marks>, String>((ref, examSubjectId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.initializeMarksSheet(examSubjectId);
});

class StudentExamParam {
  final String studentId;
  final String examId;

  const StudentExamParam({
    required this.studentId,
    required this.examId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentExamParam &&
          runtimeType == other.runtimeType &&
          studentId == other.studentId &&
          examId == other.examId;

  @override
  int get hashCode => studentId.hashCode ^ examId.hashCode;
}

/// Provider for a student's marks in a specific exam (report card)
final studentMarksProvider = FutureProvider.family<List<Marks>, StudentExamParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getMarksForStudent(param.studentId, param.examId);
});

/// Provider for grade scale list
final gradeScalesProvider = FutureProvider.family<List<GradeScale>, String>((ref, academicYear) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getGradeScales(academicYear: academicYear);
});

/// Provider for computed exam result of a student
final examResultProvider = FutureProvider.family<ExamResultData?, StudentExamParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.computeExamResult(param.examId, param.studentId);
});

/// Provider for class exam rankings
final classExamRankingsProvider = FutureProvider.family<Map<String, int>, String>((ref, examId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getClassExamRankings(examId);
});

/// Provider for term aggregation result
final termResultProvider = FutureProvider.family<TermResultData?, StudentYearParam>((ref, param) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.computeTermResult(param.studentId, param.academicYear);
});

/// Provider for Exam Results Dashboard Data
final examResultsDashboardProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, examId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getExamResultsDashboardData(examId);
});

/// Feature Flags Provider
final featureFlagProvider = FutureProvider.family<bool, String>((ref, flagKey) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.isFeatureEnabled(flagKey);
});

/// Student Hostel Info Provider
final studentHostelInfoProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, studentId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getStudentHostelInfo(studentId);
});

/// Assistant Service Provider
final assistantServiceProvider = Provider<AssistantService>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return AssistantService(dbService);
});
