# Eduvia School Management System — Codebase & Architecture Blueprint

> **Purpose**: This document provides an authoritative, instant architectural overview of the Eduvia codebase for AI assistants and developers. Use this index to locate files, understand state patterns, and execute modifications without redundant repo-wide exploration.

---

## 1. High-Level Technology Stack

| Layer | Technologies / Libraries |
| :--- | :--- |
| **Framework** | Flutter 3.x (Dart `>=3.0.0 <4.0.0`), Material 3 design |
| **State Management** | Flutter Riverpod (`flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`) |
| **Database** | SQLite with FFI (`sqflite_common_ffi`, `sqlite3_flutter_libs`, `sqflite_common_ffi_web`) |
| **PDF & Reports** | `pdf: ^3.10.8`, `printing: ^5.11.1`, `csv: ^8.0.0`, `excel: ^4.0.6` |
| **Charts & Visuals** | `fl_chart: ^0.66.2`, `flutter_svg: ^2.0.10`, `google_fonts: ^6.1.0` |
| **Security & Auth** | `bcrypt`, `crypto`, `encrypt`, `pointycastle`, `device_info_plus` |
| **AI Backend Proxy**| Node.js / Express server in `assistant-proxy/` communicating with Gemini API |

---

## 2. Directory Map & Domain Ownership

```
├── lib/
│   ├── app.dart                   # Root MaterialApp configuration with Eduvia theme
│   ├── main.dart                  # App bootstrap (dotenv, CrashReporting, AppLogger, SQLite init)
│   ├── core/                      # Global infrastructure & design tokens
│   │   ├── auth/                  # RBAC, password security, session handling
│   │   ├── constants/             # Global strings, app dimensions, asset paths
│   │   ├── database/              # database_helper.dart (SQLite schema creation, table definitions, legacy migrations)
│   │   └── theme/                 # app_theme.dart (Eduvia Purple palette, typography, card decorations)
│   ├── models/                    # 53 data entity classes (JSON / SQLite Map serialization)
│   │   └── models.dart            # Central barrel file exporting all models
│   ├── providers/                 # Riverpod state providers and controllers
│   │   ├── auth_provider.dart     # Authentication state & RBAC permissions
│   │   ├── navigation_provider.dart # NavigationTab state & sidebar routing
│   │   ├── services_provider.dart # Global singleton providers (DatabaseService, FutureProviders for lists)
│   │   ├── admission_provider.dart
│   │   ├── dashboard_provider.dart
│   │   ├── fee_collection_provider.dart
│   │   ├── hostel_provider.dart
│   │   ├── inventory_provider.dart
│   │   ├── library_provider.dart
│   │   ├── license_provider.dart
│   │   └── student_attendance_provider.dart
│   ├── services/                  # Business logic & repository services
│   │   ├── database_service.dart  # Central SQLite query repository (CRUD operations, ledger, finance)
│   │   ├── auth_service.dart      # User validation, hashing, sessions
│   │   ├── license_service.dart   # Licensing, hardware ID check, expiry & read-only lock
│   │   ├── assistant_service.dart # AI query client communicating with assistant-proxy
│   │   ├── report_generator.dart  # PDF invoices, fee receipts, financial reports
│   │   ├── report_card_generator.dart # Student exam report cards generator
│   │   ├── backup_service.dart    # SQLite backup & restoration
│   │   ├── csv_export_service.dart
│   │   ├── import_service.dart
│   │   ├── payment_service.dart
│   │   ├── time_tracker_service.dart
│   │   └── update_service.dart
│   └── ui/                        # Presentation layer
│       ├── layout/                # main_layout.dart, sidebar.dart, top_bar.dart
│       ├── widgets/               # Reusable UI widgets (cards, forms, tables, modals)
│       └── views/                 # 19 Screen modules (see Section 3)
├── assistant-proxy/               # Express.js server for Gemini AI integration
│   ├── server.js                  # Proxy endpoint handling streaming & context
│   └── package.json
└── assets/                        # Icons, images, branding assets
```

---

## 3. UI Views & Features Guide

When asked to edit a specific feature, go directly to its corresponding view:

