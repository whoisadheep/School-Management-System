import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../models/models.dart';

/// Comprehensive local DatabaseService handling all SQLite CRUD operations.
/// Utilizes raw SQL queries and batch transactions via [DatabaseHelper].
class DatabaseService {
  final String? currentAdminId;
  final DatabaseHelper _dbHelper;

  DatabaseService({DatabaseHelper? dbHelper, this.currentAdminId})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<Database> get _db async => await _dbHelper.database;
  Future<Database> get rawDb async => await _dbHelper.database;

  // ============================================================================
  // 0. STAFF CRUD OPERATIONS
  // ============================================================================

  /// Generate the next staff code for the current year (EMP-YYYY-XXX).
  ///
  /// [afterCode] is used by the form's regenerate action. It advances from a
  /// currently displayed code even though that code has not been saved yet.
  Future<String> generateNextStaffCode({String? afterCode}) async {
    final db = await _db;
    final year = DateTime.now().year;
    final prefix = 'EMP-$year-';
    final codeRows = await db.query(
      'staff',
      columns: ['staff_code'],
      where: 'staff_code LIKE ?',
      whereArgs: ['$prefix%'],
    );

    var highestSequence = 0;
    for (final row in codeRows) {
      final code = row['staff_code'] as String?;
      final sequence =
          code == null ? null : int.tryParse(code.substring(prefix.length));
      if (sequence != null && sequence > highestSequence) {
        highestSequence = sequence;
      }
    }

    final displayedSequence = afterCode != null && afterCode.startsWith(prefix)
        ? int.tryParse(afterCode.substring(prefix.length))
        : null;
    final nextSequence =
        displayedSequence != null && displayedSequence >= highestSequence
            ? displayedSequence + 1
            : highestSequence + 1;
    final seq = nextSequence.toString().padLeft(3, '0');
    return 'EMP-$year-$seq';
  }



  /// Insert a new staff record into SQLite
  Future<int> insertStaff(Staff staff) async {
    final db = await _db;

    // Auto-generate staff_code if not provided
    String? finalStaffCode = staff.staffCode;
    if (finalStaffCode == null || finalStaffCode.isEmpty) {
      finalStaffCode = await generateNextStaffCode();
    }

    final staffMap = staff.copyWith(staffCode: finalStaffCode).toMap();

    try {
      return await _insertLogged(db, 
        'staff',
        staffMap,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('unique constraint failed: staff.email')) {
        throw Exception('A staff member with this email already exists.');
      } else if (errorStr.contains('unique constraint failed: staff.phone')) {
        throw Exception(
            'A staff member with this phone number already exists.');
      } else if (errorStr
          .contains('unique constraint failed: staff.staff_code')) {
        throw Exception('A staff member with this staff code already exists.');
      }
      rethrow;
    }
  }

