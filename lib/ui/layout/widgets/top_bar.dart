import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../widgets/command_palette_dialog.dart';

class DesktopTopBar extends ConsumerWidget {
  const DesktopTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);
    final currentAdmin = ref.watch(authProvider).currentAdmin;

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          // Page Title
          Flexible(
            child: Text(
              _getPageTitle(selectedTab),
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E1E2D),
              ),
            ),
          ),
          const SizedBox(width: 32),

          // Global Command Palette (Ctrl + K) Trigger
          InkWell(
            onTap: () {
              showDialog(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.45),
                barrierDismissible: true,
                builder: (context) => const CommandPaletteDialog(),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 440,
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F0F5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.transparent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFF6B7280), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Search anything (students, views, actions)...',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF9CA3AF),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      'Ctrl + K',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          const SizedBox(width: 24),

          // User Profile
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFE8E4FF),
                child: Icon(Icons.person_rounded, color: Color(0xFF4C3BCF), size: 22),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentAdmin?.fullName ?? 'System Administrator',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E1E2D),
                    ),
                  ),
                  Text(
                    currentAdmin?.role.toUpperCase() ?? 'ADMIN',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
                onSelected: (value) {
                  if (value == 'logout') {
                    ref.read(authProvider.notifier).logout();
                  } else if (value == 'profile') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('User Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Name: ${currentAdmin?.fullName ?? "System Administrator"}', style: GoogleFonts.poppins()),
                            Text('Username: ${currentAdmin?.username ?? "admin"}', style: GoogleFonts.poppins()),
                            Text('Role: ${currentAdmin?.role.toUpperCase() ?? "ADMIN"}', style: GoogleFonts.poppins()),
                            Text('Status: Active Account', style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Close', style: GoogleFonts.poppins()),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 18),
                        const SizedBox(width: 8),
                        Text('Profile', style: GoogleFonts.poppins(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('Logout', style: GoogleFonts.poppins(fontSize: 13, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPageTitle(NavigationTab tab) {
    switch (tab) {
      case NavigationTab.dashboard:
        return 'Dashboard';
      case NavigationTab.feeCollection:
        return 'Fee Collection';
      case NavigationTab.admission:
        return 'Admissions';
      case NavigationTab.students:
        return 'Students';
      case NavigationTab.staff:
        return 'Staff';
      case NavigationTab.expenses:
        return 'Expenses';
      case NavigationTab.classes:
        return 'Class & Section Setup';
      case NavigationTab.feeStructure:
        return 'Fee Structure Configuration';
      case NavigationTab.feeReports:
        return 'Fee Reports & Analytics';
      case NavigationTab.attendance:
        return 'Attendance';
      case NavigationTab.transport:
        return 'Transport Management';
      case NavigationTab.exams:
        return 'Exams & Performance Reports';
      case NavigationTab.hostel:
        return 'Hostel Management';
      case NavigationTab.library:
        return 'Library Management';
      case NavigationTab.assistant:
        return 'Support Agent';
      case NavigationTab.inventory:
        return 'Inventory Management';
      case NavigationTab.manageUsers:
        return 'Manage Users';
      case NavigationTab.activityLog:
        return 'Activity Log';
      case NavigationTab.settings:
        return 'Settings';
    }
  }
}
