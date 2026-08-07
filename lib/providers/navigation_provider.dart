import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

/// Navigation tabs in the desktop main sidebar
enum NavigationTab {
  dashboard,
  feeCollection,
  admission,
  students,
  staff,
  expenses,
  classes,
  feeStructure,
  feeReports,
  attendance,
  transport,
  exams,
  hostel,
  library,
  inventory,
  assistant,
  manageUsers,
  activityLog,
  settings;

  String get title {
    switch (this) {
      case NavigationTab.dashboard:
        return 'Financial Dashboard';
      case NavigationTab.feeCollection:
        return 'Fee Collection & Invoicing';
      case NavigationTab.admission:
        return 'Student Admission Wizard';
      case NavigationTab.students:
        return 'Student Directory';
      case NavigationTab.staff:
        return 'Staff Directory';
      case NavigationTab.expenses:
        return 'Expenses & Ledger';
      case NavigationTab.classes:
        return 'Class & Section Setup';
      case NavigationTab.feeStructure:
        return 'Fee Structure Configuration';
      case NavigationTab.feeReports:
        return 'Fee Reports & Analytics';
      case NavigationTab.attendance:
        return 'Student Attendance';
      case NavigationTab.transport:
        return 'Transport Management';
      case NavigationTab.exams:
        return 'Exams & Performance Reports';
      case NavigationTab.hostel:
        return 'Hostel Management';
      case NavigationTab.library:
        return 'Library Management';
      case NavigationTab.inventory:
        return 'Inventory Management';
      case NavigationTab.assistant:
        return 'AI Assistant';
      case NavigationTab.manageUsers:
        return 'Manage Admin Users';
      case NavigationTab.activityLog:
        return 'Activity Log';
      case NavigationTab.settings:
        return 'System Settings';
    }
  }
}

/// Selected navigation tab state provider
final selectedTabProvider = StateProvider<NavigationTab>((ref) {
  return NavigationTab.dashboard;
});

/// Sidebar collapsed/expanded state provider
final sidebarCollapsedProvider = StateProvider<bool>((ref) {
  return false;
});

/// Profile requests issued by global search and handled by the relevant
/// directory after it becomes visible.
final pendingStudentProfileProvider = StateProvider<Student?>((ref) => null);
final pendingStaffProfileProvider = StateProvider<Staff?>((ref) => null);
