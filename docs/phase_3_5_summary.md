# Phase 3.5: Advanced Admission UI & Form State

## Overview
Phase 3.5 introduces an advanced, 4-step Student Admission Wizard UI designed for high-density desktop screens, featuring state preservation via Riverpod, automated field validation, explicit keyboard focus nodes for rapid Tab navigation, and full integration with SQLite local database (v4 schema).

---

## 1. Key Components & Implementation

| Feature | Implementation | Description |
| :--- | :--- | :--- |
| **Riverpod State Preservation** | `AdmissionFormNotifier` | Retains draft admission state in memory so switching tabs does not cause user data loss. |
| **Validation Rules** | Multi-Step Validation | Validates mandatory fields before allowing step transitions (e.g. Name/DOB in Step 1, Grade/Admission No in Step 2, Parent Contact in Step 3, Address in Step 4). |
| **Horizontal Stepper UI** | `AdmissionView` | Uses a wide desktop horizontal `Stepper` broken into 4 logical steps. |
| **Rapid Tab Keyboard Entry** | Explicit `FocusNode` Chains | Text fields are chained with dedicated focus nodes for seamless keyboard-only navigation. |
| **Smart Defaults** | Auto-generation & Pre-selection | Defaults admission date to current date, auto-generates `ADM-YYYY-xxxx` admission numbers, defaults common drop-downs (`Male`, `O+`, `Grade 1`, `General`, `Section A`). |
| **Location & Summary Review** | Step 4 Card Preview | Features "Same as Residential" address sync and displays a side-by-side summary review card before final submission. |
| **SQLite Migration v4** | `DatabaseHelper` | Upgraded SQLite database to v4 schema adding 23 new columns to the `students` table. |

---

## 2. The 4 Admission Wizard Steps

```
[ Step 1: Student Identity ]
├── First Name *
├── Last Name *
├── Date of Birth (DatePicker) *
├── Gender (Dropdown) *
├── Blood Group (Dropdown)
└── Photograph Placeholder (File Picker)

[ Step 2: Demographics & Academic ]
├── Grade Level (Dropdown) *
├── Section (Dropdown)
├── Admission Number (Auto-generated / Manual) *
├── Roll Number
├── Admission Date (DatePicker, defaults to today) *
├── Aadhaar Number (12-Digit)
├── Caste / Category (Dropdown)
└── Religion (Dropdown)

[ Step 3: Guardianship ]
├── Father's Name, Occupation & Phone *
├── Mother's Name, Occupation & Phone
└── Primary Emergency Contact Number *

[ Step 4: Location & Review Summary ]
├── Residential Address *
├── Permanent Address (with "Same as Residential" Checkbox)
├── Transport Route (Dropdown)
├── Hostel Room (Dropdown)
├── Live Summary Review Card
└── "Confirm Admission" Button (Soft-Lock Read-Only Enforced)
```

---

## 3. Implemented Files

1. **State Notifier**: [`admission_provider.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/providers/admission_provider.dart)
2. **Admission Wizard UI**: [`admission_view.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/ui/views/admission/admission_view.dart)
3. **Updated Student Model**: [`student.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/models/student.dart)
4. **Database Helper v4**: [`database_helper.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/core/database/database_helper.dart)
5. **Navigation Integration**: [`navigation_provider.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/providers/navigation_provider.dart), [`sidebar.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/ui/layout/widgets/sidebar.dart), [`main_layout.dart`](file:///home/whoisadheep/Documents/School%20Management%20System/lib/ui/layout/main_layout.dart)