  /// Retrieve a staff by unique ID
  Future<Staff?> getStaffById(String id) async {
    final db = await _db;
    final results = await db.query(
      'staff',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return Staff.fromMap(results.first);
  }

  /// Retrieve all staff with pagination (optionally filtering active-only)
  Future<List<Staff>> getAllStaff(
      {int page = 0, int pageSize = 25, bool activeOnly = true}) async {
    final db = await _db;
    final offset = page * pageSize;
    final results = await db.query(
      'staff',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'first_name ASC',
      limit: pageSize,
      offset: offset,
    );

    return results.map((map) => Staff.fromMap(map)).toList();
  }

  /// Update an existing staff record
  Future<int> updateStaff(Staff staff) async {
    final db = await _db;
    final updatedMap = staff.toMap();
    updatedMap['updated_at'] = DateTime.now().toIso8601String();

    try {
      return await _updateLogged(db, 
        'staff',
        updatedMap,
        where: 'id = ?',
        whereArgs: [staff.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('unique constraint failed: staff.email')) {
        throw Exception('A staff member with this email already exists.');
      } else if (errorStr.contains('unique constraint failed: staff.phone')) {
        throw Exception(
            'A staff member with this phone number already exists.');
      } else if (errorStr
          .contains('unique constraint failed: staff.staff_code')) {
        throw Exception('A staff member with this staff code already exists.');
      }
      rethrow;
    }
  }

  /// Soft-delete or toggle active status of a staff member
  Future<int> setStaffActiveStatus(String id, bool isActive) async {
    final db = await _db;
    return await _updateLogged(db, 
      'staff',
      {
        'is_active': isActive ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // 0.5 STAFF EXTENDED CRUD OPERATIONS
  // ============================================================================

  // --- Departments ---
  Future<List<Department>> getAllDepartments() async {
    final db = await _db;
    final results = await db.query('departments', orderBy: 'name ASC');
    return results.map((e) => Department.fromMap(e)).toList();
  }

  Future<int> insertDepartment(Department dept) async {
    final db = await _db;
    return await _insertLogged(db, 'departments', dept.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateDepartment(Department dept) async {
    final db = await _db;
    return await _updateLogged(db, 'departments', dept.toMap(),
        where: 'id = ?', whereArgs: [dept.id]);
  }

  Future<int> deleteDepartment(String id) async {
    final db = await _db;
    return await _deleteLogged(db, 'departments', where: 'id = ?', whereArgs: [id]);
  }

  // --- Staff Subjects ---
  Future<List<StaffSubjectAssignment>> getStaffSubjects(String staffId) async {
    final db = await _db;
    final results = await db
        .query('staff_subjects', where: 'staff_id = ?', whereArgs: [staffId]);
    return results.map((e) => StaffSubjectAssignment.fromMap(e)).toList();
  }

  Future<int> insertStaffSubject(StaffSubjectAssignment subject) async {
    final db = await _db;
    return await _insertLogged(db, 'staff_subjects', subject.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteStaffSubject(String id) async {
    final db = await _db;
    return await _deleteLogged(db, 'staff_subjects', where: 'id = ?', whereArgs: [id]);
  }

  // --- Staff Documents ---
  Future<List<StaffDocument>> getStaffDocuments(String staffId) async {
    final db = await _db;
    final results = await db
        .query('staff_documents', where: 'staff_id = ?', whereArgs: [staffId]);
    return results.map((e) => StaffDocument.fromMap(e)).toList();
  }

  Future<int> insertStaffDocument(StaffDocument doc) async {
    final db = await _db;
    return await _insertLogged(db, 'staff_documents', doc.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteStaffDocument(String id) async {
    final db = await _db;
    return await _deleteLogged(db, 'staff_documents', where: 'id = ?', whereArgs: [id]);
  }

  // --- Salary Components ---
  Future<List<SalaryComponent>> getSalaryComponents(String staffId) async {
    final db = await _db;
    final results = await db.query('salary_components',
        where: 'staff_id = ?', whereArgs: [staffId]);
    return results.map((e) => SalaryComponent.fromMap(e)).toList();
  }

  Future<int> insertSalaryComponent(SalaryComponent component) async {
    final db = await _db;
    return await _insertLogged(db, 'salary_components', component.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateSalaryComponent(SalaryComponent component) async {
    final db = await _db;
    return await _updateLogged(db, 'salary_components', component.toMap(),
        where: 'id = ?', whereArgs: [component.id]);
  }

  Future<int> deleteSalaryComponent(String id) async {
    final db = await _db;
    return await db
        .delete('salary_components', where: 'id = ?', whereArgs: [id]);
  }

  // ============================================================================
  // 1. STUDENT CRUD OPERATIONS
  // ============================================================================

  /// Insert a new student record into SQLite
  Future<int> insertStudent(Student student) async {
    final db = await _db;
    return await _insertLogged(db, 
      'students',
      student.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve a student by unique ID
  Future<Student?> getStudentById(String id) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT s.*, 
             COALESCE(SUM(l.amount_due - l.amount_paid), 0.0) as calculated_balance
      FROM students s
      LEFT JOIN student_fee_ledger l ON s.id = l.student_id
      WHERE s.id = ?
      GROUP BY s.id
    ''', [id]);

    if (results.isEmpty) return null;
    final mutableMap = Map<String, dynamic>.from(results.first);
    mutableMap['current_balance'] = mutableMap['calculated_balance'];
    return Student.fromMap(mutableMap);
  }

  /// Retrieve all students (optionally filtering active-only)
  Future<List<Student>> getAllStudents({bool activeOnly = true}) async {
    final db = await _db;
    final String whereClause = activeOnly ? 'WHERE s.is_active = 1' : '';
    
    final results = await db.rawQuery('''
      SELECT s.*, 
             COALESCE(SUM(l.amount_due - l.amount_paid), 0.0) as calculated_balance
      FROM students s
      LEFT JOIN student_fee_ledger l ON s.id = l.student_id
      $whereClause
      GROUP BY s.id
      ORDER BY s.name ASC
    ''');

    return results.map((map) {
      final mutableMap = Map<String, dynamic>.from(map);
      mutableMap['current_balance'] = mutableMap['calculated_balance'];
      return Student.fromMap(mutableMap);
    }).toList();
  }

  /// Retrieve active students for a specific grade level
  Future<List<Student>> getStudentsByGrade(String gradeLevel) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT s.*, 
             COALESCE(SUM(l.amount_due - l.amount_paid), 0.0) as calculated_balance
      FROM students s
      LEFT JOIN student_fee_ledger l ON s.id = l.student_id
      WHERE s.grade_level = ? AND s.is_active = 1
      GROUP BY s.id
      ORDER BY s.name ASC
    ''', [gradeLevel]);

    return results.map((map) {
      final mutableMap = Map<String, dynamic>.from(map);
      mutableMap['current_balance'] = mutableMap['calculated_balance'];
      return Student.fromMap(mutableMap);
    }).toList();
  }

  /// Update an existing student record
  Future<int> updateStudent(Student student) async {
    final db = await _db;
    final updatedMap = student.toMap();
    updatedMap['updated_at'] = DateTime.now().toIso8601String();

    return await _updateLogged(db, 
      'students',
      updatedMap,
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  /// Soft-delete or toggle active status of a student
  Future<int> setStudentActiveStatus(String id, bool isActive) async {
    final db = await _db;
    return await _updateLogged(db, 
      'students',
      {
        'is_active': isActive ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Search students by name or guardian phone number
  Future<List<Student>> searchStudents(String query) async {
    final db = await _db;
    final searchPattern = '%$query%';
    final results = await db.rawQuery('''
      SELECT s.*, 
             COALESCE(SUM(l.amount_due - l.amount_paid), 0.0) as calculated_balance
      FROM students s
      LEFT JOIN student_fee_ledger l ON s.id = l.student_id
      WHERE (s.name LIKE ? OR s.guardian_phone LIKE ? OR s.admission_number LIKE ?) AND s.is_active = 1
      GROUP BY s.id
      ORDER BY s.name ASC
    ''', [searchPattern, searchPattern, searchPattern]);

    return results.map((map) {
      final mutableMap = Map<String, dynamic>.from(map);
      mutableMap['current_balance'] = mutableMap['calculated_balance'];
      return Student.fromMap(mutableMap);
    }).toList();
  }

  /// Retrieve Alumni / Inactive students
  Future<List<Student>> getAlumniStudents() async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT s.*, 
             COALESCE(SUM(l.amount_due - l.amount_paid), 0.0) as calculated_balance
      FROM students s
      LEFT JOIN student_fee_ledger l ON s.id = l.student_id
      WHERE s.is_alumni = 1 OR s.is_active = 0
      GROUP BY s.id
      ORDER BY s.name ASC
    ''');

    return results.map((map) {
      final mutableMap = Map<String, dynamic>.from(map);
      mutableMap['current_balance'] = mutableMap['calculated_balance'];
      return Student.fromMap(mutableMap);
    }).toList();
  }

  /// Issue Transfer Certificate (TC) to a student and mark as Alumni
  Future<int> issueStudentTC({
    required String studentId,
    required String tcNumber,
    required String tcDate,
  }) async {
    final db = await _db;
    return await _updateLogged(db, 
      'students',
      {
        'is_active': 0,
        'is_alumni': 1,
        'tc_number': tcNumber,
        'tc_date': tcDate,
      },
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  /// Bulk promote a list of students to a new grade level or alumni status
  Future<void> promoteStudentsBatch({
    required List<String> studentIds,
    required String targetGrade,
    String? classId,
    String? sectionId,
    String? sectionName,
    bool markAsAlumni = false,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final id in studentIds) {
        if (markAsAlumni) {
          await _updateLogged(txn, 
            'students',
            {
              'is_active': 0,
              'is_alumni': 1,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          final Map<String, Object?> updates = {
            'grade_level': targetGrade,
          };
          if (classId != null) updates['class_id'] = classId;
          if (sectionId != null) updates['section_id'] = sectionId;
          if (sectionName != null) updates['section'] = sectionName;
          
          await _updateLogged(txn, 
            'students',
            updates,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    });
  }

  // ----------------------------------------------------------------------------
  // Student Document Storage Operations
  // ----------------------------------------------------------------------------

  /// Retrieve documents for a given student
  Future<List<StudentDocument>> getStudentDocuments(String studentId) async {
    final db = await _db;
    final results = await db.query(
      'student_documents',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'uploaded_at DESC',
    );

    return results.map((map) => StudentDocument.fromMap(map)).toList();
  }

  /// Insert a student document
  Future<int> insertStudentDocument(StudentDocument doc) async {
    final db = await _db;
    return await _insertLogged(db, 'student_documents', doc.toMap());
  }

  /// Delete a student document by ID
  Future<int> deleteStudentDocument(String docId) async {
    final db = await _db;
    return await _deleteLogged(db, 
      'student_documents',
      where: 'id = ?',
      whereArgs: [docId],
    );
  }


  // ============================================================================
  // 2. FEE CATEGORY CRUD OPERATIONS
  // ============================================================================

  /// Insert a new fee category
  Future<int> insertFeeCategory(FeeCategory category) async {
    final db = await _db;
    return await _insertLogged(db, 
      'fee_categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve a fee category by ID
  Future<FeeCategory?> getFeeCategoryById(String id) async {
    final db = await _db;
    final results = await db.query(
      'fee_categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return FeeCategory.fromMap(results.first);
  }

  /// Retrieve all fee categories
  Future<List<FeeCategory>> getAllFeeCategories(
      {bool activeOnly = true}) async {
    final db = await _db;
    final results = await db.query(
      'fee_categories',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name ASC',
    );

    return results.map((map) => FeeCategory.fromMap(map)).toList();
  }

  /// Update a fee category
  Future<int> updateFeeCategory(FeeCategory category) async {
    final db = await _db;
    final map = category.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();

    return await _updateLogged(db, 
      'fee_categories',
      map,
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  // ============================================================================
  // 3. INVOICE CRUD OPERATIONS
  // ============================================================================

  /// Insert a single invoice
  Future<int> insertInvoice(Invoice invoice) async {
    final db = await _db;
    return db.transaction((txn) async {
      final studentCountResult = await txn.rawQuery(
        'SELECT COUNT(*) AS count FROM students WHERE id = ?',
        [invoice.studentId],
      );
      if (studentCountResult.first['count'] != 1) {
        throw ArgumentError(
            'Student with ID "${invoice.studentId}" not found.');
      }

      final result = await _insertLogged(txn, 
        'invoices',
        invoice.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await txn.rawUpdate(
        '''UPDATE students
           SET current_balance = current_balance + ?, updated_at = ?
           WHERE id = ?''',
        [
          invoice.netAmount,
          DateTime.now().toIso8601String(),
          invoice.studentId
        ],
      );
      return result;
    });
  }

  /// Insert a batch of invoices inside a single SQLite transaction
  Future<void> insertInvoicesBatch(List<Invoice> invoices) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final invoice in invoices) {
        final studentCountResult = await txn.rawQuery(
          'SELECT COUNT(*) AS count FROM students WHERE id = ?',
          [invoice.studentId],
        );
        if (studentCountResult.first['count'] != 1) {
          throw ArgumentError(
              'Student with ID "${invoice.studentId}" not found.');
        }
        await _insertLogged(txn, 
          'invoices',
          invoice.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        await txn.rawUpdate(
          '''UPDATE students
             SET current_balance = current_balance + ?, updated_at = ?
             WHERE id = ?''',
          [
            invoice.netAmount,
            DateTime.now().toIso8601String(),
            invoice.studentId
          ],
        );
      }
    });
  }

  /// Retrieve an invoice by ID
  Future<Invoice?> getInvoiceById(String id) async {
    final db = await _db;
    final results = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return Invoice.fromMap(results.first);
  }

  /// Retrieve all invoices for a given student
  Future<List<Invoice>> getInvoicesByStudentId(String studentId) async {
    final db = await _db;
    final results = await db.query(
      'invoices',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'due_date DESC',
    );

    return results.map((map) => Invoice.fromMap(map)).toList();
  }

  /// Retrieve all invoices with optional status filter
  Future<List<Invoice>> getAllInvoices({InvoiceStatus? statusFilter}) async {
    final db = await _db;
    final results = await db.query(
      'invoices',
      where: statusFilter != null ? 'status = ?' : null,
      whereArgs: statusFilter != null ? [statusFilter.name] : null,
      orderBy: 'created_at DESC',
    );

    return results.map((map) => Invoice.fromMap(map)).toList();
  }

  /// Manually update invoice status
  Future<int> updateInvoiceStatus(String id, InvoiceStatus status) async {
    final db = await _db;
    return await _updateLogged(db, 
      'invoices',
      {
        'status': status.name,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // 4. TRANSACTION CRUD OPERATIONS
  // ============================================================================

  /// Insert a payment transaction
  Future<int> insertTransaction(Transaction transaction) async {
    final db = await _db;
    return await _insertLogged(db, 
      'transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve transaction by ID
  Future<Transaction?> getTransactionById(String id) async {
    final db = await _db;
    final results = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return Transaction.fromMap(results.first);
  }

  /// Retrieve transactions for a given invoice
  Future<List<Transaction>> getTransactionsByInvoiceId(String invoiceId) async {
    final db = await _db;
    final results = await db.query(
      'transactions',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'timestamp DESC',
    );

    return results.map((map) => Transaction.fromMap(map)).toList();
  }

  /// Retrieve all transactions
  Future<List<Transaction>> getAllTransactions() async {
    final db = await _db;
    final results = await db.query(
      'transactions',
      orderBy: 'timestamp DESC',
    );

    return results.map((map) => Transaction.fromMap(map)).toList();
  }

  // ============================================================================
  // 5. LEDGER ENTRY CRUD OPERATIONS
  // ============================================================================

  /// Insert a ledger entry
  Future<int> insertLedgerEntry(LedgerEntry entry) async {
    final db = await _db;
    return await _insertLogged(db, 
      'ledger_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve all ledger entries
  Future<List<LedgerEntry>> getAllLedgerEntries() async {
    final db = await _db;
    final results = await db.query(
      'ledger_entries',
      orderBy: 'date DESC',
    );

    return results.map((map) => LedgerEntry.fromMap(map)).toList();
  }

  /// Retrieve ledger entries within a date range
  Future<List<LedgerEntry>> getLedgerEntriesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _db;
    final results = await db.query(
      'ledger_entries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date DESC',
    );

    return results.map((map) => LedgerEntry.fromMap(map)).toList();
  }

  /// Get total income and total expense aggregates
  Future<Map<String, double>> getLedgerSummary() async {
    final db = await _db;
    final incomeResult = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM ledger_entries WHERE type = 'income'",
    );
    final expenseResult = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM ledger_entries WHERE type = 'expense'",
    );

    final double totalIncome = (incomeResult.first['total'] as num).toDouble();
    final double totalExpense =
        (expenseResult.first['total'] as num).toDouble();

    return {
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'net_balance': totalIncome - totalExpense,
    };
  }

  /// Run custom raw query (useful for analytics & reports)
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await _db;
    return await db.rawQuery(sql, arguments);
  }

  // ============================================================================
  // TEACHER MANAGEMENT: PHASE 1 — Class Ownership & Workload
  // ============================================================================

  /// Get class in-charge assignment for a staff member
  Future<ClassTeacherAssignment?> getClassTeacherAssignment(String staffId) async {
    final db = await _db;
    final results = await db.query(
      'class_teacher_assignments',
      where: 'staff_id = ?',
      whereArgs: [staffId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ClassTeacherAssignment.fromMap(results.first);
  }

  /// Assign or update class teacher assignment
  Future<int> assignClassTeacher(ClassTeacherAssignment assignment) async {
    final db = await _db;
    await _deleteLogged(db, 
      'class_teacher_assignments',
      where: 'staff_id = ?',
      whereArgs: [assignment.staffId],
    );
    return await _insertLogged(db, 
      'class_teacher_assignments',
      assignment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete class teacher assignment
  Future<int> deleteClassTeacherAssignment(String id) async {
    final db = await _db;
    return await _deleteLogged(db, 
      'class_teacher_assignments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Service method to compute weekly period load per teacher from staff_subjects & timetable
  Future<int> getTeacherWeeklyWorkload(String staffId) async {
    final db = await _db;
    final timetableCountResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM timetable WHERE staff_id = ?',
      [staffId],
    );
    final timetableCount = (timetableCountResult.first['cnt'] as num).toInt();
    if (timetableCount > 0) {
      return timetableCount;
    }
    final subjects = await getStaffSubjects(staffId);
    return subjects.length * 5;
  }

  // ============================================================================
  // TEACHER MANAGEMENT: PHASE 2 — Timetable
  // ============================================================================

  /// Get weekly timetable entries for a staff member
  Future<List<TimetableEntry>> getTimetableForStaff(String staffId) async {
    final db = await _db;
    final results = await db.query(
      'timetable',
      where: 'staff_id = ?',
      whereArgs: [staffId],
      orderBy: 'day_of_week ASC, period_number ASC',
    );
    return results.map((map) => TimetableEntry.fromMap(map)).toList();
  }

  /// Get timetable entries for a specific class & section
  Future<List<TimetableEntry>> getTimetableForClass(String className, String section) async {
    final db = await _db;
    final results = await db.query(
      'timetable',
      where: 'class = ? AND section = ?',
      whereArgs: [className, section],
      orderBy: 'day_of_week ASC, period_number ASC',
    );
    return results.map((map) => TimetableEntry.fromMap(map)).toList();
  }

  /// Add a timetable entry
  Future<int> addTimetableEntry(TimetableEntry entry) async {
    final db = await _db;
    return await _insertLogged(db, 
      'timetable',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete a timetable entry
  Future<int> deleteTimetableEntry(String id) async {
    final db = await _db;
    return await _deleteLogged(db, 
      'timetable',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get list of free period numbers (1..8) for a teacher on a given date (for substitute suggestions)
  Future<List<int>> getFreePeriods(String staffId, DateTime date) async {
    final dayOfWeek = date.weekday; // 1 = Monday .. 6 = Saturday
    if (dayOfWeek > 6) return [1, 2, 3, 4, 5, 6, 7, 8];

    final db = await _db;
    final busyResults = await db.query(
      'timetable',
      columns: ['period_number'],
      where: 'staff_id = ? AND day_of_week = ?',
      whereArgs: [staffId, dayOfWeek],
    );

    final busyPeriods = busyResults.map((m) => m['period_number'] as int).toSet();
    final allPeriods = [1, 2, 3, 4, 5, 6, 7, 8];
    return allPeriods.where((p) => !busyPeriods.contains(p)).toList();
  }

  // ============================================================================
  // TEACHER MANAGEMENT: PHASE 3 — Teacher Attendance
  // ============================================================================

  /// Mark or update attendance for a teacher
  Future<int> markTeacherAttendance(TeacherAttendance attendance) async {
    final db = await _db;
    return await _insertLogged(db, 
      'teacher_attendance',
      attendance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get attendance record for a teacher on a specific date
  Future<TeacherAttendance?> getTeacherAttendanceForDate(String staffId, String date) async {
    final db = await _db;
    final results = await db.query(
      'teacher_attendance',
      where: 'staff_id = ? AND date = ?',
      whereArgs: [staffId, date],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return TeacherAttendance.fromMap(results.first);
  }

  /// Get daily attendance records for all staff members on a given date
  Future<List<TeacherAttendance>> getDailyTeacherAttendance(String date) async {
    final db = await _db;
    final results = await db.query(
      'teacher_attendance',
      where: 'date = ?',
      whereArgs: [date],
    );
    return results.map((m) => TeacherAttendance.fromMap(m)).toList();
  }

  /// Get monthly attendance summary for a teacher (present, absent, late, half_day counts)
  Future<TeacherAttendanceSummary> getMonthlyAttendanceSummary(String staffId, int month, int year) async {
    final db = await _db;
    final monthStr = month.toString().padLeft(2, '0');
    final pattern = '$year-$monthStr-%';

    final results = await db.query(
      'teacher_attendance',
      where: 'staff_id = ? AND date LIKE ?',
      whereArgs: [staffId, pattern],
    );

    int present = 0;
    int absent = 0;
    int late = 0;
    int halfDay = 0;

    for (final map in results) {
      final status = map['status'] as String;
      if (status == 'present') present++;
      else if (status == 'absent') absent++;
      else if (status == 'late') late++;
      else if (status == 'half_day') halfDay++;
    }

    return TeacherAttendanceSummary(
      presentCount: present,
      absentCount: absent,
      lateCount: late,
      halfDayCount: halfDay,
      totalDays: results.length,
    );
  }

  /// Get full list of attendance records for a teacher in a given month
  Future<List<TeacherAttendance>> getTeacherMonthlyAttendanceRecords(String staffId, int month, int year) async {
    final db = await _db;
    final monthStr = month.toString().padLeft(2, '0');
    final pattern = '$year-$monthStr-%';

    final results = await db.query(
      'teacher_attendance',
      where: 'staff_id = ? AND date LIKE ?',
      whereArgs: [staffId, pattern],
      orderBy: 'date ASC',
    );

    return results.map((m) => TeacherAttendance.fromMap(m)).toList();
  }

  // ============================================================================
  // TEACHER MANAGEMENT: PHASE 4 — Leave Management
  // ============================================================================

  /// Get all leave types (seeds default if empty)
  Future<List<LeaveType>> getAllLeaveTypes() async {
    final db = await _db;
    var results = await db.query('leave_types');
    if (results.isEmpty) {
      await _insertLogged(db, 'leave_types', {'id': 'lt-casual', 'name': 'Casual Leave', 'days_allowed_per_year': 12});
      await _insertLogged(db, 'leave_types', {'id': 'lt-sick', 'name': 'Sick Leave', 'days_allowed_per_year': 10});
      await _insertLogged(db, 'leave_types', {'id': 'lt-earned', 'name': 'Earned Leave', 'days_allowed_per_year': 15});
      results = await db.query('leave_types');
    }
    return results.map((m) => LeaveType.fromMap(m)).toList();
  }

  /// Apply for staff leave
  Future<int> applyForLeave(LeaveApplication app) async {
    final db = await _db;
    return await _insertLogged(db, 'leave_applications', app.toMap());
  }

  /// Get leave applications for a staff member
  Future<List<LeaveApplication>> getLeaveApplicationsForStaff(String staffId) async {
    final db = await _db;
    final results = await db.query(
      'leave_applications',
      where: 'staff_id = ?',
      whereArgs: [staffId],
      orderBy: 'applied_at DESC',
    );
    return results.map((m) => LeaveApplication.fromMap(m)).toList();
  }

  /// Get all pending leave applications
  Future<List<LeaveApplication>> getAllPendingLeaveApplications() async {
    final db = await _db;
    final results = await db.query(
      'leave_applications',
      where: "status = 'pending'",
      orderBy: 'applied_at DESC',
    );
    return results.map((m) => LeaveApplication.fromMap(m)).toList();
  }

  /// Get all leave applications
  Future<List<LeaveApplication>> getAllLeaveApplications() async {
    final db = await _db;
    final results = await db.query(
      'leave_applications',
      orderBy: 'applied_at DESC',
    );
    return results.map((m) => LeaveApplication.fromMap(m)).toList();
  }

  /// Update leave application status (approved/rejected)
  Future<int> updateLeaveStatus(String id, String status, String approvedBy) async {
    final db = await _db;
    return await _updateLogged(db, 
      'leave_applications',
      {
        'status': status,
        'approved_by': approvedBy,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Compute leave balance (allowed − approved days used) per staff per academic year
  Future<List<LeaveBalance>> getStaffLeaveBalances(String staffId, int year) async {
    final db = await _db;
    final leaveTypes = await getAllLeaveTypes();
    final apps = await db.query(
      'leave_applications',
      where: "staff_id = ? AND status = 'approved' AND start_date LIKE ?",
      whereArgs: [staffId, '$year-%'],
    );

    final Map<String, int> usedDaysMap = {};

    for (final appMap in apps) {
      final app = LeaveApplication.fromMap(appMap);
      final start = DateTime.tryParse(app.startDate);
      final end = DateTime.tryParse(app.endDate);
      if (start != null && end != null) {
        final days = end.difference(start).inDays + 1;
        usedDaysMap[app.leaveTypeId] = (usedDaysMap[app.leaveTypeId] ?? 0) + (days > 0 ? days : 1);
      }
    }

    return leaveTypes.map((type) {
      final used = usedDaysMap[type.id] ?? 0;
      return LeaveBalance(
        leaveType: type,
        allowedDays: type.daysAllowedPerYear,
        usedDays: used,
      );
    }).toList();
  }

  // ============================================================================
  // TEACHER MANAGEMENT: PHASE 5 — Substitute Assignment
  // ============================================================================

  /// Helper class for suggested period substitution
  Future<List<Map<String, dynamic>>> getSuggestedSubstitutesForStaffLeave(String staffId, String dateStr) async {
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    final dayOfWeek = date.weekday;
    if (dayOfWeek > 6) return [];

    final db = await _db;
    final periodEntries = await db.query(
      'timetable',
      where: 'staff_id = ? AND day_of_week = ?',
      whereArgs: [staffId, dayOfWeek],
      orderBy: 'period_number ASC',
    );

    if (periodEntries.isEmpty) return [];

    final allStaff = await getAllStaff(activeOnly: true);
    final otherTeachers = allStaff.where((s) => s.id != staffId && s.role == 'teacher').toList();

    final List<Map<String, dynamic>> suggestions = [];

    for (final map in periodEntries) {
      final timetableEntry = TimetableEntry.fromMap(map);
      final List<Staff> freeTeachers = [];

      for (final teacher in otherTeachers) {
        final freePeriods = await getFreePeriods(teacher.id, date);
        if (freePeriods.contains(timetableEntry.periodNumber)) {
          freeTeachers.add(teacher);
        }
      }

      suggestions.add({
        'periodEntry': timetableEntry,
        'freeTeachers': freeTeachers,
      });
    }

    return suggestions;
  }

  /// Assign a substitute teacher for a period
  Future<int> assignSubstitution(Substitution substitution) async {
    final db = await _db;
    return await _insertLogged(db, 
      'substitutions',
      substitution.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get substitutions for a specific date
  Future<List<Substitution>> getSubstitutionsForDate(String date) async {
    final db = await _db;
    final results = await db.query(
      'substitutions',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'period_number ASC',
    );
    return results.map((m) => Substitution.fromMap(m)).toList();
  }

  /// Get substitutions where staff member is acting as substitute
  Future<List<Substitution>> getSubstitutionsForStaff(String staffId) async {
    final db = await _db;
    final results = await db.query(
      'substitutions',
      where: 'substitute_staff_id = ?',
      whereArgs: [staffId],
      orderBy: 'date DESC, period_number ASC',
    );
    return results.map((m) => Substitution.fromMap(m)).toList();
  }

  // ============================================================================
  // TEACHER MANAGEMENT: PHASE 6 — Exam Duty
  // ============================================================================

  /// Add exam duty entry
  Future<int> addExamDuty(ExamDuty duty) async {
    final db = await _db;
    return await _insertLogged(db, 'exam_duty', duty.toMap());
  }

  /// Get exam duties for a staff member
  Future<List<ExamDuty>> getExamDutiesForStaff(String staffId) async {
    final db = await _db;
    final results = await db.query(
      'exam_duty',
      where: 'staff_id = ?',
      whereArgs: [staffId],
      orderBy: 'date ASC',
    );
    return results.map((m) => ExamDuty.fromMap(m)).toList();
  }

  /// Get all exam duties across staff
  Future<List<ExamDuty>> getAllExamDuties() async {
    final db = await _db;
    final results = await db.query(
      'exam_duty',
      orderBy: 'date ASC',
    );
    return results.map((m) => ExamDuty.fromMap(m)).toList();
  }

  /// Delete exam duty entry
  Future<int> deleteExamDuty(String id) async {
    final db = await _db;
    return await _deleteLogged(db, 
      'exam_duty',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Check if leave approval conflicts with an existing exam duty (returns list of conflicting duties)
  Future<List<ExamDuty>> checkExamDutyConflictsForLeave(String staffId, String startDate, String endDate) async {
    final db = await _db;
    final results = await db.query(
      'exam_duty',
      where: 'staff_id = ? AND date >= ? AND date <= ?',
      whereArgs: [staffId, startDate, endDate],
    );
    return results.map((m) => ExamDuty.fromMap(m)).toList();
  }

  // ============================================================================
  // TEACHER MANAGEMENT: PHASE 7 — Portal Access & RBAC
  // ============================================================================

  /// Get user linked to staff member
  Future<User?> getUserByStaffId(String staffId) async {
    final db = await _db;
    final results = await db.query(
      'users',
      where: 'staff_id = ?',
      whereArgs: [staffId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return User.fromMap(results.first);
  }

  /// Update user RBAC permissions
  Future<int> updateUserPermissions(String userId, Map<String, bool> permissions) async {
    final db = await _db;
    final Map<String, dynamic> updateMap = {};
    if (permissions.containsKey('can_view_finance')) {
      updateMap['can_view_finance'] = permissions['can_view_finance']! ? 1 : 0;
    }
    if (permissions.containsKey('can_mark_own_attendance')) {
      updateMap['can_mark_own_attendance'] = permissions['can_mark_own_attendance']! ? 1 : 0;
    }
    if (permissions.containsKey('can_upload_marks')) {
      updateMap['can_upload_marks'] = permissions['can_upload_marks']! ? 1 : 0;
    }
    if (permissions.containsKey('can_view_all_students')) {
      updateMap['can_view_all_students'] = permissions['can_view_all_students']! ? 1 : 0;
    }
    if (permissions.containsKey('can_approve_leave')) {
      updateMap['can_approve_leave'] = permissions['can_approve_leave']! ? 1 : 0;
    }

    if (updateMap.isEmpty) return 0;

    return await _updateLogged(db, 
      'users',
      updateMap,
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // ============================================================================
  // TEACHER MANAGEMENT: PHASE 8 — Communication (Circulars)
  // ============================================================================

  /// Send circular announcement
  Future<int> sendCircular(Circular circular) async {
    final db = await _db;
    return await _insertLogged(db, 'circulars', circular.toMap());
  }

  /// Get circulars visible for a specific staff member
  Future<List<Circular>> getCircularsForStaff(String staffId, String? departmentId) async {
    final db = await _db;
    final results = await db.query(
      'circulars',
      where: "target_type = 'all' OR (target_type = 'department' AND target_id = ?) OR (target_type = 'individual' AND target_id = ?)",
      whereArgs: [departmentId ?? '', staffId],
      orderBy: 'sent_at DESC',
    );
    return results.map((m) => Circular.fromMap(m)).toList();
  }

  /// Get all circulars across system
  Future<List<Circular>> getAllCirculars() async {
    final db = await _db;
    final results = await db.query(
      'circulars',
      orderBy: 'sent_at DESC',
    );
    return results.map((m) => Circular.fromMap(m)).toList();
  }

  /// Delete circular
  Future<int> deleteCircular(String id) async {
    final db = await _db;
    return await _deleteLogged(db, 
      'circulars',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // TEACHER MANAGEMENT: PHASE 9 — Performance & Evaluation (Appraisals)
  // ============================================================================

  /// Add performance appraisal record
  Future<int> addAppraisal(Appraisal appraisal) async {
    final db = await _db;
    return await _insertLogged(db, 'appraisals', appraisal.toMap());
  }

  /// Get appraisals for a teacher
  Future<List<Appraisal>> getAppraisalsForStaff(String staffId) async {
    final db = await _db;
    final results = await db.query(
      'appraisals',
      where: 'staff_id = ?',
      whereArgs: [staffId],
      orderBy: 'created_at DESC',
    );
    return results.map((m) => Appraisal.fromMap(m)).toList();
  }

  /// Delete appraisal record
  Future<int> deleteAppraisal(String id) async {
    final db = await _db;
    return await _deleteLogged(db, 
      'appraisals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // TEACHER MANAGEMENT: PHASE 10 — Professional Development (Trainings)
  // ============================================================================

  /// Add professional training record
  Future<int> addTraining(Training training) async {
    final db = await _db;
    return await _insertLogged(db, 'trainings', training.toMap());
  }

  /// Get training records for a teacher
  Future<List<Training>> getTrainingsForStaff(String staffId) async {
    final db = await _db;
    final results = await db.query(
      'trainings',
      where: 'staff_id = ?',
      whereArgs: [staffId],
      orderBy: 'date DESC',
    );
    return results.map((m) => Training.fromMap(m)).toList();
  }

  /// Delete training record
  Future<int> deleteTraining(String id) async {
    final db = await _db;
    return await _deleteLogged(db, 
      'trainings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // CLASS & SECTION MASTER DATA
  // ============================================================================

  /// Get all classes
  Future<List<ClassModel>> getAllClasses() async {
    final db = await _db;
    final results = await db.query('classes', orderBy: 'name ASC');
    return results.map((m) => ClassModel.fromMap(m)).toList();
  }

  Future<void> cloneClassesToAcademicYear(String sourceYear, String targetYear) async {
    final db = await _db;
    await db.transaction((txn) async {
      final srcClasses = await txn.query('classes', where: 'academic_year = ?', whereArgs: [sourceYear]);
      
      for (final srcClass in srcClasses) {
        final String newClassId = 'cls-' + const Uuid().v4().substring(0, 8);
        
        final existing = await txn.query('classes', where: 'name = ? AND academic_year = ?', whereArgs: [srcClass['name'], targetYear]);
        if (existing.isNotEmpty) continue;
        
        await _insertLogged(txn, 'classes', {
          'id': newClassId,
          'name': srcClass['name'],
          'academic_year': targetYear,
          'capacity': srcClass['capacity'],
          'created_at': DateTime.now().toIso8601String(),
        });
        
        final srcSections = await txn.query('sections', where: 'class_id = ?', whereArgs: [srcClass['id']]);
        
        for (final srcSec in srcSections) {
          final String newSecId = 'sec-' + const Uuid().v4().substring(0, 8);
          await _insertLogged(txn, 'sections', {
            'id': newSecId,
            'class_id': newClassId,
            'name': srcSec['name'],
            'capacity': srcSec['capacity'],
            'class_teacher_id': null,
          });
        }
      }
    });
  }


  /// Get class by ID
  Future<ClassModel?> getClassById(String id) async {
    final db = await _db;
    final results = await db.query('classes', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return ClassModel.fromMap(results.first);
  }

  /// Create class
  Future<int> createClass(ClassModel classModel) async {
    final db = await _db;
    return await _insertLogged(db, 'classes', classModel.toMap());
  }

  /// Update class
  Future<int> updateClass(ClassModel classModel) async {
    final db = await _db;
    return await _updateLogged(db, 'classes', classModel.toMap(), where: 'id = ?', whereArgs: [classModel.id]);
  }

  /// Delete class
  Future<int> deleteClass(String id) async {
    final db = await _db;
    return await _deleteLogged(db, 'classes', where: 'id = ?', whereArgs: [id]);
  }

  /// Get sections for a class
  Future<List<Section>> getSectionsForClass(String classId) async {
    final db = await _db;
    final results = await db.query('sections', where: 'class_id = ?', whereArgs: [classId], orderBy: 'name ASC');
    return results.map((m) => Section.fromMap(m)).toList();
  }

  /// Create section
  Future<int> createSection(Section section) async {
    final db = await _db;
    return await _insertLogged(db, 'sections', section.toMap());
  }

  /// Update section
  Future<int> updateSection(Section section) async {
    final db = await _db;
    return await _updateLogged(db, 'sections', section.toMap(), where: 'id = ?', whereArgs: [section.id]);
  }

  /// Delete section
  Future<int> deleteSection(String id) async {
    final db = await _db;
    return await _deleteLogged(db, 'sections', where: 'id = ?', whereArgs: [id]);
  }

  /// Assign class teacher to section
  Future<int> assignClassTeacherToSection(String sectionId, String? staffId) async {
    final db = await _db;
    return await _updateLogged(db, 
      'sections',
      {'class_teacher_id': staffId},
      where: 'id = ?',
      whereArgs: [sectionId],
    );
  }

  /// Get student count for section
  Future<int> getStudentCountForSection(String sectionId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM students WHERE section_id = ? AND is_active = 1',
      [sectionId],
    );
    if (result.isEmpty) return 0;
    return (result.first['cnt'] as num?)?.toInt() ?? 0;
  }

  // ============================================================================
  // FEE HEADS & FEE STRUCTURE CONFIGURATION (PHASE 1)
  // ============================================================================

  /// Get all fee heads
  Future<List<FeeHead>> getAllFeeHeads() async {
    final db = await _db;
    final results = await db.query('fee_heads', orderBy: 'name ASC');
    return results.map((m) => FeeHead.fromMap(m)).toList();
  }

  /// Create fee head
  Future<int> createFeeHead(FeeHead head) async {
    final db = await _db;
    return await _insertLogged(db, 'fee_heads', head.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update fee head
  Future<int> updateFeeHead(FeeHead head) async {
    final db = await _db;
    return await _updateLogged(db, 'fee_heads', head.toMap(), where: 'id = ?', whereArgs: [head.id]);
  }

  /// Delete fee head
  Future<int> deleteFeeHead(String id) async {
    final db = await _db;
    return await _deleteLogged(db, 'fee_heads', where: 'id = ?', whereArgs: [id]);
  }

  /// Get fee structures for class and academic year
  Future<List<FeeStructure>> getFeeStructuresForClass(String className, String academicYear) async {
    final db = await _db;
    final results = await db.query(
      'fee_structures',
      where: '(class = ? OR grade_level = ?) AND (academic_year = ? OR academic_year_id = ?)',
      whereArgs: [className, className, academicYear, academicYear],
    );
    return results.map((m) => FeeStructure.fromMap(m)).toList();
  }

  /// Save / Insert or Update fee structure row
  Future<int> saveFeeStructureRow(FeeStructure fs) async {
    final db = await _db;
    
    final ayId = fs.academicYear.startsWith('ay-') ? fs.academicYear : 'ay-${fs.academicYear}';
    final parts = fs.academicYear.split('-');
    final startYear = parts.isNotEmpty ? parts[0] : '2024';
    final endYear = parts.length > 1 ? parts[1] : '2025';
    
    await db.execute(
      'INSERT OR IGNORE INTO academic_years (id, name, start_date, end_date) VALUES (?, ?, ?, ?)',
      [ayId, fs.academicYear, '$startYear-06-01', '$endYear-04-30']
    );

    await db.execute(
      'INSERT OR IGNORE INTO fee_categories (id, name, default_amount, cycle) VALUES (?, ?, ?, ?)',
      [fs.feeCategoryId, fs.feeCategoryId, 0.0, 'monthly']
    );

    final inserted = await _insertLogged(db, 'fee_structures', fs.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Sync unpaid ledger amounts for all students in this class
    await syncLedgerAmountsForFeeStructure(fs);
    
    return inserted;
  }

  /// Sync unpaid ledger rows when a fee structure is changed
  Future<void> syncLedgerAmountsForFeeStructure(FeeStructure fs) async {
    final db = await _db;
    
    // Get all students in this class
    final students = await db.query(
      'students',
      where: 'grade_level = ? AND is_active = 1 AND is_alumni = 0',
      whereArgs: [fs.className],
    );

    for (final s in students) {
      final studentId = s['id'] as String;
      // Re-calculate net fee for this specific fee head (including discounts)
      final netFees = await getStudentNetPayableFees(studentId, fs.className, fs.academicYear);
      final item = netFees.where((n) => n.feeHeadId == (fs.feeHeadId ?? fs.feeCategoryId)).firstOrNull;
      if (item == null) continue;

      // Update unpaid ledger rows for this student, fee head, and academic year
      await db.update(
        'student_fee_ledger',
        {'amount_due': item.netPayable},
        where: 'student_id = ? AND fee_head_id = ? AND academic_year = ? AND status = ?',
        whereArgs: [studentId, item.feeHeadId, fs.academicYear, 'pending'],
      );
    }
  }

  /// Delete fee structure row
  Future<int> deleteFeeStructureRow(String id) async {
    final db = await _db;
    
    // Get details before deleting
    final existing = await db.query('fee_structures', where: 'id = ?', whereArgs: [id]);
    if (existing.isNotEmpty) {
      final fs = FeeStructure.fromMap(existing.first);
      
      // Delete unpaid ledger rows for this fee head in this academic year for all students in this class
      final students = await db.query(
        'students',
        where: 'grade_level = ?',
        whereArgs: [fs.className],
      );
      
      for (final s in students) {
        final studentId = s['id'] as String;
        await db.delete(
          'student_fee_ledger',
          where: 'student_id = ? AND fee_head_id = ? AND academic_year = ? AND status = ?',
          whereArgs: [studentId, fs.feeHeadId ?? fs.feeCategoryId, fs.academicYear, 'pending'],
        );
      }
    }

    return await _deleteLogged(db, 'fee_structures', where: 'id = ?', whereArgs: [id]);
  }

  // ============================================================================
  // DISCOUNTS & SCHOLARSHIPS (PHASE 2)
  // ============================================================================

  /// Get all discount types
  Future<List<DiscountType>> getAllDiscountTypes() async {
    final db = await _db;
    final results = await db.query('discount_types', orderBy: 'name ASC');
    return results.map((m) => DiscountType.fromMap(m)).toList();
  }

  /// Create discount type
  Future<int> createDiscountType(DiscountType dt) async {
    final db = await _db;
    return await _insertLogged(db, 'discount_types', dt.toMap());
  }

  /// Update discount type
  Future<int> updateDiscountType(DiscountType dt) async {
    final db = await _db;
    return await _updateLogged(db, 'discount_types', dt.toMap(), where: 'id = ?', whereArgs: [dt.id]);
  }

  /// Delete discount type
  Future<int> deleteDiscountType(String id) async {
    final db = await _db;
    return await _deleteLogged(db, 'discount_types', where: 'id = ?', whereArgs: [id]);
  }

  /// Get discounts assigned to a student
  Future<List<StudentDiscount>> getDiscountsForStudent(String studentId, String academicYear) async {
    final db = await _db;
    final results = await db.query(
      'student_discounts',
      where: 'student_id = ? AND academic_year = ?',
      whereArgs: [studentId, academicYear],
    );
    return results.map((m) => StudentDiscount.fromMap(m)).toList();
  }

  /// Apply a discount to a student
  Future<int> applyStudentDiscount(StudentDiscount sd) async {
    final db = await _db;
    final id = await _insertLogged(db, 'student_discounts', sd.toMap());
    
    // Sync unpaid ledger amounts for this student to reflect new discount
    await syncLedgerAmountsForStudent(sd.studentId, sd.academicYear);
    
    return id;
  }

  /// Remove discount from a student
  Future<int> removeStudentDiscount(String id) async {
    final db = await _db;
    
    // Get details before deleting
    final existing = await db.query('student_discounts', where: 'id = ?', whereArgs: [id]);
    if (existing.isEmpty) return 0;
    
    final studentId = existing.first['student_id'] as String;
    final academicYear = existing.first['academic_year'] as String;
    
    final deleted = await _deleteLogged(db, 'student_discounts', where: 'id = ?', whereArgs: [id]);
    
    // Sync unpaid ledger amounts to reflect removed discount
    await syncLedgerAmountsForStudent(studentId, academicYear);
    
    return deleted;
  }

  /// Sync unpaid ledger rows when a discount is added or removed for a specific student
  Future<void> syncLedgerAmountsForStudent(String studentId, String academicYear) async {
    final db = await _db;
    final student = await getStudentById(studentId);
    if (student == null) return;
    
    final netFees = await getStudentNetPayableFees(studentId, student.gradeLevel, academicYear);
    
    for (final item in netFees) {
      await db.update(
        'student_fee_ledger',
        {'amount_due': item.netPayable},
        where: 'student_id = ? AND fee_head_id = ? AND academic_year = ? AND status = ?',
        whereArgs: [studentId, item.feeHeadId, academicYear, 'pending'],
      );
    }
  }

  /// Compute student net payable fees per fee head for an academic year
  Future<List<StudentNetFeeBreakdown>> getStudentNetPayableFees(String studentId, String className, String academicYear) async {
    final structures = await getFeeStructuresForClass(className, academicYear);
    final feeHeads = await getAllFeeHeads();
    final studentDiscounts = await getDiscountsForStudent(studentId, academicYear);
    final allDiscountTypes = await getAllDiscountTypes();

    final Map<String, DiscountType> discountTypeMap = {for (var dt in allDiscountTypes) dt.id: dt};
    final Map<String, FeeHead> headMap = {for (var fh in feeHeads) fh.id: fh};

    // Calculate total discount percentage & flat discount for the student
    double totalPercentDiscount = 0.0;
    double totalFlatDiscount = 0.0;

    for (final sd in studentDiscounts) {
      final dt = discountTypeMap[sd.discountTypeId];
      if (dt != null) {
        if (dt.discountKind == 'percentage') {
          totalPercentDiscount += dt.value;
        } else if (dt.discountKind == 'flat') {
          totalFlatDiscount += dt.value;
        }
      }
    }

    final List<StudentNetFeeBreakdown> result = [];

    for (final fs in structures) {
      final headId = fs.feeHeadId ?? fs.feeCategoryId;
      final head = headMap[headId];
      final headName = head?.name ?? 'Fee Head ($headId)';
      final frequency = head?.frequency ?? 'monthly';
      final baseAmt = fs.amount;

      // Apply percentage discount first, then distribute flat discount if any
      double discAmt = baseAmt * (totalPercentDiscount / 100.0);
      if (totalFlatDiscount > 0 && structures.isNotEmpty) {
        discAmt += (totalFlatDiscount / structures.length);
      }
      if (discAmt > baseAmt) discAmt = baseAmt;

      final netPayable = baseAmt - discAmt;

      result.add(StudentNetFeeBreakdown(
        feeHeadId: headId,
        feeHeadName: headName,
        frequency: frequency,
        baseAmount: baseAmt,
        discountAmount: discAmt,
        netPayable: netPayable,
      ));
    }

    return result;
  }

  // ============================================================================
  // STUDENT FEE LEDGER OPERATIONS (PHASE 3)
  // ============================================================================

  /// Get all ledger entries for a student in an academic year, enriched with fee head name
  Future<List<StudentFeeLedger>> getStudentFeeLedger(String studentId, String academicYear) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT sfl.*, fh.name as fee_head_name, fh.frequency as frequency
      FROM student_fee_ledger sfl
      LEFT JOIN fee_heads fh ON sfl.fee_head_id = fh.id
      WHERE sfl.student_id = ? AND sfl.academic_year = ?
      ORDER BY sfl.due_date ASC, fh.name ASC
    ''', [studentId, academicYear]);

    return results.map((map) => StudentFeeLedger.fromMap(map)).toList();
  }

  /// Get a single ledger entry by ID
  Future<StudentFeeLedger?> getFeeLedgerById(String id) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT sfl.*, fh.name as fee_head_name, fh.frequency as frequency
      FROM student_fee_ledger sfl
      LEFT JOIN fee_heads fh ON sfl.fee_head_id = fh.id
      WHERE sfl.id = ?
      LIMIT 1
    ''', [id]);
    if (results.isEmpty) return null;
    return StudentFeeLedger.fromMap(results.first);
  }

  /// Auto-generate ledger rows for a student based on their class fee structures minus discounts.
  /// Returns the number of rows created. Skips any row that already exists (same student+feeHead+year).
  Future<int> generateLedgerForStudent(String studentId, String className, String academicYear) async {
    final db = await _db;
    final netFees = await getStudentNetPayableFees(studentId, className, academicYear);
    final feeHeads = await getAllFeeHeads();
    final feeHeadMap = {for (var fh in feeHeads) fh.id: fh};

    int created = 0;
    final now = DateTime.now();

    await db.transaction((txn) async {
      for (final item in netFees) {
        // Check if ledger entry already exists (only for non-monthly, we'll check monthly later)
        if (feeHeadMap[item.feeHeadId]?.frequency != 'monthly') {
          final existing = await txn.rawQuery(
            'SELECT COUNT(*) AS cnt FROM student_fee_ledger WHERE student_id = ? AND fee_head_id = ? AND academic_year = ?',
            [studentId, item.feeHeadId, academicYear],
          );
          if ((existing.first['cnt'] as int) > 0) continue;
        }

        final fh = feeHeadMap[item.feeHeadId];
        
        if (fh != null && fh.frequency == 'monthly') {
          // Generate 12 separate ledger rows (April to March)
          final yearParts = academicYear.split('-');
          final startYear = int.tryParse(yearParts[0]) ?? now.year;
          
          final monthNames = [
            'April', 'May', 'June', 'July', 'August', 'September', 
            'October', 'November', 'December', 'January', 'February', 'March'
          ];
          
          for (int i = 0; i < 12; i++) {
            final monthIndex = (i + 3) % 12 + 1; // 4 to 12, then 1 to 3
            final currentYear = i < 9 ? startYear : startYear + 1; // April to Dec in startYear, Jan to Mar in startYear+1
            final dueDate = DateTime(currentYear, monthIndex, 10); // 10th of each month
            final monthLabel = '${monthNames[i]} $currentYear';
            
            // Check if THIS specific month is already added
            final existingMonth = await txn.rawQuery(
              'SELECT COUNT(*) AS cnt FROM student_fee_ledger WHERE student_id = ? AND fee_head_id = ? AND academic_year = ? AND month_label = ?',
              [studentId, item.feeHeadId, academicYear, monthLabel],
            );
            if ((existingMonth.first['cnt'] as int) > 0) continue;

            final ledger = StudentFeeLedger.create(
              studentId: studentId,
              feeHeadId: item.feeHeadId,
              academicYear: academicYear,
              amountDue: item.netPayable,
              dueDate: dueDate,
              feeHeadName: item.feeHeadName,
              frequency: item.frequency,
              monthLabel: monthLabel,
            );

            await _insertLogged(txn, 'student_fee_ledger', ledger.toMap());
            created++;
          }
        } else if (fh != null && fh.frequency == 'quarterly') {
          final yearParts = academicYear.split('-');
          final startYear = int.tryParse(yearParts[0]) ?? now.year;
          
          final quarters = [
            {'label': 'Q1 (Apr-Jun)', 'month': 4, 'nextYear': false},
            {'label': 'Q2 (Jul-Sep)', 'month': 7, 'nextYear': false},
            {'label': 'Q3 (Oct-Dec)', 'month': 10, 'nextYear': false},
            {'label': 'Q4 (Jan-Mar)', 'month': 1, 'nextYear': true},
          ];

          for (final q in quarters) {
            final qYear = (q['nextYear'] == true) ? startYear + 1 : startYear;
            final dueDate = DateTime(qYear, q['month'] as int, 10); // 10th of the first month of quarter
            final qLabel = '${q['label']} $startYear-${startYear + 1}';
            
            final existingQ = await txn.rawQuery(
              'SELECT COUNT(*) AS cnt FROM student_fee_ledger WHERE student_id = ? AND fee_head_id = ? AND academic_year = ? AND month_label = ?',
              [studentId, item.feeHeadId, academicYear, qLabel],
            );
            if ((existingQ.first['cnt'] as int) > 0) continue;

            final ledger = StudentFeeLedger.create(
              studentId: studentId,
              feeHeadId: item.feeHeadId,
              academicYear: academicYear,
              amountDue: item.netPayable,
              dueDate: dueDate,
              feeHeadName: item.feeHeadName,
              frequency: item.frequency,
              monthLabel: qLabel,
            );

            await _insertLogged(txn, 'student_fee_ledger', ledger.toMap());
            created++;
          }
        } else {
          // Annual/one-time: end of academic year (March 31 of next year)
          final yearParts = academicYear.split('-');
          final endYear = yearParts.length > 1 ? int.tryParse(yearParts[1]) ?? (now.year + 1) : now.year + 1;
          final dueDate = DateTime(endYear, 3, 31);

          final existingAnn = await txn.rawQuery(
            'SELECT COUNT(*) AS cnt FROM student_fee_ledger WHERE student_id = ? AND fee_head_id = ? AND academic_year = ?',
            [studentId, item.feeHeadId, academicYear],
          );
          if ((existingAnn.first['cnt'] as int) > 0) continue;

          final ledger = StudentFeeLedger.create(
            studentId: studentId,
            feeHeadId: item.feeHeadId,
            academicYear: academicYear,
            amountDue: item.netPayable,
            dueDate: dueDate,
            feeHeadName: item.feeHeadName,
            frequency: item.frequency,
          );

          await _insertLogged(txn, 'student_fee_ledger', ledger.toMap());
          created++;
        }
      }
    });

    return created;
  }

  /// Bulk-generate ledger rows for ALL enrolled students in a given academic year.
  /// Returns total rows created across all students.
  Future<int> generateLedgerForAllStudents(String academicYear) async {
    final students = await getAllStudents();
    int totalCreated = 0;
    for (final student in students) {
      if (student.gradeLevel.isNotEmpty) {
        final count = await generateLedgerForStudent(
          student.id,
          student.gradeLevel,
          academicYear,
        );
        totalCreated += count;
      }
    }
    return totalCreated;
  }

  /// Record a payment against a specific ledger entry.
  /// Updates amount_paid and status accordingly.
  /// Returns the updated ledger entry.
  Future<StudentFeeLedger> recordLedgerPayment(String ledgerId, double paymentAmount) async {
    final db = await _db;

    late StudentFeeLedger updatedEntry;

    await db.transaction((txn) async {
      final rows = await txn.rawQuery(
        'SELECT * FROM student_fee_ledger WHERE id = ? LIMIT 1',
        [ledgerId],
      );
      if (rows.isEmpty) {
        throw ArgumentError('Ledger entry with ID "$ledgerId" not found.');
      }
      final entry = StudentFeeLedger.fromMap(rows.first);
      final newPaid = entry.amountPaid + paymentAmount;
      final remaining = entry.amountDue - newPaid;

      LedgerStatus newStatus;
      if (remaining <= 0.01) {
        newStatus = LedgerStatus.paid;
      } else if (newPaid > 0) {
        newStatus = LedgerStatus.partial;
      } else {
        newStatus = entry.status;
      }

      final nowIso = DateTime.now().toIso8601String();
      await txn.rawUpdate('''
        UPDATE student_fee_ledger
        SET amount_paid = ?, status = ?, updated_at = ?
        WHERE id = ?
      ''', [newPaid, newStatus.name, nowIso, ledgerId]);

      updatedEntry = entry.copyWith(
        amountPaid: newPaid,
        status: newStatus,
        updatedAt: DateTime.now(),
      );
    });

    return updatedEntry;
  }

  /// Auto-allocate a lump sum payment across ledger entries (oldest-due-first).
  /// Creates invoice + transaction records for each allocated portion.
  /// Returns list of updated ledger entries.
  Future<List<StudentFeeLedger>> recordMultiMonthPayment({
    required String studentId,
    required String academicYear,
    required List<String> ledgerIds,
    required PaymentMethod paymentMethod,
    String? referenceNumber,
  }) async {
    final db = await _db;
    final updatedEntries = <StudentFeeLedger>[];
    final ayId = academicYear.startsWith('ay-') ? academicYear : 'ay-$academicYear';

    await db.transaction((txn) async {
      // Get the specific open ledger entries
      final placeholders = List.filled(ledgerIds.length, '?').join(',');
      final openRows = await txn.rawQuery('''
        SELECT sfl.*, fh.name as fee_head_name, fh.frequency as frequency
        FROM student_fee_ledger sfl
        LEFT JOIN fee_heads fh ON sfl.fee_head_id = fh.id
        WHERE sfl.id IN ($placeholders)
          AND sfl.status IN ('pending', 'partial', 'overdue')
      ''', ledgerIds);

      final nowIso = DateTime.now().toIso8601String();

      for (final row in openRows) {
        final entry = StudentFeeLedger.fromMap(row);
        final allocate = entry.amountDue - entry.amountPaid;
        
        if (allocate <= 0.01) continue;

        final newPaid = entry.amountDue;
        final newStatus = LedgerStatus.paid;

        await txn.rawUpdate('''
          UPDATE student_fee_ledger
          SET amount_paid = ?, status = ?, updated_at = ?
          WHERE id = ?
        ''', [newPaid, newStatus.name, nowIso, entry.id]);

        final ayId = academicYear.startsWith('ay-') ? academicYear : 'ay-$academicYear';
        
        // Create a matching invoice linked to this ledger entry
        final invoiceId = const Uuid().v4();
        await _insertLogged(txn, 'invoices', {
          'id': invoiceId,
          'student_id': studentId,
          'academic_year_id': ayId,
          'total_amount': allocate,
          'discount_amount': 0.0,
          'penalty_amount': 0.0,
          'due_date': entry.dueDate.toIso8601String(),
          'status': 'paid',
          'notes': 'Multi-month payment: ${entry.feeHeadName ?? entry.feeHeadId}',
          'fee_head_id': entry.feeHeadId,
          'ledger_id': entry.id,
          'created_at': nowIso,
          'updated_at': nowIso,
        });

        // Create transaction record
        final transactionId = const Uuid().v4();
        await _insertLogged(txn, 'transactions', {
          'id': transactionId,
          'invoice_id': invoiceId,
          'amount_paid': allocate,
          'payment_method': paymentMethod.dbValue,
          'reference_number': referenceNumber,
          'timestamp': nowIso,
          'created_at': nowIso,
          'updated_at': nowIso,
        });

        // Create ledger entry (financial ledger) for income
        final ledgerEntryId = const Uuid().v4();
        await _insertLogged(txn, 'ledger_entries', {
          'id': ledgerEntryId,
          'date': nowIso,
          'type': 'income',
          'category': 'Fee Collection',
          'amount': allocate,
          'description': 'Multi-month payment: ${entry.feeHeadName ?? entry.feeHeadId} (Student: $studentId)',
          'reference_id': transactionId,
          'created_at': nowIso,
        });

        // Update student balance
        await txn.rawUpdate('''
          UPDATE students SET current_balance = current_balance - ?, updated_at = ?
          WHERE id = ?
        ''', [allocate, nowIso, studentId]);

        final updatedEntry = StudentFeeLedger(
          id: entry.id,
          studentId: entry.studentId,
          feeHeadId: entry.feeHeadId,
          academicYear: entry.academicYear,
          amountDue: entry.amountDue,
          amountPaid: newPaid,
          dueDate: entry.dueDate,
          status: newStatus,
          feeHeadName: entry.feeHeadName,
          frequency: entry.frequency,
          monthLabel: entry.monthLabel,
          createdAt: entry.createdAt,
          updatedAt: DateTime.now(),
        );
        updatedEntries.add(updatedEntry);
      }
    });

    return updatedEntries;
  }

  Future<List<StudentFeeLedger>> recordLumpSumPayment({
    required String studentId,
    required String academicYear,
    required double totalAmount,
    required PaymentMethod paymentMethod,
    String? referenceNumber,
  }) async {
    final db = await _db;
    final updatedEntries = <StudentFeeLedger>[];

    await db.transaction((txn) async {
      // Get open ledger entries ordered by due date (oldest first)
      final openRows = await txn.rawQuery('''
        SELECT sfl.*, fh.name as fee_head_name, fh.frequency as frequency
        FROM student_fee_ledger sfl
        LEFT JOIN fee_heads fh ON sfl.fee_head_id = fh.id
        WHERE sfl.student_id = ? AND sfl.academic_year = ?
          AND sfl.status IN ('pending', 'partial', 'overdue')
        ORDER BY sfl.due_date ASC
      ''', [studentId, academicYear]);

      double remaining = totalAmount;
      final nowIso = DateTime.now().toIso8601String();

      for (final row in openRows) {
        if (remaining <= 0.01) break;

        final entry = StudentFeeLedger.fromMap(row);
        final entryRemaining = entry.amountDue - entry.amountPaid;
        final allocate = remaining >= entryRemaining ? entryRemaining : remaining;

        final newPaid = entry.amountPaid + allocate;
        LedgerStatus newStatus;
        if ((entry.amountDue - newPaid).abs() <= 0.01) {
          newStatus = LedgerStatus.paid;
        } else {
          newStatus = LedgerStatus.partial;
        }

        await txn.rawUpdate('''
          UPDATE student_fee_ledger
          SET amount_paid = ?, status = ?, updated_at = ?
          WHERE id = ?
        ''', [newPaid, newStatus.name, nowIso, entry.id]);

        final ayId = academicYear.startsWith('ay-') ? academicYear : 'ay-$academicYear';
        
        // Create a matching invoice linked to this ledger entry
        final invoiceId = const Uuid().v4();
        await _insertLogged(txn, 'invoices', {
          'id': invoiceId,
          'student_id': studentId,
          'academic_year_id': ayId,
          'total_amount': allocate,
          'discount_amount': 0.0,
          'penalty_amount': 0.0,
          'due_date': entry.dueDate.toIso8601String(),
          'status': 'paid',
          'notes': 'Ledger payment: ${entry.feeHeadName ?? entry.feeHeadId}',
          'fee_head_id': entry.feeHeadId,
          'ledger_id': entry.id,
          'created_at': nowIso,
          'updated_at': nowIso,
        });

        // Create transaction record
        final transactionId = const Uuid().v4();
        await _insertLogged(txn, 'transactions', {
          'id': transactionId,
          'invoice_id': invoiceId,
          'amount_paid': allocate,
          'payment_method': paymentMethod.dbValue,
          'reference_number': referenceNumber,
          'timestamp': nowIso,
          'created_at': nowIso,
          'updated_at': nowIso,
        });

        // Create ledger entry (financial ledger) for income
        final ledgerEntryId = const Uuid().v4();
        await _insertLogged(txn, 'ledger_entries', {
          'id': ledgerEntryId,
          'date': nowIso,
          'type': 'income',
          'category': 'Fee Collection',
          'amount': allocate,
          'description': 'Ledger payment: ${entry.feeHeadName ?? entry.feeHeadId} (Student: $studentId)',
          'reference_id': transactionId,
          'created_at': nowIso,
        });

        // Update student balance
        await txn.rawUpdate('''
          UPDATE students SET current_balance = current_balance - ?, updated_at = ?
          WHERE id = ?
        ''', [allocate, nowIso, studentId]);

        updatedEntries.add(entry.copyWith(
          amountPaid: newPaid,
          status: newStatus,
          updatedAt: DateTime.now(),
        ));

        remaining -= allocate;
      }
    });

    return updatedEntries;
  }

  /// Recalculate overdue status for all ledger entries past due date with unpaid amounts.
  /// Returns count of rows updated.
  Future<int> recalculateOverdueLedgerEntries() async {
    final db = await _db;
    final updated = await db.rawUpdate('''
      UPDATE student_fee_ledger
      SET status = 'overdue',
          updated_at = datetime('now')
      WHERE due_date < datetime('now')
        AND status IN ('pending', 'partial')
        AND amount_paid < amount_due
    ''');
    return updated;
  }

  /// Get ledger summary for a student: total due, total paid, total overdue
  Future<Map<String, double>> getStudentLedgerSummary(String studentId, String academicYear) async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(amount_due), 0.0) as total_due,
        COALESCE(SUM(amount_paid), 0.0) as total_paid,
        COALESCE(SUM(CASE WHEN status = 'overdue' THEN (amount_due - amount_paid) ELSE 0 END), 0.0) as total_overdue
      FROM student_fee_ledger
      WHERE student_id = ? AND academic_year = ?
    ''', [studentId, academicYear]);

    final row = result.first;
    return {
      'total_due': (row['total_due'] as num).toDouble(),
      'total_paid': (row['total_paid'] as num).toDouble(),
      'total_overdue': (row['total_overdue'] as num).toDouble(),
    };
  }

  /// Get class-wide ledger summary for admin reports
  Future<List<Map<String, dynamic>>> getClassLedgerSummary(String className, String academicYear) async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT
        s.id as student_id,
        s.first_name || ' ' || s.last_name as student_name,
        s.roll_number,
        COALESCE(SUM(sfl.amount_due), 0.0) as total_due,
        COALESCE(SUM(sfl.amount_paid), 0.0) as total_paid,
        COALESCE(SUM(sfl.amount_due) - SUM(sfl.amount_paid), 0.0) as balance
      FROM students s
      LEFT JOIN student_fee_ledger sfl ON s.id = sfl.student_id AND sfl.academic_year = ?
      WHERE s.grade_level = ?
      GROUP BY s.id
      ORDER BY s.first_name ASC
    ''', [academicYear, className]);
  }

  // ============================================================================
  // FEE REPORTING & RECEIPT OPERATIONS (PHASE 4 & 5)
  // ============================================================================

  /// Class-wise dues summary: returns list of {class_name, total_students, total_due, total_paid, outstanding_balance}
  Future<List<Map<String, dynamic>>> getClassWiseDuesSummary(String academicYear, {String? feeHeadId}) async {
    final db = await _db;
    final classes = await getAllClasses();
    if (classes.isEmpty) {
      // Fallback: group by students.grade_level if classes master is empty
      String query = '''
        SELECT
          s.grade_level as class_name,
          COUNT(DISTINCT s.id) as total_students,
          COALESCE(SUM(sfl.amount_due), 0.0) as total_due,
          COALESCE(SUM(sfl.amount_paid), 0.0) as total_paid,
          COALESCE(SUM(sfl.amount_due) - SUM(sfl.amount_paid), 0.0) as outstanding_balance
        FROM students s
        LEFT JOIN student_fee_ledger sfl ON sfl.student_id = s.id AND sfl.academic_year = ?
      ''';
      final args = <Object?>[academicYear];
      if (feeHeadId != null) {
        query += ' AND sfl.fee_head_id = ?';
        args.add(feeHeadId);
      }
      query += '''
        WHERE s.grade_level IS NOT NULL AND s.grade_level != ''
        GROUP BY s.grade_level
        ORDER BY s.grade_level ASC
      ''';
      return await db.rawQuery(query, args);
    }

    final results = <Map<String, dynamic>>[];
    for (final cls in classes) {
      String query = '''
        SELECT
          COUNT(DISTINCT s.id) as total_students,
          COALESCE(SUM(sfl.amount_due), 0.0) as total_due,
          COALESCE(SUM(sfl.amount_paid), 0.0) as total_paid,
          COALESCE(SUM(sfl.amount_due) - SUM(sfl.amount_paid), 0.0) as outstanding_balance
        FROM students s
        LEFT JOIN student_fee_ledger sfl ON sfl.student_id = s.id AND sfl.academic_year = ?
      ''';
      final args = <Object?>[academicYear];
      if (feeHeadId != null) {
        query += ' AND sfl.fee_head_id = ?';
        args.add(feeHeadId);
      }
      query += '''
        WHERE s.class_id = ? OR s.grade_level = ?
      ''';
      args.addAll([cls.id, cls.name]);

      final rows = await db.rawQuery(query, args);

      final row = rows.first;
      results.add({
        'class_name': cls.name,
        'total_students': row['total_students'] as int? ?? 0,
        'total_due': (row['total_due'] as num).toDouble(),
        'total_paid': (row['total_paid'] as num).toDouble(),
        'outstanding_balance': (row['outstanding_balance'] as num).toDouble(),
      });
    }

    return results;
  }

  /// Get list of students with overdue fee ledger entries
  Future<List<Map<String, dynamic>>> getOverdueStudents(String academicYear) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        s.id as student_id,
        s.first_name || ' ' || s.last_name as student_name,
        s.grade_level,
        s.roll_number,
        s.father_phone,
        s.mother_phone,
        COUNT(sfl.id) as overdue_count,
        SUM(sfl.amount_due - sfl.amount_paid) as total_overdue_amount,
        MIN(sfl.due_date) as oldest_due_date
      FROM students s
      JOIN student_fee_ledger sfl ON s.id = sfl.student_id
      WHERE sfl.academic_year = ?
        AND (sfl.status = 'overdue' OR (sfl.due_date < datetime('now') AND sfl.amount_paid < sfl.amount_due))
      GROUP BY s.id
      ORDER BY total_overdue_amount DESC
    ''', [academicYear]);

    return rows;
  }

  /// Collection summary by Fee Head with optional date range filter
  Future<List<Map<String, dynamic>>> getCollectionSummaryByFeeHead(
    String academicYear, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _db;
    String dateFilter = '';
    final args = <dynamic>[academicYear];

    if (startDate != null) {
      dateFilter += ' AND t.timestamp >= ?';
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      dateFilter += ' AND t.timestamp <= ?';
      args.add(endDate.toIso8601String());
    }

    final query = '''
      SELECT
        fh.id as fee_head_id,
        fh.name as fee_head_name,
        fh.frequency as frequency,
        COALESCE(SUM(t.amount_paid), 0.0) as total_collected,
        COUNT(t.id) as transaction_count
      FROM fee_heads fh
      LEFT JOIN student_fee_ledger sfl ON sfl.fee_head_id = fh.id AND sfl.academic_year = ?
      LEFT JOIN invoices i ON i.ledger_id = sfl.id OR i.fee_head_id = fh.id
      LEFT JOIN transactions t ON t.invoice_id = i.id $dateFilter
      GROUP BY fh.id, fh.name, fh.frequency
      ORDER BY total_collected DESC
    ''';

    return await db.rawQuery(query, args);
  }

  /// Get detailed date-wise fee collection report with filters
  Future<Map<String, dynamic>> getDateWiseFeeReport(
    String academicYear,
    DateTime startDate,
    DateTime endDate, {
    String? classId,
    String? sectionId,
    String? feeHeadId,
  }) async {
    final db = await _db;
    final args = <dynamic>[
      startDate.toIso8601String(),
      endDate.toIso8601String(),
    ];

    String query = '''
      SELECT 
        t.id as transaction_id,
        t.timestamp as date,
        s.first_name || ' ' || s.last_name as student_name,
        COALESCE(c.name, s.grade_level) as class_name,
        COALESCE(sec.name, s.section) as section_name,
        fh.id as fee_head_id, 
        fh.name as fee_head_name,
        t.amount_paid,
        t.payment_method,
        t.reference_number
      FROM transactions t
      JOIN invoices i ON t.invoice_id = i.id
      JOIN students s ON i.student_id = s.id
      LEFT JOIN classes c ON s.class_id = c.id
      LEFT JOIN sections sec ON s.section_id = sec.id
      LEFT JOIN student_fee_ledger sfl ON i.ledger_id = sfl.id
      LEFT JOIN fee_heads fh ON (sfl.fee_head_id = fh.id OR i.fee_head_id = fh.id)
      WHERE t.timestamp >= ? AND t.timestamp <= ?
    ''';

    // Invoices might use 'ay-2024-2025' or '2024-2025'
    final ayStr = academicYear.startsWith('ay-') ? academicYear : 'ay-$academicYear';
    query += ' AND (i.academic_year_id = ? OR i.academic_year_id = ?)';
    args.addAll([academicYear, ayStr]);

    if (classId != null && classId.isNotEmpty) {
      query += ' AND (s.class_id = ? OR s.grade_level = (SELECT name FROM classes WHERE id = ?))';
      args.addAll([classId, classId]);
    }
    if (sectionId != null && sectionId.isNotEmpty) {
      query += ' AND s.section_id = ?';
      args.add(sectionId);
    }
    if (feeHeadId != null && feeHeadId.isNotEmpty) {
      query += ' AND fh.id = ?';
      args.add(feeHeadId);
    }

    query += ' ORDER BY t.timestamp DESC';

    final rows = await db.rawQuery(query, args);

    double totalRevenue = 0.0;
    final Map<String, double> headBreakdown = {};
    final Map<String, double> methodBreakdown = {};

    for (final row in rows) {
      final amt = (row['amount_paid'] as num?)?.toDouble() ?? 0.0;
      final head = (row['fee_head_name'] as String?) ?? 'Other / Uncategorized';
      final method = (row['payment_method'] as String?)?.toUpperCase() ?? 'UNKNOWN';

      totalRevenue += amt;
      headBreakdown[head] = (headBreakdown[head] ?? 0.0) + amt;
      methodBreakdown[method] = (methodBreakdown[method] ?? 0.0) + amt;
    }

    return {
      'totalRevenue': totalRevenue,
      'headBreakdown': headBreakdown,
      'methodBreakdown': methodBreakdown,
      'transactions': rows,
    };
  }

  /// Generate next sequential receipt number in format RCT-{year}-{sequential}
  Future<String> getNextReceiptNumber([int? year]) async {
    final db = await _db;
    final rctYear = year ?? DateTime.now().year;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM transactions');
    final count = ((result.first['count'] as int? ?? 0) + 1);
    final seqStr = count.toString().padLeft(4, '0');
    return 'RCT-$rctYear-$seqStr';
  }

  // ============================================================================
  // TRANSPORT MANAGEMENT OPERATIONS (PHASE 2)
  // ============================================================================

  /// Get all drivers from staff table (role = 'driver')
  Future<List<Staff>> getDrivers() async {
    final db = await _db;
    final results = await db.query(
      'staff',
      where: 'LOWER(role) = ?',
      whereArgs: ['driver'],
      orderBy: 'first_name ASC',
    );
    return results.map((map) => Staff.fromMap(map)).toList();
  }

  /// Get all vehicles enriched with driver name
  Future<List<Vehicle>> getAllVehicles({bool activeOnly = false}) async {
    final db = await _db;
    final whereClause = activeOnly ? 'WHERE v.is_active = 1' : '';
    final results = await db.rawQuery('''
      SELECT v.*,
             TRIM(COALESCE(st.first_name, '') || ' ' || COALESCE(st.last_name, '')) as driver_name
      FROM vehicles v
      LEFT JOIN staff st ON v.driver_staff_id = st.id
      $whereClause
      ORDER BY v.vehicle_number ASC
    ''');
    return results.map((map) => Vehicle.fromMap(map)).toList();
  }

  /// Get vehicle by ID
  Future<Vehicle?> getVehicleById(String id) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT v.*,
             TRIM(COALESCE(st.first_name, '') || ' ' || COALESCE(st.last_name, '')) as driver_name
      FROM vehicles v
      LEFT JOIN staff st ON v.driver_staff_id = st.id
      WHERE v.id = ?
      LIMIT 1
    ''', [id]);
    if (results.isEmpty) return null;
    return Vehicle.fromMap(results.first);
  }

  /// Insert new vehicle
  Future<void> insertVehicle(Vehicle vehicle) async {
    final db = await _db;
    await _insertLogged(db, 
      'vehicles',
      vehicle.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update existing vehicle
  Future<void> updateVehicle(Vehicle vehicle) async {
    final db = await _db;
    await _updateLogged(db, 
      'vehicles',
      vehicle.toMap(),
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  /// Delete vehicle by ID
  Future<void> deleteVehicle(String id) async {
    final db = await _db;
    await _deleteLogged(db, 'vehicles', where: 'id = ?', whereArgs: [id]);
  }

  /// Flag vehicles where insurance_expiry or fitness_expiry is within `withinDays` (default 30 days)
  Future<List<Vehicle>> getVehiclesNeedingRenewal({int withinDays = 30}) async {
    final vehicles = await getAllVehicles(activeOnly: true);
    return vehicles.where((v) => v.isRenewalNeeded(withinDays)).toList();
  }

  /// Get all routes enriched with vehicle_number and ordered stops
  Future<List<Route>> getAllRoutes() async {
    final db = await _db;
    final routeMaps = await db.rawQuery('''
      SELECT r.*, v.vehicle_number
      FROM routes r
      LEFT JOIN vehicles v ON r.vehicle_id = v.id
      ORDER BY r.route_name ASC
    ''');

    final List<Route> routes = [];
    for (final map in routeMaps) {
      final routeId = map['id'] as String;
      final stops = await getStopsForRoute(routeId);
      routes.add(Route.fromMap(map, stops));
    }
    return routes;
  }

  /// Get route by ID with stops
  Future<Route?> getRouteById(String id) async {
    final db = await _db;
    final routeMaps = await db.rawQuery('''
      SELECT r.*, v.vehicle_number
      FROM routes r
      LEFT JOIN vehicles v ON r.vehicle_id = v.id
      WHERE r.id = ?
      LIMIT 1
    ''', [id]);
    if (routeMaps.isEmpty) return null;
    final stops = await getStopsForRoute(id);
    return Route.fromMap(routeMaps.first, stops);
  }

  /// Insert route with stops
  Future<void> insertRoute(Route route) async {
    final db = await _db;
    await db.transaction((txn) async {
      await _insertLogged(txn, 'routes', route.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      for (final stop in route.stops) {
        await _insertLogged(txn, 'route_stops', stop.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Update route and replace stops
  Future<void> updateRoute(Route route) async {
    final db = await _db;
    await db.transaction((txn) async {
      await _updateLogged(txn, 'routes', route.toMap(), where: 'id = ?', whereArgs: [route.id]);
      await _deleteLogged(txn, 'route_stops', where: 'route_id = ?', whereArgs: [route.id]);
      for (final stop in route.stops) {
        await _insertLogged(txn, 'route_stops', stop.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Delete route
  Future<void> deleteRoute(String id) async {
    final db = await _db;
    await _deleteLogged(db, 'routes', where: 'id = ?', whereArgs: [id]);
  }

  /// Get stops for a route ordered by stop_order ASC
  Future<List<RouteStop>> getStopsForRoute(String routeId) async {
    final db = await _db;
    final results = await db.query(
      'route_stops',
      where: 'route_id = ?',
      whereArgs: [routeId],
      orderBy: 'stop_order ASC',
    );
    return results.map((map) => RouteStop.fromMap(map)).toList();
  }

  /// Save / update stops for a route in transaction
  Future<void> saveRouteStops(String routeId, List<RouteStop> stops) async {
    final db = await _db;
    await db.transaction((txn) async {
      await _deleteLogged(txn, 'route_stops', where: 'route_id = ?', whereArgs: [routeId]);
      for (int i = 0; i < stops.length; i++) {
        final stop = stops[i].copyWith(stopOrder: i + 1, routeId: routeId);
        await _insertLogged(txn, 'route_stops', stop.toMap());
      }
    });
  }

  /// Assign student to route + stop + monthly fee, and sync with student_fee_ledger
  Future<StudentTransport> assignStudentToRoute({
    required String studentId,
    required String routeId,
    required String stopId,
    required double monthlyFee,
    required String academicYear,
  }) async {
    final db = await _db;
    late StudentTransport result;

    await db.transaction((txn) async {
      final existing = await txn.rawQuery(
        'SELECT * FROM student_transport WHERE student_id = ? AND academic_year = ? LIMIT 1',
        [studentId, academicYear],
      );

      final nowIso = DateTime.now().toIso8601String();
      if (existing.isNotEmpty) {
        final id = existing.first['id'] as String;
        await txn.rawUpdate('''
          UPDATE student_transport
          SET route_id = ?, stop_id = ?, monthly_fee = ?, is_active = 1
          WHERE id = ?
        ''', [routeId, stopId, monthlyFee, id]);

        result = StudentTransport(
          id: id,
          studentId: studentId,
          routeId: routeId,
          stopId: stopId,
          monthlyFee: monthlyFee,
          academicYear: academicYear,
          isActive: true,
        );
      } else {
        final transport = StudentTransport.create(
          studentId: studentId,
          routeId: routeId,
          stopId: stopId,
          monthlyFee: monthlyFee,
          academicYear: academicYear,
          isActive: true,
        );
        await _insertLogged(txn, 'student_transport', transport.toMap());
        result = transport;
      }

      // Link with student_fee_ledger system!
      // Ensure 'fh-transport' fee head exists
      final fhRows = await txn.query('fee_heads', where: 'id = ? OR name = ?', whereArgs: ['fh-transport', 'Transport Fee']);
      String feeHeadId = 'fh-transport';
      if (fhRows.isEmpty) {
        await _insertLogged(txn, 'fee_heads', {
          'id': 'fh-transport',
          'name': 'Transport Fee',
          'description': 'Monthly school bus and conveyance charges',
          'is_recurring': 1,
          'frequency': 'monthly',
        });
      } else {
        feeHeadId = fhRows.first['id'] as String;
      }

      // Upsert student_fee_ledger entry for Transport Fee
      final ledgerRows = await txn.query(
        'student_fee_ledger',
        where: 'student_id = ? AND fee_head_id = ? AND academic_year = ?',
        whereArgs: [studentId, feeHeadId, academicYear],
      );

      final now = DateTime.now();
      final dueDate = DateTime(now.year, now.month + 1, 0);

      if (ledgerRows.isNotEmpty) {
        final ledgerId = ledgerRows.first['id'] as String;
        await txn.rawUpdate('''
          UPDATE student_fee_ledger
          SET amount_due = ?, updated_at = ?
          WHERE id = ?
        ''', [monthlyFee, nowIso, ledgerId]);
      } else {
        final ledger = StudentFeeLedger.create(
          studentId: studentId,
          feeHeadId: feeHeadId,
          academicYear: academicYear,
          amountDue: monthlyFee,
          dueDate: dueDate,
          feeHeadName: 'Transport Fee',
          frequency: 'monthly',
        );
        await _insertLogged(txn, 'student_fee_ledger', ledger.toMap());
      }
    });

    return result;
  }

  /// Remove student transport assignment and deactivate ledger row if unpaid
  Future<void> removeStudentTransport(String studentId, String academicYear) async {
    final db = await _db;
    await db.transaction((txn) async {
      await _deleteLogged(txn, 
        'student_transport',
        where: 'student_id = ? AND academic_year = ?',
        whereArgs: [studentId, academicYear],
      );
      // Remove unpaid transport ledger row if exists
      await _deleteLogged(txn, 
        'student_fee_ledger',
        where: 'student_id = ? AND fee_head_id = ? AND academic_year = ? AND amount_paid = 0',
        whereArgs: [studentId, 'fh-transport', academicYear],
      );
    });
  }

  /// Get student transport details for a given student & academic year
  Future<StudentTransport?> getStudentTransport(String studentId, String academicYear) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT st.*,
             TRIM(COALESCE(s.first_name, '') || ' ' || COALESCE(s.last_name, '')) as student_name,
             s.roll_number, s.grade_level, s.section,
             r.route_name,
             rs.stop_name, rs.pickup_time, rs.drop_time
      FROM student_transport st
      JOIN students s ON st.student_id = s.id
      JOIN routes r ON st.route_id = r.id
      JOIN route_stops rs ON st.stop_id = rs.id
      WHERE st.student_id = ? AND st.academic_year = ? AND st.is_active = 1
      LIMIT 1
    ''', [studentId, academicYear]);

    if (results.isEmpty) return null;
    return StudentTransport.fromMap(results.first);
  }

  /// Get route manifest with stops in order, each with its assigned students list
  Future<Map<String, dynamic>> getRouteWithStudents(String routeId, {String academicYear = '2024-2025'}) async {
    final db = await _db;
    final route = await getRouteById(routeId);
    if (route == null) return {'route': null, 'stops': []};

    final stops = await getStopsForRoute(routeId);
    final List<Map<String, dynamic>> stopsWithStudents = [];

    for (final stop in stops) {
      final studentRows = await db.rawQuery('''
        SELECT st.*,
               TRIM(COALESCE(s.first_name, '') || ' ' || COALESCE(s.last_name, '')) as student_name,
               s.roll_number, s.grade_level, s.section,
               r.route_name,
               rs.stop_name, rs.pickup_time, rs.drop_time
        FROM student_transport st
        JOIN students s ON st.student_id = s.id
        JOIN routes r ON st.route_id = r.id
        JOIN route_stops rs ON st.stop_id = rs.id
        WHERE st.stop_id = ? AND st.academic_year = ? AND st.is_active = 1
        ORDER BY s.first_name ASC
      ''', [stop.id, academicYear]);

      final students = studentRows.map((map) => StudentTransport.fromMap(map)).toList();
      stopsWithStudents.add({
        'stop': stop,
        'students': students,
      });
    }

    return {
      'route': route,
      'stops_with_students': stopsWithStudents,
    };
  }

  /// Get Fleet Overview: vehicle details, capacity, assigned student count, renewal alerts
  Future<List<Map<String, dynamic>>> getFleetOverview({String academicYear = '2024-2025'}) async {
    final db = await _db;
    final vehicles = await getAllVehicles();
    final List<Map<String, dynamic>> overview = [];

    for (final v in vehicles) {
      // Find route assigned to vehicle
      final routes = await db.rawQuery('SELECT * FROM routes WHERE vehicle_id = ?', [v.id]);
      String routeName = 'Unassigned';
      String? routeId;
      if (routes.isNotEmpty) {
        routeName = routes.first['route_name'] as String;
        routeId = routes.first['id'] as String;
      }

      // Count assigned students on this vehicle's routes
      int studentCount = 0;
      if (routeId != null) {
        final countResult = await db.rawQuery('''
          SELECT COUNT(*) as cnt FROM student_transport
          WHERE route_id = ? AND academic_year = ? AND is_active = 1
        ''', [routeId, academicYear]);
        studentCount = countResult.first['cnt'] as int? ?? 0;
      }

      overview.add({
        'vehicle': v,
        'route_name': routeName,
        'assigned_students': studentCount,
        'capacity': v.capacity,
        'occupancy_percentage': v.capacity > 0 ? (studentCount / v.capacity * 100).clamp(0.0, 100.0) : 0.0,
        'needs_renewal': v.isRenewalNeeded(30),
      });
    }

    return overview;
  }

  // ============================================================================
  // EXAMINATION & REPORTS OPERATIONS (PHASE 1 & PHASE 2)
  // ============================================================================

  /// Get all exam types
  Future<List<ExamType>> getAllExamTypes() async {
    final db = await _db;
    final results = await db.query('exam_types', orderBy: 'weightage_percent ASC');
    return results.map((map) => ExamType.fromMap(map)).toList();
  }

  /// Insert exam type
  Future<void> insertExamType(ExamType examType) async {
    final db = await _db;
    await _insertLogged(db, 'exam_types', examType.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update exam type
  Future<void> updateExamType(ExamType examType) async {
    final db = await _db;
    await _updateLogged(db, 'exam_types', examType.toMap(), where: 'id = ?', whereArgs: [examType.id]);
  }

  /// Delete exam type
  Future<void> deleteExamType(String id) async {
    final db = await _db;
    await _deleteLogged(db, 'exam_types', where: 'id = ?', whereArgs: [id]);
  }

  /// Get all exams enriched with exam_type_name, with optional class & academic year filtering
  Future<List<Exam>> getAllExams({String? className, String? academicYear}) async {
    final db = await _db;
    final whereClauses = <String>[];
    final args = <dynamic>[];

    if (className != null && className.isNotEmpty && className != 'All') {
      whereClauses.add('e.class = ?');
      args.add(className);
    }

    if (academicYear != null && academicYear.isNotEmpty) {
      whereClauses.add('e.academic_year = ?');
      args.add(academicYear);
    }

    final whereStr = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final results = await db.rawQuery('''
      SELECT e.*, et.name as exam_type_name
      FROM exams e
      JOIN exam_types et ON e.exam_type_id = et.id
      $whereStr
      ORDER BY e.start_date DESC, e.name ASC
    ''', args);

    return results.map((map) => Exam.fromMap(map)).toList();
  }

  /// Get exam by ID
  Future<Exam?> getExamById(String id) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT e.*, et.name as exam_type_name
      FROM exams e
      JOIN exam_types et ON e.exam_type_id = et.id
      WHERE e.id = ?
      LIMIT 1
    ''', [id]);
    if (results.isEmpty) return null;
    return Exam.fromMap(results.first);
  }

  /// Insert new exam
  Future<void> insertExam(Exam exam) async {
    final db = await _db;
    await _insertLogged(db, 'exams', exam.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update exam
  Future<void> updateExam(Exam exam) async {
    final db = await _db;
    await _updateLogged(db, 'exams', exam.toMap(), where: 'id = ?', whereArgs: [exam.id]);
  }

  /// Delete exam
  Future<void> deleteExam(String id) async {
    final db = await _db;
    await _deleteLogged(db, 'exams', where: 'id = ?', whereArgs: [id]);
  }

  /// Get subjects for an exam enriched with staff_name (teacher)
  Future<List<ExamSubject>> getExamSubjects(String examId) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT es.*,
             e.name as exam_name,
             TRIM(COALESCE(st.first_name, '') || ' ' || COALESCE(st.last_name, '')) as staff_name
      FROM exam_subjects es
      JOIN exams e ON es.exam_id = e.id
      LEFT JOIN staff st ON es.staff_id = st.id
      WHERE es.exam_id = ?
      ORDER BY es.exam_date ASC, es.subject ASC
    ''', [examId]);
    return results.map((map) => ExamSubject.fromMap(map)).toList();
  }

  /// Get a single exam subject by ID
  Future<ExamSubject?> getExamSubjectById(String id) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT es.*,
             e.name as exam_name,
             TRIM(COALESCE(st.first_name, '') || ' ' || COALESCE(st.last_name, '')) as staff_name
      FROM exam_subjects es
      JOIN exams e ON es.exam_id = e.id
      LEFT JOIN staff st ON es.staff_id = st.id
      WHERE es.id = ?
      LIMIT 1
    ''', [id]);
    if (results.isEmpty) return null;
    return ExamSubject.fromMap(results.first);
  }

  /// Insert exam subject
  Future<void> insertExamSubject(ExamSubject examSubject) async {
    final db = await _db;
    await _insertLogged(db, 'exam_subjects', examSubject.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update exam subject
  Future<void> updateExamSubject(ExamSubject examSubject) async {
    final db = await _db;
    await _updateLogged(db, 'exam_subjects', examSubject.toMap(), where: 'id = ?', whereArgs: [examSubject.id]);
  }

  /// Delete exam subject
  Future<void> deleteExamSubject(String id) async {
    final db = await _db;
    await _deleteLogged(db, 'exam_subjects', where: 'id = ?', whereArgs: [id]);
  }

  /// Phase 2: Initialize marks sheet for an exam subject by pre-creating
  /// a marks row per enrolled student in that class/section.
  /// Returns the complete marks roster list enriched with student info.
  Future<List<Marks>> initializeMarksSheet(String examSubjectId, {String? enteredBy}) async {
    final db = await _db;

    // 1. Fetch exam subject & exam details
    final examSub = await getExamSubjectById(examSubjectId);
    if (examSub == null) return [];

    final exam = await getExamById(examSub.examId);
    if (exam == null) return [];

    // 2. Fetch enrolled students matching class and optional section
    final whereClauses = <String>['(grade_level = ? OR class_id = ? OR class_id = (SELECT id FROM classes WHERE name = ?))'];
    final whereArgs = <dynamic>[exam.className, exam.className, exam.className];

    if (exam.section != null && exam.section!.isNotEmpty && exam.section != 'All') {
      whereClauses.add('(section = ? OR section IS NULL)');
      whereArgs.add(exam.section);
    }

    final studentRows = await db.query(
      'students',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'first_name ASC, last_name ASC',
    );

    final nowIso = DateTime.now().toIso8601String();

    // 3. Pre-create missing marks rows for each student
    await db.transaction((txn) async {
      for (final sRow in studentRows) {
        final sId = sRow['id'] as String;
        final markId = 'mks-${examSubjectId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}-$sId';

        await txn.rawInsert('''
          INSERT OR IGNORE INTO marks
            (id, exam_subject_id, student_id, marks_obtained, is_absent, remarks, entered_by, entered_at)
          VALUES (?, ?, ?, NULL, 0, NULL, ?, ?)
        ''', [markId, examSubjectId, sId, enteredBy, nowIso]);
      }
    });

    // 4. Return full marks roster enriched with student details
    final marksRows = await db.rawQuery('''
      SELECT m.*,
             TRIM(COALESCE(s.first_name, '') || ' ' || COALESCE(s.last_name, '')) as student_name,
             s.roll_number, s.grade_level, s.section,
             es.subject, es.max_marks, es.passing_marks,
             e.name as exam_name
      FROM marks m
      JOIN students s ON m.student_id = s.id
      JOIN exam_subjects es ON m.exam_subject_id = es.id
      JOIN exams e ON es.exam_id = e.id
      WHERE m.exam_subject_id = ?
      ORDER BY s.roll_number ASC, s.first_name ASC
    ''', [examSubjectId]);

    return marksRows.map((map) => Marks.fromMap(map)).toList();
  }

  /// Phase 2: Bulk update a whole marks sheet at once in a transaction
  Future<void> bulkUpdateMarks(String examSubjectId, List<Marks> marksList) async {
    final db = await _db;
    final nowIso = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (final m in marksList) {
        await txn.rawUpdate('''
          UPDATE marks
          SET marks_obtained = ?,
              is_absent = ?,
              remarks = ?,
              entered_by = ?,
              entered_at = ?
          WHERE id = ?
        ''', [
          m.isAbsent ? null : m.marksObtained,
          m.isAbsent ? 1 : 0,
          m.remarks,
          m.enteredBy,
          nowIso,
          m.id,
        ]);
      }
    });
  }

  /// Phase 2: Get all marks for a student in a specific exam (for report card pulling)
  Future<List<Marks>> getMarksForStudent(String studentId, String examId) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT m.*,
             TRIM(COALESCE(s.first_name, '') || ' ' || COALESCE(s.last_name, '')) as student_name,
             s.roll_number, s.grade_level, s.section,
             es.subject, es.max_marks, es.passing_marks,
             e.name as exam_name
      FROM marks m
      JOIN students s ON m.student_id = s.id
      JOIN exam_subjects es ON m.exam_subject_id = es.id
      JOIN exams e ON es.exam_id = e.id
      WHERE m.student_id = ? AND es.exam_id = ?
      ORDER BY es.exam_date ASC, es.subject ASC
    ''', [studentId, examId]);

    return results.map((map) => Marks.fromMap(map)).toList();
  }

  // ============================================================================
  // GRADING & TERM AGGREGATION OPERATIONS (PHASE 3 & PHASE 4)
  // ============================================================================

  /// Get grade scale list for an academic year
  Future<List<GradeScale>> getGradeScales({String academicYear = '2024-2025'}) async {
    final db = await _db;
    final results = await db.query(
      'grade_scale',
      where: 'academic_year = ?',
      whereArgs: [academicYear],
      orderBy: 'min_percent DESC',
    );
    if (results.isEmpty) {
      // Return default scale
      return const [
        GradeScale(id: 'gs-a-plus', academicYear: '2024-2025', minPercent: 90.0, maxPercent: 100.0, grade: 'A+', gradePoint: 4.0),
        GradeScale(id: 'gs-a', academicYear: '2024-2025', minPercent: 80.0, maxPercent: 89.99, grade: 'A', gradePoint: 3.5),
        GradeScale(id: 'gs-b', academicYear: '2024-2025', minPercent: 70.0, maxPercent: 79.99, grade: 'B', gradePoint: 3.0),
        GradeScale(id: 'gs-c', academicYear: '2024-2025', minPercent: 60.0, maxPercent: 69.99, grade: 'C', gradePoint: 2.5),
        GradeScale(id: 'gs-d', academicYear: '2024-2025', minPercent: 50.0, maxPercent: 59.99, grade: 'D', gradePoint: 2.0),
        GradeScale(id: 'gs-e', academicYear: '2024-2025', minPercent: 35.0, maxPercent: 49.99, grade: 'E', gradePoint: 1.0),
        GradeScale(id: 'gs-f', academicYear: '2024-2025', minPercent: 0.0, maxPercent: 34.99, grade: 'F', gradePoint: 0.0),
      ];
    }
    return results.map((map) => GradeScale.fromMap(map)).toList();
  }

  /// Insert or update grade scale row
  Future<void> saveGradeScaleRow(GradeScale scale) async {
    final db = await _db;
    await _insertLogged(db, 'grade_scale', scale.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Delete grade scale row
  Future<void> deleteGradeScaleRow(String id) async {
    final db = await _db;
    await _deleteLogged(db, 'grade_scale', where: 'id = ?', whereArgs: [id]);
  }

  /// Phase 3: computeGrade(percent, academicYear) — looks up grade_scale and returns matching grade & point
  Future<Map<String, dynamic>> computeGrade(double percent, String academicYear) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT grade, grade_point
      FROM grade_scale
      WHERE academic_year = ? AND ? >= min_percent AND ? <= max_percent
      LIMIT 1
    ''', [academicYear, percent, percent]);

    if (results.isNotEmpty) {
      return {
        'grade': results.first['grade'] as String,
        'grade_point': (results.first['grade_point'] as num?)?.toDouble(),
      };
    }

    // Default Fallback Scale
    if (percent >= 90.0) return {'grade': 'A+', 'grade_point': 4.0};
    if (percent >= 80.0) return {'grade': 'A', 'grade_point': 3.5};
    if (percent >= 70.0) return {'grade': 'B', 'grade_point': 3.0};
    if (percent >= 60.0) return {'grade': 'C', 'grade_point': 2.5};
    if (percent >= 50.0) return {'grade': 'D', 'grade_point': 2.0};
    if (percent >= 35.0) return {'grade': 'E', 'grade_point': 1.0};
    return {'grade': 'F', 'grade_point': 0.0};
  }

  /// Phase 3: computeExamResult(examId, studentId) — sums marks_obtained across exam_subjects,
  /// computes percent, applies computeGrade, flags pass/fail per subject and overall.
  Future<ExamResultData?> computeExamResult(String examId, String studentId) async {
    final exam = await getExamById(examId);
    if (exam == null) return null;

    final student = await getStudentById(studentId);
    if (student == null) return null;

    final examSubjects = await getExamSubjects(examId);
    if (examSubjects.isEmpty) return null;

    final marksList = await getMarksForStudent(studentId, examId);
    final marksMap = {for (var m in marksList) m.examSubjectId: m};

    final List<SubjectResultItem> subjectResults = [];
    double totalObtained = 0.0;
    double totalMax = 0.0;
    bool anyFailed = false;

    for (final es in examSubjects) {
      final m = marksMap[es.id];
      final double obtained = (m != null && !m.isAbsent && m.marksObtained != null) ? m.marksObtained! : 0.0;
      final bool isAbsent = m?.isAbsent ?? false;
      final double subjPercent = es.maxMarks > 0 ? (obtained / es.maxMarks) * 100 : 0.0;
      final gradeInfo = await computeGrade(subjPercent, exam.academicYear);
      final bool pass = !isAbsent && obtained >= es.passingMarks;

      if (!pass) anyFailed = true;

      totalObtained += obtained;
      totalMax += es.maxMarks;

      subjectResults.add(SubjectResultItem(
        subject: es.subject,
        examDate: es.examDate,
        maxMarks: es.maxMarks,
        passingMarks: es.passingMarks,
        marksObtained: isAbsent ? null : obtained,
        isAbsent: isAbsent,
        grade: gradeInfo['grade'] as String,
        gradePoint: gradeInfo['grade_point'] as double?,
        isPassed: pass,
        remarks: m?.remarks,
        teacherName: es.staffName,
      ));
    }

    final double overallPercent = totalMax > 0 ? (totalObtained / totalMax) * 100 : 0.0;
    final overallGradeInfo = await computeGrade(overallPercent, exam.academicYear);
    final bool overallPass = !anyFailed && overallPercent >= 35.0;

    return ExamResultData(
      examId: exam.id,
      examName: exam.name,
      studentId: student.id,
      studentName: student.name,
      rollNumber: student.rollNumber ?? 'N/A',
      className: student.gradeLevel,
      section: student.section,
      academicYear: exam.academicYear,
      subjectResults: subjectResults,
      totalMarksObtained: totalObtained,
      totalMaxMarks: totalMax,
      percentage: overallPercent,
      grade: overallGradeInfo['grade'] as String,
      gradePoint: overallGradeInfo['grade_point'] as double?,
      isPassed: overallPass,
      attendancePercent: await computeAttendancePercentForReportCard(studentId, exam.academicYear),
    );
  }

  /// Compute class rankings for an exam across all enrolled students
  Future<Map<String, int>> getClassExamRankings(String examId) async {
    final exam = await getExamById(examId);
    if (exam == null) return {};

    final db = await _db;
    final whereClauses = <String>['(grade_level = ? OR grade_level = ?)'];
    final whereArgs = <dynamic>[exam.className, exam.className];

    if (exam.section != null && exam.section!.isNotEmpty && exam.section != 'All') {
      whereClauses.add('(section = ? OR section IS NULL)');
      whereArgs.add(exam.section);
    }

    final studentRows = await db.query('students', where: whereClauses.join(' AND '), whereArgs: whereArgs);
    final List<Map<String, dynamic>> studentScores = [];

    for (final s in studentRows) {
      final sId = s['id'] as String;
      final res = await computeExamResult(examId, sId);
      if (res != null) {
        studentScores.add({
          'student_id': sId,
          'percent': res.percentage,
        });
      }
    }

    studentScores.sort((a, b) => (b['percent'] as double).compareTo(a['percent'] as double));

    final Map<String, int> ranks = {};
    for (int i = 0; i < studentScores.length; i++) {
      ranks[studentScores[i]['student_id'] as String] = i + 1;
    }

    return ranks;
  }

  /// Phase 4: computeTermResult(studentId, academicYear) — combines results across exams
  /// within the year using exam_types.weightage_percent to produce a final term percentage/grade.
  Future<TermResultData?> computeTermResult(String studentId, String academicYear) async {
    final student = await getStudentById(studentId);
    if (student == null) return null;

    final allExams = await getAllExams(className: student.gradeLevel, academicYear: academicYear);
    if (allExams.isEmpty) return null;

    final examTypes = await getAllExamTypes();
    final typeMap = {for (var et in examTypes) et.id: et};

    final List<ExamResultData> examResults = [];
    double weightedSum = 0.0;
    double weightTotal = 0.0;
    bool anyExamFailed = false;

    for (final exam in allExams) {
      final res = await computeExamResult(exam.id, studentId);
      if (res != null) {
        examResults.add(res);
        final et = typeMap[exam.examTypeId];
        final weight = et?.weightagePercent ?? 25.0;

        weightedSum += res.percentage * (weight / 100.0);
        weightTotal += weight / 100.0;

        if (!res.isPassed) anyExamFailed = true;
      }
    }

    final double termPercent = weightTotal > 0 ? (weightedSum / weightTotal) : 0.0;
    final termGradeInfo = await computeGrade(termPercent, academicYear);

    return TermResultData(
      studentId: student.id,
      studentName: student.name,
      rollNumber: student.rollNumber ?? 'N/A',
      className: student.gradeLevel,
      section: student.section,
      academicYear: academicYear,
      examResults: examResults,
      weightedPercentage: termPercent,
      overallGrade: termGradeInfo['grade'] as String,
      overallGradePoint: termGradeInfo['grade_point'] as double?,
      isPassed: !anyExamFailed && termPercent >= 35.0,
    );
  }

  /// Get Dashboard metrics for a specific exam
  Future<Map<String, dynamic>> getExamResultsDashboardData(String examId) async {
    final exam = await getExamById(examId);
    if (exam == null) {
      return {
        'overallAverage': 0.0,
        'overallPassPercentage': 0.0,
        'topPerformers': [],
        'subjectPerformance': [],
      };
    }

    final db = await _db;
    final examSubjects = await getExamSubjects(examId);
    List<Map<String, dynamic>> subjectPerformance = [];

    for (var es in examSubjects) {
      final marksRows = await db.query('marks', where: 'exam_subject_id = ?', whereArgs: [es.id]);
      
      double totalMarks = 0;
      int passCount = 0;
      int studentsCount = marksRows.length;
      
      for (var m in marksRows) {
        final obtained = (m['marks_obtained'] as num?)?.toDouble();
        final isAbsent = m['is_absent'] == 1;
        final val = (obtained != null && !isAbsent) ? obtained : 0.0;
        totalMarks += val;
        
        if (!isAbsent && val >= es.passingMarks) {
          passCount++;
        }
      }
      
      double avg = studentsCount > 0 ? totalMarks / studentsCount : 0.0;
      double passPct = studentsCount > 0 ? (passCount / studentsCount) * 100 : 0.0;
      
      subjectPerformance.add({
        'subject': es.subject,
        'averageMarks': avg,
        'passPercentage': passPct,
        'maxMarks': es.maxMarks,
      });
    }

    final whereClauses = <String>['(grade_level = ? OR grade_level = ?)', 'is_active = 1'];
    final whereArgs = <dynamic>[exam.className, exam.className];

    if (exam.section != null && exam.section!.isNotEmpty && exam.section != 'All') {
      whereClauses.add('(section = ? OR section IS NULL)');
      whereArgs.add(exam.section);
    }

    final studentRows = await db.query('students', where: whereClauses.join(' AND '), whereArgs: whereArgs);
    
    List<ExamResultData> allResults = [];
    for (var s in studentRows) {
      final sId = s['id'] as String;
      final res = await computeExamResult(examId, sId);
      if (res != null) {
        allResults.add(res);
      }
    }

    double totalPercentageSum = 0;
    int overallPassCount = 0;
    
    for (var res in allResults) {
      totalPercentageSum += res.percentage;
      if (res.isPassed) overallPassCount++;
    }
    
    double overallAvg = allResults.isNotEmpty ? totalPercentageSum / allResults.length : 0.0;
    double overallPassPercentage = allResults.isNotEmpty ? (overallPassCount / allResults.length) * 100 : 0.0;
    
    allResults.sort((a, b) => b.totalMarksObtained.compareTo(a.totalMarksObtained));
    final top5 = allResults.take(5).map((r) => {
      'studentName': r.studentName,
      'totalMarks': r.totalMarksObtained,
      'totalMaxMarks': r.totalMaxMarks,
      'percentage': r.percentage,
    }).toList();

    return {
      'overallAverage': overallAvg,
      'overallPassPercentage': overallPassPercentage,
      'topPerformers': top5,
      'subjectPerformance': subjectPerformance,
    };
  }
  // ============================================================================
  // FEATURE FLAGS (PHASE 0)
  // ============================================================================

  /// Check if a feature is enabled
  Future<bool> isFeatureEnabled(String flagKey) async {
    final db = await _db;
    final result = await db.query(
      'feature_flags',
      where: 'flag_key = ?',
      whereArgs: [flagKey],
    );
    if (result.isEmpty) return false;
    return (result.first['is_enabled'] as int) == 1;
  }

  /// Toggle feature flag
  Future<void> toggleFeature(String flagKey, bool isEnabled) async {
    final db = await _db;
    await _updateLogged(db, 
      'feature_flags',
      {'is_enabled': isEnabled ? 1 : 0},
      where: 'flag_key = ?',
      whereArgs: [flagKey],
    );
  }
  // ============================================================================
  // HOSTEL MANAGEMENT (PHASE 2 & 3)
  // ============================================================================

  Future<void> createHostelBlock(HostelBlock block) async {
    final db = await _db;
    await _insertLogged(db, 'hostel_blocks', block.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<HostelBlock>> getHostelBlocks() async {
    final db = await _db;
    final result = await db.query('hostel_blocks');
    return result.map((m) => HostelBlock.fromMap(m)).toList();
  }

  Future<void> createHostelRoom(HostelRoom room) async {
    final db = await _db;
    await _insertLogged(db, 'hostel_rooms', room.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<HostelRoom>> getAllHostelRooms() async {
    final db = await _db;
    final result = await db.query('hostel_rooms');
    return result.map((m) => HostelRoom.fromMap(m)).toList();
  }

  Future<List<HostelAllocation>> getHostelAllocations() async {
    final db = await _db;
    final result = await db.query('hostel_allocations', where: 'is_active = 1');
    return result.map((m) => HostelAllocation.fromMap(m)).toList();
  }

  Future<List<Outpass>> getOutpasses() async {
    final db = await _db;
    final result = await db.query('outpasses', orderBy: 'out_date DESC');
    return result.map((m) => Outpass.fromMap(m)).toList();
  }

  Future<void> allocateStudent(String studentId, String roomId, String academicYear, double monthlyFee) async {
    final db = await _db;
    await db.transaction((txn) async {
      final roomResult = await txn.query('hostel_rooms', where: 'id = ?', whereArgs: [roomId]);
      if (roomResult.isEmpty) throw Exception('Room not found');
      
      final room = roomResult.first;
      final capacity = room['capacity'] as int;
      final currentOccupancy = room['current_occupancy'] as int;

      if (currentOccupancy >= capacity) {
        throw Exception('Room is already at full capacity');
      }

      final allocationId = 'alloc-${DateTime.now().millisecondsSinceEpoch}';
      await _insertLogged(txn, 'hostel_allocations', {
        'id': allocationId,
        'student_id': studentId,
        'room_id': roomId,
        'academic_year': academicYear,
        'allocated_date': DateTime.now().toIso8601String(),
        'is_active': 1,
      });

      await _updateLogged(txn, 
        'hostel_rooms',
        {'current_occupancy': currentOccupancy + 1},
        where: 'id = ?',
        whereArgs: [roomId],
      );

      // Fee Integration for Hostel
      final fhRows = await txn.query('fee_heads', where: 'id = ? OR name = ?', whereArgs: ['fh-hostel', 'Hostel Fee']);
      String feeHeadId = 'fh-hostel';
      if (fhRows.isEmpty) {
        await _insertLogged(txn, 'fee_heads', {
          'id': 'fh-hostel',
          'name': 'Hostel Fee',
          'description': 'Monthly hostel accommodation and mess charges',
          'is_recurring': 1,
          'frequency': 'monthly',
        });
      } else {
        feeHeadId = fhRows.first['id'] as String;
      }

      final ledgerRows = await txn.query(
        'student_fee_ledger',
        where: 'student_id = ? AND fee_head_id = ? AND academic_year = ?',
        whereArgs: [studentId, feeHeadId, academicYear],
      );

      final now = DateTime.now();
      final dueDate = DateTime(now.year, now.month + 1, 0);

      if (ledgerRows.isNotEmpty) {
        final ledgerId = ledgerRows.first['id'] as String;
        await txn.rawUpdate('''
          UPDATE student_fee_ledger
          SET amount_due = ?, updated_at = ?
          WHERE id = ?
        ''', [monthlyFee, now.toIso8601String(), ledgerId]);
      } else {
        final ledger = StudentFeeLedger.create(
          studentId: studentId,
          feeHeadId: feeHeadId,
          academicYear: academicYear,
          amountDue: monthlyFee,
          dueDate: dueDate,
          feeHeadName: 'Hostel Fee',
          frequency: 'monthly',
        );
        await _insertLogged(txn, 'student_fee_ledger', ledger.toMap());
      }
    });
  }

  Future<void> vacateStudent(String allocationId) async {
    final db = await _db;
    await db.transaction((txn) async {
      final allocResult = await txn.query('hostel_allocations', where: 'id = ? AND is_active = 1', whereArgs: [allocationId]);
      if (allocResult.isEmpty) return;

      final roomId = allocResult.first['room_id'] as String;

      await _updateLogged(txn, 
        'hostel_allocations',
        {
          'is_active': 0,
          'vacated_date': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [allocationId],
      );

      final roomResult = await txn.query('hostel_rooms', where: 'id = ?', whereArgs: [roomId]);
      if (roomResult.isNotEmpty) {
        final currentOccupancy = roomResult.first['current_occupancy'] as int;
        if (currentOccupancy > 0) {
          await _updateLogged(txn, 
            'hostel_rooms',
            {'current_occupancy': currentOccupancy - 1},
            where: 'id = ?',
            whereArgs: [roomId],
          );
        }
      }
    });
  }

  Future<List<HostelRoom>> getAvailableRooms(String blockId) async {
    final db = await _db;
    final result = await db.query(
      'hostel_rooms',
      where: 'block_id = ? AND current_occupancy < capacity',
      whereArgs: [blockId],
    );
    return result.map((m) => HostelRoom.fromMap(m)).toList();
  }

  Future<Map<String, dynamic>?> getStudentHostelInfo(String studentId) async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT 
        a.id AS allocation_id, a.bed_number, a.allocated_date,
        r.room_number, r.floor,
        b.block_name, b.warden_staff_id
      FROM hostel_allocations a
      JOIN hostel_rooms r ON a.room_id = r.id
      JOIN hostel_blocks b ON r.block_id = b.id
      WHERE a.student_id = ? AND a.is_active = 1
      LIMIT 1
    ''', [studentId]);

    if (result.isEmpty) return null;
    final info = Map<String, dynamic>.from(result.first);
    
    // Fetch warden info if available
    final wardenId = info['warden_staff_id'] as String?;
    if (wardenId != null) {
      final staffResult = await db.query('staff', where: 'id = ?', whereArgs: [wardenId]);
      if (staffResult.isNotEmpty) {
        final s = staffResult.first;
        info['warden_name'] = '${s['first_name']} ${s['last_name']}';
      }
    }
    return info;
  }

  Future<void> markHostelAttendance(List<HostelAttendance> attendanceList) async {
    final db = await _db;
    final batch = db.batch();
    for (var att in attendanceList) {
      batch.insert(
        'hostel_attendance',
        att.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> requestOutpass(Outpass outpass) async {
    final db = await _db;
    await _insertLogged(db, 'outpasses', outpass.toMap());
  }

  Future<void> updateOutpassStatus(String outpassId, String status, {String? returnDate, String? approvedBy}) async {
    final db = await _db;
    final updateData = <String, dynamic>{'status': status};
    if (returnDate != null) updateData['actual_return_date'] = returnDate;
    if (approvedBy != null) updateData['approved_by'] = approvedBy;

    await _updateLogged(db, 
      'outpasses',
      updateData,
      where: 'id = ?',
      whereArgs: [outpassId],
    );
  }
  // ============================================================================
  // STUDENT ATTENDANCE (PHASE 2)
  // ============================================================================

  Future<void> initializeAttendanceSheet(String className, String section, String date, String markedBy) async {
    final db = await _db;
    await db.transaction((txn) async {
      // 1. Check if date is a holiday/weekend
      final calendarResult = await txn.query('academic_calendar', where: 'date = ?', whereArgs: [date]);
      if (calendarResult.isNotEmpty) {
        final dayType = calendarResult.first['day_type'] as String;
        if (dayType == 'holiday' || dayType == 'weekend') {
          throw Exception('Cannot initialize attendance: The selected date is marked as a $dayType.');
        }
      }

      // 2. Fetch active students in class/section
      final studentsResult = await txn.query(
        'students',
        where: 'grade_level = ? AND section = ? AND is_active = 1',
        whereArgs: [className, section],
      );

      if (studentsResult.isEmpty) {
        throw Exception('No active students found in $className-$section');
      }

      // 3. Insert default 'present' records
      final now = DateTime.now().toIso8601String();
      for (var studentRow in studentsResult) {
        final studentId = studentRow['id'] as String;
        final attendanceId = 'att-${const Uuid().v4()}';
        
        await _insertLogged(txn, 
          'student_attendance',
          {
            'id': attendanceId,
            'student_id': studentId,
            'class': className,
            'section': section,
            'date': date,
            'status': 'present',
            'marked_by': markedBy,
            'marked_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore, // Skip if already initialized
        );
      }
    });
  }

  Future<void> bulkUpdateAttendance(String date, String className, String section, List<StudentAttendance> sheet) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (var att in sheet) {
        await _updateLogged(txn, 
          'student_attendance',
          {
            'status': att.status,
            'remarks': att.remarks,
            'marked_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [att.id],
        );
      }
    });
  }

  Future<List<StudentAttendance>> getAttendanceForStudent(String studentId, {String? startDate, String? endDate}) async {
    final db = await _db;
    
    String whereClause = 'student_id = ?';
    List<dynamic> whereArgs = [studentId];

    if (startDate != null && endDate != null) {
      whereClause += ' AND date >= ? AND date <= ?';
      whereArgs.addAll([startDate, endDate]);
    }

    final result = await db.query(
      'student_attendance',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    return result.map((m) => StudentAttendance.fromMap(m)).toList();
  }

  Future<List<StudentAttendance>> getClassAttendanceForDate(String className, String section, String date) async {
    final db = await _db;
    final result = await db.query(
      'student_attendance',
      where: 'class = ? AND section = ? AND date = ?',
      whereArgs: [className, section, date],
    );
    return result.map((m) => StudentAttendance.fromMap(m)).toList();
  }

  Future<void> updateStudentAttendanceRecord(StudentAttendance record) async {
    final db = await _db;
    await _updateLogged(db, 
      'student_attendance',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  // ============================================================================
  // STUDENT ATTENDANCE (PHASE 3)
  // ============================================================================

  Future<Map<String, dynamic>> computeMonthlyAttendance(String studentId, int month, int year) async {
    final db = await _db;
    final monthStr = month.toString().padLeft(2, '0');
    final startPrefix = '$year-$monthStr';

    final attRecords = await db.query(
      'student_attendance',
      where: 'student_id = ? AND date LIKE ?',
      whereArgs: [studentId, '$startPrefix%'],
    );

    int present = 0;
    int absent = 0;
    int halfDay = 0;
    int late = 0;
    int excused = 0;

    for (var row in attRecords) {
      final status = row['status'] as String;
      if (status == 'present') present++;
      if (status == 'absent') absent++;
      if (status == 'half_day') halfDay++;
      if (status == 'late') late++;
      if (status == 'excused') excused++;
    }

    final totalWorkingDays = present + absent + halfDay + late + excused;
    double percent = totalWorkingDays > 0 ? (present + halfDay * 0.5 + late) / totalWorkingDays * 100 : 0.0;

    return {
      'present': present,
      'absent': absent,
      'half_day': halfDay,
      'late': late,
      'excused': excused,
      'percent': percent,
      'total_working_days': totalWorkingDays,
    };
  }

  Future<double> computeAttendancePercentForReportCard(String studentId, String academicYear) async {
    final db = await _db;
    final attRecords = await db.query(
      'student_attendance',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );

    int presentAndLate = 0;
    int halfDay = 0;
    
    for (var row in attRecords) {
      final status = row['status'] as String;
      if (status == 'present' || status == 'late') presentAndLate++;
      if (status == 'half_day') halfDay++;
    }

    int total = attRecords.length;
    if (total == 0) return 0.0;
    return ((presentAndLate + halfDay * 0.5) / total) * 100;
  }

  Future<List<Map<String, dynamic>>> getLowAttendanceStudents(String className, String section, String academicYear) async {
    final db = await _db;
    
    // Get the threshold
    final settingsResult = await db.query('attendance_settings', where: 'academic_year = ?', whereArgs: [academicYear]);
    double threshold = 75.0; // Default
    if (settingsResult.isNotEmpty) {
      threshold = settingsResult.first['low_attendance_threshold_percent'] as double;
    }

    // Get students
    final studentsResult = await db.query(
      'students',
      where: 'grade_level = ? AND section = ? AND is_active = 1',
      whereArgs: [className, section],
    );

    List<Map<String, dynamic>> lowAttendanceList = [];

    for (var sRow in studentsResult) {
      final studentId = sRow['id'] as String;
      final percent = await computeAttendancePercentForReportCard(studentId, academicYear);
      if (percent < threshold && percent > 0.0) { 
         final attRecords = await db.query('student_attendance', where: 'student_id = ?', whereArgs: [studentId]);
         if (attRecords.isNotEmpty) {
            lowAttendanceList.add({
              'student': Student.fromMap(sRow),
              'percent': percent,
            });
         }
      }
    }
    return lowAttendanceList;
  }

  // ============================================================================
  // PHASE 2: LIBRARY MANAGEMENT
  // ============================================================================

  Future<void> createBook(Book book) async {
    final db = await _db;
    await _insertLogged(db, 'books', book.toMap());
  }

  Future<void> updateBook(Book book) async {
    final db = await _db;
    await _updateLogged(db, 'books', book.toMap(), where: 'id = ?', whereArgs: [book.id]);
  }

  Future<void> deleteBook(String id) async {
    final db = await _db;
    await _deleteLogged(db, 'books', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Book>> getAllBooks() async {
    final db = await _db;
    final results = await db.query('books', orderBy: 'added_at DESC');
    return results.map((map) => Book.fromMap(map)).toList();
  }

  Future<List<Book>> searchBooks(String query) async {
    final db = await _db;
    final q = '%${query.toLowerCase()}%';
    final results = await db.rawQuery('''
      SELECT * FROM books 
      WHERE LOWER(title) LIKE ? 
         OR LOWER(author) LIKE ? 
         OR LOWER(isbn) LIKE ? 
         OR LOWER(category) LIKE ?
      ORDER BY title ASC
    ''', [q, q, q, q]);
    return results.map((map) => Book.fromMap(map)).toList();
  }

  Future<void> issueBook(String bookId, String borrowerType, String borrowerId, DateTime dueDate) async {
    final db = await _db;
    await db.transaction((txn) async {
      // Check availability
      final bookResults = await txn.query('books', where: 'id = ?', whereArgs: [bookId]);
      if (bookResults.isEmpty) throw Exception('Book not found');
      
      final book = Book.fromMap(bookResults.first);
      if (book.availableCopies <= 0) {
        throw Exception('No copies available for issue');
      }

      // Decrement available copies
      await _updateLogged(txn, 
        'books',
        {'available_copies': book.availableCopies - 1},
        where: 'id = ?',
        whereArgs: [book.id],
      );

      // Create issue
      final issue = BookIssue.create(
        bookId: bookId,
        borrowerType: borrowerType,
        borrowerId: borrowerId,
        dueDate: dueDate,
      );
      await _insertLogged(txn, 'book_issues', issue.toMap());
    });
  }

  Future<void> returnBook(String issueId, {bool isLost = false}) async {
    final db = await _db;
    await db.transaction((txn) async {
      final issueResults = await txn.query('book_issues', where: 'id = ?', whereArgs: [issueId]);
      if (issueResults.isEmpty) throw Exception('Issue record not found');
      
      final issue = BookIssue.fromMap(issueResults.first);
      if (issue.status == 'returned' || issue.status == 'lost') {
        throw Exception('Book is already marked as returned or lost');
      }

      // Compute fine (₹2/day)
      double fineAmount = 0.0;
      final now = DateTime.now();
      if (now.isAfter(issue.dueDate)) {
        final daysOverdue = now.difference(issue.dueDate).inDays;
        fineAmount = (daysOverdue * 2.0) > 0 ? (daysOverdue * 2.0) : 0.0;
      }

      // Update issue
      final updatedIssue = issue.copyWith(
        returnDate: now,
        status: isLost ? 'lost' : 'returned',
        fineAmount: fineAmount,
      );
      await _updateLogged(txn, 'book_issues', updatedIssue.toMap(), where: 'id = ?', whereArgs: [issueId]);

      // If not lost, increment copies
      if (!isLost) {
        final bookResults = await txn.query('books', where: 'id = ?', whereArgs: [issue.bookId]);
        if (bookResults.isNotEmpty) {
          final book = Book.fromMap(bookResults.first);
          await _updateLogged(txn, 
            'books',
            {'available_copies': book.availableCopies + 1},
            where: 'id = ?',
            whereArgs: [book.id],
          );
        }
      }
    });
  }
  
  Future<void> payFine(String issueId) async {
    final db = await _db;
    await _updateLogged(db, 'book_issues', {'fine_paid': 1}, where: 'id = ?', whereArgs: [issueId]);
  }

  Future<List<Map<String, dynamic>>> getOverdueIssues() async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    
    // Auto-flip status to overdue
    await db.rawUpdate('''
      UPDATE book_issues 
      SET status = 'overdue' 
      WHERE status = 'issued' AND due_date < ?
    ''', [now]);

    final results = await db.rawQuery('''
      SELECT bi.*, b.title as book_title, b.author as book_author 
      FROM book_issues bi
      JOIN books b ON bi.book_id = b.id
      WHERE bi.status = 'overdue'
      ORDER BY bi.due_date ASC
    ''');
    
    return results;
  }
  
  Future<List<Map<String, dynamic>>> getActiveIssues() async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT bi.*, b.title as book_title, b.author as book_author 
      FROM book_issues bi
      JOIN books b ON bi.book_id = b.id
      WHERE bi.status IN ('issued', 'overdue')
      ORDER BY bi.due_date ASC
    ''');
    
    return results;
  }

  Future<List<Map<String, dynamic>>> getBorrowerHistory(String borrowerType, String borrowerId) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT bi.*, b.title as book_title, b.author as book_author 
      FROM book_issues bi
      JOIN books b ON bi.book_id = b.id
      WHERE bi.borrower_type = ? AND bi.borrower_id = ?
      ORDER BY bi.issue_date DESC
    ''', [borrowerType, borrowerId]);
    return results;
  }

  // ============================================================================
  // TEACHER ATTENDANCE (PHASE 2 & 3)
  // ============================================================================

  Future<List<TeacherAttendance>> getAttendanceForStaff(String staffId, {String? startDate, String? endDate}) async {
    final db = await _db;
    String whereClause = 'staff_id = ?';
    List<dynamic> whereArgs = [staffId];

    if (startDate != null && endDate != null) {
      whereClause += ' AND date >= ? AND date <= ?';
      whereArgs.addAll([startDate, endDate]);
    }

    final result = await db.query(
      'teacher_attendance',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    return result.map((m) => TeacherAttendance.fromMap(m)).toList();
  }

  Future<void> updateTeacherAttendanceRecord(TeacherAttendance record) async {
    final db = await _db;
    await _updateLogged(db, 
      'teacher_attendance',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  // ============================================================================
  // FEE MANAGEMENT (PHASE 2 - MONTHLY)
  // ============================================================================

  /// Returns a map of month_label -> status for a student (summarizing multiple monthly fee heads)
  Future<Map<String, dynamic>> getMonthlyFeeStatus(String studentId, String academicYear) async {
    final ledger = await getStudentFeeLedger(studentId, academicYear);
    
    final monthlyLedgers = ledger.where((l) => l.frequency == 'monthly').toList();
    final nonMonthlyLedgers = ledger.where((l) => l.frequency != 'monthly').toList();
    
    // Group monthly by monthLabel
    Map<String, List<StudentFeeLedger>> monthGroups = {};
    for (final l in monthlyLedgers) {
      if (l.monthLabel != null) {
        monthGroups.putIfAbsent(l.monthLabel!, () => []).add(l);
      }
    }
    
    Map<String, String> monthStatus = {};
    for (final entry in monthGroups.entries) {
      bool hasOverdue = entry.value.any((l) => l.status == LedgerStatus.overdue);
      bool hasPendingOrPartial = entry.value.any((l) => l.status == LedgerStatus.pending || l.status == LedgerStatus.partial);
      
      if (hasOverdue) {
        monthStatus[entry.key] = 'overdue';
      } else if (hasPendingOrPartial) {
        monthStatus[entry.key] = 'pending';
      } else {
        monthStatus[entry.key] = 'paid';
      }
    }
    
    return {
      'monthly_status': monthStatus,
      'monthly_ledgers': monthGroups,
      'non_monthly': nonMonthlyLedgers,
    };
  }

  /// Returns a students x months grid with status per cell for an entire class.
  /// List of Map with 'student_id', 'student_name', and 'monthly_matrix'
  Future<List<Map<String, dynamic>>> getClassMonthlyCollectionMatrix(String className, String section, String academicYear, {String? feeHeadId}) async {
    final db = await _db;
    
    // Get all active students in class
    final studentsData = await db.rawQuery('''
      SELECT * FROM students 
      WHERE (grade_level = ? OR class_id IN (SELECT id FROM classes WHERE name = ?))
      AND section = ? 
      AND COALESCE(is_active, 1) = 1
    ''', [className, className, section]);
    
    final studentIds = studentsData.map((s) => s['id'] as String).toList();
    if (studentIds.isEmpty) return [];
    
    // Get all monthly ledger rows for these students
    final placeholders = List.filled(studentIds.length, '?').join(',');
    final queryArgs = <Object?>[...studentIds, academicYear];
    
    String query = '''
      SELECT sfl.student_id, sfl.month_label, sfl.status, sfl.amount_due, sfl.amount_paid
      FROM student_fee_ledger sfl
      JOIN fee_heads fh ON sfl.fee_head_id = fh.id
      WHERE sfl.student_id IN ($placeholders) 
      AND sfl.academic_year = ? 
      AND sfl.month_label IS NOT NULL
    ''';

    if (feeHeadId != null) {
      query += ' AND fh.id = ?';
      queryArgs.add(feeHeadId);
    } else {
      query += ' AND fh.frequency = ?';
      queryArgs.add('monthly');
    }

    final ledgerData = await db.rawQuery(query, queryArgs);
    
    // Group by student, then by month
    Map<String, Map<String, List<Map<String, dynamic>>>> rawMatrix = {};
    for (final row in ledgerData) {
      final sId = row['student_id'] as String;
      final mLabel = row['month_label'] as String;
      final status = row['status'] as String;
      final amtDue = (row['amount_due'] as num?)?.toDouble() ?? 0.0;
      final amtPaid = (row['amount_paid'] as num?)?.toDouble() ?? 0.0;
      
      // month_label is like "April 2024" or "April"
      String shortMonth = mLabel.length >= 3 ? mLabel.substring(0, 3) : mLabel;
      
      rawMatrix.putIfAbsent(sId, () => {});
      rawMatrix[sId]!.putIfAbsent(shortMonth, () => []).add({
        'status': status,
        'amount_due': amtDue,
        'amount_paid': amtPaid,
      });
    }
    
    // Summarize status per month per student
    List<Map<String, dynamic>> finalResult = [];
    for (final student in studentsData) {
      final sId = student['id'] as String;
      final firstName = student['first_name'] as String;
      final lastName = student['last_name'] as String;
      final studentName = '$firstName $lastName';
      
      Map<String, dynamic> studentMatrix = {};
      
      if (rawMatrix.containsKey(sId)) {
        for (final monthEntry in rawMatrix[sId]!.entries) {
          bool hasOverdue = false;
          bool hasPendingOrPartial = false;
          double totalDue = 0.0;
          double totalPaid = 0.0;
          
          for (final item in monthEntry.value) {
            final st = item['status'] as String;
            totalDue += item['amount_due'] as double;
            totalPaid += item['amount_paid'] as double;
            
            if (st == 'overdue') hasOverdue = true;
            if (st == 'pending' || st == 'partial') hasPendingOrPartial = true;
          }
          
          String finalStatus = 'paid';
          if (hasOverdue) {
            finalStatus = 'overdue';
          } else if (hasPendingOrPartial) {
            finalStatus = 'pending';
          }
          
          studentMatrix[monthEntry.key] = {
            'status': finalStatus,
            'amount_due': totalDue,
            'amount_paid': totalPaid,
          };
        }
      }
      
      finalResult.add({
        'student_id': sId,
        'student_name': studentName,
        'monthly_matrix': studentMatrix,
      });
    }
    
    return finalResult;
  }

  // ============================================================================
  // INVENTORY MANAGEMENT (PHASE 2)
  // ============================================================================

  Future<List<InventoryCategory>> getInventoryCategories() async {
    final db = await _db;
    final result = await db.query('inventory_categories', orderBy: 'name ASC');
    return result.map((m) => InventoryCategory.fromMap(m)).toList();
  }

  Future<void> createInventoryItem(InventoryItem item) async {
    final db = await _db;
    await _insertLogged(db, 'inventory_items', item.toMap());
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    final db = await _db;
    await _updateLogged(db, 
      'inventory_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<List<InventoryItem>> getInventoryItems({String? categoryId}) async {
    final db = await _db;
    final result = await db.query(
      'inventory_items',
      where: categoryId != null ? 'category_id = ?' : null,
      whereArgs: categoryId != null ? [categoryId] : null,
      orderBy: 'name ASC',
    );
    return result.map((m) => InventoryItem.fromMap(m)).toList();
  }

  Future<List<InventoryItem>> getLowStockItems() async {
    final db = await _db;
    final result = await db.query(
      'inventory_items',
      where: 'current_stock <= reorder_threshold',
      orderBy: 'name ASC',
    );
    return result.map((m) => InventoryItem.fromMap(m)).toList();
  }

  Future<List<StockTransaction>> getItemTransactionHistory(String itemId) async {
    final db = await _db;
    final result = await db.query(
      'stock_transactions',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'transaction_date DESC',
    );
    return result.map((m) => StockTransaction.fromMap(m)).toList();
  }

  Future<Map<String, double>> getStockValuationSummary() async {
    final db = await _db;
    final query = '''
      SELECT c.name as category_name, SUM(i.current_stock * IFNULL(i.unit_cost, 0)) as total_value
      FROM inventory_items i
      JOIN inventory_categories c ON i.category_id = c.id
      WHERE i.current_stock > 0
      GROUP BY c.id
    ''';
    final result = await db.rawQuery(query);
    
    Map<String, double> summary = {};
    for (var row in result) {
      final name = row['category_name'] as String;
      final val = (row['total_value'] as num).toDouble();
      summary[name] = val;
    }
    return summary;
  }

  Future<void> recordStockTransaction(StockTransaction tx) async {
    final db = await _db;
    
    await db.transaction((txn) async {
      // Get current stock
      final itemResult = await txn.query(
        'inventory_items',
        where: 'id = ?',
        whereArgs: [tx.itemId],
      );
      
      if (itemResult.isEmpty) {
        throw Exception('Item not found');
      }
      
      final currentStock = (itemResult.first['current_stock'] as num).toDouble();
      double newStock = currentStock;
      
      // Calculate new stock based on transaction type
      if (tx.transactionType == 'purchase' || tx.transactionType == 'return') {
        newStock += tx.quantity;
      } else if (tx.transactionType == 'issue' || tx.transactionType == 'damage') {
        newStock -= tx.quantity;
        if (newStock < 0) {
          throw Exception('Insufficient stock for this transaction');
        }
      } else if (tx.transactionType == 'adjustment') {
        // Adjustments could be positive or negative, assuming tx.quantity has the sign, or if it's purely negative/positive we need to know.
        // Assuming adjustment quantity has sign. If not, maybe need a separate field, but keeping it simple: just add quantity (which can be -ve).
        newStock += tx.quantity;
        if (newStock < 0) {
          throw Exception('Adjustment would result in negative stock');
        }
      }

      // Insert transaction
      await _insertLogged(txn, 'stock_transactions', tx.toMap());
      
      // Update item stock
      await _updateLogged(txn, 
        'inventory_items',
        {'current_stock': newStock},
        where: 'id = ?',
        whereArgs: [tx.itemId],
      );
    });
  }

  // --- Audit Logging Helpers ---

  Future<void> logAction({
    DatabaseExecutor? executor,
    required String actionType,
    required String module,
    String? entityType,
    String? entityId,
    required String description,
    String? oldValue,
    String? newValue,
  }) async {
    if (currentAdminId == null) return;
    
    final db = executor ?? await rawDb;
    await db.rawInsert(
      'INSERT INTO audit_logs (id, admin_user_id, action_type, module, entity_type, entity_id, description, old_value, new_value, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        const Uuid().v4(),
        currentAdminId,
        actionType,
        module,
        entityType,
        entityId,
        description,
        oldValue,
        newValue,
        DateTime.now().toIso8601String(),
      ]
    );
  }

  Future<int> _insertLogged(DatabaseExecutor executor, String table, Map<String, Object?> values, {ConflictAlgorithm? conflictAlgorithm, String? nullColumnHack}) async {
    final id = await executor.insert(table, values, conflictAlgorithm: conflictAlgorithm, nullColumnHack: nullColumnHack);
    
    String? entityId = values['id']?.toString() ?? id.toString();
    
    await logAction(
      executor: executor,
      actionType: 'create',
      module: table,
      entityType: table,
      entityId: entityId,
      description: 'Created record in $table',
      newValue: jsonEncode(values),
    );
    return id;
  }

  Future<int> _updateLogged(DatabaseExecutor executor, String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) async {
    String? oldValueStr;
    String? entityId;
    try {
      final oldRows = await executor.query(table, where: where, whereArgs: whereArgs);
      if (oldRows.isNotEmpty) {
        oldValueStr = jsonEncode(oldRows.first);
        entityId = oldRows.first['id']?.toString();
      }
    } catch (_) {}

    final count = await executor.update(table, values, where: where, whereArgs: whereArgs, conflictAlgorithm: conflictAlgorithm);
    
    if (count > 0) {
      await logAction(
        executor: executor,
        actionType: 'update',
        module: table,
        entityType: table,
        entityId: entityId ?? whereArgs?.join(','),
        description: 'Updated record in $table',
        oldValue: oldValueStr,
        newValue: jsonEncode(values),
      );
    }
    return count;
  }

  Future<int> _deleteLogged(DatabaseExecutor executor, String table, {String? where, List<Object?>? whereArgs}) async {
    String? oldValueStr;
    String? entityId;
    try {
      final oldRows = await executor.query(table, where: where, whereArgs: whereArgs);
      if (oldRows.isNotEmpty) {
        oldValueStr = jsonEncode(oldRows.first);
        entityId = oldRows.first['id']?.toString();
      }
    } catch (_) {}

    final count = await executor.delete(table, where: where, whereArgs: whereArgs);
    
    if (count > 0) {
      await logAction(
        executor: executor,
        actionType: 'delete',
        module: table,
        entityType: table,
        entityId: entityId ?? whereArgs?.join(','),
        description: 'Deleted record in $table',
        oldValue: oldValueStr,
      );
    }
    return count;
  }

  Future<List<AcademicYear>> getAllAcademicYears() async {
    final db = await _db;
    final results = await db.query('academic_years', orderBy: 'name DESC');
    return results.map((m) => AcademicYear.fromMap(m)).toList();
  }
}
