# Teachers and Staff Database Implementation

This document outlines the complete technical implementation for the Teachers and Staff module added to the School Management System.

## 1. Database Schema & Migration

A new `staff` table was introduced via a schema version bump (v4 to v5) in `DatabaseHelper`. The table is designed to capture all essential details for school employees.

### Table: `staff`
| Column Name | Type | Description |
| :--- | :--- | :--- |
| `id` | `TEXT (PK)` | Unique identifier for the staff member. |
| `first_name` | `TEXT` | Required. First name. |
| `last_name` | `TEXT` | Required. Last name. |
| `dob` | `TEXT` | Date of Birth. |
| `gender` | `TEXT` | Gender identity. |
| `blood_group` | `TEXT` | Blood group for emergencies. |
| `photograph_path` | `TEXT` | Local URI to the staff's profile picture. |
| `role` | `TEXT` | Required. Checked constraint: `teacher`, `admin`, `support_staff`, `driver`. |
| `department` | `TEXT` | Academic or administrative department (e.g., "Science", "Transport"). |
| `designation` | `TEXT` | Specific job title (e.g., "Senior Biology Teacher"). |
| `joining_date` | `TEXT` | Date of employment commencement. |
| `qualification` | `TEXT` | Highest educational degree or certification. |
| `experience_years` | `INTEGER`| Years of prior experience. |
| `email` | `TEXT` | Contact email address. |
| `phone` | `TEXT` | Primary contact number. |
| `address` | `TEXT` | Residential address. |
| `emergency_contact`| `TEXT` | Emergency contact name/number. |
| `basic_salary` | `REAL` | Base salary amount. |
| `is_active` | `INTEGER` | Soft delete flag (1 = active, 0 = inactive). |
| `created_at` | `TEXT` | Auto-generated creation timestamp. |
| `updated_at` | `TEXT` | Auto-generated modification timestamp. |

## 2. Models & State Management

### The `Staff` Model (`lib/models/staff.dart`)
- **Properties:** Mirrors the database schema precisely.
- **Computed getters:** `fullName` automatically combines `firstName` and `lastName`.
- **Serialization:** Provides `toMap()`, `fromMap()`, `toJson()`, and `fromJson()` for SQLite and API readiness.
- **Immutability:** Includes a `copyWith()` method for state management best practices.
- **Export:** Exported through the `models.dart` barrel file.

### Riverpod Providers (`lib/providers/services_provider.dart`)
- `staffListProvider`: A `FutureProvider` that automatically fetches and caches the list of all active staff from the database.
- `staffSearchQueryProvider`: A `StateProvider` holding the current search text (with 300ms debounce).
- `filteredStaffProvider`: A derived `Provider` that filters the `staffListProvider` results locally based on the search query across names, roles, departments, and phone numbers.

## 3. Database Services (`lib/services/database_service.dart`)

Added dedicated CRUD operations to handle the `staff` table safely:
- `insertStaff(Staff staff)`: Creates a new staff record using `ConflictAlgorithm.replace`.
- `getStaffById(String id)`: Retrieves a specific staff member.
- `getAllStaff({bool activeOnly = true})`: Returns the directory list, ordered alphabetically by first name.
- `updateStaff(Staff staff)`: Edits a staff profile and automatically bumps the `updated_at` timestamp.
- `setStaffActiveStatus(String id, bool isActive)`: Performs a soft-delete or reactivation.

## 4. UI Components

### Staff Directory View (`lib/ui/views/staff/staff_directory_view.dart`)
A brand new, full-page desktop view implementing the "Purple/Indigo" design aesthetic.

**Key Features:**
- **Animated Background:** A subtle, slow-pulsing radial gradient behind the main layout.
- **Header:** A premium linear gradient (`#5B4BC4` to `#7B68EE`) container featuring the page title and an "Add New Staff" CTA button.
- **Search Bar:** Real-time, debounced search filtering by name, role, department, or phone.
- **List View:** Staff are displayed in elevated cards showcasing their initial (in a circular avatar), full name, role, department, and phone number. An edit icon allows quick modifications.
- **Inline Form Mode:** Clicking "Add New Staff" or "Edit" replaces the list with a clean, grid-based entry form capturing:
  - First & Last Name
  - Phone & Email
  - Role (Dropdown: Teacher, Admin, Support Staff, Driver)
  - Department
  - Designation
  - Basic Salary

### Layout Integration (`lib/ui/layout/widgets/`)
- **`NavigationTab` Enum:** Added `NavigationTab.staff`.
- **Sidebar (`sidebar.dart`):** Appended a new navigation item with an `Icons.badge_rounded` icon.
- **Top Bar (`top_bar.dart`):** Ensured the app bar correctly titles the page "Staff" when selected.
- **Main Layout (`main_layout.dart`):** Mapped the new tab to render `StaffDirectoryView` within the main scaffold switch statement.
