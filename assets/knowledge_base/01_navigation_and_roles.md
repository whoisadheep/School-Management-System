# Navigation Map, Sidebar Layout & User Roles

> **Purpose**: Complete reference of Eduvia's navigation structure, sidebar tabs, and Role-Based Access Control (RBAC).

---

## 1. Sidebar Navigation Map

Eduvia features 19 primary functional tabs accessible from the persistent left sidebar.

| # | Sidebar Tab Title | Tab Key (`tab_id`) | Primary Function & Contents | Permitted Roles |
| :- | :--- | :--- | :--- | :--- |
| 1 | **Financial Dashboard** | `dashboard` | High-level metrics: total revenue, pending fees, student count, recent income/expense charts. | Super Admin, Admin, Accountant |
| 2 | **Fee Collection & Invoicing** | `feeCollection` | Collect fees by **Admission Number**, view balance dues, generate Thermal/A4 receipts, view student fee ledger. | Super Admin, Admin, Accountant |
| 3 | **Student Admission Wizard** | `admission` | Multi-step form to register new students, assign class/section, upload documents, record parent details. | Super Admin, Admin |
| 4 | **Student Directory** | `students` | Browse, filter, search, and edit active/inactive students. AI-powered CSV import tool. | All Roles |
| 5 | **Staff Directory** | `staff` | Manage teachers and non-teaching staff, designations, contracts, and salary structures. | Super Admin, Admin |
| 6 | **Expenses & Ledger** | `expenses` | Record operational expenses, vendor payments, general daybook, and school financial ledger. | Super Admin, Admin, Accountant |
| 7 | **Class & Section Setup** | `classes` | Create/edit classes, sections, assign class teachers, and configure **Class Subject Curriculum**. | Super Admin, Admin |
| 8 | **Fee Structure Configuration** | `feeStructure` | Define fee categories, fee heads (Tuition, Exam, Library), and term-wise fee amounts per class. | Super Admin, Admin, Accountant |
| 9 | **Fee Reports & Analytics** | `feeReports` | Detailed reports on collected fees, outstanding defaulters list, fee summaries by class and date. | Super Admin, Admin, Accountant |
| 10 | **Student Attendance** | `attendance` | Daily attendance marking by class and section, attendance register, percentage calculation. | All Roles |
| 11 | **Transport Management** | `transport` | Manage bus fleet, routes, pick-up/drop-off stops, driver records, and student bus assignments. | Super Admin, Admin |
| 12 | **Exams & Performance Reports** | `exams` | Create exams, auto-pick class subjects, exclude/add subjects, **Marks Entry Roster**, and PDF report cards. | All Roles |
| 13 | **Hostel Management** | `hostel` | Manage hostel blocks, rooms, bed capacity, and room allocations for boarding students. | Super Admin, Admin |
| 14 | **Library Management** | `library` | Book catalog, ISBN indexing, book issuing/returns, overdue tracking, and member lists. | All Roles |
| 15 | **Inventory Management** | `inventory` | Manage physical assets, furniture, IT equipment, lab supplies, and stock quantities. | Super Admin, Admin |
| 16 | **AI Assistant** | `assistant` | Conversational ERP copilot, data lookup, how-to tutorials, and system navigation. | All Roles |
| 17 | **Manage Admin Users** | `manageUsers` | Create system users, assign roles (Admin, Accountant, Teacher), and reset passwords. | Super Admin |
| 18 | **Activity Log** | `activityLog` | Audit trail of critical system events, login attempts, data updates, and record deletions. | Super Admin, Admin |
| 19 | **System Settings** | `settings` | School name, address, contact details, logo branding, database backup & restore, license key. | Super Admin, Admin |

---

## 2. Role-Based Access Control (RBAC)

Eduvia enforces four predefined security roles:

1. **Super Admin**:
   - Unrestricted master access to all 19 tabs.
   - Exclusive ability to create and manage system user accounts (`manageUsers`), view audit logs, and activate software licenses.
2. **Admin**:
   - Full operational access to academic, student, staff, fee, and inventory management.
   - Cannot delete or modify Super Admin credentials.
3. **Accountant**:
   - Focused access on financial operations: `dashboard`, `feeCollection`, `feeStructure`, `feeReports`, `expenses`, and `students`.
   - Cannot modify exam marks, class curriculum, or system settings.
4. **Teacher**:
   - Access to academic operations: `students`, `attendance`, `exams`, `classes`, and `library`.
   - Cannot view school financial dashboards, fee balances, or staff payrolls.

---

## 3. Deep Linking Directive for the AI Assistant

When guiding users to a specific screen, always mention the primary tab name in bold and, when applicable, use the deep link action tag:
`[NAV:<tab_id>]`

*Example*:
> "To assign subjects to Class 1, go to **Class & Section Setup** [NAV:classes] from the sidebar."
