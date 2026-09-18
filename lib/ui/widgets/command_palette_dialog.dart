import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/services_provider.dart';

enum CommandCategory {
  action('QUICK ACTIONS'),
  student('STUDENTS'),
  staff('STAFF'),
  navigation('NAVIGATION');

  final String label;
  const CommandCategory(this.label);
}

class CommandItem {
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final CommandCategory category;
  final List<String> keywords;
  final String? shortcut;
  final VoidCallback onSelect;

  CommandItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor = AppTheme.primaryPurple,
    required this.category,
    this.keywords = const [],
    this.shortcut,
    required this.onSelect,
  });
}

class CommandPaletteDialog extends ConsumerStatefulWidget {
  const CommandPaletteDialog({super.key});

  @override
  ConsumerState<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends ConsumerState<CommandPaletteDialog> {
  final TextEditingController _queryController = TextEditingController();
  late final FocusNode _searchFocusNode;
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;
  List<Staff> _allStaff = [];

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode(
      debugLabel: 'CommandPaletteFocusNode',
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _moveSelection(1);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _moveSelection(-1);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            _executeSelected();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );

    _loadStaff();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_searchFocusNode.canRequestFocus) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  Future<void> _loadStaff() async {
    try {
      final dbService = ref.read(databaseServiceProvider);
      final staff = await dbService.getAllStaff(page: 0, pageSize: 500, activeOnly: false);
      if (mounted) {
        setState(() {
          _allStaff = staff;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _queryController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _moveSelection(int delta) {
    final items = _computeFilteredItems();
    if (items.isEmpty) return;
    setState(() {
      _selectedIndex = (_selectedIndex + delta) % items.length;
      if (_selectedIndex < 0) {
        _selectedIndex = items.length - 1;
      }
    });
    _scrollToIndex(_selectedIndex);
  }

  void _scrollToIndex(int index) {
    const itemHeight = 56.0;
    final targetOffset = (index * itemHeight) - 100.0;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  void _executeSelected() {
    final items = _computeFilteredItems();
    if (items.isNotEmpty && _selectedIndex < items.length) {
      Navigator.of(context).pop();
      items[_selectedIndex].onSelect();
    }
  }

  List<CommandItem> _getStaticActions() {
    return [
      CommandItem(
        id: 'action_rapid_counter',
        title: 'Rapid Express Fee Counter',
        subtitle: 'Collect fees in 10 seconds with keyboard-only POS mode',
        icon: Icons.flash_on_rounded,
        iconColor: Colors.amber[800]!,
        category: CommandCategory.action,
        keywords: ['fees', 'collect', 'counter', 'pos', 'express', 'cash', 'pay', 'receipt'],
        shortcut: 'Ctrl+2',
        onSelect: () {
          ref.read(selectedTabProvider.notifier).state = NavigationTab.feeCollection;
        },
      ),
      CommandItem(
        id: 'action_new_admission',
        title: 'New Student Admission',
        subtitle: 'Register a new student via the guided admission wizard',
        icon: Icons.person_add_rounded,
        iconColor: Colors.blue[700]!,
        category: CommandCategory.action,
        keywords: ['admission', 'student', 'new', 'register', 'enroll', 'wizard'],
        shortcut: 'Ctrl+3',
        onSelect: () {
          ref.read(selectedTabProvider.notifier).state = NavigationTab.admission;
        },
      ),
      CommandItem(
        id: 'action_mark_attendance',
        title: 'Mark Student Attendance',
        subtitle: 'Record class roll call and attendance registers',
        icon: Icons.fact_check_rounded,
        iconColor: Colors.teal[700]!,
        category: CommandCategory.action,
        keywords: ['attendance', 'absent', 'present', 'roll call', 'class'],
        onSelect: () {
          ref.read(selectedTabProvider.notifier).state = NavigationTab.attendance;
        },
      ),
      CommandItem(
        id: 'action_record_expense',
        title: 'Record School Expense',
        subtitle: 'Log petty cash, vendor payments, and maintenance costs',
        icon: Icons.receipt_long_rounded,
        iconColor: Colors.redAccent[700]!,
        category: CommandCategory.action,
        keywords: ['expense', 'petty cash', 'spend', 'payment', 'vendor', 'ledger'],
        shortcut: 'Ctrl+5',
        onSelect: () {
          ref.read(selectedTabProvider.notifier).state = NavigationTab.expenses;
        },
      ),
      CommandItem(
        id: 'action_exam_reports',
        title: 'Exams & Performance Report Cards',
        subtitle: 'Input subject marks and generate student report card PDFs',
        icon: Icons.assignment_rounded,
        iconColor: Colors.deepOrange[700]!,
        category: CommandCategory.action,
        keywords: ['exam', 'marks', 'report card', 'grade', 'test', 'result', 'performance'],
        onSelect: () {
          ref.read(selectedTabProvider.notifier).state = NavigationTab.exams;
        },
      ),
      CommandItem(
        id: 'action_backup_db',
        title: 'Create Database Backup',
        subtitle: 'Export and safely snapshot the SQLite database file',
        icon: Icons.backup_rounded,
        iconColor: Colors.indigo[700]!,
        category: CommandCategory.action,
        keywords: ['backup', 'export', 'database', 'sqlite', 'snapshot', 'restore'],
        onSelect: () {
          ref.read(selectedTabProvider.notifier).state = NavigationTab.settings;
        },
      ),
      CommandItem(
        id: 'action_ai_assistant',
        title: 'Ask AI Support Agent',
        subtitle: 'Query school intelligence, drafting, and troubleshooting with Gemini AI',
        icon: Icons.smart_toy_rounded,
        iconColor: AppTheme.primaryPurple,
        category: CommandCategory.action,
        keywords: ['ai', 'assistant', 'gemini', 'chat', 'help', 'bot', 'support'],
        onSelect: () {
          ref.read(selectedTabProvider.notifier).state = NavigationTab.assistant;
        },
      ),
    ];
  }

  List<CommandItem> _getNavigationViews() {
    return [
      CommandItem(
        id: 'nav_dashboard',
        title: 'Financial Dashboard',
        subtitle: 'Revenue, collections, overdue dues, and KPIs',
        icon: Icons.dashboard_rounded,
        category: CommandCategory.navigation,
        keywords: ['dashboard', 'home', 'kpi', 'revenue', 'overview', 'stats', 'analytics'],
        shortcut: 'Ctrl+1',
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.dashboard,
      ),
      CommandItem(
        id: 'nav_fee_collection',
        title: 'Fee Collection & Invoicing',
        subtitle: 'Rapid Counter, custom invoicing, dual A4 receipts',
        icon: Icons.payment_rounded,
        category: CommandCategory.navigation,
        keywords: ['fees', 'collection', 'invoices', 'receipts', 'billing', 'counter'],
        shortcut: 'Ctrl+2',
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.feeCollection,
      ),
      CommandItem(
        id: 'nav_admissions',
        title: 'Student Admission Wizard',
        subtitle: 'Register new students, guardians, and documents',
        icon: Icons.how_to_reg_rounded,
        category: CommandCategory.navigation,
        keywords: ['admission', 'enrollment', 'register student', 'new student'],
        shortcut: 'Ctrl+3',
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.admission,
      ),
      CommandItem(
        id: 'nav_students',
        title: 'Student Directory',
        subtitle: 'Browse all students, profiles, ID cards, and TCs',
        icon: Icons.people_alt_rounded,
        category: CommandCategory.navigation,
        keywords: ['students', 'directory', 'profiles', 'id card', 'tc', 'transfer certificate', 'discount'],
        shortcut: 'Ctrl+4',
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.students,
      ),
      CommandItem(
        id: 'nav_staff',
        title: 'Staff & Payroll Directory',
        subtitle: 'Teachers, administrative staff, designations, and salary slips',
        icon: Icons.badge_rounded,
        category: CommandCategory.navigation,
        keywords: ['staff', 'teachers', 'faculty', 'payroll', 'salary', 'employees', 'designation'],
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.staff,
      ),
      CommandItem(
        id: 'nav_expenses',
        title: 'Expenses & Financial Ledger',
        subtitle: 'Track school disbursements, categories, and audit trail',
        icon: Icons.account_balance_wallet_rounded,
        category: CommandCategory.navigation,
        keywords: ['expenses', 'ledger', 'spending', 'transactions', 'accounts'],
        shortcut: 'Ctrl+5',
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.expenses,
      ),
      CommandItem(
        id: 'nav_classes',
        title: 'Classes, Sections & Timetable',
        subtitle: 'Setup grades, period schedules, and teacher substitutions',
        icon: Icons.class_rounded,
        category: CommandCategory.navigation,
        keywords: ['classes', 'sections', 'grades', 'timetable', 'periods', 'substitutions', 'subjects'],
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.classes,
      ),
      CommandItem(
        id: 'nav_fee_structure',
        title: 'Fee Structure Configuration',
        subtitle: 'Fee heads, recurring categories, fines, and discount rules',
        icon: Icons.tune_rounded,
        category: CommandCategory.navigation,
        keywords: ['fee structure', 'fee heads', 'pricing', 'fines', 'discounts', 'categories'],
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.feeStructure,
      ),
      CommandItem(
        id: 'nav_fee_reports',
        title: 'Fee Reports & Analytics',
        subtitle: 'Defaulter lists, collection breakdown, and Excel exports',
        icon: Icons.bar_chart_rounded,
        category: CommandCategory.navigation,
        keywords: ['reports', 'fee reports', 'defaulters', 'analytics', 'excel export', 'summary'],
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.feeReports,
      ),
      CommandItem(
        id: 'nav_attendance',
        title: 'Student Attendance',
        subtitle: 'Daily attendance logs, monthly registers, and absence reports',
        icon: Icons.calendar_today_rounded,
        category: CommandCategory.navigation,
        keywords: ['attendance', 'present', 'absent', 'register', 'daily'],
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.attendance,
      ),
      CommandItem(
        id: 'nav_transport',
        title: 'Transport & Fleet Management',
        subtitle: 'Vehicles, bus routes, stops, and student passenger lists',
        icon: Icons.directions_bus_rounded,
        category: CommandCategory.navigation,
        keywords: ['transport', 'bus', 'vehicles', 'routes', 'stops', 'fleet', 'driver'],
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.transport,
      ),
      CommandItem(
        id: 'nav_exams',
        title: 'Exams & Performance',
        subtitle: 'Marks entry, grading scales, and report card generators',
        icon: Icons.school_rounded,
        category: CommandCategory.navigation,
        keywords: ['exams', 'marks', 'grades', 'report card', 'results', 'terms'],
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.exams,
      ),
      CommandItem(
        id: 'nav_hostel',
        title: 'Hostel Management',
        subtitle: 'Hostel blocks, rooms, bed capacity, and student allocations',
        icon: Icons.hotel_rounded,
        category: CommandCategory.navigation,
        keywords: ['hostel', 'rooms', 'beds', 'blocks', 'boarding', 'allocation'],
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.hostel,
      ),
      CommandItem(
        id: 'nav_library',
        title: 'Library Management',
        subtitle: 'Book catalog, issues, returns, and borrower records',
        icon: Icons.local_library_rounded,
        category: CommandCategory.navigation,
        keywords: ['library', 'books', 'catalog', 'issue', 'return', 'borrowers'],
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.library,
      ),
      CommandItem(
        id: 'nav_inventory',
        title: 'Inventory & Assets',
        subtitle: 'Stationery, classroom assets, equipment, and stock levels',
        icon: Icons.inventory_2_rounded,
        category: CommandCategory.navigation,
        keywords: ['inventory', 'stock', 'assets', 'supplies', 'stationery'],
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.inventory,
      ),
      CommandItem(
        id: 'nav_assistant',
        title: 'AI Support Agent',
        subtitle: 'Gemini AI assistant for queries, drafts, and administrative insights',
        icon: Icons.chat_bubble_rounded,
        category: CommandCategory.navigation,
        keywords: ['assistant', 'ai', 'gemini', 'chat', 'help'],
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.assistant,
      ),
      CommandItem(
        id: 'nav_manage_users',
        title: 'Manage Admin Users',
        subtitle: 'Create operator accounts, reset passwords, and assign roles',
        icon: Icons.admin_panel_settings_rounded,
        category: CommandCategory.navigation,
        keywords: ['admin users', 'users', 'roles', 'passwords', 'security', 'operators'],
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.manageUsers,
      ),
      CommandItem(
        id: 'nav_activity_log',
        title: 'Activity & Audit Log',
        subtitle: 'System audit logs, operator changes, and security events',
        icon: Icons.history_rounded,
        category: CommandCategory.navigation,
        keywords: ['audit', 'activity log', 'history', 'security', 'logs', 'changes'],
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.activityLog,
      ),
      CommandItem(
        id: 'nav_settings',
        title: 'System Settings',
        subtitle: 'School profile, branding logo, backup/restore, and export paths',
        icon: Icons.settings_rounded,
        category: CommandCategory.navigation,
        keywords: ['settings', 'school profile', 'logo', 'branding', 'backup', 'export path'],
        shortcut: 'Ctrl+6',
        onSelect: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.settings,
      ),
    ];
  }

  List<CommandItem> _computeFilteredItems() {
    final query = _queryController.text.trim().toLowerCase();
    final allActions = _getStaticActions();
    final allNav = _getNavigationViews();

    if (query.isEmpty) {
      // Return top quick actions and key navigation destinations
      return [
        ...allActions.take(4),
        allNav.firstWhere((n) => n.id == 'nav_dashboard'),
        allNav.firstWhere((n) => n.id == 'nav_fee_collection'),
        allNav.firstWhere((n) => n.id == 'nav_students'),
        allNav.firstWhere((n) => n.id == 'nav_attendance'),
        allNav.firstWhere((n) => n.id == 'nav_settings'),
      ];
    }

    final result = <CommandItem>[];

    // 1. Actions matching query
    for (final a in allActions) {
      if (a.title.toLowerCase().contains(query) ||
          (a.subtitle?.toLowerCase().contains(query) ?? false) ||
          a.keywords.any((k) => k.toLowerCase().contains(query))) {
        result.add(a);
      }
    }

    // 2. Students matching query
    final studentsList = ref.watch(studentsListProvider).value ?? <Student>[];
    final matchedStudents = studentsList.where((s) {
      final name = s.name.toLowerCase();
      final adm = s.admissionNumber?.toLowerCase() ?? '';
      final roll = s.rollNumber?.toLowerCase() ?? '';
      final grade = s.gradeLevel.toLowerCase();
      final phone = s.guardianPhone ?? s.fatherPhone ?? '';
      return name.contains(query) || adm.contains(query) || roll.contains(query) || grade.contains(query) || phone.contains(query);
    }).take(4).toList();

    for (final s in matchedStudents) {
      // Option A: View profile
      result.add(
        CommandItem(
          id: 'student_profile_${s.id}',
          title: s.name,
          subtitle: 'Adm: ${s.admissionNumber ?? "N/A"} • Roll: ${s.rollNumber ?? "N/A"} • ${s.gradeLevel} ➔ View Profile',
          icon: Icons.person_rounded,
          iconColor: AppTheme.primaryPurple,
          category: CommandCategory.student,
          keywords: [s.name, s.admissionNumber ?? '', s.rollNumber ?? '', s.gradeLevel],
          onSelect: () {
            ref.read(selectedTabProvider.notifier).state = NavigationTab.students;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(pendingStudentProfileProvider.notifier).state = s;
            });
          },
        ),
      );
      // Option B: Collect fee
      result.add(
        CommandItem(
          id: 'student_fee_${s.id}',
          title: 'Collect Fee: ${s.name}',
          subtitle: 'Open Rapid Counter directly for ${s.name} (${s.gradeLevel})',
          icon: Icons.flash_on_rounded,
          iconColor: Colors.amber[800]!,
          category: CommandCategory.student,
          keywords: [s.name, 'fee', 'collect', s.admissionNumber ?? ''],
          onSelect: () {
            ref.read(selectedTabProvider.notifier).state = NavigationTab.feeCollection;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(pendingRapidFeeStudentProvider.notifier).state = s;
            });
          },
        ),
      );
    }

    // 3. Staff matching query
    final matchedStaff = _allStaff.where((st) {
      final name = st.fullName.toLowerCase();
      final code = st.staffCode?.toLowerCase() ?? '';
      final desig = st.designation?.toLowerCase() ?? '';
      final phone = st.phone?.toLowerCase() ?? '';
      return name.contains(query) || code.contains(query) || desig.contains(query) || phone.contains(query);
    }).take(3).toList();

    for (final st in matchedStaff) {
      result.add(
        CommandItem(
          id: 'staff_profile_${st.id}',
          title: st.fullName,
          subtitle: '${st.designation ?? st.role} • Code: ${st.staffCode ?? "N/A"} ➔ View Staff Profile',
          icon: Icons.badge_rounded,
          iconColor: Colors.teal[700]!,
          category: CommandCategory.staff,
          keywords: [st.fullName, st.staffCode ?? '', st.designation ?? ''],
          onSelect: () {
            ref.read(selectedTabProvider.notifier).state = NavigationTab.staff;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(pendingStaffProfileProvider.notifier).state = st;
            });
          },
        ),
      );
    }

    // 4. Navigation Views matching query
    for (final n in allNav) {
      if (n.title.toLowerCase().contains(query) ||
          (n.subtitle?.toLowerCase().contains(query) ?? false) ||
          n.keywords.any((k) => k.toLowerCase().contains(query))) {
        result.add(n);
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _computeFilteredItems();

    if (_selectedIndex >= filteredItems.length) {
      _selectedIndex = 0;
    }

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
          border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.25), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Input Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.divider)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.search_rounded, color: AppTheme.primaryPurple, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      onChanged: (_) => setState(() => _selectedIndex = 0),
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: "Type a command, student, or view... (e.g. 'Rahul', 'Fees', 'Backup')",
                        hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textHint),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_queryController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textSecondary),
                      onPressed: () {
                        _queryController.clear();
                        setState(() => _selectedIndex = 0);
                      },
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Text(
                      'ESC',
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            // Results List
            Flexible(
              child: filteredItems.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 44, color: AppTheme.textHint.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            'No matching commands or records found',
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try searching a student roll number, staff name, or navigation tab.',
                            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isSelected = index == _selectedIndex;

                        // Show section header if this item starts a new category
                        final isFirstInCategory = index == 0 || filteredItems[index - 1].category != item.category;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isFirstInCategory)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                                child: Text(
                                  item.category.label,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textSecondary,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                item.onSelect();
                              },
                              onHover: (hovered) {
                                if (hovered && _selectedIndex != index) {
                                  setState(() => _selectedIndex = index);
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.primaryPurple.withValues(alpha: 0.1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: isSelected ? Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)) : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: item.iconColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(item.icon, size: 18, color: item.iconColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                              color: isSelected ? AppTheme.primaryPurple : AppTheme.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (item.subtitle != null)
                                            Text(
                                              item.subtitle!,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: AppTheme.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (item.shortcut != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.bgSurface,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppTheme.divider),
                                        ),
                                        child: Text(
                                          item.shortcut!,
                                          style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryPurple,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Enter',
                                              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.keyboard_return_rounded, size: 12, color: Colors.white),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            // Keyboard Hints Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: AppTheme.divider)),
              ),
              child: Row(
                children: [
                  _buildFooterHint('↑ ↓', 'Navigate'),
                  const SizedBox(width: 14),
                  _buildFooterHint('↵', 'Select'),
                  const SizedBox(width: 14),
                  _buildFooterHint('Esc', 'Exit'),
                  const Spacer(),
                  Text(
                    'Eduvia Command Palette',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textHint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterHint(String key, String desc) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Text(
            key,
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          desc,
          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
