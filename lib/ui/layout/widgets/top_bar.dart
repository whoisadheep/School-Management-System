import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/models.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/services_provider.dart';

class _GlobalSearchData {
  final List<Student> students;
  final List<Staff> staff;

  const _GlobalSearchData({required this.students, required this.staff});
}

final _globalSearchDataProvider =
    FutureProvider<_GlobalSearchData>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  final results = await Future.wait([
    dbService.getAllStudents(activeOnly: false),
    dbService.getAllStaff(page: 0, pageSize: 10000, activeOnly: false),
  ]);
  return _GlobalSearchData(
    students: results[0] as List<Student>,
    staff: results[1] as List<Staff>,
  );
});

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

          SizedBox(
            width: 440,
            child: SearchAnchor.bar(
              barHintText: 'Search students or staff by name, ID, or phone',
              barLeading: const Icon(Icons.search_rounded),
              barElevation: const WidgetStatePropertyAll(0),
              barBackgroundColor:
                  const WidgetStatePropertyAll(Color(0xFFF1F0F5)),
              barShape: const WidgetStatePropertyAll(
                StadiumBorder(),
              ),
              isFullScreen: false,
              viewConstraints:
                  const BoxConstraints(maxWidth: 520, maxHeight: 500),
              suggestionsBuilder: (context, controller) async {
                final query = controller.text.trim().toLowerCase();
                if (query.length < 2) {
                  return [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Type at least 2 characters to search students and staff.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ];
                }

                final data = await ref.read(_globalSearchDataProvider.future);
                final students = data.students
                    .where((student) => _matchesStudent(student, query))
                    .take(6)
                    .toList();
                final staff = data.staff
                    .where((member) => _matchesStaff(member, query))
                    .take(6)
                    .toList();

                if (students.isEmpty && staff.isEmpty) {
                  return [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No students or staff match “${controller.text.trim()}”.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ];
                }

                return [
                  if (students.isNotEmpty) ...[
                    _buildSearchSectionLabel('Students'),
                    ...students.map(
                      (student) => _buildStudentSuggestion(
                        context,
                        ref,
                        controller,
                        student,
                      ),
                    ),
                  ],
                  if (staff.isNotEmpty) ...[
                    _buildSearchSectionLabel('Staff'),
                    ...staff.map(
                      (member) => _buildStaffSuggestion(
                        context,
                        ref,
                        controller,
                        member,
                      ),
                    ),
                  ],
                ];
              },
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
                child: Icon(Icons.person_rounded,
                    color: Color(0xFF4C3BCF), size: 22),
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
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade600),
                onSelected: (value) {
                  if (value == 'logout') {
                    ref.read(authProvider.notifier).logout();
                  } else if (value == 'profile') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('User Profile',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Name: ${currentAdmin?.fullName ?? "System Administrator"}',
                                style: GoogleFonts.poppins()),
                            Text(
                                'Username: ${currentAdmin?.username ?? "admin"}',
                                style: GoogleFonts.poppins()),
                            Text(
                                'Role: ${currentAdmin?.role.toUpperCase() ?? "ADMIN"}',
                                style: GoogleFonts.poppins()),
                            Text('Status: Active Account',
                                style: GoogleFonts.poppins(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child:
                                  Text('Close', style: GoogleFonts.poppins())),
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
                        Text('Profile',
                            style: GoogleFonts.poppins(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('Logout',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: Colors.red)),
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

  static bool _matchesStudent(Student student, String query) {
    return [
      student.name,
      student.admissionNumber,
      student.rollNumber,
      student.id,
      student.guardianPhone,
      student.fatherPhone,
      student.motherPhone,
      student.gradeLevel,
      student.section,
    ].any((value) => value?.toLowerCase().contains(query) ?? false);
  }

  static bool _matchesStaff(Staff staff, String query) {
    return [
      staff.fullName,
      staff.staffCode,
      staff.id,
      staff.phone,
      staff.email,
      staff.designation,
      staff.departmentId,
      staff.role,
    ].any((value) => value?.toLowerCase().contains(query) ?? false);
  }

  Widget _buildSearchSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.poppins(
          color: const Color(0xFF6B7280),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _buildStudentSuggestion(
    BuildContext context,
    WidgetRef ref,
    SearchController controller,
    Student student,
  ) {
    final details = [
      student.admissionNumber ?? 'No admission ID',
      '${student.gradeLevel}${student.section == null ? '' : ' • ${student.section}'}',
      student.guardianPhone ?? student.fatherPhone,
    ].whereType<String>().join('  ·  ');
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.school_outlined)),
      title: Text(student.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      subtitle: Text(details, style: GoogleFonts.poppins(fontSize: 12)),
      onTap: () {
        controller.closeView(student.name);
        ref.read(selectedTabProvider.notifier).state = NavigationTab.students;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(pendingStudentProfileProvider.notifier).state = student;
        });
      },
    );
  }

  Widget _buildStaffSuggestion(
    BuildContext context,
    WidgetRef ref,
    SearchController controller,
    Staff staff,
  ) {
    final details = [
      staff.staffCode ?? 'No employee ID',
      staff.designation ?? staff.role.replaceAll('_', ' '),
      staff.phone,
    ].whereType<String>().join('  ·  ');
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
      title: Text(staff.fullName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      subtitle: Text(details, style: GoogleFonts.poppins(fontSize: 12)),
      onTap: () {
        controller.closeView(staff.fullName);
        ref.read(selectedTabProvider.notifier).state = NavigationTab.staff;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(pendingStaffProfileProvider.notifier).state = staff;
        });
      },
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
        return 'AI Assistant';
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
