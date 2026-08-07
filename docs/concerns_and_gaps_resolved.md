# Architectural Concerns & Gaps — Fully Resolved

This document details how all 8 architectural concerns and gaps raised in the review were addressed in the codebase.

---

## Resolution Matrix

| # | Concern / Gap Raised | Implemented Solution | Relevant Source Code |
| :--- | :--- | :--- | :--- |
| **1** | **Business Logic Trapped in SQLite Triggers** | Removed hidden triggers. Balance updates, invoice status transitions (`paid`/`partial`), discounts, and late penalties are calculated explicitly in Dart (`PaymentService` & `InvoiceService`) inside atomic SQLite transactions (`db.transaction`). | [`payment_service.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/services/payment_service.dart)<br/>[`invoice_service.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/services/invoice_service.dart) |
| **2** | **Missing Schema Migration Strategy** | Implemented a versioned migration runner in `DatabaseHelper._onUpgrade` (v1 -> v2) that safely alters existing tables, creates new entities, and handles schema evolution cleanly. | [`database_helper.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/core/database/database_helper.dart#L180-L240) |
| **3** | **No Multi-Academic-Year Isolation** | Created `academic_years` table (`id`, `name`, `start_date`, `end_date`, `is_current`) and added `academic_year_id` foreign key on `invoices` and `fee_structures`. | [`academic_year.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/models/academic_year.dart)<br/>[`schema.sql`](file:///home/whoisadheep/Documents/School%20Management%20System/docs/schema.sql) |
| **4** | **10 Performance Indexes Missing from DDL** | Added 11 explicit `CREATE INDEX` statements in `schema.sql` and `DatabaseHelper` targeting `grade_level`, `due_date`, `student_id`, `timestamp`, and `academic_year_id` for scaling to 5,000+ students. | [`schema.sql`](file:///home/whoisadheep/Documents/School%20Management%20System/docs/schema.sql#L125-L138) |
| **5** | **Backup Strategy for Local SQLite** | Created `BackupService` providing automated daily database file copies (`Backups/school_management_backup_YYYYMMDD.db`), manual export to external/USB/OneDrive folders, and safe DB restore capability. | [`backup_service.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/services/backup_service.dart) |
| **6** | **Fee Flexibility (Grade Rates, Discounts & Penalties)** | Added `fee_structures` linking grade levels to fee categories per academic year. Added `discount_amount` and `penalty_amount` columns to `invoices` with `netAmount` calculation. | [`fee_structure.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/models/fee_structure.dart)<br/>[`invoice.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/models/invoice.dart) |
| **7** | **No RBAC or Action Logging** | Added `users` table (`role: admin, accountant, viewer`) and `audit_logs` table (`user_id`, `action`, `entity_type`, `entity_id`, `details`, `timestamp`) for staff action tracking. | [`user.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/models/user.dart)<br/>[`audit_log.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/models/audit_log.dart) |
| **8** | **Report Generator Path Hardcoded** | Created `SettingsService` storing `receipt_export_path` in SQLite. Updated `ReportGenerator` to use configurable export directories (e.g. shared network drives or custom local folders). | [`settings_service.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/services/settings_service.dart)<br/>[`report_generator.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/services/report_generator.dart) |

---

## Code Base Status

The codebase in `/home/whoisadheep/Documents/School Management System/` has been upgraded to **Database Version 2.0** with full backward compatibility and zero external cloud dependencies.
