import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../models/models.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/services_provider.dart';
import 'hover_scale.dart';

class DesktopSidebar extends ConsumerWidget {
  const DesktopSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);
    final authState = ref.watch(authProvider);
    final user = authState.currentUser;
    final canViewFinance = user?.role == UserRole.principal || (user?.canViewFinance ?? false);
    final hostelFlagAsync = ref.watch(featureFlagProvider('hostel_management'));
    final isHostelEnabled = hostelFlagAsync.valueOrNull ?? false;

    return Container(
      width: 80,
      decoration: const BoxDecoration(
        color: Color(0xFF4C3BCF),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // School Logo
          InkWell(
            onTap: () {
              ref.read(selectedTabProvider.notifier).state = NavigationTab.dashboard;
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/app_icon.svg',
                  width: 28,
                  height: 28,
                  placeholderBuilder: (context) => const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Nav Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildNavItem(ref, NavigationTab.dashboard, Icons.grid_view_rounded, selectedTab, isRestricted: !canViewFinance),
                const SizedBox(height: 8),
                _buildNavItem(ref, NavigationTab.students, Icons.people_rounded, selectedTab),
                const SizedBox(height: 8),
                _buildNavItem(ref, NavigationTab.staff, Icons.badge_rounded, selectedTab),
                const SizedBox(height: 8),
                _buildNavItem(ref, NavigationTab.classes, Icons.class_rounded, selectedTab),
                const SizedBox(height: 8),
                _buildNavItem(ref, NavigationTab.attendance, Icons.co_present_rounded, selectedTab),
                const SizedBox(height: 8),
                _buildNavItem(ref, NavigationTab.admission, Icons.person_add_alt_1_rounded, selectedTab),
                const SizedBox(height: 8),
                _buildNavItem(ref, NavigationTab.feeCollection, Icons.account_balance_wallet_rounded, selectedTab, isRestricted: !canViewFinance),
                const SizedBox(height: 8),
                _buildNavItem(ref, NavigationTab.feeStructure, Icons.payments_rounded, selectedTab, isRestricted: !canViewFinance),
                const SizedBox(height: 8),
                _buildNavItem(ref, NavigationTab.feeReports, Icons.analytics_rounded, selectedTab, isRestricted: !canViewFinance),
                const SizedBox(height: 8),
                _buildNavItem(ref, NavigationTab.expenses, Icons.receipt_long_rounded, selectedTab, isRestricted: !canViewFinance),
                const SizedBox(height: 8),

                _buildNavItem(ref, NavigationTab.transport, Icons.directions_bus_rounded, selectedTab),
                const SizedBox(height: 8),
                _buildNavItem(ref, NavigationTab.exams, Icons.assignment_rounded, selectedTab),
                if (isHostelEnabled) ...[
                  const SizedBox(height: 8),
                  _buildNavItem(ref, NavigationTab.hostel, Icons.apartment_rounded, selectedTab),
                ],
                const SizedBox(height: 8),
                _buildNavItem(ref, NavigationTab.library, Icons.local_library_rounded, selectedTab),
                const SizedBox(height: 8),
                _buildNavItem(ref, NavigationTab.assistant, Icons.smart_toy_rounded, selectedTab),
                const SizedBox(height: 8),
                _buildNavItem(ref, NavigationTab.inventory, Icons.inventory_2_rounded, selectedTab, isRestricted: !canViewFinance),
                const SizedBox(height: 8),
                _buildNavItem(ref, NavigationTab.settings, Icons.settings_rounded, selectedTab),
                if (user?.role == UserRole.principal) ...[
                  const SizedBox(height: 8),
                  _buildNavItem(ref, NavigationTab.manageUsers, Icons.manage_accounts_rounded, selectedTab),
                  const SizedBox(height: 8),
                  _buildNavItem(ref, NavigationTab.activityLog, Icons.history_rounded, selectedTab),
                ],
              ],
            ),
          ),

          // Help icon at bottom
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Help & Support', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('School Management System (Antigravity SMS)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Text('Keyboard Shortcuts:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('• Ctrl + 1: Dashboard\n• Ctrl + 2: Fee Collection\n• Ctrl + 3: Admissions\n• Ctrl + 4: Students Directory\n• Ctrl + 5: Operational Expenses\n• Ctrl + 6: System Settings', style: GoogleFonts.poppins(fontSize: 12, height: 1.5)),
                        const SizedBox(height: 12),
                        Text('For assistance, contact: support@saiinfotek.com', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: GoogleFonts.poppins())),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.help_outline_rounded, color: Colors.white70, size: 22),
              tooltip: 'Help & Support',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(WidgetRef ref, NavigationTab tab, IconData icon, NavigationTab selectedTab, {bool isRestricted = false}) {
    final isSelected = tab == selectedTab;
    return HoverScale(
      scale: 1.1,
      child: Tooltip(
        message: isRestricted ? '${tab.title} (Locked - RBAC)' : tab.title,
        child: InkWell(
          onTap: () => ref.read(selectedTabProvider.notifier).state = tab,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF4C3BCF) : Colors.white70,
                  size: 22,
                ),
                if (isRestricted)
                  const Positioned(
                    right: 4,
                    top: 4,
                    child: Icon(Icons.lock_rounded, size: 12, color: Colors.orange),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
