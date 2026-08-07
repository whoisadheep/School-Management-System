import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/services_provider.dart';

enum RiskyAction {
  deleteRecord('Delete Record'),
  editFeeStructure('Edit Fee Structure'),
  editSalaryComponent('Edit Salary Component'),
  editGradeScale('Edit Grade Scale'),
  deactivateStaff('Deactivate Staff'),
  deactivateStudent('Deactivate Student'),
  licenseManagement('License Management'),
  databaseBackupRestore('Database Backup & Restore'),
  bulkImport('Bulk Import'),
  manageAdminUsers('Manage Admin Users'),
  toggleFeatureFlag('Toggle Feature Flag'),
  closeAcademicYear('Close Academic Year');

  final String label;
  const RiskyAction(this.label);
}

class PermissionHelper {
  /// Checks if the current admin has permission to perform a risky action.
  /// If the role is 'administration', it blocks the action, shows an error, and returns false.
  /// Returns true if permitted.
  static bool requireAdminRole(BuildContext context, WidgetRef ref, RiskyAction action) {
    final authState = ref.read(authProvider);
    final role = authState.currentAdmin?.role;

    // We allow if the role is specifically 'principal'
    if (role == 'principal') {
      return true;
    }

    // Otherwise (e.g. 'administration'), we block and log
    final dbService = ref.read(databaseServiceProvider);
    dbService.logAction(
      actionType: 'risky_action_blocked',
      module: 'Security',
      description: 'Blocked unauthorized attempt to perform: ${action.label}',
    );

    _showPermissionDeniedDialog(context, action);
    return false;
  }

  static void _showPermissionDeniedDialog(BuildContext context, RiskyAction action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: Colors.red),
            const SizedBox(width: 12),
            Text('Access Denied', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'This action (${action.label}) requires Admin access. Your current role is not authorized to perform this operation.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Understood', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
