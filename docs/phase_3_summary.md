# Phase 3: Desktop UI Layout (Flutter)

## Overview
Phase 3 establishes the primary Windows desktop navigation frame and responsive workspace structure for the **School Management System (SMS)** Admin & Accounting Module.

---

## 1. UI Layout Architecture

The desktop application layout is split into three main persistent components:

```
+-----------------------------------------------------------------------------------+
|  [Logo] EDUACCOUNT    Module > Financial Dashboard          [WAL Mode]  18:45  [Admin]|
+---------------------+-------------------------------------------------------------+
|                     |                                                             |
|  [#] Dashboard      |  FINANCIAL OVERVIEW & METRICS                               |
|                     |                                                             |
|  [$] Fee Collection |  +-------------------+  +-------------------+  +------------+ |
|                     |  | Total Collections |  | Total Expenses    |  | Net Cash   | |
|  [W] Expenses       |  | ₹1,250,000.00     |  | ₹420,000.00       |  | ₹830,000   | |
|                     |  +-------------------+  +-------------------+  +------------+ |
|  [*] Settings       |                                                             |
|                     |  QUICK SHORTCUTS                                            |
|                     |  [Batch Invoices]   [Collect Fee]   [Log Expense]           |
|                     |                                                             |
|  [<] Collapse       |                                                             |
+---------------------+-------------------------------------------------------------+
```

---

## 2. Desktop Keyboard Navigation Shortcuts

Global hotkeys are bound using Flutter `CallbackShortcuts` at the root layout:

| Shortcut | Action |
| :--- | :--- |
| `Ctrl + 1` | Switch to **Dashboard** view |
| `Ctrl + 2` | Switch to **Fee Collection** view |
| `Ctrl + 3` | Switch to **Expenses & Ledger** view |
| `Ctrl + 4` | Switch to **Settings** view |
| `Ctrl + B` | Toggle **Sidebar Collapse/Expand** state |

---

## 3. Implemented Files Directory

```
School Management System/
├── docs/
│   ├── phase_1_summary.md
│   ├── phase_2_summary.md
│   ├── phase_3_summary.md
│   └── schema.sql
├── lib/
│   ├── app.dart
│   ├── main.dart
│   ├── core/...
│   ├── models/...
│   ├── providers/
│   │   ├── navigation_provider.dart
│   │   └── services_provider.dart
│   ├── services/...
│   └── ui/
│       ├── layout/
│       │   ├── main_layout.dart
│       │   └── widgets/
│       │       ├── sidebar.dart
│       │       └── top_bar.dart
│       └── views/
│           ├── dashboard/dashboard_view.dart
│           ├── expenses/expenses_view.dart
│           ├── fee_collection/fee_collection_view.dart
│           └── settings/settings_view.dart
└── pubspec.yaml
```
