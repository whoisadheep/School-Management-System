# Eduvia Capabilities, Scope & Limitations Index

> **Purpose**: This document serves as the absolute ground truth for the Eduvia AI Assistant regarding what features exist in Eduvia and, crucially, what is **NOT** supported. The AI must never hallucinate features not listed as supported.

---

## 1. Supported Features

Eduvia is an offline-first, high-performance Desktop ERP (Windows & Linux) built for K-12 schools, colleges, and academies.

### Core Architecture & Storage
- **Offline SQLite Database**: All data is stored locally on the school's machine in an encrypted/reliable SQLite database. No external cloud database required for core operations.
- **Local Automated Backups**: One-click database backup and restoration to local storage or external USB drives.
- **Role-Based Access Control (RBAC)**: Support for `Super Admin`, `Admin`, `Accountant`, and `Teacher` roles with granular view permissions.
- **Hardware-Locked Licensing**: Offline machine hardware ID (HWID) verification for licensing.

### Academic Management
- **Class & Section Setup**: Unlimited classes and sections with designated class teachers and student capacities.
- **Class Subject Curriculum**: Assigning official subjects (with codes) to specific classes (e.g., Class 1 gets Math, English, Hindi; Class 11 gets Physics, Chemistry, Biology).
- **Exam Management**: Flexible exam creation (Term, Mid-term, Final) with passing and maximum marks.
- **Subject Auto-Pick in Exams**: Exams automatically inherit the class curriculum subjects, with the option to exclude or add subjects per exam.
- **Marks Entry Roster**: Fast tabular marks entry for entire classes with auto-calculated total and percentage.
- **Report Card Generation**: Printable PDF student report cards with grade scales (A+, A, B, etc.) and attendance summaries.
- **Timetable & Substitution**: Daily period schedules and teacher substitution management.

### Students & Admissions
- **Multi-Step Admission Wizard**: Comprehensive student profile creation (personal, parents, previous school, transport/hostel opt-in).
- **Admission Number System**: Unique system-wide admission numbers for every student.
- **AI-Powered CSV Import**: Smart CSV/Excel student roster import with intelligent fuzzy column mapping.
- **Student Document Vault**: Attaching student birth certificates, transfer certificates, and photos.

### Fee Collection & Billing
- **Flexible Fee Structures**: Custom fee heads (Tuition, Library, Sports, Exam, Transport, Hostel) per class and term.
- **Scholarships & Concessions**: Flat or percentage-based discounts assigned to individual students.
- **Fast Fee Collection Desk**: Instant lookup by **Admission Number** or Name, displaying due items and past payments.
- **Multiple Payment Modes**: Cash, Bank Transfer, Cheque, and UPI reference recording.
- **Receipt Printing**: Instant 80mm Thermal receipts and standard A4 invoice generation.
- **Student Fee Ledger**: Complete chronological ledger of charges, payments, and outstanding balances.

### Staff & Auxiliary Operations
- **Staff Directory & Payroll**: Teacher and staff records, salary component structures, and monthly pay slip generation.
- **Attendance**: Daily class-wise student attendance registers and staff check-in tracking.
- **Library Management**: Book cataloging, ISBN tracking, book issue/return records, and overdue tracking.
- **Transport Management**: Bus fleet records, route and stop setup, student route assignments.
- **Hostel Management**: Hostel blocks, room allocations, bed capacity management.
- **Inventory & Assets**: School asset tracking, categories, quantities, and condition monitoring.
- **Expenses & Finance**: Expense tracking, category-wise ledger, daybook, and income vs expense summaries.

---

## 2. Features NOT Supported (Critical Limitations)

The AI Assistant must **NEVER** claim Eduvia supports the following features. If asked, it must state that the feature is currently unsupported and provide the closest manual alternative:

| Requested Feature | Status | What the AI Must Tell the User | Recommended Manual Alternative |
| :--- | :--- | :--- | :--- |
| **Biometric / RFID Hardware Sync** | ❌ Not Supported | Eduvia does not connect directly to biometric fingerprint or RFID turnstiles. | Mark attendance in bulk in the **Attendance** screen or import daily records via CSV. |
| **Online Payment Gateways (Razorpay/Stripe/Cards)** | ❌ Not Supported | Eduvia does not process live credit card transactions or online payment gateways directly. | Record payments under **Fee Collection** as Bank Transfer, Cheque, or UPI reference number. |
| **Automated SMS / WhatsApp Gateway** | ❌ Not Supported | Eduvia does not have an integrated SIM/SMS telecom gateway to send background text messages. | Generate and print or PDF-export student fee receipts, report cards, or dues notices. |
| **Parent / Student Mobile App** | ❌ Not Supported | There is no mobile app for parents or students. Eduvia is an administrative desktop system. | Staff can print or email PDF report cards and fee receipts to parents. |
| **Multi-Branch Cloud Sync** | ❌ Not Supported | Eduvia runs on a local SQLite database per installation and does not do real-time cloud multi-branch synchronization. | Use the **Database Backup & Restore** feature in Settings to move data between machines. |
| **LMS / Online Homework Submission** | ❌ Not Supported | Eduvia is a School ERP/Management System, not a virtual classroom or Learning Management System (LMS). | Use third-party tools (Google Classroom, etc.) for homework; manage grades and marks in Eduvia. |

---

## 3. Strict AI Behavioral Instructions

1. **Groundedness**: Only answer based on features confirmed in this knowledge base.
2. **Unsupported Inquiries**: When a user asks about an unsupported feature:
   - State clearly: *"Eduvia does not currently support [Feature Name]."*
   - Offer the recommended manual alternative from the table above.
   - Do not invent menu items, settings, or external plugins that do not exist.
3. **Deep Linking**: When explaining where to go, always mention the exact Sidebar Tab name so the user can easily find it.
