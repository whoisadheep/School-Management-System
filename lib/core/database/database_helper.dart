import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:uuid/uuid.dart';
import '../../models/user.dart';

/// Desktop-optimized SQLite DatabaseHelper with versioned schema migrations (v3),
/// explicit performance indexes, unique constraints, and overdue automation.
class DatabaseHelper {

  /// Migrate legacy database from 'SchoolManagementSystem' to 'Eduvia' if needed
  Future<void> _migrateLegacyDatabasePath(String appDocPath) async {
    final legacyDir = Directory(p.join(appDocPath, 'SchoolManagementSystem'));
    final legacyDb = File(p.join(legacyDir.path, 'school_management.db'));
    
    final newDir = Directory(p.join(appDocPath, 'Eduvia'));
    final newDb = File(p.join(newDir.path, 'school_management.db'));
    
    if (await legacyDb.exists() && !(await newDb.exists())) {
      print('Legacy database found! Migrating data to new Eduvia directory...');
      if (!(await newDir.exists())) {
        await newDir.create(recursive: true);
      }
      
      
      // Copy database file and WAL files
      await legacyDb.copy(newDb.path);
      
      final legacyWal = File('${legacyDb.path}-wal');
      if (await legacyWal.exists()) {
        await legacyWal.copy('${newDb.path}-wal');
      }
      
      final legacyShm = File('${legacyDb.path}-shm');
      if (await legacyShm.exists()) {
        await legacyShm.copy('${newDb.path}-shm');
      }

      
      // Also attempt to migrate Receipts, Backups, Reports, etc. if they exist
      final legacyFolders = ['Receipts', 'Backups', 'ReportCards', 'Logs', 'Media', 'ID_Cards', 'Certificates'];
      for (final folder in legacyFolders) {
        final oldFolder = Directory(p.join(legacyDir.path, folder));
        if (await oldFolder.exists()) {
          final targetFolder = Directory(p.join(newDir.path, folder));
          if (!(await targetFolder.exists())) {
            await targetFolder.create(recursive: true);
          }
          // We don't recursively copy files in pure Dart easily without a package, but moving the directory works if on same drive
          try {
            await oldFolder.rename(targetFolder.path);
          } catch (e) {
            print('Could not move $folder: $e');
          }
        }
      }
    }
  }

  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  /// Schema version 27 (Admin Users RBAC)
  static const int _databaseVersion = 31;
  static const String _databaseName = 'school_management.db';

  Future<Database> get database async {
    if (_database == null) {
      _database = await _initDatabase();
      try {
        await autoUpdateOverdueInvoices(_database!);
      } catch (_) {}
    }
    return _database!;
  }

