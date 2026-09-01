import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/license_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../services/license_service.dart';
import '../views/admission/admission_view.dart';
import '../views/students/student_directory_view.dart';
import '../views/staff/staff_directory_view.dart';
import '../views/auth/login_view.dart';
import '../views/auth/password_change_view.dart';
import '../views/auth/security_question_setup_view.dart';
import '../views/classes/class_section_setup_view.dart';
import '../views/dashboard/dashboard_view.dart';
import '../views/expenses/expenses_view.dart';
import '../views/fees/fee_structure_setup_view.dart';
import '../views/fees/fee_reports_view.dart';
import '../views/transport/transport_view.dart';
import '../views/exams/exam_management_view.dart';
import '../views/fee_collection/fee_collection_view.dart';
import '../views/license/license_activation_view.dart';
import '../views/hostel/hostel_management_view.dart';
import '../views/assistant/assistant_view.dart';
import '../views/attendance/student_attendance_view.dart';
import '../views/library/library_management_view.dart';
import '../views/inventory/inventory_management_view.dart';
import '../views/settings/admin_users_view.dart';
import '../views/settings/activity_log_view.dart';
import '../views/settings/settings_view.dart';
import '../views/update/update_dialog.dart';
import '../../services/update_service.dart';
import 'widgets/sidebar.dart';
import 'widgets/top_bar.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdates();
    });
  }

  Future<void> _checkUpdates() async {
    final updateInfo = await UpdateService.instance.checkForUpdate();
    if (updateInfo != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: !updateInfo.isMandatory,
        builder: (context) => UpdateDialog(updateInfo: updateInfo),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final licenseAsync = ref.watch(licenseStateProvider);

    if (!authState.isAuthenticated) {
      return const AdminLoginView();
    }

    if (authState.forcePasswordChange) {
      return const PasswordChangeView();
    }

    final securityQuestionPending = ref.watch(securityQuestionPendingProvider);
    if (securityQuestionPending) {
      return const SecurityQuestionSetupView();
    }

    final selectedTab = ref.watch(selectedTabProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () {
          ref.read(selectedTabProvider.notifier).state = NavigationTab.dashboard;
        },
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () {
          ref.read(selectedTabProvider.notifier).state = NavigationTab.feeCollection;
        },
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () {
          ref.read(selectedTabProvider.notifier).state = NavigationTab.admission;
        },
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () {
          ref.read(selectedTabProvider.notifier).state = NavigationTab.students;
        },
        const SingleActivator(LogicalKeyboardKey.digit5, control: true): () {
          ref.read(selectedTabProvider.notifier).state = NavigationTab.expenses;
        },
        const SingleActivator(LogicalKeyboardKey.digit6, control: true): () {
          ref.read(selectedTabProvider.notifier).state = NavigationTab.settings;
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F3FF),
          body: Column(
            children: [
              // License Banner
              licenseAsync.when(
                data: (result) => _buildLicenseBanner(context, ref, result),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              Expanded(
                child: Row(
                  children: [
                    const DesktopSidebar(),
                    Expanded(
                      child: Column(
                        children: [
                          const DesktopTopBar(),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: _getTabWidget(selectedTab, authState),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseBanner(
    BuildContext context,
    WidgetRef ref,
    LicenseValidationResult result,
  ) {
    if (result.status == LicenseStatus.gracePeriod) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        color: const Color(0xFF78350F),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFBBF24), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'License expires in ${result.daysRemaining} day(s). Please contact Sai Infotek for renewal.',
                style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LicenseActivationView()),
                );
              },
              child: const Text('Renew License Key', style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (result.status.isReadOnly) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        color: const Color(0xFF7F1D1D),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFFF87171), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'SOFT-LOCK ACTIVE (Read-Only Mode): ${result.message ?? "License Expired or Clock Tampered."}',
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LicenseActivationView()),
                );
              },
              icon: const Icon(Icons.key_rounded, size: 14),
              label: const Text('Activate License Key', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _getTabWidget(NavigationTab tab, AuthState authState) {
    final currentUser = authState.currentUser;
    final currentAdmin = authState.currentAdmin;
    final adminRole = currentAdmin?.role.toLowerCase();
    final isAdmin = currentUser?.role == UserRole.admin ||
        adminRole == 'admin' ||
        adminRole == 'principal' ||
        currentAdmin?.username.toLowerCase() == 'admin';
    final canViewFinance = isAdmin || (currentUser?.canViewFinance ?? false);

    if (!canViewFinance && (tab == NavigationTab.dashboard || tab == NavigationTab.feeCollection || tab == NavigationTab.expenses || tab == NavigationTab.feeStructure || tab == NavigationTab.feeReports || tab == NavigationTab.inventory)) {
      return _buildAccessDeniedWidget(tab);
    }

    switch (tab) {
      case NavigationTab.dashboard:
        return const DashboardView(key: ValueKey('DashboardView'));
      case NavigationTab.feeCollection:
        return const FeeCollectionView(key: ValueKey('FeeCollectionView'));
      case NavigationTab.admission:
        return const AdmissionView(key: ValueKey('AdmissionView'));
      case NavigationTab.students:
        return const StudentDirectoryView(key: ValueKey('StudentDirectoryView'));
      case NavigationTab.staff:
        return const StaffDirectoryView(key: ValueKey('StaffDirectoryView'));
      case NavigationTab.expenses:
        return const ExpensesView(key: ValueKey('ExpensesView'));
      case NavigationTab.classes:
        return const ClassSectionSetupView(key: ValueKey('ClassSectionSetupView'));
      case NavigationTab.feeStructure:
        return const FeeStructureSetupView(key: ValueKey('FeeStructureSetupView'));
      case NavigationTab.feeReports:
        return const FeeReportsView(key: ValueKey('FeeReportsView'));
      case NavigationTab.attendance:
        return const StudentAttendanceView(key: ValueKey('StudentAttendanceView'));
      case NavigationTab.transport:
        return const TransportView(key: ValueKey('TransportView'));
      case NavigationTab.exams:
        return const ExamManagementView(key: ValueKey('ExamManagementView'));
      case NavigationTab.hostel:
        return const HostelManagementView(key: ValueKey('HostelManagementView'));
      case NavigationTab.assistant:
        return const AssistantView(key: ValueKey('AssistantView'));
      case NavigationTab.library:
        return const LibraryManagementView(key: ValueKey('LibraryManagementView'));
      case NavigationTab.inventory:
        return const InventoryManagementView(key: ValueKey('InventoryManagementView'));
      case NavigationTab.manageUsers:
        return const AdminUsersView(key: ValueKey('AdminUsersView'));
      case NavigationTab.activityLog:
        return const ActivityLogView(key: ValueKey('ActivityLogView'));
      case NavigationTab.settings:
        return const SettingsView(key: ValueKey('SettingsView'));
    }
  }

  Widget _buildAccessDeniedWidget(NavigationTab tab) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFFEF4444), size: 56),
            const SizedBox(height: 16),
            const Text(
              'ACCESS RESTRICTED (RBAC Policy)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Your account role does not have "can_view_finance" permission required to access ${tab.title}. Please contact your System Administrator to request permission.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