| Feature Domain | View Directory | Key Models & Services |
| :--- | :--- | :--- |
| **Dashboard** | `lib/ui/views/dashboard/` | `dashboard_provider.dart`, `ledgerSummaryProvider` |
| **Fee Collection & Billing** | `lib/ui/views/fee_collection/` | `fee_collection_provider.dart`, `invoice.dart`, `student_fee_ledger.dart` |
| **Fee Structure Setup & Reports** | `lib/ui/views/fees/` | `fee_structure.dart`, `fee_category.dart`, `fee_head.dart`, `discount_type.dart` |
| **Admissions** | `lib/ui/views/admission/` | `admission_provider.dart`, `student.dart`, `student_document.dart` |
| **Student Directory** | `lib/ui/views/students/` | `student.dart`, `student_discount.dart`, `studentsListProvider` |
| **Staff & Payroll** | `lib/ui/views/staff/` | `staff.dart`, `salary_component.dart`, `staff_document.dart` |
| **Attendance (Students & Teachers)** | `lib/ui/views/attendance/` | `student_attendance.dart`, `teacher_attendance.dart`, `attendance_settings.dart` |
| **Classes, Sections, Timetable** | `lib/ui/views/classes/` | `class_model.dart`, `section.dart`, `timetable_entry.dart`, `substitution.dart` |
| **Exams & Marks** | `lib/ui/views/exams/` | `exam.dart`, `marks.dart`, `grade_scale.dart`, `report_card_generator.dart` |
| **Hostel Management** | `lib/ui/views/hostel/` | `hostel_block.dart`, `hostel_room.dart`, `hostel_allocation.dart` |
| **Library Management** | `lib/ui/views/library/` | `book.dart`, `book_issue.dart`, `library_provider.dart` |
| **Transport & Fleet** | `lib/ui/views/transport/` | `vehicle.dart`, `route.dart`, `route_stop.dart`, `student_transport.dart` |
| **Inventory & Assets** | `lib/ui/views/inventory/` | `inventory.dart`, `inventory_provider.dart` |
| **Expenses & Ledger** | `lib/ui/views/expenses/` | `transaction.dart`, `ledger_entry.dart`, `database_service.dart` |
| **AI Assistant** | `lib/ui/views/assistant/` | `assistant_service.dart`, `ai_message_service.dart`, `assistant-proxy/` |
| **Auth & Security** | `lib/ui/views/auth/` | `auth_provider.dart`, `auth_service.dart`, `user.dart`, `admin_user.dart` |
| **License Activation & Lock** | `lib/ui/views/license/` | `license_provider.dart`, `license_service.dart`, `hardware_id_service.dart` |
| **Settings & Audit Logs** | `lib/ui/views/settings/` | `audit_log.dart`, `settings_service.dart`, `backup_service.dart` |

---

## 4. Key Architectural Patterns & Conventions

### 1. State Management (Riverpod)
- **Reading Data**: Consume providers in UI using `ConsumerWidget` or `ConsumerStatefulWidget`.
- **Async Data**: Use `ref.watch(someFutureProvider)` with `.when(data: ..., loading: ..., error: ...)`.
- **Triggering Actions**: Read providers inside callbacks using `ref.read(...)` or call methods on `DatabaseService` via `ref.read(databaseServiceProvider)`.
- **Code Generation**: Providers annotated with `@riverpod` require running `dart run build_runner build --delete-conflicting-outputs`.

### 2. Database & Data Access
- **Single Source of Truth**: All SQLite queries live inside `lib/services/database_service.dart`. Do not write raw SQL queries inside UI widgets.
- **Table Definitions**: Schema setup and tables are defined in `lib/core/database/database_helper.dart`.
- **Models**: Every entity in `lib/models/` must implement `toMap()` and `fromMap(Map<String, dynamic> map)` for SQLite persistence.

### 3. Design System & Theming
- Primary brand color: `AppTheme.primaryPurple` (`#4C3BCF`)
- Background: `AppTheme.bgMain` (`#F5F3FF`)
- Card surface: `AppTheme.bgSurface` (`#FFFFFF`) with `AppTheme.cardDecoration()`
- Text Theme: Google Fonts `Poppins`

---

## 5. Common Commands

```bash
# Run the application in desktop/debug mode
flutter run -d linux # or -d windows / -d chrome

# Regenerate Riverpod / build_runner files
dart run build_runner build --delete-conflicting-outputs

# Analyze Dart code & lints
flutter analyze

# Run unit and widget tests
flutter test

# Start the AI Assistant backend proxy
cd assistant-proxy && npm start
```