  /// Closes active database connection and resets the singleton instance
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: _databaseVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onConfigure: _onConfigure,
        ),
      );
      await ensureSchemaIntegrity(db);
      await autoUpdateOverdueInvoices(db);
      return db;
    }

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    await _migrateLegacyDatabasePath(appDocDir.path);
      final String dbPath = p.join(appDocDir.path, 'Eduvia', _databaseName);

    final dbDir = Directory(p.dirname(dbPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
      ),
    );
    await ensureSchemaIntegrity(db);
    await autoUpdateOverdueInvoices(db);
    return db;
  }

  Future<void> _onConfigure(Database db) async {
    try {
      await db.execute('PRAGMA foreign_keys = ON');
    } catch (_) {}
    if (!kIsWeb) {
      try {
        await db.execute('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA busy_timeout = 5000');
      } catch (_) {}
    }
  }

  /// Automated job: Flips pending/partial invoices to 'overdue' when due_date < current date
  Future<void> autoUpdateOverdueInvoices(Database db) async {
    await db.rawUpdate('''
      UPDATE invoices
      SET status = 'overdue',
          updated_at = datetime('now')
      WHERE due_date < datetime('now')
        AND status IN ('pending', 'partial')
    ''');

    // Also update student_fee_ledger entries past due
    try {
      await db.rawUpdate('''
        UPDATE student_fee_ledger
        SET status = 'overdue',
            updated_at = datetime('now')
        WHERE due_date < datetime('now')
          AND status IN ('pending', 'partial')
          AND amount_paid < amount_due
      ''');
    } catch (_) {
      // Table may not exist yet on first run before migration
    }
  }

  /// Maintenance Utility: Recomputes and repairs current_balance for all active students
  /// eliminating any denormalization balance drift.
  Future<void> recalculateAllStudentBalances() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.execute('''
        UPDATE students
        SET current_balance = (
          COALESCE((
            SELECT SUM(total_amount - discount_amount + penalty_amount)
            FROM invoices
            WHERE student_id = students.id AND status != 'cancelled'
          ), 0.0)
          -
          COALESCE((
            SELECT SUM(t.amount_paid)
            FROM transactions t
            JOIN invoices i ON t.invoice_id = i.id
            WHERE i.student_id = students.id
          ), 0.0)
        ),
        updated_at = datetime('now')
      ''');
    });
  }

  /// Create database schema for fresh installations (v3)
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. Academic Years Table
    batch.execute('''
      CREATE TABLE academic_years (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL UNIQUE,
        start_date  TEXT NOT NULL,
        end_date    TEXT NOT NULL,
        is_current  INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // 2. Students Table (with expanded admission fields)
    batch.execute('''
      CREATE TABLE students (
        id                    TEXT PRIMARY KEY,
        name                  TEXT NOT NULL,
        first_name            TEXT,
        last_name             TEXT,
        dob                   TEXT,
        gender                TEXT,
        blood_group           TEXT,
        photograph_path       TEXT,
        caste                 TEXT,
        religion              TEXT,
        aadhaar_number        TEXT,
        admission_number      TEXT,
        roll_number           TEXT,
        grade_level           TEXT NOT NULL,
        section               TEXT,
        admission_date        TEXT,
        father_name           TEXT,
        father_occupation     TEXT,
        father_phone          TEXT,
        mother_name           TEXT,
        mother_occupation     TEXT,
        mother_phone          TEXT,
        guardian_phone        TEXT,
        residential_address   TEXT,
        permanent_address     TEXT,
        transport_route_id    TEXT,
        hostel_id             TEXT,
        current_balance       REAL NOT NULL DEFAULT 0.0,
        is_active             INTEGER NOT NULL DEFAULT 1,
        is_alumni             INTEGER NOT NULL DEFAULT 0,
        tc_number             TEXT,
        tc_date               TEXT,
        created_at            TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at            TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // 3. Fee Categories Table
    batch.execute('''
      CREATE TABLE fee_categories (
        id              TEXT PRIMARY KEY,
        name            TEXT NOT NULL UNIQUE,
        default_amount  REAL NOT NULL,
        cycle           TEXT NOT NULL CHECK (cycle IN ('monthly', 'yearly')),
        is_active       INTEGER NOT NULL DEFAULT 1,
        created_at      TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // 4. Fee Structures Table (with UNIQUE constraint and updated_at timestamp)
    batch.execute('''
      CREATE TABLE fee_structures (
        id                TEXT PRIMARY KEY,
        fee_category_id   TEXT NOT NULL,
        grade_level       TEXT NOT NULL,
        academic_year_id  TEXT NOT NULL,
        amount            REAL NOT NULL,
        created_at        TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at        TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (fee_category_id) REFERENCES fee_categories (id) ON DELETE CASCADE,
        FOREIGN KEY (academic_year_id) REFERENCES academic_years (id) ON DELETE CASCADE,
        CONSTRAINT unq_fee_structure UNIQUE (fee_category_id, grade_level, academic_year_id)
      )
    ''');

    // 5. Invoices Table
    batch.execute('''
      CREATE TABLE invoices (
        id                TEXT PRIMARY KEY,
        student_id        TEXT NOT NULL,
        academic_year_id  TEXT,
        total_amount      REAL NOT NULL,
        discount_amount   REAL NOT NULL DEFAULT 0.0,
        penalty_amount    REAL NOT NULL DEFAULT 0.0,
        due_date          TEXT NOT NULL,
        status            TEXT NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending', 'paid', 'overdue', 'partial', 'cancelled')),
        notes             TEXT,
        fee_head_id       TEXT,
        ledger_id         TEXT,
        created_at        TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at        TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (academic_year_id) REFERENCES academic_years (id) ON DELETE SET NULL
      )
    ''');

    // 6. Transactions Table (with updated_at timestamp)
    batch.execute('''
      CREATE TABLE transactions (
        id              TEXT PRIMARY KEY,
        invoice_id      TEXT NOT NULL,
        amount_paid     REAL NOT NULL,
        payment_method  TEXT NOT NULL
                        CHECK (payment_method IN ('cash', 'bank_transfer', 'cheque', 'online', 'other')),
        reference_number TEXT,
        timestamp       TEXT NOT NULL DEFAULT (datetime('now')),
        created_at      TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE RESTRICT ON UPDATE CASCADE
      )
    ''');

    // 7. Ledger Entries Table
    batch.execute('''
      CREATE TABLE ledger_entries (
        id              TEXT PRIMARY KEY,
        date            TEXT NOT NULL,
        type            TEXT NOT NULL CHECK (type IN ('income', 'expense')),
        category        TEXT NOT NULL,
        amount          REAL NOT NULL,
        description     TEXT,
        reference_id    TEXT,
        created_at      TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // 8. Users Table (with pin_hash and updated_at)
    batch.execute('''
      CREATE TABLE users (
        id            TEXT PRIMARY KEY,
        username      TEXT NOT NULL UNIQUE,
        full_name     TEXT NOT NULL,
        role          TEXT NOT NULL CHECK (role IN ('admin', 'accountant', 'viewer')),
        pin_hash      TEXT NOT NULL,
        is_active     INTEGER NOT NULL DEFAULT 1,
        created_at    TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // 9. Audit Logs Table
    batch.execute('''
      CREATE TABLE audit_logs (
        id TEXT PRIMARY KEY,
        admin_user_id TEXT,
        action_type TEXT CHECK(action_type IN ('create','update','delete','login','risky_action_blocked')),
        module TEXT,
        entity_type TEXT,
        entity_id TEXT,
        description TEXT,
        old_value TEXT,
        new_value TEXT,
        timestamp TEXT,
        FOREIGN KEY (admin_user_id) REFERENCES admin_users(id) ON DELETE SET NULL
      )
    ''');

    // 10. Departments Table
    batch.execute('''
      CREATE TABLE departments (
        id            TEXT PRIMARY KEY,
        name          TEXT NOT NULL UNIQUE,
        created_at    TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // 11. Staff Table (with extended fields)
    batch.execute('''
      CREATE TABLE staff (
        id                TEXT PRIMARY KEY,
        staff_code        TEXT UNIQUE,
        first_name        TEXT NOT NULL,
        last_name         TEXT NOT NULL,
        dob               TEXT,
        gender            TEXT,
        blood_group       TEXT,
        photograph_path   TEXT,
        role              TEXT NOT NULL CHECK (role IN ('teacher', 'admin', 'support_staff', 'driver')),
        department_id     TEXT,
        designation       TEXT,
        joining_date      TEXT,
        qualification     TEXT,
        experience_years  INTEGER,
        email             TEXT UNIQUE,
        phone             TEXT UNIQUE,
        address           TEXT,
        emergency_contact TEXT,
        basic_salary      REAL,
        bank_account_number TEXT,
        bank_ifsc         TEXT,
        pan_number        TEXT,
        aadhaar_number    TEXT,
        last_working_day  TEXT,
        exit_reason       TEXT,
        updated_by        TEXT,
        is_active         INTEGER NOT NULL DEFAULT 1,
        created_at        TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at        TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (department_id) REFERENCES departments (id) ON DELETE SET NULL
      )
    ''');

    // 12. Staff Subjects Table
    batch.execute('''
      CREATE TABLE staff_subjects (
        id              TEXT PRIMARY KEY,
        staff_id        TEXT NOT NULL,
        subject         TEXT NOT NULL,
        class_assigned  TEXT NOT NULL,
        FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
      )
    ''');

    // 13. Staff Documents Table
    batch.execute('''
      CREATE TABLE staff_documents (
        id              TEXT PRIMARY KEY,
        staff_id        TEXT NOT NULL,
        doc_type        TEXT NOT NULL,
        file_path       TEXT NOT NULL,
        uploaded_at     TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
      )
    ''');

    // 14. Salary Components Table
    batch.execute('''
      CREATE TABLE salary_components (
        id              TEXT PRIMARY KEY,
        staff_id        TEXT NOT NULL,
        component_type  TEXT NOT NULL CHECK (component_type IN ('basic','hra','da','deduction','pf','other')),
        amount          REAL NOT NULL,
        effective_from  TEXT NOT NULL,
        FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
      )
    ''');

    // 11. System Settings Table
    batch.execute('''
      CREATE TABLE app_settings (
        key           TEXT PRIMARY KEY,
        value         TEXT NOT NULL,
        updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Indexes
    batch.execute('CREATE INDEX idx_students_grade       ON students (grade_level)');
    batch.execute('CREATE INDEX idx_students_active      ON students (is_active)');
    batch.execute('CREATE INDEX idx_invoices_student     ON invoices (student_id)');
    batch.execute('CREATE INDEX idx_invoices_status      ON invoices (status)');
    batch.execute('CREATE INDEX idx_invoices_due_date    ON invoices (due_date)');
    batch.execute('CREATE INDEX idx_invoices_year        ON invoices (academic_year_id)');
    batch.execute('CREATE INDEX idx_transactions_invoice ON transactions (invoice_id)');
    batch.execute('CREATE INDEX idx_transactions_ts      ON transactions (timestamp)');
    batch.execute('CREATE INDEX idx_ledger_date          ON ledger_entries (date)');
    batch.execute('CREATE INDEX idx_ledger_type          ON ledger_entries (type)');
    batch.execute('CREATE INDEX idx_ledger_category      ON ledger_entries (category)');

    // Seed default Academic Year & Admin User with SHA-256 PIN hash
    final adminPinHash = User.hashPin('1234');
    batch.execute('''
      INSERT INTO academic_years (id, name, start_date, end_date, is_current)
      VALUES ('ay-2025-2026', '2025-2026', '2025-06-01', '2026-04-30', 1)
    ''');

    batch.execute('''
      INSERT INTO users (id, username, full_name, role, pin_hash)
      VALUES ('usr-admin-001', 'admin', 'System Administrator', 'admin', '$adminPinHash')
    ''');

    // 12. Feature Flags Table
    batch.execute('''
      CREATE TABLE feature_flags (
        id            TEXT PRIMARY KEY,
        flag_key      TEXT UNIQUE NOT NULL,
        is_enabled    INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute("INSERT OR IGNORE INTO feature_flags (id, flag_key, is_enabled) VALUES ('ff-hostel', 'hostel_management', 0)");

    // 13. Hostel Tables
    batch.execute('''
      CREATE TABLE hostel_blocks (
        id                TEXT PRIMARY KEY,
        block_name        TEXT NOT NULL,
        warden_staff_id   TEXT,
        total_rooms       INTEGER NOT NULL,
        is_active         INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (warden_staff_id) REFERENCES staff (id) ON DELETE SET NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE hostel_rooms (
        id                TEXT PRIMARY KEY,
        block_id          TEXT NOT NULL,
        room_number       TEXT NOT NULL,
        floor             INTEGER NOT NULL,
        capacity          INTEGER NOT NULL,
        current_occupancy INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (block_id) REFERENCES hostel_blocks (id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE hostel_allocations (
        id                TEXT PRIMARY KEY,
        student_id        TEXT NOT NULL,
        room_id           TEXT NOT NULL,
        bed_number        INTEGER,
        academic_year     TEXT NOT NULL,
        allocated_date    TEXT NOT NULL,
        vacated_date      TEXT,
        is_active         INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (room_id) REFERENCES hostel_rooms (id) ON DELETE CASCADE
      )
    ''');

    // 14. Hostel Attendance and Outpasses
    batch.execute('''
      CREATE TABLE hostel_attendance (
        id            TEXT PRIMARY KEY,
        student_id    TEXT NOT NULL,
        date          TEXT NOT NULL,
        status        TEXT NOT NULL CHECK (status IN ('present', 'absent')),
        marked_by     TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');
    
    batch.execute('''
      CREATE TABLE outpasses (
        id                    TEXT PRIMARY KEY,
        student_id            TEXT NOT NULL,
        reason                TEXT NOT NULL,
        out_date              TEXT NOT NULL,
        expected_return_date  TEXT NOT NULL,
        actual_return_date    TEXT,
        approved_by           TEXT,
        status                TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected', 'returned')),
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    // 15. Student Attendance Tables
    batch.execute('''
      CREATE TABLE academic_calendar (
        id          TEXT PRIMARY KEY,
        date        TEXT UNIQUE NOT NULL,
        day_type    TEXT NOT NULL CHECK (day_type IN ('working', 'holiday', 'weekend')),
        remarks     TEXT
      )
    ''');
    
    batch.execute('''
      CREATE TABLE student_attendance (
        id          TEXT PRIMARY KEY,
        student_id  TEXT NOT NULL,
        class       TEXT NOT NULL,
        section     TEXT NOT NULL,
        date        TEXT NOT NULL,
        status      TEXT NOT NULL CHECK (status IN ('present', 'absent', 'half_day', 'late', 'excused')),
        marked_by   TEXT NOT NULL,
        marked_at   TEXT NOT NULL,
        remarks     TEXT,
        corrected_by TEXT,
        corrected_at TEXT,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        UNIQUE (student_id, date)
      )
    ''');

    batch.execute('''
      CREATE TABLE attendance_settings (
        id                                TEXT PRIMARY KEY,
        academic_year                     TEXT UNIQUE NOT NULL,
        low_attendance_threshold_percent  REAL NOT NULL DEFAULT 75
      )
    ''');
    // 16. Library Tables
    batch.execute('''
      CREATE TABLE books (
        id               TEXT PRIMARY KEY,
        title            TEXT NOT NULL,
        author           TEXT NOT NULL,
        isbn             TEXT,
        category         TEXT,
        publisher        TEXT,
        total_copies     INTEGER NOT NULL,
        available_copies INTEGER NOT NULL,
        rack_location    TEXT,
        added_at         TEXT NOT NULL
      )
    ''');
    
    batch.execute('''
      CREATE TABLE book_issues (
        id             TEXT PRIMARY KEY,
        book_id        TEXT NOT NULL,
        borrower_type  TEXT NOT NULL CHECK (borrower_type IN ('student', 'staff')),
        borrower_id    TEXT NOT NULL,
        issue_date     TEXT NOT NULL,
        due_date       TEXT NOT NULL,
        return_date    TEXT,
        fine_amount    REAL DEFAULT 0,
        fine_paid      INTEGER DEFAULT 0,
        status         TEXT NOT NULL CHECK (status IN ('issued', 'returned', 'overdue', 'lost')),
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    // Admin Users Table
    batch.execute('''
      CREATE TABLE admin_users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('admin','user')),
        is_active INTEGER NOT NULL DEFAULT 1,
        force_password_change INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        last_login TEXT
      )
    ''');

    await batch.commit(noResult: true);

    // Run all schema migrations to ensure all latest tables and columns are created
    await _onUpgrade(db, 1, version);

    // Run comprehensive schema self-repair and seed initial master data
    await ensureSchemaIntegrity(db);
  }

  /// Versioned Schema Migration Runner (v1 -> v2 -> v3)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TRIGGER IF EXISTS trg_update_balance_after_transaction');
      await db.execute('DROP TRIGGER IF EXISTS trg_update_balance_after_invoice');
    }

    if (oldVersion < 3) {
      // Version 3 Polish Migrations:
      // 1. Add pin_hash to users table
      // 2. Add updated_at to transactions, fee_structures, academic_years, users
      try {
        await db.execute('ALTER TABLE users ADD COLUMN pin_hash TEXT NOT NULL DEFAULT "${User.hashPin('1234')}"');
      } catch (_) {}

      try {
        await db.execute('ALTER TABLE users ADD COLUMN updated_at TEXT NOT NULL DEFAULT (datetime("now"))');
        await db.execute('ALTER TABLE academic_years ADD COLUMN updated_at TEXT NOT NULL DEFAULT (datetime("now"))');
        await db.execute('ALTER TABLE fee_structures ADD COLUMN updated_at TEXT NOT NULL DEFAULT (datetime("now"))');
        await db.execute('ALTER TABLE transactions ADD COLUMN updated_at TEXT NOT NULL DEFAULT (datetime("now"))');
      } catch (_) {}
    }

    if (oldVersion < 4) {
      // Version 4 Migration: Add expanded Student Admission fields
      final columns = [
        'first_name TEXT',
        'last_name TEXT',
        'dob TEXT',
        'gender TEXT',
        'blood_group TEXT',
        'photograph_path TEXT',
        'caste TEXT',
        'religion TEXT',
        'aadhaar_number TEXT',
        'admission_number TEXT',
        'roll_number TEXT',
        'section TEXT',
        'admission_date TEXT',
        'father_name TEXT',
        'father_occupation TEXT',
        'father_phone TEXT',
        'mother_name TEXT',
        'mother_occupation TEXT',
        'mother_phone TEXT',
        'residential_address TEXT',
        'permanent_address TEXT',
        'transport_route_id TEXT',
        'hostel_id TEXT',
      ];
      for (final col in columns) {
        try {
          await db.execute('ALTER TABLE students ADD COLUMN $col');
        } catch (_) {}
      }
    }

    if (oldVersion < 5) {
      // Version 5 Migration: Add staff table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS staff (
            id                TEXT PRIMARY KEY,
            first_name        TEXT NOT NULL,
            last_name         TEXT NOT NULL,
            dob               TEXT,
            gender            TEXT,
            blood_group       TEXT,
            photograph_path   TEXT,
            role              TEXT NOT NULL CHECK (role IN ('teacher', 'admin', 'support_staff', 'driver')),
            department        TEXT,
            designation       TEXT,
            joining_date      TEXT,
            qualification     TEXT,
            experience_years  INTEGER,
            email             TEXT,
            phone             TEXT,
            address           TEXT,
            emergency_contact TEXT,
            basic_salary      REAL,
            is_active         INTEGER NOT NULL DEFAULT 1,
            created_at        TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
      } catch (_) {}
    }

    if (oldVersion < 6) {
      // Version 6 Migration: Add departments, staff extended fields, and related tables
      
      // 1. Create departments table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS departments (
            id            TEXT PRIMARY KEY,
            name          TEXT NOT NULL UNIQUE,
            created_at    TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
      } catch (_) {}

      // 2. Seed default departments
      final defaultDepts = ['Science', 'Commerce', 'Arts', 'Administration', 'Transport'];
      for (final dept in defaultDepts) {
        try {
          final id = 'dept-${DateTime.now().microsecondsSinceEpoch}-${dept.toLowerCase()}';
          await db.execute('INSERT OR IGNORE INTO departments (id, name) VALUES (?, ?)', [id, dept]);
        } catch (_) {}
      }

      // 3. Add new columns to staff
      final staffNewColumns = [
        'staff_code TEXT',
        'department_id TEXT',
        'bank_account_number TEXT',
        'bank_ifsc TEXT',
        'pan_number TEXT',
        'aadhaar_number TEXT',
        'last_working_day TEXT',
        'exit_reason TEXT',
        'updated_by TEXT',
      ];
      
      for (final col in staffNewColumns) {
        try {
          await db.execute('ALTER TABLE staff ADD COLUMN $col');
        } catch (_) {}
      }

      // 4. Migrate old department string to department_id
      try {
        final List<Map<String, dynamic>> existingStaff = await db.query('staff');
        for (final staff in existingStaff) {
          if (staff.containsKey('department') && staff['department'] != null) {
            final deptName = staff['department'] as String;
            if (deptName.isNotEmpty) {
              // Find or create department
              final existingDepts = await db.query('departments', where: 'name = ?', whereArgs: [deptName]);
              String deptId;
              if (existingDepts.isEmpty) {
                deptId = 'dept-${DateTime.now().microsecondsSinceEpoch}';
                await db.insert('departments', {'id': deptId, 'name': deptName});
              } else {
                deptId = existingDepts.first['id'] as String;
              }
              // Update staff
              await db.update('staff', {'department_id': deptId}, where: 'id = ?', whereArgs: [staff['id']]);
            }
          }
        }
      } catch (e) {
        print('Warning: Failed to migrate staff departments: $e');
      }

      // 5. Add unique indexes (since we can't easily add UNIQUE constraints via ALTER TABLE in SQLite)
      try {
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_code ON staff (staff_code)');
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_email ON staff (email)');
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_phone ON staff (phone)');
      } catch (_) {}

      // 6. Create staff_subjects
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS staff_subjects (
            id              TEXT PRIMARY KEY,
            staff_id        TEXT NOT NULL,
            subject         TEXT NOT NULL,
            class_assigned  TEXT NOT NULL,
            FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
          )
        ''');
      } catch (_) {}

      // 7. Create staff_documents
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS staff_documents (
            id              TEXT PRIMARY KEY,
            staff_id        TEXT NOT NULL,
            doc_type        TEXT NOT NULL,
            file_path       TEXT NOT NULL,
            uploaded_at     TEXT NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
          )
        ''');
      } catch (_) {}

      // 8. Create salary_components
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS salary_components (
            id              TEXT PRIMARY KEY,
            staff_id        TEXT NOT NULL,
            component_type  TEXT NOT NULL CHECK (component_type IN ('basic','hra','da','deduction','pf','other')),
            amount          REAL NOT NULL,
            effective_from  TEXT NOT NULL,
            FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
          )
        ''');
      } catch (_) {}
    }

    if (oldVersion < 7) {
      // 0. Ensure departments table and defaults exist
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS departments (
            id            TEXT PRIMARY KEY,
            name          TEXT NOT NULL UNIQUE,
            created_at    TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
        final defaultDepts = ['Science', 'Commerce', 'Arts', 'Administration', 'Transport'];
        for (final dept in defaultDepts) {
          final id = 'dept-${DateTime.now().microsecondsSinceEpoch}-${dept.toLowerCase()}';
          await db.execute('INSERT OR IGNORE INTO departments (id, name) VALUES (?, ?)', [id, dept]);
        }
      } catch (e) {
        print("Failed to ensure departments: $e");
      }

      // 0.5 Ensure indexes exist
      try {
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_code ON staff (staff_code)');
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_email ON staff (email)');
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_phone ON staff (phone)');
      } catch (e) {
        print("Failed to ensure indexes: $e");
      }

      // 1. Create staff_subjects
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS staff_subjects (
            id              TEXT PRIMARY KEY,
            staff_id        TEXT NOT NULL,
            subject         TEXT NOT NULL,
            class_assigned  TEXT NOT NULL,
            FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Failed to create staff_subjects: $e");
      }

      // 2. Create staff_documents
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS staff_documents (
            id              TEXT PRIMARY KEY,
            staff_id        TEXT NOT NULL,
            doc_type        TEXT NOT NULL,
            file_path       TEXT NOT NULL,
            uploaded_at     TEXT NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Failed to create staff_documents: $e");
      }

      // 3. Create salary_components
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS salary_components (
            id              TEXT PRIMARY KEY,
            staff_id        TEXT NOT NULL,
            component_type  TEXT NOT NULL CHECK (component_type IN ('basic','hra','da','deduction','pf','other')),
            amount          REAL NOT NULL,
            effective_from  TEXT NOT NULL,
            FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Failed to create salary_components: $e");
      }
    }

    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE students ADD COLUMN is_alumni INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        print("Failed to add is_alumni: $e");
      }
      try {
        await db.execute('ALTER TABLE students ADD COLUMN tc_number TEXT');
      } catch (e) {
        print("Failed to add tc_number: $e");
      }
      try {
        await db.execute('ALTER TABLE students ADD COLUMN tc_date TEXT');
      } catch (e) {
        print("Failed to add tc_date: $e");
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS student_documents (
            id              TEXT PRIMARY KEY,
            student_id      TEXT NOT NULL,
            title           TEXT NOT NULL,
            document_type   TEXT NOT NULL,
            file_path       TEXT NOT NULL,
            uploaded_at     TEXT NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Failed to create student_documents: $e");
      }
    }

    if (oldVersion < 9) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS class_teacher_assignments (
            id              TEXT PRIMARY KEY,
            staff_id        TEXT NOT NULL,
            class           TEXT NOT NULL,
            section         TEXT NOT NULL,
            academic_year   TEXT NOT NULL,
            FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Failed to create class_teacher_assignments: $e");
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS timetable (
            id              TEXT PRIMARY KEY,
            class           TEXT NOT NULL,
            section         TEXT NOT NULL,
            day_of_week     INTEGER NOT NULL,
            period_number   INTEGER NOT NULL,
            start_time      TEXT NOT NULL,
            end_time        TEXT NOT NULL,
            subject         TEXT NOT NULL,
            staff_id        TEXT NOT NULL,
            FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Failed to create timetable: $e");
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS teacher_attendance (
            id              TEXT PRIMARY KEY,
            staff_id        TEXT NOT NULL,
            date            TEXT NOT NULL,
            check_in        TEXT,
            check_out       TEXT,
            status          TEXT NOT NULL CHECK (status IN ('present','absent','half_day','late')),
            marked_by       TEXT,
            FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE,
            CONSTRAINT unq_teacher_att UNIQUE (staff_id, date)
          )
        ''');
      } catch (e) {
        print("Failed to create teacher_attendance: $e");
      }
    }

    if (oldVersion < 10) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS leave_types (
            id                     TEXT PRIMARY KEY,
            name                   TEXT NOT NULL,
            days_allowed_per_year  INTEGER NOT NULL
          )
        ''');
        // Seed initial leave types
        await db.execute("INSERT OR IGNORE INTO leave_types (id, name, days_allowed_per_year) VALUES ('lt-casual', 'Casual Leave', 12)");
        await db.execute("INSERT OR IGNORE INTO leave_types (id, name, days_allowed_per_year) VALUES ('lt-sick', 'Sick Leave', 10)");
        await db.execute("INSERT OR IGNORE INTO leave_types (id, name, days_allowed_per_year) VALUES ('lt-earned', 'Earned Leave', 15)");
      } catch (e) {
        print("Failed to create leave_types: $e");
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS leave_applications (
            id              TEXT PRIMARY KEY,
            staff_id        TEXT NOT NULL,
            leave_type_id   TEXT NOT NULL,
            start_date      TEXT NOT NULL,
            end_date        TEXT NOT NULL,
            reason          TEXT NOT NULL,
            status          TEXT NOT NULL CHECK (status IN ('pending','approved','rejected')),
            approved_by     TEXT,
            applied_at      TEXT NOT NULL,
            FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE,
            FOREIGN KEY (leave_type_id) REFERENCES leave_types (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Failed to create leave_applications: $e");
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS substitutions (
            id                   TEXT PRIMARY KEY,
            date                 TEXT NOT NULL,
            period_number        INTEGER NOT NULL,
            class                TEXT NOT NULL,
            subject              TEXT NOT NULL,
            original_staff_id    TEXT NOT NULL,
            substitute_staff_id  TEXT NOT NULL,
            created_at           TEXT NOT NULL,
            FOREIGN KEY (original_staff_id) REFERENCES staff (id) ON DELETE CASCADE,
            FOREIGN KEY (substitute_staff_id) REFERENCES staff (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Failed to create substitutions: $e");
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS exam_duty (
            id             TEXT PRIMARY KEY,
            staff_id       TEXT NOT NULL,
            exam_name      TEXT NOT NULL,
            date           TEXT NOT NULL,
            time_slot      TEXT NOT NULL,
            room_or_class  TEXT NOT NULL,
            duty_type      TEXT NOT NULL CHECK (duty_type IN ('invigilation','paper_setting')),
            FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Failed to create exam_duty: $e");
      }
    }

    if (oldVersion < 11) {
      try {
        await db.execute("ALTER TABLE users ADD COLUMN staff_id TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE users ADD COLUMN can_view_finance INTEGER DEFAULT 0");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE users ADD COLUMN can_mark_own_attendance INTEGER DEFAULT 0");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE users ADD COLUMN can_upload_marks INTEGER DEFAULT 0");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE users ADD COLUMN can_view_all_students INTEGER DEFAULT 0");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE users ADD COLUMN can_approve_leave INTEGER DEFAULT 0");
      } catch (_) {}

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS circulars (
            id            TEXT PRIMARY KEY,
            title         TEXT NOT NULL,
            body          TEXT NOT NULL,
            sent_by       TEXT NOT NULL,
            sent_at       TEXT NOT NULL,
            target_type   TEXT NOT NULL CHECK (target_type IN ('all','department','individual')),
            target_id     TEXT
          )
        ''');
      } catch (e) {
        print("Failed to create circulars table: $e");
      }
    }

    if (oldVersion < 12) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS appraisals (
            id                 TEXT PRIMARY KEY,
            staff_id           TEXT NOT NULL,
            review_period      TEXT NOT NULL,
            self_assessment    TEXT NOT NULL,
            principal_remarks  TEXT NOT NULL,
            rating             INTEGER NOT NULL,
            created_at         TEXT NOT NULL,
            FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Failed to create appraisals table: $e");
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS trainings (
            id                TEXT PRIMARY KEY,
            staff_id          TEXT NOT NULL,
            training_name     TEXT NOT NULL,
            provider          TEXT NOT NULL,
            date              TEXT NOT NULL,
            certificate_path  TEXT,
            FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Failed to create trainings table: $e");
      }
    }

    if (oldVersion < 13) {
      // 1. Create classes table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS classes (
            id             TEXT PRIMARY KEY,
            name           TEXT NOT NULL,
            academic_year  TEXT,
            capacity       INTEGER,
            created_at     TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
      } catch (e) {
        print("Failed to create classes table: $e");
      }

      // 2. Create sections table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sections (
            id                TEXT PRIMARY KEY,
            class_id          TEXT NOT NULL,
            name              TEXT NOT NULL,
            capacity          INTEGER,
            class_teacher_id  TEXT,
            FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE,
            FOREIGN KEY (class_teacher_id) REFERENCES staff (id) ON DELETE SET NULL,
            CONSTRAINT unq_class_sec UNIQUE (class_id, name)
          )
        ''');
      } catch (e) {
        print("Failed to create sections table: $e");
      }

      // 3. Add class_id & section_id to students table
      try {
        await db.execute("ALTER TABLE students ADD COLUMN class_id TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE students ADD COLUMN section_id TEXT");
      } catch (_) {}

      // Add class_id & section_id to timetable, class_teacher_assignments, staff_subjects
      try {
        await db.execute("ALTER TABLE timetable ADD COLUMN class_id TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE timetable ADD COLUMN section_id TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE class_teacher_assignments ADD COLUMN class_id TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE class_teacher_assignments ADD COLUMN section_id TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE staff_subjects ADD COLUMN class_id TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE staff_subjects ADD COLUMN section_id TEXT");
      } catch (_) {}

      // 4. Data Migration & Normalization
      try {
        final Set<String> rawClassNames = {};
        final Map<String, Set<String>> classToSections = {};

        final studentRows = await db.query('students', columns: ['grade_level', 'section']);
        for (final r in studentRows) {
          final cName = (r['grade_level'] as String?)?.trim();
          final sName = (r['section'] as String?)?.trim() ?? 'A';
          if (cName != null && cName.isNotEmpty) {
            rawClassNames.add(cName);
            classToSections.putIfAbsent(cName, () => {}).add(sName.isEmpty ? 'A' : sName);
          }
        }

        try {
          final ctaRows = await db.query('class_teacher_assignments', columns: ['class', 'section']);
          for (final r in ctaRows) {
            final cName = (r['class'] as String?)?.trim();
            final sName = (r['section'] as String?)?.trim() ?? 'A';
            if (cName != null && cName.isNotEmpty) {
              rawClassNames.add(cName);
              classToSections.putIfAbsent(cName, () => {}).add(sName.isEmpty ? 'A' : sName);
            }
          }
        } catch (_) {}

        try {
          final ttRows = await db.query('timetable', columns: ['class', 'section']);
          for (final r in ttRows) {
            final cName = (r['class'] as String?)?.trim();
            final sName = (r['section'] as String?)?.trim() ?? 'A';
            if (cName != null && cName.isNotEmpty) {
              rawClassNames.add(cName);
              classToSections.putIfAbsent(cName, () => {}).add(sName.isEmpty ? 'A' : sName);
            }
          }
        } catch (_) {}

        if (rawClassNames.isEmpty) {
          final defaultGrades = ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10'];
          for (final g in defaultGrades) {
            rawClassNames.add(g);
            classToSections[g] = {'A', 'B'};
          }
        }

        final Map<String, String> classNameToId = {};
        final Map<String, String> classSecToSectionId = {};

        for (final cName in rawClassNames) {
          final classId = 'cls-${cName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
          classNameToId[cName] = classId;
          await db.execute(
            "INSERT OR IGNORE INTO classes (id, name, academic_year, capacity, created_at) VALUES (?, ?, '2024-2025', 40, datetime('now'))",
            [classId, cName],
          );

          final secs = classToSections[cName] ?? {'A'};
          for (final secName in secs) {
            final secId = 'sec-${classId.replaceFirst('cls-', '')}-${secName.toLowerCase()}';
            classSecToSectionId['$cName|$secName'] = secId;
            await db.execute(
              "INSERT OR IGNORE INTO sections (id, class_id, name, capacity) VALUES (?, ?, ?, 40)",
              [secId, classId, secName],
            );
          }
        }

        for (final entry in classSecToSectionId.entries) {
          final parts = entry.key.split('|');
          final cName = parts[0];
          final sName = parts[1];
          final secId = entry.value;
          final clsId = classNameToId[cName];

          if (clsId != null) {
            await db.execute(
              "UPDATE students SET class_id = ?, section_id = ? WHERE (grade_level = ? OR grade_level = ?) AND (section = ? OR (section IS NULL AND ? = 'A'))",
              [clsId, secId, cName, cName, sName, sName],
            );
          }
        }

        for (final entry in classSecToSectionId.entries) {
          final parts = entry.key.split('|');
          final cName = parts[0];
          final sName = parts[1];
          final secId = entry.value;
          final clsId = classNameToId[cName];

          if (clsId != null) {
            await db.execute(
              "UPDATE timetable SET class_id = ?, section_id = ? WHERE class = ? AND section = ?",
              [clsId, secId, cName, sName],
            );
            await db.execute(
              "UPDATE class_teacher_assignments SET class_id = ?, section_id = ? WHERE class = ? AND section = ?",
              [clsId, secId, cName, sName],
            );
          }
        }

        for (final cEntry in classNameToId.entries) {
          final cName = cEntry.key;
          final clsId = cEntry.value;
          final secId = classSecToSectionId['$cName|A'];
          await db.execute(
            "UPDATE staff_subjects SET class_id = ?, section_id = ? WHERE class_assigned LIKE ?",
            [clsId, secId, '$cName%'],
          );
        }

        try {
          final ctaList = await db.query('class_teacher_assignments');
          for (final cta in ctaList) {
            final staffId = cta['staff_id'] as String?;
            final secId = cta['section_id'] as String?;
            if (staffId != null && secId != null) {
              await db.execute(
                "UPDATE sections SET class_teacher_id = ? WHERE id = ?",
                [staffId, secId],
              );
            }
          }
        } catch (_) {}
      } catch (e) {
        print("Data migration for Phase 1 failed: $e");
      }
    }

    if (oldVersion < 14) {
      // 1. Fee heads table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS fee_heads (
            id           TEXT PRIMARY KEY,
            name         TEXT NOT NULL UNIQUE,
            description  TEXT,
            is_recurring INTEGER NOT NULL DEFAULT 1,
            frequency    TEXT NOT NULL CHECK (frequency IN ('monthly','quarterly','annual','one_time'))
          )
        ''');

        // Seed common fee heads
        await db.execute('''
          INSERT OR IGNORE INTO fee_heads (id, name, description, is_recurring, frequency) VALUES
          ('fh-tuition', 'Tuition Fee', 'Core monthly academic tuition charges', 1, 'monthly'),
          ('fh-lab', 'Lab Fee', 'Science and computer lab equipment maintenance', 1, 'quarterly'),
          ('fh-exam', 'Exam Fee', 'Term assessment and examination evaluation fee', 1, 'quarterly'),
          ('fh-admission', 'Admission Fee', 'One-time student enrolment & registration fee', 0, 'one_time'),
          ('fh-library', 'Library Fee', 'Annual library resources & digital catalog access', 1, 'annual')
        ''');
      } catch (e) {
        print("Failed to create fee_heads: $e");
      }

      // 2. Extend fee_structures table columns
      try {
        await db.execute("ALTER TABLE fee_structures ADD COLUMN class TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE fee_structures ADD COLUMN section TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE fee_structures ADD COLUMN academic_year TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE fee_structures ADD COLUMN fee_head_id TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE fee_structures ADD COLUMN due_day_of_month INTEGER");
      } catch (_) {}

      try {
        await db.execute("UPDATE fee_structures SET class = grade_level WHERE class IS NULL");
        await db.execute("UPDATE fee_structures SET academic_year = academic_year_id WHERE academic_year IS NULL");
      } catch (_) {}

      // 3. Discount types table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS discount_types (
            id            TEXT PRIMARY KEY,
            name          TEXT NOT NULL,
            discount_kind TEXT NOT NULL CHECK (discount_kind IN ('percentage','flat')),
            value         REAL NOT NULL
          )
        ''');

        // Seed common discount types
        await db.execute('''
          INSERT OR IGNORE INTO discount_types (id, name, discount_kind, value) VALUES
          ('dt-sibling', 'Sibling Discount', 'percentage', 15.0),
          ('dt-staff', 'Staff Ward Discount', 'percentage', 50.0),
          ('dt-merit', 'Merit Scholarship', 'percentage', 25.0),
          ('dt-aid', 'Financial Aid', 'flat', 5000.0)
        ''');
      } catch (e) {
        print("Failed to create discount_types: $e");
      }

      // 4. Student discounts table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS student_discounts (
            id                TEXT PRIMARY KEY,
            student_id        TEXT NOT NULL,
            discount_type_id  TEXT NOT NULL,
            academic_year     TEXT NOT NULL,
            approved_by       TEXT,
            remarks           TEXT,
            FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
            FOREIGN KEY (discount_type_id) REFERENCES discount_types (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Failed to create student_discounts: $e");
      }
    }

    // ===================== VERSION 15 =====================
    if (oldVersion < 15) {
      // 1. Student fee ledger table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS student_fee_ledger (
            id              TEXT PRIMARY KEY,
            student_id      TEXT NOT NULL,
            fee_head_id     TEXT NOT NULL,
            academic_year   TEXT NOT NULL,
            amount_due      REAL NOT NULL,
            amount_paid     REAL NOT NULL DEFAULT 0.0,
            due_date        TEXT NOT NULL,
            status          TEXT NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending', 'partial', 'paid', 'overdue')),
            created_at      TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
            FOREIGN KEY (fee_head_id) REFERENCES fee_heads (id) ON DELETE CASCADE
          )
        ''');

        // Performance indexes
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sfl_student ON student_fee_ledger (student_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sfl_year ON student_fee_ledger (academic_year)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sfl_status ON student_fee_ledger (status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sfl_due ON student_fee_ledger (due_date)');
      } catch (e) {
        print("Failed to create student_fee_ledger: $e");
      }

      // 2. Extend invoices table with fee_head_id for ledger linkage
      try {
        await db.execute("ALTER TABLE invoices ADD COLUMN fee_head_id TEXT");
      } catch (_) {}

      // 3. Extend invoices table with ledger_id for direct linkage
      try {
        await db.execute("ALTER TABLE invoices ADD COLUMN ledger_id TEXT");
      } catch (_) {}

      // 4. Migrate existing invoice data to ledger rows where possible
      try {
        // For each existing non-cancelled invoice, create a ledger entry if one doesn't exist
        final existingInvoices = await db.rawQuery('''
          SELECT i.id, i.student_id, i.academic_year_id, i.total_amount, i.discount_amount,
                 i.penalty_amount, i.due_date, i.status, i.created_at,
                 COALESCE(SUM(t.amount_paid), 0.0) as total_paid
          FROM invoices i
          LEFT JOIN transactions t ON t.invoice_id = i.id
          WHERE i.status != 'cancelled'
          GROUP BY i.id
        ''');

        for (final inv in existingInvoices) {
          final invoiceId = inv['id'] as String;
          final studentId = inv['student_id'] as String;
          final academicYear = (inv['academic_year_id'] as String?) ?? '2024-2025';
          final totalAmount = (inv['total_amount'] as num).toDouble();
          final discountAmount = (inv['discount_amount'] as num?)?.toDouble() ?? 0.0;
          final penaltyAmount = (inv['penalty_amount'] as num?)?.toDouble() ?? 0.0;
          final netAmount = totalAmount - discountAmount + penaltyAmount;
          final totalPaid = (inv['total_paid'] as num).toDouble();
          final dueDate = inv['due_date'] as String;
          final createdAt = inv['created_at'] as String;
          final invStatus = inv['status'] as String;

          // Determine ledger status from invoice status
          String ledgerStatus;
          if (invStatus == 'paid') {
            ledgerStatus = 'paid';
          } else if (invStatus == 'overdue') {
            ledgerStatus = 'overdue';
          } else if (totalPaid > 0) {
            ledgerStatus = 'partial';
          } else {
            ledgerStatus = 'pending';
          }

          // Use a deterministic ID so re-runs don't duplicate
          final ledgerId = 'migrated-$invoiceId';

          await db.execute('''
            INSERT OR IGNORE INTO student_fee_ledger
              (id, student_id, fee_head_id, academic_year, amount_due, amount_paid, due_date, status, created_at, updated_at)
            VALUES (?, ?, 'fh-tuition', ?, ?, ?, ?, ?, ?, datetime('now'))
          ''', [ledgerId, studentId, academicYear, netAmount, totalPaid, dueDate, ledgerStatus, createdAt]);

          // Link invoice to ledger
          await db.execute('''
            UPDATE invoices SET ledger_id = ? WHERE id = ?
          ''', [ledgerId, invoiceId]);
        }
      } catch (e) {
        print("Failed to migrate invoices to ledger: $e");
      }
    }

    // ===================== VERSION 16 =====================
    if (oldVersion < 16) {
      // 1. Vehicles table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS vehicles (
            id                TEXT PRIMARY KEY,
            vehicle_number    TEXT NOT NULL UNIQUE,
            vehicle_type      TEXT NOT NULL DEFAULT 'bus' CHECK (vehicle_type IN ('bus', 'van')),
            capacity          INTEGER NOT NULL,
            driver_staff_id   TEXT,
            conductor_name    TEXT,
            insurance_expiry  TEXT,
            fitness_expiry    TEXT,
            is_active         INTEGER NOT NULL DEFAULT 1,
            FOREIGN KEY (driver_staff_id) REFERENCES staff (id) ON DELETE SET NULL
          )
        ''');
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_vehicle_num ON vehicles (vehicle_number)');
      } catch (e) {
        print("Failed to create vehicles table: $e");
      }

      // 2. Routes table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS routes (
            id           TEXT PRIMARY KEY,
            route_name   TEXT NOT NULL,
            vehicle_id   TEXT,
            start_point  TEXT NOT NULL,
            end_point    TEXT NOT NULL,
            FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE SET NULL
          )
        ''');
      } catch (e) {
        print("Failed to create routes table: $e");
      }

      // 3. Route stops table
      try {
        await db.execute('''
           CREATE TABLE IF NOT EXISTS route_stops (
            id           TEXT PRIMARY KEY,
            route_id     TEXT NOT NULL,
            stop_name    TEXT NOT NULL,
            stop_order   INTEGER NOT NULL,
            fee          REAL NOT NULL DEFAULT 0,
            FOREIGN KEY (route_id) REFERENCES routes (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_route_stop_order ON route_stops (route_id, stop_order)');
      } catch (e) {
        print("Failed to create route_stops table: $e");
      }

      // 4. Student transport table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS student_transport (
            id             TEXT PRIMARY KEY,
            student_id     TEXT NOT NULL,
            route_id       TEXT NOT NULL,
            stop_id        TEXT NOT NULL,
            monthly_fee    REAL NOT NULL,
            academic_year  TEXT NOT NULL,
            is_active      INTEGER NOT NULL DEFAULT 1,
            FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
            FOREIGN KEY (route_id) REFERENCES routes (id) ON DELETE CASCADE,
            FOREIGN KEY (stop_id) REFERENCES route_stops (id) ON DELETE CASCADE,
            CONSTRAINT unq_student_transport UNIQUE (student_id, academic_year)
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_st_student ON student_transport (student_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_st_route ON student_transport (route_id)');
      } catch (e) {
        print("Failed to create student_transport table: $e");
      }
    }

    // ===================== VERSION 17 =====================
    if (oldVersion < 17) {
      // 1. Exam types table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS exam_types (
            id                TEXT PRIMARY KEY,
            name              TEXT NOT NULL UNIQUE,
            weightage_percent REAL NOT NULL
          )
        ''');

        // Seed default exam types
        await db.execute('''
          INSERT OR IGNORE INTO exam_types (id, name, weightage_percent) VALUES
          ('et-unit-1', 'Unit Test 1', 10.0),
          ('et-unit-2', 'Unit Test 2', 10.0),
          ('et-midterm', 'Mid-Term Exam', 30.0),
          ('et-final', 'Final Exam', 50.0)
        ''');
      } catch (e) {
        print("Failed to create exam_types table: $e");
      }

      // 2. Exams table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS exams (
            id             TEXT PRIMARY KEY,
            exam_type_id   TEXT NOT NULL,
            name           TEXT NOT NULL,
            class          TEXT NOT NULL,
            section        TEXT,
            academic_year  TEXT NOT NULL,
            start_date     TEXT NOT NULL,
            end_date       TEXT NOT NULL,
            FOREIGN KEY (exam_type_id) REFERENCES exam_types (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_exam_class_year ON exams (class, academic_year)');
      } catch (e) {
        print("Failed to create exams table: $e");
      }

      // 3. Exam subjects table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS exam_subjects (
            id             TEXT PRIMARY KEY,
            exam_id        TEXT NOT NULL,
            subject        TEXT NOT NULL,
            exam_date      TEXT NOT NULL,
            max_marks      REAL NOT NULL,
            passing_marks  REAL NOT NULL,
            staff_id       TEXT,
            FOREIGN KEY (exam_id) REFERENCES exams (id) ON DELETE CASCADE,
            FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE SET NULL
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_exam_sub_exam ON exam_subjects (exam_id)');
      } catch (e) {
        print("Failed to create exam_subjects table: $e");
      }

      // 4. Marks table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS marks (
            id               TEXT PRIMARY KEY,
            exam_subject_id  TEXT NOT NULL,
            student_id       TEXT NOT NULL,
            marks_obtained   REAL,
            is_absent        INTEGER NOT NULL DEFAULT 0,
            remarks          TEXT,
            entered_by       TEXT,
            entered_at       TEXT NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (exam_subject_id) REFERENCES exam_subjects (id) ON DELETE CASCADE,
            FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
            CONSTRAINT unq_exam_subj_student UNIQUE (exam_subject_id, student_id)
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_marks_student ON marks (student_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_marks_subject ON marks (exam_subject_id)');
      } catch (e) {
        print("Failed to create marks table: $e");
      }
    }

    // ===================== VERSION 18 =====================
    if (oldVersion < 18) {
      // 1. Grade scale table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS grade_scale (
            id             TEXT PRIMARY KEY,
            academic_year  TEXT NOT NULL,
            min_percent    REAL NOT NULL,
            max_percent    REAL NOT NULL,
            grade          TEXT NOT NULL,
            grade_point    REAL
          )
        ''');

        // Seed default grade scale thresholds for 2024-2025
        await db.execute('''
          INSERT OR IGNORE INTO grade_scale (id, academic_year, min_percent, max_percent, grade, grade_point) VALUES
          ('gs-a-plus', '2024-2025', 90.0, 100.0, 'A+', 4.0),
          ('gs-a', '2024-2025', 80.0, 89.99, 'A', 3.5),
          ('gs-b', '2024-2025', 70.0, 79.99, 'B', 3.0),
          ('gs-c', '2024-2025', 60.0, 69.99, 'C', 2.5),
          ('gs-d', '2024-2025', 50.0, 59.99, 'D', 2.0),
          ('gs-e', '2024-2025', 35.0, 49.99, 'E', 1.0),
          ('gs-f', '2024-2025', 0.0, 34.99, 'F', 0.0)
        ''');
      } catch (e) {
        print("Failed to create grade_scale table: $e");
      }
    }

    // ===================== VERSION 19 =====================
    if (oldVersion < 19) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS feature_flags (
            id            TEXT PRIMARY KEY,
            flag_key      TEXT UNIQUE NOT NULL,
            is_enabled    INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute("INSERT OR IGNORE INTO feature_flags (id, flag_key, is_enabled) VALUES ('ff-hostel', 'hostel_management', 0)");
      } catch (e) {
        print("Failed to create feature_flags table: $e");
      }
    }

    // ===================== VERSION 20 =====================
    if (oldVersion < 20) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS hostel_blocks (
            id                TEXT PRIMARY KEY,
            block_name        TEXT NOT NULL,
            warden_staff_id   TEXT,
            total_rooms       INTEGER NOT NULL,
            is_active         INTEGER NOT NULL DEFAULT 1,
            FOREIGN KEY (warden_staff_id) REFERENCES staff (id) ON DELETE SET NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS hostel_rooms (
            id                TEXT PRIMARY KEY,
            block_id          TEXT NOT NULL,
            room_number       TEXT NOT NULL,
            floor             INTEGER NOT NULL,
            capacity          INTEGER NOT NULL,
            current_occupancy INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (block_id) REFERENCES hostel_blocks (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS hostel_allocations (
            id                TEXT PRIMARY KEY,
            student_id        TEXT NOT NULL,
            room_id           TEXT NOT NULL,
            bed_number        INTEGER,
            academic_year     TEXT NOT NULL,
            allocated_date    TEXT NOT NULL,
            vacated_date      TEXT,
            is_active         INTEGER NOT NULL DEFAULT 1,
            FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
            FOREIGN KEY (room_id) REFERENCES hostel_rooms (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Failed to create hostel tables: $e");
      }
    }

    // ===================== VERSION 21 =====================
    if (oldVersion < 21) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS hostel_attendance (
            id            TEXT PRIMARY KEY,
            student_id    TEXT NOT NULL,
            date          TEXT NOT NULL,
            status        TEXT NOT NULL CHECK (status IN ('present', 'absent')),
            marked_by     TEXT NOT NULL,
            FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS outpasses (
            id                    TEXT PRIMARY KEY,
            student_id            TEXT NOT NULL,
            reason                TEXT NOT NULL,
            out_date              TEXT NOT NULL,
            expected_return_date  TEXT NOT NULL,
            actual_return_date    TEXT,
            approved_by           TEXT,
            status                TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected', 'returned')),
            FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Failed to create hostel attendance/outpass tables: $e");
      }
    }

    // ===================== VERSION 22 =====================
    if (oldVersion < 22) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS academic_calendar (
            id          TEXT PRIMARY KEY,
            date        TEXT UNIQUE NOT NULL,
            day_type    TEXT NOT NULL CHECK (day_type IN ('working', 'holiday', 'weekend')),
            remarks     TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS student_attendance (
            id          TEXT PRIMARY KEY,
            student_id  TEXT NOT NULL,
            class       TEXT NOT NULL,
            section     TEXT NOT NULL,
            date        TEXT NOT NULL,
            status      TEXT NOT NULL CHECK (status IN ('present', 'absent', 'half_day', 'late', 'excused')),
            marked_by   TEXT NOT NULL,
            marked_at   TEXT NOT NULL,
            remarks     TEXT,
            FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
            UNIQUE (student_id, date)
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS attendance_settings (
            id                                TEXT PRIMARY KEY,
            academic_year                     TEXT UNIQUE NOT NULL,
            low_attendance_threshold_percent  REAL NOT NULL DEFAULT 75
          )
        ''');
      } catch (e) {
        print("Failed to create student attendance tables: $e");
      }
    }

    // ===================== VERSION 23 =====================
    if (oldVersion < 23) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS books (
            id               TEXT PRIMARY KEY,
            title            TEXT NOT NULL,
            author           TEXT NOT NULL,
            isbn             TEXT,
            category         TEXT,
            publisher        TEXT,
            total_copies     INTEGER NOT NULL,
            available_copies INTEGER NOT NULL,
            rack_location    TEXT,
            added_at         TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS book_issues (
            id             TEXT PRIMARY KEY,
            book_id        TEXT NOT NULL,
            borrower_type  TEXT NOT NULL CHECK (borrower_type IN ('student', 'staff')),
            borrower_id    TEXT NOT NULL,
            issue_date     TEXT NOT NULL,
            due_date       TEXT NOT NULL,
            return_date    TEXT,
            fine_amount    REAL DEFAULT 0,
            fine_paid      INTEGER DEFAULT 0,
            status         TEXT NOT NULL CHECK (status IN ('issued', 'returned', 'overdue', 'lost')),
            FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Failed to create library tables: $e");
      }
    }

    // ===================== VERSION 24 =====================
    if (oldVersion < 24) {
      try {
        await db.execute('ALTER TABLE student_attendance ADD COLUMN corrected_by TEXT;');
        await db.execute('ALTER TABLE student_attendance ADD COLUMN corrected_at TEXT;');
        await db.execute('ALTER TABLE teacher_attendance ADD COLUMN corrected_by TEXT;');
        await db.execute('ALTER TABLE teacher_attendance ADD COLUMN corrected_at TEXT;');
      } catch (e) {
        print("Failed to add correction columns to attendance tables: $e");
      }
    }

    // ===================== VERSION 25 =====================
    if (oldVersion < 25) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS inventory_categories (
            id      TEXT PRIMARY KEY,
            name    TEXT UNIQUE NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS inventory_items (
            id                  TEXT PRIMARY KEY,
            name                TEXT NOT NULL,
            category_id         TEXT NOT NULL,
            unit                TEXT NOT NULL CHECK (unit IN ('piece', 'box', 'kg', 'litre', 'set')),
            current_stock       REAL NOT NULL DEFAULT 0,
            reorder_threshold   REAL NOT NULL DEFAULT 0,
            unit_cost           REAL,
            storage_location    TEXT,
            FOREIGN KEY (category_id) REFERENCES inventory_categories (id) ON DELETE RESTRICT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS stock_transactions (
            id                  TEXT PRIMARY KEY,
            item_id             TEXT NOT NULL,
            transaction_type    TEXT NOT NULL CHECK (transaction_type IN ('purchase', 'issue', 'return', 'adjustment', 'damage')),
            quantity            REAL NOT NULL,
            issued_to_type      TEXT CHECK (issued_to_type IN ('staff', 'class', 'department')),
            issued_to_id        TEXT,
            transaction_date    TEXT NOT NULL,
            remarks             TEXT,
            recorded_by         TEXT NOT NULL,
            FOREIGN KEY (item_id) REFERENCES inventory_items (id) ON DELETE CASCADE
          )
        ''');

        // Seed inventory categories
        final categories = [
          'Stationery',
          'Sports Equipment',
          'Lab Equipment',
          'Furniture',
          'Electronics',
          'Cleaning Supplies'
        ];
        
        for (var i = 0; i < categories.length; i++) {
          await db.insert('inventory_categories', {
            'id': 'cat-${i + 1}',
            'name': categories[i],
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      } catch (e) {
        print("Failed to create inventory tables: $e");
      }
    }

    // ===================== VERSION 26 =====================
    if (oldVersion < 26) {
      try {
        await db.execute('ALTER TABLE student_fee_ledger ADD COLUMN month_label TEXT;');
        
        // Migrate existing lump-sum monthly fee ledger rows into 12 separate rows
        final rowsToMigrate = await db.rawQuery('''
          SELECT sfl.*, fh.frequency 
          FROM student_fee_ledger sfl
          JOIN fee_heads fh ON sfl.fee_head_id = fh.id
          WHERE fh.frequency = 'monthly' AND sfl.month_label IS NULL
        ''');

        for (final row in rowsToMigrate) {
          final id = row['id'] as String;
          final studentId = row['student_id'] as String;
          final feeHeadId = row['fee_head_id'] as String;
          final academicYear = row['academic_year'] as String;
          final amountDue = (row['amount_due'] as num).toDouble();
          final amountPaid = (row['amount_paid'] as num).toDouble();
          final createdAt = row['created_at'] as String;
          final updatedAt = row['updated_at'] as String;

          final monthNames = [
            'April', 'May', 'June', 'July', 'August', 'September', 
            'October', 'November', 'December', 'January', 'February', 'March'
          ];
          
          final yearParts = academicYear.split('-');
          final startYear = int.tryParse(yearParts[0]) ?? DateTime.now().year;

          final monthlyDue = amountDue / 12;
          double remainingPaid = amountPaid;

          // Delete the original row
          await db.delete('student_fee_ledger', where: 'id = ?', whereArgs: [id]);

          // Create 12 new rows
          for (int i = 0; i < 12; i++) {
            final monthIndex = (i + 3) % 12 + 1; // 4 to 12, then 1 to 3
            final currentYear = i < 9 ? startYear : startYear + 1;
            
            final dueDate = DateTime(currentYear, monthIndex, 10).toIso8601String();
            final monthLabel = '${monthNames[i]} $currentYear';

            double currentMonthPaid = 0;
            if (remainingPaid >= monthlyDue) {
              currentMonthPaid = monthlyDue;
              remainingPaid -= monthlyDue;
            } else if (remainingPaid > 0) {
              currentMonthPaid = remainingPaid;
              remainingPaid = 0;
            }

            String status = 'pending';
            if (currentMonthPaid >= monthlyDue) {
              status = 'paid';
            } else if (currentMonthPaid > 0) {
              status = 'partial';
            } else if (DateTime.parse(dueDate).isBefore(DateTime.now())) {
              status = 'overdue';
            }

            final newId = '${id}_$i'; // use a derived ID or generate a new UUID if preferred

            await db.insert('student_fee_ledger', {
              'id': newId,
              'student_id': studentId,
              'fee_head_id': feeHeadId,
              'academic_year': academicYear,
              'amount_due': monthlyDue,
              'amount_paid': currentMonthPaid,
              'due_date': dueDate,
              'status': status,
              'month_label': monthLabel,
              'created_at': createdAt,
              'updated_at': updatedAt,
            });
          }
        }
      } catch (e) {
        print("Failed to run version 26 fee ledger migration: $e");
      }
    }

    if (oldVersion < 27) {
      try {
        await db.execute('''
          CREATE TABLE admin_users (
            id TEXT PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            full_name TEXT NOT NULL,
            role TEXT NOT NULL CHECK (role IN ('admin','user')),
            is_active INTEGER NOT NULL DEFAULT 1,
            force_password_change INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            last_login TEXT
          )
        ''');

        final results = await db.rawQuery('SELECT COUNT(*) as count FROM admin_users');
        final count = results.first['count'] as int;
        if (count == 0) {
          final adminExists = await db.rawQuery('SELECT id FROM admin_users WHERE username = ?', ['admin']);
          if (adminExists.isEmpty) {
            final initialPassword = BCrypt.hashpw('ChangeMe@2026', BCrypt.gensalt());
            await db.insert('admin_users', {
              'id': const Uuid().v4(),
              'username': 'admin',
              'password_hash': initialPassword,
              'full_name': 'System Administrator',
              'role': 'admin',
              'force_password_change': 1,
            });
          }
        }
      } catch (e) {
        print("Failed to run version 27 migration: $e");
      }
    }

    if (oldVersion < 28) {
      try {
        await db.execute('DROP TABLE IF EXISTS audit_logs');
        await db.execute('''
          CREATE TABLE audit_logs (
            id TEXT PRIMARY KEY,
            admin_user_id TEXT,
            action_type TEXT CHECK(action_type IN ('create','update','delete','login','risky_action_blocked')),
            module TEXT,
            entity_type TEXT,
            entity_id TEXT,
            description TEXT,
            old_value TEXT,
            new_value TEXT,
            timestamp TEXT,
            FOREIGN KEY (admin_user_id) REFERENCES admin_users(id) ON DELETE SET NULL
          )
        ''');
      } catch (e) {
        print("Failed to run version 28 migration: $e");
      }
    }

    if (oldVersion < 29) {
      try {
        await db.execute('PRAGMA foreign_keys=OFF;');
        
        // We might fail if admin_users doesn't exist, but it should exist from v28
        await db.execute('ALTER TABLE admin_users RENAME TO admin_users_old;');
        
        await db.execute('''
          CREATE TABLE admin_users (
            id TEXT PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            full_name TEXT NOT NULL,
            role TEXT NOT NULL CHECK (role IN ('admin','user')),
            is_active INTEGER NOT NULL DEFAULT 1,
            force_password_change INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            last_login TEXT
          )
        ''');

        await db.execute('''
          INSERT INTO admin_users (id, username, password_hash, full_name, role, is_active, force_password_change, created_at, last_login)
          SELECT id, username, password_hash, full_name, 
                 CASE WHEN role = 'principal' THEN 'admin' ELSE role END, 
                 is_active, 1, created_at, last_login 
          FROM admin_users_old
        ''');

        await db.execute('DROP TABLE admin_users_old;');
        await db.execute('PRAGMA foreign_keys=ON;');
      } catch (e) {
        print("Failed to run version 29 migration: $e");
      }
    }

    if (oldVersion < 30) {
      try {
        await db.execute('ALTER TABLE admin_users ADD COLUMN security_question TEXT');
        await db.execute('ALTER TABLE admin_users ADD COLUMN security_answer_hash TEXT');
      } catch (e) {
        print("Failed to run version 30 migration: $e");
      }
    }

    if (oldVersion < 31) {
      // v31: Add fee column to route_stops for per-stop transport pricing & remove class-wide transport fee structures
      try {
        await db.execute('ALTER TABLE route_stops ADD COLUMN fee REAL NOT NULL DEFAULT 0');
      } catch (e) {
        print("Failed to run version 31 migration: $e");
      }
      try {
        await db.execute("DELETE FROM fee_structures WHERE fee_head_id = 'fh-transport' OR fee_category_id = 'fh-transport'");
      } catch (e) {
        print("Failed to clean up transport fee_structures: $e");
      }
    }
  }

  /// Self-Healing Schema Verifier & Master Data Bootstrapper
  /// Runs on EVERY database open to guarantee all tables, columns, and seed rows exist.
  Future<void> ensureSchemaIntegrity(Database db) async {
    try {
      // 0. Essential Core Tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS academic_years (
          id          TEXT PRIMARY KEY,
          name        TEXT NOT NULL UNIQUE,
          start_date  TEXT NOT NULL,
          end_date    TEXT NOT NULL,
          is_current  INTEGER NOT NULL DEFAULT 0,
          created_at  TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_logs (
          id TEXT PRIMARY KEY,
          admin_user_id TEXT,
          action_type TEXT,
          module TEXT,
          entity_type TEXT,
          entity_id TEXT,
          description TEXT,
          old_value TEXT,
          new_value TEXT,
          timestamp TEXT
        )
      ''');

      // 1. Classes & Sections
      await db.execute('''
        CREATE TABLE IF NOT EXISTS classes (
          id             TEXT PRIMARY KEY,
          name           TEXT NOT NULL,
          academic_year  TEXT,
          capacity       INTEGER,
          created_at     TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sections (
          id                TEXT PRIMARY KEY,
          class_id          TEXT NOT NULL,
          name              TEXT NOT NULL,
          capacity          INTEGER,
          class_teacher_id  TEXT,
          FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE,
          FOREIGN KEY (class_teacher_id) REFERENCES staff (id) ON DELETE SET NULL,
          CONSTRAINT unq_class_sec UNIQUE (class_id, name)
        )
      ''');

      // Ensure invoices table has newer columns
      try {
        await db.execute("ALTER TABLE invoices ADD COLUMN fee_head_id TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE invoices ADD COLUMN ledger_id TEXT");
      } catch (_) {}

      // Ensure 2024-2025 academic year exists for foreign keys
      await db.execute(
        "INSERT OR IGNORE INTO academic_years (id, name, start_date, end_date, is_current) VALUES ('ay-2024-2025', '2024-2025', '2024-06-01', '2025-04-30', 0)"
      );

      // Seed default classes if none exist
      final classCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM classes');
      final classCount = (classCountRes.first['count'] as int?) ?? 0;
      if (classCount == 0) {
        final defaultGrades = [
          'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5',
          'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10'
        ];
        for (final g in defaultGrades) {
          final cid = 'cls-${g.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
          await db.execute(
            "INSERT OR IGNORE INTO classes (id, name, academic_year, capacity, created_at) VALUES (?, ?, '2024-2025', 40, datetime('now'))",
            [cid, g],
          );
          for (final sec in ['A', 'B']) {
            final secId = 'sec-${cid.replaceFirst('cls-', '')}-${sec.toLowerCase()}';
            await db.execute(
              "INSERT OR IGNORE INTO sections (id, class_id, name, capacity) VALUES (?, ?, ?, 40)",
              [secId, cid, sec],
            );
          }
        }
      }

      // Ensure student columns exist
      final studentCols = [
        'class_id TEXT',
        'section_id TEXT',
        'first_name TEXT',
        'last_name TEXT',
        'dob TEXT',
        'gender TEXT',
        'blood_group TEXT',
        'photograph_path TEXT',
        'caste TEXT',
        'religion TEXT',
        'aadhaar_number TEXT',
        'admission_number TEXT',
        'roll_number TEXT',
        'section TEXT',
        'admission_date TEXT',
        'father_name TEXT',
        'father_occupation TEXT',
        'father_phone TEXT',
        'mother_name TEXT',
        'mother_occupation TEXT',
        'mother_phone TEXT',
        'guardian_phone TEXT',
        'residential_address TEXT',
        'permanent_address TEXT',
        'transport_route_id TEXT',
        'hostel_id TEXT',
        'is_alumni INTEGER NOT NULL DEFAULT 0',
        'tc_number TEXT',
        'tc_date TEXT'
      ];
      for (final col in studentCols) {
        try {
          await db.execute('ALTER TABLE students ADD COLUMN $col');
        } catch (_) {}
      }

      // 2. Fee Heads, Fee Structures & Ledger
      await db.execute('''
        CREATE TABLE IF NOT EXISTS fee_heads (
          id           TEXT PRIMARY KEY,
          name         TEXT NOT NULL UNIQUE,
          description  TEXT,
          is_recurring INTEGER NOT NULL DEFAULT 1,
          frequency    TEXT NOT NULL CHECK (frequency IN ('monthly','quarterly','annual','one_time'))
        )
      ''');

      await db.execute('''
        INSERT OR IGNORE INTO fee_heads (id, name, description, is_recurring, frequency) VALUES
        ('fh-tuition', 'Tuition Fee', 'Core monthly academic tuition charges', 1, 'monthly'),
        ('fh-lab', 'Lab Fee', 'Science and computer lab equipment maintenance', 1, 'quarterly'),
        ('fh-exam', 'Exam Fee', 'Term assessment and examination evaluation fee', 1, 'quarterly'),
        ('fh-admission', 'Admission Fee', 'One-time student enrolment & registration fee', 0, 'one_time'),
        ('fh-library', 'Library Fee', 'Annual library resources & digital catalog access', 1, 'annual')
      ''');

      final feeStructureCols = [
        'class TEXT',
        'section TEXT',
        'academic_year TEXT',
        'fee_head_id TEXT',
        'due_day_of_month INTEGER'
      ];
      for (final col in feeStructureCols) {
        try {
          await db.execute('ALTER TABLE fee_structures ADD COLUMN $col');
        } catch (_) {}
      }

      try {
        await db.execute("UPDATE fee_structures SET class = grade_level WHERE class IS NULL");
        await db.execute("UPDATE fee_structures SET academic_year = academic_year_id WHERE academic_year IS NULL");
      } catch (_) {}

      await db.execute('''
        CREATE TABLE IF NOT EXISTS discount_types (
          id            TEXT PRIMARY KEY,
          name          TEXT NOT NULL,
          discount_kind TEXT NOT NULL CHECK (discount_kind IN ('percentage','flat')),
          value         REAL NOT NULL
        )
      ''');

      await db.execute('''
        INSERT OR IGNORE INTO discount_types (id, name, discount_kind, value) VALUES
        ('dt-sibling', 'Sibling Discount', 'percentage', 15.0),
        ('dt-staff', 'Staff Ward Discount', 'percentage', 50.0),
        ('dt-merit', 'Merit Scholarship', 'percentage', 25.0),
        ('dt-aid', 'Financial Aid', 'flat', 5000.0)
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS student_discounts (
          id                TEXT PRIMARY KEY,
          student_id        TEXT NOT NULL,
          discount_type_id  TEXT NOT NULL,
          academic_year     TEXT NOT NULL,
          approved_by       TEXT,
          remarks           TEXT,
          FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
          FOREIGN KEY (discount_type_id) REFERENCES discount_types (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS student_fee_ledger (
          id              TEXT PRIMARY KEY,
          student_id      TEXT NOT NULL,
          fee_head_id     TEXT NOT NULL,
          academic_year   TEXT NOT NULL,
          amount_due      REAL NOT NULL,
          amount_paid     REAL NOT NULL DEFAULT 0.0,
          due_date        TEXT NOT NULL,
          status          TEXT NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending', 'partial', 'paid', 'overdue')),
          month_label     TEXT,
          created_at      TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
          FOREIGN KEY (fee_head_id) REFERENCES fee_heads (id) ON DELETE CASCADE
        )
      ''');

      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sfl_student ON student_fee_ledger (student_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sfl_year ON student_fee_ledger (academic_year)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sfl_status ON student_fee_ledger (status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sfl_due ON student_fee_ledger (due_date)');
      } catch (_) {}

      // 3. Vehicles & Transport
      await db.execute('''
        CREATE TABLE IF NOT EXISTS vehicles (
          id                TEXT PRIMARY KEY,
          vehicle_number    TEXT NOT NULL UNIQUE,
          vehicle_type      TEXT NOT NULL DEFAULT 'bus' CHECK (vehicle_type IN ('bus', 'van')),
          capacity          INTEGER NOT NULL,
          driver_staff_id   TEXT,
          conductor_name    TEXT,
          insurance_expiry  TEXT,
          fitness_expiry    TEXT,
          is_active         INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (driver_staff_id) REFERENCES staff (id) ON DELETE SET NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS routes (
          id           TEXT PRIMARY KEY,
          route_name   TEXT NOT NULL,
          vehicle_id   TEXT,
          start_point  TEXT NOT NULL,
          end_point    TEXT NOT NULL,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE SET NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS route_stops (
          id           TEXT PRIMARY KEY,
          route_id     TEXT NOT NULL,
          stop_name    TEXT NOT NULL,
          stop_order   INTEGER NOT NULL,
          fee          REAL NOT NULL DEFAULT 0,
          FOREIGN KEY (route_id) REFERENCES routes (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS student_transport (
          id             TEXT PRIMARY KEY,
          student_id     TEXT NOT NULL,
          route_id       TEXT NOT NULL,
          stop_id        TEXT NOT NULL,
          monthly_fee    REAL NOT NULL,
          academic_year  TEXT NOT NULL,
          is_active      INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
          FOREIGN KEY (route_id) REFERENCES routes (id) ON DELETE CASCADE,
          FOREIGN KEY (stop_id) REFERENCES route_stops (id) ON DELETE CASCADE,
          CONSTRAINT unq_student_transport UNIQUE (student_id, academic_year)
        )
      ''');

      // 4. Exams & Assessment
      await db.execute('''
        CREATE TABLE IF NOT EXISTS exam_types (
          id                TEXT PRIMARY KEY,
          name              TEXT NOT NULL UNIQUE,
          weightage_percent REAL NOT NULL
        )
      ''');

      await db.execute('''
        INSERT OR IGNORE INTO exam_types (id, name, weightage_percent) VALUES
        ('et-unit-1', 'Unit Test 1', 10.0),
        ('et-unit-2', 'Unit Test 2', 10.0),
        ('et-midterm', 'Mid-Term Exam', 30.0),
        ('et-final', 'Final Exam', 50.0)
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS exams (
          id             TEXT PRIMARY KEY,
          exam_type_id   TEXT NOT NULL,
          name           TEXT NOT NULL,
          class          TEXT NOT NULL,
          section        TEXT,
          academic_year  TEXT NOT NULL,
          start_date     TEXT NOT NULL,
          end_date       TEXT NOT NULL,
          FOREIGN KEY (exam_type_id) REFERENCES exam_types (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS exam_subjects (
          id             TEXT PRIMARY KEY,
          exam_id        TEXT NOT NULL,
          subject        TEXT NOT NULL,
          exam_date      TEXT NOT NULL,
          max_marks      REAL NOT NULL,
          passing_marks  REAL NOT NULL,
          staff_id       TEXT,
          FOREIGN KEY (exam_id) REFERENCES exams (id) ON DELETE CASCADE,
          FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE SET NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS marks (
          id               TEXT PRIMARY KEY,
          exam_subject_id  TEXT NOT NULL,
          student_id       TEXT NOT NULL,
          marks_obtained   REAL,
          is_absent        INTEGER NOT NULL DEFAULT 0,
          remarks          TEXT,
          entered_by       TEXT,
          entered_at       TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (exam_subject_id) REFERENCES exam_subjects (id) ON DELETE CASCADE,
          FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
          CONSTRAINT unq_exam_subj_student UNIQUE (exam_subject_id, student_id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS grade_scale (
          id             TEXT PRIMARY KEY,
          academic_year  TEXT NOT NULL,
          min_percent    REAL NOT NULL,
          max_percent    REAL NOT NULL,
          grade          TEXT NOT NULL,
          grade_point    REAL
        )
      ''');

      await db.execute('''
        INSERT OR IGNORE INTO grade_scale (id, academic_year, min_percent, max_percent, grade, grade_point) VALUES
        ('gs-a-plus', '2024-2025', 90.0, 100.0, 'A+', 4.0),
        ('gs-a', '2024-2025', 80.0, 89.99, 'A', 3.5),
        ('gs-b', '2024-2025', 70.0, 79.99, 'B', 3.0),
        ('gs-c', '2024-2025', 60.0, 69.99, 'C', 2.5),
        ('gs-d', '2024-2025', 50.0, 59.99, 'D', 2.0),
        ('gs-e', '2024-2025', 35.0, 49.99, 'E', 1.0),
        ('gs-f', '2024-2025', 0.0, 34.99, 'F', 0.0)
      ''');

      // 5. Staff, Timetable, Circulars, Documents
      await db.execute('''
        CREATE TABLE IF NOT EXISTS student_documents (
          id           TEXT PRIMARY KEY,
          student_id   TEXT NOT NULL,
          doc_type     TEXT NOT NULL,
          file_path    TEXT NOT NULL,
          file_name    TEXT NOT NULL,
          uploaded_at  TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS class_teacher_assignments (
          id             TEXT PRIMARY KEY,
          class          TEXT NOT NULL,
          section        TEXT NOT NULL,
          staff_id       TEXT NOT NULL,
          academic_year  TEXT NOT NULL,
          class_id       TEXT,
          section_id     TEXT,
          FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS timetable (
          id             TEXT PRIMARY KEY,
          class          TEXT NOT NULL,
          section        TEXT NOT NULL,
          day_of_week    TEXT NOT NULL,
          period_number  INTEGER NOT NULL,
          subject        TEXT NOT NULL,
          staff_id       TEXT NOT NULL,
          start_time     TEXT NOT NULL,
          end_time       TEXT NOT NULL,
          academic_year  TEXT NOT NULL,
          class_id       TEXT,
          section_id     TEXT,
          FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS teacher_attendance (
          id             TEXT PRIMARY KEY,
          staff_id       TEXT NOT NULL,
          date           TEXT NOT NULL,
          status         TEXT NOT NULL CHECK (status IN ('present', 'absent', 'half_day', 'on_leave', 'holiday')),
          time_in        TEXT,
          time_out       TEXT,
          remarks        TEXT,
          corrected_by   TEXT,
          corrected_at   TEXT,
          FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE,
          UNIQUE (staff_id, date)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS leave_types (
          id              TEXT PRIMARY KEY,
          name            TEXT NOT NULL UNIQUE,
          days_allowed    REAL NOT NULL,
          is_carryover    INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS leave_applications (
          id              TEXT PRIMARY KEY,
          staff_id        TEXT NOT NULL,
          leave_type_id   TEXT NOT NULL,
          from_date       TEXT NOT NULL,
          to_date         TEXT NOT NULL,
          reason          TEXT NOT NULL,
          status          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
          reviewed_by     TEXT,
          reviewed_at     TEXT,
          FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE,
          FOREIGN KEY (leave_type_id) REFERENCES leave_types (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS substitutions (
          id                      TEXT PRIMARY KEY,
          absent_staff_id         TEXT NOT NULL,
          substitute_staff_id     TEXT NOT NULL,
          date                    TEXT NOT NULL,
          period_number           INTEGER NOT NULL,
          class                   TEXT NOT NULL,
          section                 TEXT NOT NULL,
          status                  TEXT NOT NULL DEFAULT 'assigned' CHECK (status IN ('assigned', 'completed', 'cancelled')),
          FOREIGN KEY (absent_staff_id) REFERENCES staff (id) ON DELETE CASCADE,
          FOREIGN KEY (substitute_staff_id) REFERENCES staff (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS exam_duty (
          id             TEXT PRIMARY KEY,
          staff_id       TEXT NOT NULL,
          exam_name      TEXT NOT NULL,
          date           TEXT NOT NULL,
          room_number    TEXT NOT NULL,
          start_time     TEXT NOT NULL,
          end_time       TEXT NOT NULL,
          FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS circulars (
          id            TEXT PRIMARY KEY,
          title         TEXT NOT NULL,
          body          TEXT NOT NULL,
          sent_by       TEXT NOT NULL,
          sent_at       TEXT NOT NULL,
          target_type   TEXT NOT NULL CHECK (target_type IN ('all','department','individual')),
          target_id     TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS appraisals (
          id                 TEXT PRIMARY KEY,
          staff_id           TEXT NOT NULL,
          review_period      TEXT NOT NULL,
          self_assessment    TEXT NOT NULL,
          principal_remarks  TEXT NOT NULL,
          rating             INTEGER NOT NULL,
          created_at         TEXT NOT NULL,
          FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS trainings (
          id                TEXT PRIMARY KEY,
          staff_id          TEXT NOT NULL,
          training_name     TEXT NOT NULL,
          provider          TEXT NOT NULL,
          date              TEXT NOT NULL,
          certificate_path  TEXT,
          FOREIGN KEY (staff_id) REFERENCES staff (id) ON DELETE CASCADE
        )
      ''');

      // 6. Inventory
      await db.execute('''
        CREATE TABLE IF NOT EXISTS inventory_categories (
          id      TEXT PRIMARY KEY,
          name    TEXT UNIQUE NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS inventory_items (
          id                  TEXT PRIMARY KEY,
          name                TEXT NOT NULL,
          category_id         TEXT NOT NULL,
          unit                TEXT NOT NULL CHECK (unit IN ('piece', 'box', 'kg', 'litre', 'set')),
          current_stock       REAL NOT NULL DEFAULT 0,
          reorder_threshold   REAL NOT NULL DEFAULT 0,
          unit_cost           REAL,
          storage_location    TEXT,
          FOREIGN KEY (category_id) REFERENCES inventory_categories (id) ON DELETE RESTRICT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_transactions (
          id                  TEXT PRIMARY KEY,
          item_id             TEXT NOT NULL,
          transaction_type    TEXT NOT NULL CHECK (transaction_type IN ('purchase', 'issue', 'return', 'adjustment', 'damage')),
          quantity            REAL NOT NULL,
          issued_to_type      TEXT CHECK (issued_to_type IN ('staff', 'class', 'department')),
          issued_to_id        TEXT,
          transaction_date    TEXT NOT NULL,
          remarks             TEXT,
          recorded_by         TEXT NOT NULL,
          FOREIGN KEY (item_id) REFERENCES inventory_items (id) ON DELETE CASCADE
        )
      ''');

      final invCategories = [
        'Stationery', 'Sports Equipment', 'Lab Equipment',
        'Furniture', 'Electronics', 'Cleaning Supplies'
      ];
      for (var i = 0; i < invCategories.length; i++) {
        await db.execute(
          "INSERT OR IGNORE INTO inventory_categories (id, name) VALUES (?, ?)",
          ['cat-${i + 1}', invCategories[i]],
        );
      }

      // 7. Admin Users & Default Principal
      await db.execute('''
        CREATE TABLE IF NOT EXISTS admin_users (
          id TEXT PRIMARY KEY,
          username TEXT UNIQUE NOT NULL,
          password_hash TEXT NOT NULL,
          full_name TEXT NOT NULL,
          role TEXT NOT NULL CHECK (role IN ('admin','user')),
          is_active INTEGER NOT NULL DEFAULT 1,
          force_password_change INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          last_login TEXT,
          security_question TEXT,
          security_answer_hash TEXT
        )
      ''');

      final adminCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM admin_users');
      final adminCount = (adminCountRes.first['count'] as int?) ?? 0;
      if (adminCount == 0) {
        final initialPassword = BCrypt.hashpw('ChangeMe@2026', BCrypt.gensalt());
        await db.insert('admin_users', {
          'id': 'usr-admin-001',
          'username': 'admin',
          'password_hash': initialPassword,
          'full_name': 'System Administrator',
          'role': 'admin',
          'force_password_change': 1,
        });
      } else {
        // Ensure 'usr-admin-001' exists to satisfy hardcoded references (e.g. PaymentService)
        final usrAdminRes = await db.rawQuery("SELECT id FROM admin_users WHERE id = 'usr-admin-001'");
        if (usrAdminRes.isEmpty) {
          final initialPassword = BCrypt.hashpw('ChangeMe@2026', BCrypt.gensalt());
          await db.insert('admin_users', {
            'id': 'usr-admin-001',
            'username': 'admin_legacy', // Avoid UNIQUE constraint on username 'admin' if it exists
            'password_hash': initialPassword,
            'full_name': 'Legacy System Administrator',
            'role': 'admin',
            'force_password_change': 1,
          });
        }
      }

      // Ensure security question columns exist for older databases
      try {
        await db.execute('ALTER TABLE admin_users ADD COLUMN security_question TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE admin_users ADD COLUMN security_answer_hash TEXT');
      } catch (_) {}

      // 8. Default App Settings
      await db.execute('''
        INSERT OR REPLACE INTO app_settings (key, value)
        VALUES ('school_name', 'Eduvia')
      ''');
      await db.execute('''
        INSERT OR REPLACE INTO app_settings (key, value)
        VALUES ('school_motto', 'Inspiring Excellence, Building Futures')
      ''');
    } catch (e) {
      print('DatabaseHelper ensureSchemaIntegrity warning: $e');
    }
  }
}
