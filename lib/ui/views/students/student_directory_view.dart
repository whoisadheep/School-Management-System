import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../services/csv_export_service.dart';
import '../../../services/file_storage_service.dart';
import '../../../services/database_seeder.dart';
import '../../../services/report_generator.dart';
import '../../../services/app_logger.dart';
import '../../layout/widgets/glass_card.dart';
import '../fees/student_fee_ledger_view.dart';
import '../attendance/student_attendance_history_dialog.dart';
import '../../../core/auth/permission_helper.dart';

final studentSearchQueryProvider = StateProvider<String>((ref) => '');
final studentGradeFilterProvider = StateProvider<String>((ref) => 'All');
final studentStatusFilterProvider = StateProvider<String>((ref) => 'Active');

final studentDirectoryProvider =
    FutureProvider<List<Student>>((ref) async {
  final query = ref.watch(studentSearchQueryProvider);
  final grade = ref.watch(studentGradeFilterProvider);
  final statusFilter = ref.watch(studentStatusFilterProvider);
  final dbService = ref.watch(databaseServiceProvider);

  List<Student> list;
  if (query.isEmpty) {
    list = await dbService.getAllStudents(activeOnly: false);
  } else {
    list = await dbService.searchStudents(query);
  }

  if (grade != 'All') {
    list = list
        .where((s) => s.gradeLevel.toLowerCase() == grade.toLowerCase())
        .toList();
  }

  if (statusFilter == 'Active') {
    list = list.where((s) => s.isActive && !s.isAlumni).toList();
  } else if (statusFilter == 'Alumni') {
    list = list.where((s) => s.isAlumni || !s.isActive).toList();
  }

  return list;
});

class StudentDirectoryView extends ConsumerStatefulWidget {
  const StudentDirectoryView({super.key});

  @override
  ConsumerState<StudentDirectoryView> createState() =>
      _StudentDirectoryViewState();
}

class _StudentDirectoryViewState extends ConsumerState<StudentDirectoryView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _glowAnimation;

  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  final List<String> _grades = [
    'All',
    'Nursery',
    'LKG',
    'UKG',
    'Grade 1',
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Grade 6',
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Student?>(pendingStudentProfileProvider, (previous, student) {
      if (student == null) return;
      ref.read(pendingStudentProfileProvider.notifier).state = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showStudentProfileDialog(context, student);
        }
      });
    });
    final studentsAsync = ref.watch(studentDirectoryProvider);
    final selectedGrade = ref.watch(studentGradeFilterProvider);

    return Stack(
      children: [
        Positioned(
          top: -150,
          left: -100,
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _glowAnimation.value,
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.primaryPurple.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: -100,
          right: -100,
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.8 - _glowAnimation.value,
                child: Container(
                  width: 600,
                  height: 600,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.info.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B4BC4), Color(0xFF7B68EE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student Directory',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SEARCH, FILTER, AND MANAGE ALL REGISTERED STUDENT RECORDS',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Search & Filter Bar ──
              GlassCard(
                padding: const EdgeInsets.all(24),
                borderRadius: 16.0,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        onChanged: (val) {
                          if (_debounceTimer?.isActive ?? false) {
                            _debounceTimer!.cancel();
                          }
                          _debounceTimer =
                              Timer(const Duration(milliseconds: 300), () {
                            ref
                                .read(studentSearchQueryProvider.notifier)
                                .state = val.trim();
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Search by Name, Admission No, or Phone',
                          labelStyle: GoogleFonts.poppins(
                              color: AppTheme.textHint, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                const BorderSide(color: AppTheme.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                const BorderSide(color: AppTheme.primaryPurple),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Grade Filter Dropdown
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedGrade,
                        dropdownColor: Colors.white,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Grade Filter',
                          labelStyle: GoogleFonts.poppins(
                              color: AppTheme.textHint, fontSize: 13),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                const BorderSide(color: AppTheme.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                const BorderSide(color: AppTheme.primaryPurple),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        items: _grades.map((g) {
                          return DropdownMenuItem(value: g, child: Text(g));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            ref
                                .read(studentGradeFilterProvider.notifier)
                                .state = val;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Status / Alumni Filter Dropdown
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: ref.watch(studentStatusFilterProvider),
                        dropdownColor: Colors.white,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Status',
                          labelStyle: GoogleFonts.poppins(
                              color: AppTheme.textHint, fontSize: 13),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                const BorderSide(color: AppTheme.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                const BorderSide(color: AppTheme.primaryPurple),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Active', child: Text('Active Students')),
                          DropdownMenuItem(value: 'Alumni', child: Text('Alumni / Inactive')),
                          DropdownMenuItem(value: 'All', child: Text('All Records')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(studentStatusFilterProvider.notifier).state = val;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Bulk Class Promotion Button
                    ElevatedButton.icon(
                      onPressed: () => _showClassPromotionDialog(context),
                      icon: const Icon(Icons.published_with_changes_rounded, size: 16),
                      label: Text(
                        'PROMOTIONS',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          fontSize: 11,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 12),

                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final students =
                              await ref.read(studentDirectoryProvider.future);
                          final exporter = CsvExportService();
                          final file =
                              await exporter.exportStudentsToCsv(students);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Directory exported to CSV: ${file.path}',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                backgroundColor: AppTheme.primaryPurple,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Error exporting CSV: $e',
                                      style: GoogleFonts.poppins()),
                                  backgroundColor: AppTheme.error),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.file_download_rounded, size: 16),
                      label: Text(
                        'EXPORT CSV',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          fontSize: 11,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryPurple,
                        side: const BorderSide(color: AppTheme.primaryPurple),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                    ),


                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(studentDirectoryProvider);
                      },
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: Text(
                        'REFRESH',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          fontSize: 11,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: AppTheme.divider),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Student Data Table ──
              Expanded(
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 16.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 20),
                        child: Text(
                          'DIRECTORY RESULTS',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const Divider(
                          color: AppTheme.divider, height: 1, thickness: 1),
                      Expanded(
                        child: studentsAsync.when(
                          data: (students) {
                            if (students.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 40),
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primarySoft,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.search_off_rounded,
                                        size: 48,
                                        color: AppTheme.primaryPurple,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'No students found',
                                      style: GoogleFonts.poppins(
                                        color: AppTheme.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your filters or search query.',
                                      style: GoogleFonts.poppins(
                                        color: AppTheme.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                  ],
                                ),
                              );
                            }

                            return SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth:
                                        MediaQuery.of(context).size.width - 320,
                                  ),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                        Colors.white.withValues(alpha: 0.02)),
                                    dataRowMinHeight: 64,
                                    dataRowMaxHeight: 64,
                                    headingTextStyle: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                      letterSpacing: 1.0,
                                      color: AppTheme.textSecondary,
                                    ),
                                    dividerThickness: 1,
                                    horizontalMargin: 24,
                                    columns: const [
                                      DataColumn(label: Text('ADMISSION NO')),
                                      DataColumn(label: Text('STUDENT NAME')),
                                      DataColumn(label: Text('GRADE & SEC')),
                                      DataColumn(label: Text('PARENT PHONE')),
                                      DataColumn(label: Text('BALANCE')),
                                      DataColumn(label: Text('STATUS')),
                                      DataColumn(label: Text('ACTIONS')),
                                    ],
                                    rows: students.map((student) {
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(
                                            student.admissionNumber ?? '—',
                                            style: GoogleFonts.poppins(
                                                color: AppTheme.textPrimary,
                                                fontWeight: FontWeight.w500),
                                          )),
                                          DataCell(Text(
                                            '${student.firstName ?? student.name} ${student.lastName ?? ""}'
                                                .trim(),
                                            style: GoogleFonts.poppins(
                                                color: AppTheme.textPrimary,
                                                fontWeight: FontWeight.w600),
                                          )),
                                          DataCell(Text(
                                            '${student.gradeLevel}${student.section != null ? " (${student.section})" : ""}',
                                            style: GoogleFonts.poppins(
                                                color: AppTheme.textPrimary),
                                          )),
                                          DataCell(Text(
                                            student.guardianPhone ??
                                                student.fatherPhone ??
                                                student.motherPhone ??
                                                '—',
                                            style: GoogleFonts.poppins(
                                                color: AppTheme.textPrimary),
                                          )),
                                          DataCell(Text(
                                            '₹${student.currentBalance.toStringAsFixed(2)}',
                                            style: GoogleFonts.poppins(
                                              color: student.currentBalance > 0
                                                  ? AppTheme.error
                                                  : AppTheme.success,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          )),
                                          DataCell(Text(
                                            student.isActive
                                                ? 'ACTIVE'
                                                : 'INACTIVE',
                                            style: GoogleFonts.poppins(
                                              color: student.isActive
                                                  ? AppTheme.success
                                                  : AppTheme.error,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11,
                                            ),
                                          )),
                                          DataCell(
                                            Row(
                                              children: [
                                                TextButton(
                                                  onPressed: () =>
                                                      _showStudentProfileDialog(
                                                          context, student),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        AppTheme.primaryPurple,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12),
                                                  ),
                                                  child: Text(
                                                    'VIEW PROFILE',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: Icon(
                                                    student.isActive
                                                        ? Icons.block_rounded
                                                        : Icons
                                                            .check_circle_outline_rounded,
                                                    size: 16,
                                                    color: student.isActive
                                                        ? AppTheme.error
                                                        : AppTheme.success,
                                                  ),
                                                  tooltip: student.isActive
                                                      ? 'Deactivate Student'
                                                      : 'Reactivate Student',
                                                  onPressed: () =>
                                                      _toggleStudentStatus(
                                                          student),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            );
                          },
                          loading: () => const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primaryPurple, strokeWidth: 2),
                          ),
                          error: (err, stack) => Center(
                            child: Text(
                              'Error loading directory: $err',
                              style: GoogleFonts.poppins(color: AppTheme.error),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showStudentProfileDialog(BuildContext context, Student student) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 850,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppTheme.elevatedShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 1. Banner & Header ──
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF5B4BC4), Color(0xFF7B68EE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -40,
                    left: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.bgSurface, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.primarySoft,
                        backgroundImage: (student.photographPath != null &&
                                student.photographPath!.isNotEmpty &&
                                File(student.photographPath!).existsSync())
                            ? FileImage(File(student.photographPath!))
                            : null,
                        child: (student.photographPath == null ||
                                student.photographPath!.isEmpty ||
                                !File(student.photographPath!).existsSync())
                            ? Text(
                                student.name.isNotEmpty
                                    ? student.name[0].toUpperCase()
                                    : 'S',
                                style: GoogleFonts.poppins(
                                  fontSize: 40,
                                  color: AppTheme.primaryPurple,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              
              // ── 2. Name & Title ──
              Padding(
                padding: const EdgeInsets.only(top: 50, left: 40, right: 40, bottom: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '${student.firstName ?? student.name} ${student.lastName ?? ""}'.trim(),
                              style: GoogleFonts.poppins(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: student.isActive ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: student.isActive ? AppTheme.success : AppTheme.error),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    student.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                    size: 14,
                                    color: student.isActive ? AppTheme.success : AppTheme.error,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    student.isActive ? 'ACTIVE' : 'INACTIVE',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: student.isActive ? AppTheme.success : AppTheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${student.gradeLevel}${student.section != null ? " - Sec ${student.section}" : ""}  •  Adm. No: ${student.admissionNumber ?? "N/A"}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _generateStudentIdCard(context, student),
                          icon: const Icon(Icons.badge_rounded, size: 14),
                          label: const Text('ID CARD'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryPurple,
                            side: const BorderSide(color: AppTheme.primaryPurple),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        if (student.isActive && !student.isAlumni)
                          ElevatedButton.icon(
                            onPressed: () => _showIssueTcDialog(context, student),
                            icon: const Icon(Icons.verified_user_rounded, size: 14),
                            label: const Text('ISSUE TC'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showEditStudentDialog(context, student);
                          },
                          icon: const Icon(Icons.edit_rounded, size: 14),
                          label: Text(
                            'EDIT PROFILE',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // ── 3. Data Sections (Grid Layout) ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoCard(
                              title: 'Personal Details',
                              icon: Icons.person_outline_rounded,
                              children: [
                                _buildDetailRow('Date of Birth', student.dob ?? '—'),
                                _buildDetailRow('Gender', student.gender ?? '—'),
                                _buildDetailRow('Blood Group', student.bloodGroup ?? '—'),
                                _buildDetailRow('Religion / Caste', '${student.religion ?? "—"} / ${student.caste ?? "—"}'),
                                _buildDetailRow('Aadhaar Number', student.aadhaarNumber ?? '—'),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildInfoCard(
                              title: 'Academic Details',
                              icon: Icons.school_outlined,
                              children: [
                                _buildDetailRow('Roll Number', student.rollNumber ?? '—'),
                                _buildDetailRow('Grade', student.gradeLevel),
                                _buildDetailRow('Section', student.section ?? '—'),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildAttendanceCard(context, student),
                            if (student.isAlumni || student.tcNumber != null) ...[
                              const SizedBox(height: 24),
                              _buildInfoCard(
                                title: 'Transfer Certificate & Alumni Info',
                                icon: Icons.history_edu_rounded,
                                children: [
                                  _buildDetailRow('Status', student.isAlumni ? 'Alumni / Graduated' : 'Inactive'),
                                  _buildDetailRow('TC Number', student.tcNumber ?? '—'),
                                  _buildDetailRow('TC Date', student.tcDate ?? '—'),
                                ],
                              ),
                            ],
                            const SizedBox(height: 24),
                            _buildStudentDocumentsCard(context, student),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoCard(
                              title: 'Family & Contact',
                              icon: Icons.family_restroom_rounded,
                              children: [
                                _buildDetailRow('Father\'s Name', student.fatherName ?? '—'),
                                _buildDetailRow('Father\'s Phone', student.fatherPhone ?? '—'),
                                _buildDetailRow('Mother\'s Name', student.motherName ?? '—'),
                                _buildDetailRow('Mother\'s Phone', student.motherPhone ?? '—'),
                                _buildDetailRow('Guardian Phone', student.guardianPhone ?? '—'),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildInfoCard(
                              title: 'Addresses',
                              icon: Icons.location_on_outlined,
                              children: [
                                _buildDetailRow('Residential Address', student.residentialAddress ?? '—'),
                                _buildDetailRow('Permanent Address', student.permanentAddress ?? '—'),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: student.currentBalance > 0 ? AppTheme.error.withValues(alpha: 0.05) : AppTheme.success.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: student.currentBalance > 0 ? AppTheme.error.withValues(alpha: 0.3) : AppTheme.success.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: student.currentBalance > 0 ? AppTheme.error.withValues(alpha: 0.1) : AppTheme.success.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      student.currentBalance > 0 ? Icons.account_balance_wallet_rounded : Icons.check_circle_rounded,
                                      color: student.currentBalance > 0 ? AppTheme.error : AppTheme.success,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Outstanding Balance',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          '₹${student.currentBalance.toStringAsFixed(2)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: student.currentBalance > 0 ? AppTheme.error : AppTheme.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildStudentDiscountsAndNetFeeCard(context, student),
                            const SizedBox(height: 16),
                            _buildStudentTransportAssignmentCard(context, student),
                            const SizedBox(height: 16),
                            // View Fee Ledger Button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop(); // Close profile dialog
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => StudentFeeLedgerView(student: student),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                                label: Text(
                                  'View Fee Ledger',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryPurple,
                                  side: const BorderSide(color: AppTheme.primaryPurple),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  void _showEditStudentDialog(BuildContext context, Student student) {
    final firstNameController =
        TextEditingController(text: student.firstName ?? student.name);
    final lastNameController =
        TextEditingController(text: student.lastName ?? '');
    final photoPathController =
        TextEditingController(text: student.photographPath ?? '');
    final dobController = TextEditingController(text: student.dob ?? '');
    final casteController = TextEditingController(text: student.caste ?? '');
    final religionController =
        TextEditingController(text: student.religion ?? '');
    final aadhaarController =
        TextEditingController(text: student.aadhaarNumber ?? '');
    final admissionNoController =
        TextEditingController(text: student.admissionNumber ?? '');
    final rollNoController =
        TextEditingController(text: student.rollNumber ?? '');
    final sectionController =
        TextEditingController(text: student.section ?? '');

    final fatherNameController =
        TextEditingController(text: student.fatherName ?? '');
    final fatherOccController =
        TextEditingController(text: student.fatherOccupation ?? '');
    final fatherPhoneController =
        TextEditingController(text: student.fatherPhone ?? '');

    final motherNameController =
        TextEditingController(text: student.motherName ?? '');
    final motherOccController =
        TextEditingController(text: student.motherOccupation ?? '');
    final motherPhoneController =
        TextEditingController(text: student.motherPhone ?? '');

    final guardianPhoneController =
        TextEditingController(text: student.guardianPhone ?? '');
    final resAddrController =
        TextEditingController(text: student.residentialAddress ?? '');
    final permAddrController =
        TextEditingController(text: student.permanentAddress ?? '');

    String selectedGrade = student.gradeLevel;
    String selectedGender = student.gender ?? 'Male';
    String selectedBlood = student.bloodGroup ?? 'A+';

    final grades = [
      'Nursery',
      'LKG',
      'UKG',
      'Grade 1',
      'Grade 2',
      'Grade 3',
      'Grade 4',
      'Grade 5',
      'Grade 6',
      'Grade 7',
      'Grade 8',
      'Grade 9',
      'Grade 10',
    ];
    if (!grades.contains(selectedGrade)) grades.add(selectedGrade);

    final genders = ['Male', 'Female', 'Other'];
    if (!genders.contains(selectedGender)) genders.add(selectedGender);

    final bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
    if (!bloodGroups.contains(selectedBlood)) bloodGroups.add(selectedBlood);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: AppTheme.divider)),
            title: Row(
              children: [
                const Icon(Icons.edit_note_rounded,
                    color: AppTheme.primaryPurple, size: 22),
                const SizedBox(width: 10),
                Text(
                  'EDIT COMPLETE STUDENT RECORD',
                  style: GoogleFonts.poppins(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 650,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('1. IDENTITY & DEMOGRAPHICS'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              AppTheme.primaryPurple.withValues(alpha: 0.15),
                          backgroundImage: (photoPathController
                                      .text.isNotEmpty &&
                                  File(photoPathController.text).existsSync())
                              ? FileImage(File(photoPathController.text))
                              : null,
                          child: (photoPathController.text.isEmpty ||
                                  !File(photoPathController.text).existsSync())
                              ? const Icon(Icons.person_rounded,
                                  color: AppTheme.primaryPurple, size: 24)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: photoPathController,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary),
                            decoration:
                                _buildEditInputDecoration('Photograph Path'),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              allowMultiple: false,
                            );
                            if (result != null &&
                                result.files.single.path != null) {
                              try {
                                final newPath = await FileStorageService.copyFileToAppDirectory(result.files.single.path!);
                                photoPathController.text = newPath;
                                setDialogState(() {});
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to save image: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.folder_open_rounded, size: 16),
                          label: Text('BROWSE FILE EXPLORER',
                              style: GoogleFonts.poppins(
                                  fontSize: 10, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryPurple,
                            side:
                                const BorderSide(color: AppTheme.primaryPurple),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: firstNameController,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary),
                            decoration: _buildEditInputDecoration('First Name'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: lastNameController,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary),
                            decoration: _buildEditInputDecoration('Last Name'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dobController,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary),
                            decoration:
                                _buildEditInputDecoration('DOB (YYYY-MM-DD)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedGender,
                            dropdownColor: Colors.white,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary),
                            decoration: _buildEditInputDecoration('Gender'),
                            items: genders
                                .map((g) =>
                                    DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null)
                                setDialogState(() => selectedGender = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedBlood,
                            dropdownColor: Colors.white,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary),
                            decoration:
                                _buildEditInputDecoration('Blood Group'),
                            items: bloodGroups
                                .map((b) =>
                                    DropdownMenuItem(value: b, child: Text(b)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null)
                                setDialogState(() => selectedBlood = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: casteController,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary),
                            decoration: _buildEditInputDecoration('Caste'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: religionController,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary),
                            decoration: _buildEditInputDecoration('Religion'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: aadhaarController,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary),
                            decoration:
                                _buildEditInputDecoration('Aadhaar Number'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionHeader('2. ACADEMIC DETAILS'),
                    const SizedBox(height: 10),
                    Consumer(
                      builder: (context, ref, child) {
                        final classesAsync = ref.watch(classListProvider);
                        return classesAsync.when(
                          data: (classList) {
                            final currentClass = classList.where((c) => c.id == student.classId || c.name.toLowerCase() == selectedGrade.toLowerCase()).firstOrNull;
                            final activeClassId = currentClass?.id ?? classList.firstOrNull?.id;
                            final sectionsAsync = activeClassId != null ? ref.watch(sectionsForClassProvider(activeClassId)) : null;

                            return Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: currentClass?.id,
                                    dropdownColor: Colors.white,
                                    style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                                    decoration: _buildEditInputDecoration('Class / Grade'),
                                    items: classList
                                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        final selCls = classList.firstWhere((c) => c.id == val);
                                        setDialogState(() {
                                          selectedGrade = selCls.name;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: sectionsAsync != null
                                      ? sectionsAsync.when(
                                          data: (secList) {
                                            final currentSec = secList.where((s) => s.id == student.sectionId || s.name == sectionController.text.trim()).firstOrNull;
                                            return DropdownButtonFormField<String>(
                                              initialValue: currentSec?.id,
                                              dropdownColor: Colors.white,
                                              style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                                              decoration: _buildEditInputDecoration('Section'),
                                              items: secList
                                                  .map((s) => DropdownMenuItem(value: s.id, child: Text('Section ${s.name}')))
                                                  .toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  final selSec = secList.firstWhere((s) => s.id == val);
                                                  setDialogState(() {
                                                    sectionController.text = selSec.name;
                                                  });
                                                }
                                              },
                                            );
                                          },
                                          loading: () => const CircularProgressIndicator(),
                                          error: (_, __) => TextField(
                                            controller: sectionController,
                                            style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                                            decoration: _buildEditInputDecoration('Section'),
                                          ),
                                        )
                                      : TextField(
                                          controller: sectionController,
                                          style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                                          decoration: _buildEditInputDecoration('Section'),
                                        ),
                                ),
                              ],
                            );
                          },
                          loading: () => const CircularProgressIndicator(),
                          error: (_, __) => Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: TextEditingController(text: selectedGrade),
                                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                                  decoration: _buildEditInputDecoration('Grade Level'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: sectionController,
                                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                                  decoration: _buildEditInputDecoration('Section'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: admissionNoController,
                            style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                            decoration: _buildEditInputDecoration('Admission No.'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: rollNoController,
                            style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                            decoration: _buildEditInputDecoration('Roll No.'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionHeader('3. PARENT & GUARDIAN DETAILS'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: fatherNameController,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary),
                            decoration:
                                _buildEditInputDecoration('Father Name'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: fatherOccController,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary),
                            decoration:
                                _buildEditInputDecoration('Father Occupation'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: fatherPhoneController,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary),
                            decoration:
                                _buildEditInputDecoration('Father Phone'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: motherNameController,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary),
                            decoration:
                                _buildEditInputDecoration('Mother Name'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: motherOccController,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary),
                            decoration:
                                _buildEditInputDecoration('Mother Occupation'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: motherPhoneController,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textPrimary),
                            decoration:
                                _buildEditInputDecoration('Mother Phone'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: guardianPhoneController,
                      style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                      decoration: _buildEditInputDecoration(
                          'Primary Guardian Phone (SMS Alerts)'),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionHeader('4. ADDRESS DETAILS'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: resAddrController,
                      style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                      decoration:
                          _buildEditInputDecoration('Residential Address'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: permAddrController,
                      style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                      decoration:
                          _buildEditInputDecoration('Permanent Address'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.divider)),
                child: Text('CANCEL', style: GoogleFonts.poppins(fontSize: 11)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final fn = firstNameController.text.trim();
                  final ln = lastNameController.text.trim();
                  if (fn.isEmpty) return;

                  final updatedStudent = student.copyWith(
                    name: '$fn $ln'.trim(),
                    firstName: fn,
                    lastName: ln,
                    photographPath: photoPathController.text.trim().isNotEmpty
                        ? photoPathController.text.trim()
                        : null,
                    dob: dobController.text.trim().isNotEmpty
                        ? dobController.text.trim()
                        : null,
                    gender: selectedGender,
                    bloodGroup: selectedBlood,
                    caste: casteController.text.trim().isNotEmpty
                        ? casteController.text.trim()
                        : null,
                    religion: religionController.text.trim().isNotEmpty
                        ? religionController.text.trim()
                        : null,
                    aadhaarNumber: aadhaarController.text.trim().isNotEmpty
                        ? aadhaarController.text.trim()
                        : null,
                    admissionNumber:
                        admissionNoController.text.trim().isNotEmpty
                            ? admissionNoController.text.trim()
                            : null,
                    rollNumber: rollNoController.text.trim().isNotEmpty
                        ? rollNoController.text.trim()
                        : null,
                    gradeLevel: selectedGrade,
                    section: sectionController.text.trim().isNotEmpty
                        ? sectionController.text.trim()
                        : null,
                    classId: (ref.read(classListProvider).value?.where((c) => c.name.toLowerCase() == selectedGrade.toLowerCase()).firstOrNull)?.id,
                    sectionId: sectionController.text.trim().isNotEmpty
                        ? 'sec-${((ref.read(classListProvider).value?.where((c) => c.name.toLowerCase() == selectedGrade.toLowerCase()).firstOrNull)?.id ?? "").replaceFirst("cls-", "")}-${sectionController.text.trim().toLowerCase()}'
                        : null,
                    fatherName: fatherNameController.text.trim().isNotEmpty
                        ? fatherNameController.text.trim()
                        : null,
                    fatherOccupation: fatherOccController.text.trim().isNotEmpty
                        ? fatherOccController.text.trim()
                        : null,
                    fatherPhone: fatherPhoneController.text.trim().isNotEmpty
                        ? fatherPhoneController.text.trim()
                        : null,
                    motherName: motherNameController.text.trim().isNotEmpty
                        ? motherNameController.text.trim()
                        : null,
                    motherOccupation: motherOccController.text.trim().isNotEmpty
                        ? motherOccController.text.trim()
                        : null,
                    motherPhone: motherPhoneController.text.trim().isNotEmpty
                        ? motherPhoneController.text.trim()
                        : null,
                    guardianPhone:
                        guardianPhoneController.text.trim().isNotEmpty
                            ? guardianPhoneController.text.trim()
                            : null,
                    residentialAddress: resAddrController.text.trim().isNotEmpty
                        ? resAddrController.text.trim()
                        : null,
                    permanentAddress: permAddrController.text.trim().isNotEmpty
                        ? permAddrController.text.trim()
                        : null,
                    updatedAt: DateTime.now(),
                  );

                  try {
                    final dbService = ref.read(databaseServiceProvider);
                    await dbService.updateStudent(updatedStudent);

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ref.invalidate(studentDirectoryProvider);
                      ref.invalidate(studentsListProvider);
                      ref.invalidate(dashboardMetricsProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Student profile updated successfully!',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                          backgroundColor: AppTheme.primaryPurple,
                        ),
                      );
                    }
                  } catch (e, stackTrace) {
                    AppLogger.instance.error('Failed to update student profile', e, stackTrace);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Error updating student: $e',
                                style: GoogleFonts.poppins()),
                            backgroundColor: AppTheme.error),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.save_rounded, size: 14),
                label: Text('SAVE ALL CHANGES',
                    style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryPurple,
            letterSpacing: 1.0),
      ),
    );
  }

  InputDecoration _buildEditInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppTheme.divider)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppTheme.primaryPurple)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgMain,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.primaryPurple),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(BuildContext context, Student student) {
    // A FutureBuilder to load the student's attendance history and percent
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        ref.read(databaseServiceProvider).computeAttendancePercentForReportCard(student.id, '2026-2027'),
        ref.read(databaseServiceProvider).getAttendanceForStudent(student.id),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Text('Error loading attendance');
        }

        final percent = snapshot.data![0] as double;
        final history = snapshot.data![1] as List<dynamic>; // List<StudentAttendance>
        
        return _buildInfoCard(
          title: 'Attendance (2026-2027)',
          icon: Icons.calendar_today_rounded,
          children: [
            _buildDetailRow('Overall Percentage', '${percent.toStringAsFixed(1)}%'),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Recent History (Last 5 Days):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              ...history.take(5).map((att) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(att.date.substring(0, 10), style: const TextStyle(fontSize: 12)),
                      Text(att.status.toUpperCase(), style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: att.status == 'present' ? AppTheme.success : AppTheme.error,
                      )),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => StudentAttendanceHistoryDialog(student: student),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryPurple,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerLeft,
                ),
                child: const Text('View Full History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ] else 
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('No attendance records found.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              )
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStudentStatus(Student student) async {
    if (!student.isActive && !PermissionHelper.requireAdminRole(context, ref, RiskyAction.deactivateStudent)) return;
    if (student.isActive && !PermissionHelper.requireAdminRole(context, ref, RiskyAction.deactivateStudent)) return;
    try {
      final dbService = ref.read(databaseServiceProvider);
      final newStatus = !student.isActive;
      await dbService.setStudentActiveStatus(student.id, newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Student status updated to ${newStatus ? "ACTIVE" : "INACTIVE"}.',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.primaryPurple,
          ),
        );
      }
      ref.invalidate(studentDirectoryProvider);
      ref.invalidate(studentsListProvider);
      ref.invalidate(dashboardMetricsProvider);
    } catch (e, stackTrace) {
      AppLogger.instance.error('Failed to delete student', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating status: $e',
                  style: GoogleFonts.poppins()),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }
  Future<void> _generateStudentIdCard(BuildContext context, Student student) async {
    try {
      final pdfFile = await ReportGenerator.generateStudentIdCard(student: student);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Student ID Card PDF generated: ${pdfFile.path}', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: AppTheme.primaryPurple,
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.instance.error('Failed to generate Student ID Card', e, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating ID Card: $e', style: GoogleFonts.poppins()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showIssueTcDialog(BuildContext context, Student student) {
    final tcNumController = TextEditingController(text: 'TC-${DateTime.now().year}-${student.admissionNumber ?? student.id.substring(0, 4)}');
    final reasonController = TextEditingController(text: 'Completed Academic Course');
    final tcDateController = TextEditingController(text: DateFormat('yyyy-MM-DD').format(DateTime.now()));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: Colors.amber),
            const SizedBox(width: 10),
            Text('ISSUE TRANSFER CERTIFICATE (TC)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Issuing a TC will mark ${student.name} as Alumni (Inactive) and generate an official printable PDF Certificate.', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: tcNumController,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'TC Certificate Number *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tcDateController,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'TC Date (YYYY-MM-DD) *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Reason for Leaving School *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              final tcNum = tcNumController.text.trim();
              final tcDate = tcDateController.text.trim();
              final reason = reasonController.text.trim();
              if (tcNum.isEmpty || tcDate.isEmpty) return;

              try {
                final dbService = ref.read(databaseServiceProvider);
                await dbService.issueStudentTC(
                  studentId: student.id,
                  tcNumber: tcNum,
                  tcDate: tcDate,
                );

                final pdfFile = await ReportGenerator.generateTransferCertificate(
                  student: student,
                  tcNumber: tcNum,
                  tcDate: tcDate,
                  reasonForLeaving: reason,
                );

                ref.invalidate(studentDirectoryProvider);
                ref.invalidate(studentsListProvider);
                ref.invalidate(dashboardMetricsProvider);

                if (context.mounted) {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Close profile modal
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('TC Issued for ${student.name}! Saved to: ${pdfFile.path}', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                      backgroundColor: AppTheme.primaryPurple,
                    ),
                  );
                }
              } catch (e, stackTrace) {
                AppLogger.instance.error('Failed to issue TC', e, stackTrace);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error issuing TC: $e', style: GoogleFonts.poppins()), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('ISSUE TC & GENERATE PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showDocumentUploadDialog(BuildContext context, Student student) async {
    final res = await FilePicker.platform.pickFiles();
    if (res == null || res.files.single.path == null) return;

    final filePath = res.files.single.path!;
    final fileName = res.files.single.name;
    final titleController = TextEditingController(text: fileName);
    String selectedType = 'Birth Certificate';
    final types = ['Birth Certificate', 'Aadhaar Card', 'Marks Card', 'Transfer Certificate', 'Other'];

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('UPLOAD STUDENT DOCUMENT', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Document Title *'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Document Type'),
                items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedType = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                try {
                  final savedPath = await FileStorageService.copyFileToAppDirectory(filePath);
                  final doc = StudentDocument.create(
                    studentId: student.id,
                    title: title,
                    documentType: selectedType,
                    filePath: savedPath,
                  );

                  final dbService = ref.read(databaseServiceProvider);
                  await dbService.insertStudentDocument(doc);
                  ref.invalidate(studentDocumentsProvider(student.id));

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Document uploaded successfully!'), backgroundColor: AppTheme.primaryPurple),
                    );
                  }
                } catch (e, stackTrace) {
                  AppLogger.instance.error('Failed to upload student document', e, stackTrace);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error uploading document: $e'), backgroundColor: AppTheme.error),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: const Text('SAVE DOCUMENT'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentDocumentsCard(BuildContext context, Student student) {
    final docsAsync = ref.watch(studentDocumentsProvider(student.id));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_shared_rounded, color: AppTheme.primaryPurple, size: 20),
                  const SizedBox(width: 10),
                  Text('Student Documents', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => _showDocumentUploadDialog(context, student),
                icon: const Icon(Icons.upload_file_rounded, size: 14),
                label: Text('UPLOAD DOC', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryPurple,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          docsAsync.when(
            data: (docs) {
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('No uploaded documents yet.', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint, fontStyle: FontStyle.italic)),
                );
              }
              return Column(
                children: docs.map((doc) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined, size: 18, color: AppTheme.primaryPurple),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(doc.title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                              Text('${doc.documentType} • ${DateFormat("dd MMM yyyy").format(doc.uploadedAt)}', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                          onPressed: () async {
                            if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.deleteRecord)) return;
                            final dbService = ref.read(databaseServiceProvider);
                            await dbService.deleteStudentDocument(doc.id);
                            ref.invalidate(studentDocumentsProvider(student.id));
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('Error loading documents: $e', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  void _showClassPromotionDialog(BuildContext context) {
    String fromGrade = 'Grade 1';
    String toGrade = 'Grade 2';
    List<Student> currentStudents = [];
    Set<String> selectedStudentIds = {};
    bool isLoading = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isLoading) {
            ref.read(databaseServiceProvider).getStudentsByGrade(fromGrade).then((list) {
              setDialogState(() {
                currentStudents = list;
                selectedStudentIds = list.map((s) => s.id).toSet();
                isLoading = false;
              });
            });
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            title: Row(
              children: [
                const Icon(Icons.published_with_changes_rounded, color: AppTheme.primaryPurple),
                const SizedBox(width: 10),
                Text('STUDENT CLASS PROMOTION TOOL', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 600, maxHeight: MediaQuery.of(context).size.height * 0.7),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Promote students from one academic grade to the next class or mark as Alumni.', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: fromGrade,
                            style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                            decoration: const InputDecoration(labelText: 'From Grade (Current)'),
                            items: _grades.where((g) => g != 'All').map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  fromGrade = val;
                                  isLoading = true;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: toGrade,
                            style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                            decoration: const InputDecoration(labelText: 'To Grade (Target)'),
                            items: [..._grades.where((g) => g != 'All'), 'Alumni / Graduated'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => toGrade = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (currentStudents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(child: Text('No active students found in $fromGrade.', style: GoogleFonts.poppins(color: AppTheme.textHint))),
                      )
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Students in $fromGrade (${currentStudents.length}):', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                if (selectedStudentIds.length == currentStudents.length) {
                                  selectedStudentIds.clear();
                                } else {
                                  selectedStudentIds = currentStudents.map((s) => s.id).toSet();
                                }
                              });
                            },
                            child: Text(selectedStudentIds.length == currentStudents.length ? 'Deselect All' : 'Select All'),
                          ),
                        ],
                      ),
                      Column(
                        children: currentStudents.map((student) {
                          final isSelected = selectedStudentIds.contains(student.id);
                          return CheckboxListTile(
                            value: isSelected,
                            activeColor: AppTheme.primaryPurple,
                            title: Text(student.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            subtitle: Text('Adm. No: ${student.admissionNumber ?? "N/A"} • Roll: ${student.rollNumber ?? "N/A"}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  selectedStudentIds.add(student.id);
                                } else {
                                  selectedStudentIds.remove(student.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: selectedStudentIds.isEmpty
                    ? null
                    : () async {
                        final isAlumni = toGrade == 'Alumni / Graduated';
                        try {
                          final dbService = ref.read(databaseServiceProvider);
                          await dbService.promoteStudentsBatch(
                            studentIds: selectedStudentIds.toList(),
                            targetGrade: isAlumni ? fromGrade : toGrade,
                            markAsAlumni: isAlumni,
                          );

                          ref.invalidate(studentDirectoryProvider);
                          ref.invalidate(studentsListProvider);
                          ref.invalidate(dashboardMetricsProvider);

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Successfully promoted ${selectedStudentIds.length} student(s) to $toGrade!', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                                backgroundColor: AppTheme.primaryPurple,
                              ),
                            );
                          }
                        } catch (e, stackTrace) {
                          AppLogger.instance.error('Failed to promote students', e, stackTrace);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error promoting students: $e'), backgroundColor: AppTheme.error),
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                label: Text('PROMOTE ${selectedStudentIds.length} STUDENT(S)'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudentDiscountsAndNetFeeCard(BuildContext context, Student student) {
    const academicYear = '2024-2025';
    final studentYearParam = StudentYearParam(studentId: student.id, academicYear: academicYear);
    final studentClassYearParam = StudentClassYearParam(studentId: student.id, className: student.gradeLevel, academicYear: academicYear);

    return Consumer(
      builder: (context, ref, child) {
        final discountsAsync = ref.watch(studentDiscountsProvider(studentYearParam));
        final discountTypesAsync = ref.watch(discountTypesProvider);
        final netFeeBreakdownAsync = ref.watch(studentNetFeeBreakdownProvider(studentClassYearParam));

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.discount_rounded, color: AppTheme.primaryPurple, size: 20),
                      const SizedBox(width: 8),
                      Text('Fee Discounts & Net Fee', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _showApplyDiscountModal(context, ref, student),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: Text('Apply Discount', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Active Discounts List
              discountsAsync.when(
                data: (discounts) {
                  if (discounts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text('No scholarships/discounts applied for $academicYear.',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint, fontStyle: FontStyle.italic)),
                    );
                  }
                  final types = discountTypesAsync.value ?? [];
                  final typeMap = {for (var t in types) t.id: t};

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: discounts.map((sd) {
                      final dt = typeMap[sd.discountTypeId];
                      final valStr = dt?.discountKind == 'percentage' ? '${dt?.value}%' : '₹${dt?.value}';
                      return Chip(
                        backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.08),
                        side: const BorderSide(color: AppTheme.primaryPurple),
                        avatar: const Icon(Icons.card_giftcard_rounded, size: 14, color: AppTheme.primaryPurple),
                        label: Text('${dt?.name ?? "Discount"} ($valStr)',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                        onDeleted: () async {
                          final dbService = ref.read(databaseServiceProvider);
                          await dbService.removeStudentDiscount(sd.id);
                          ref.invalidate(studentDiscountsProvider(studentYearParam));
                          ref.invalidate(studentNetFeeBreakdownProvider(studentClassYearParam));
                        },
                        deleteIconColor: AppTheme.error,
                      );
                    }).toList(),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error loading discounts: $e'),
              ),
              const Divider(height: 24),

              // Net Payable Live Breakdown Table
              Text('Calculated Net Payable per Fee Head:',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),

              netFeeBreakdownAsync.when(
                data: (List<StudentNetFeeBreakdown> breakdownList) {
                  if (breakdownList.isEmpty) {
                    return Text('No fee structure configured for ${student.gradeLevel}.',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint, fontStyle: FontStyle.italic));
                  }

                  double totalNetPayable = 0.0;
                  for (final item in breakdownList) {
                    totalNetPayable += item.netPayable;
                  }

                  return Column(
                    children: [
                      Table(
                        border: TableBorder.all(color: AppTheme.divider, borderRadius: BorderRadius.circular(8)),
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(color: AppTheme.bgSurface),
                            children: [
                              Padding(padding: const EdgeInsets.all(8), child: Text('Fee Head', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(8), child: Text('Base (₹)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(8), child: Text('Discount (₹)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(8), child: Text('Net (₹)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                          ),
                          ...breakdownList.map((StudentNetFeeBreakdown item) => TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(8), child: Text('${item.feeHeadName} (${item.frequency})', style: GoogleFonts.poppins(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(8), child: Text('₹${item.baseAmount.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(8), child: Text('₹${item.discountAmount.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.success))),
                              Padding(padding: const EdgeInsets.all(8), child: Text('₹${item.netPayable.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold))),
                            ],
                          )),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Net Payable Total:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                          Text('₹${totalNetPayable.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryPurple)),
                        ],
                      ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error calculating net fee: $e'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showApplyDiscountModal(BuildContext context, WidgetRef ref, Student student) {
    final discountTypesAsync = ref.read(discountTypesProvider);
    final types = discountTypesAsync.value ?? [];
    if (types.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No discount types configured in the system.'), backgroundColor: AppTheme.error),
      );
      return;
    }

    String selectedTypeId = types.first.id;
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Apply Discount / Scholarship', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedTypeId,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Select Discount Type *'),
                  items: types.map((dt) {
                    final valStr = dt.discountKind == 'percentage' ? '${dt.value}%' : '₹${dt.value}';
                    return DropdownMenuItem(value: dt.id, child: Text('${dt.name} ($valStr)'));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedTypeId = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksController,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Remarks / Approval Note (Optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                const academicYear = '2024-2025';
                final sd = StudentDiscount.create(
                  studentId: student.id,
                  discountTypeId: selectedTypeId,
                  academicYear: academicYear,
                  remarks: remarksController.text.trim().isNotEmpty ? remarksController.text.trim() : null,
                );

                final dbService = ref.read(databaseServiceProvider);
                await dbService.applyStudentDiscount(sd);

                final studentYearParam = StudentYearParam(studentId: student.id, academicYear: academicYear);
                final studentClassYearParam = StudentClassYearParam(studentId: student.id, className: student.gradeLevel, academicYear: academicYear);
                ref.invalidate(studentDiscountsProvider(studentYearParam));
                ref.invalidate(studentNetFeeBreakdownProvider(studentClassYearParam));

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Discount applied!'), backgroundColor: AppTheme.primaryPurple),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: const Text('Apply Discount'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentTransportAssignmentCard(BuildContext context, Student student) {
    const academicYear = '2024-2025';
    final param = StudentYearParam(studentId: student.id, academicYear: academicYear);

    return Consumer(
      builder: (context, ref, child) {
        final transportAsync = ref.watch(studentTransportProvider(param));

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_bus_rounded, color: AppTheme.primaryPurple, size: 20),
                      const SizedBox(width: 8),
                      Text('Transport Facility Assignment',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _showAssignTransportModal(context, ref, student),
                    icon: const Icon(Icons.edit_road_rounded, size: 16),
                    label: Text('Assign / Change', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              transportAsync.when(
                data: (st) {
                  if (st == null) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text('No transport route assigned for AY $academicYear.',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint, fontStyle: FontStyle.italic)),
                    );
                  }

                  final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(st.routeName ?? 'Assigned Route', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('${fmt.format(st.monthlyFee)}/mo',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.success)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Stop: ${st.stopName ?? "N/A"}  (Pickup: ${st.pickupTime ?? "-"} | Drop: ${st.dropTime ?? "-"})',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                error: (e, _) => Text('Error loading transport: $e', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.error)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAssignTransportModal(BuildContext context, WidgetRef ref, Student student) {
    const academicYear = '2024-2025';
    String? selectedRouteId;
    String? selectedStopId;
    List<RouteStop> availableStops = [];
    final feeController = TextEditingController(text: '1500');

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final routesAsync = ref.watch(routesListProvider);

          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(Icons.directions_bus_rounded, color: AppTheme.primaryPurple, size: 20),
                  const SizedBox(width: 10),
                  Text('Assign Transport Route — ${student.name}',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Transport Route *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    routesAsync.when(
                      data: (routes) {
                        return DropdownButtonFormField<String>(
                          value: selectedRouteId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          hint: Text('Choose Route', style: GoogleFonts.poppins(fontSize: 12)),
                          items: routes
                              .map((r) => DropdownMenuItem(
                                    value: r.id,
                                    child: Text('${r.routeName} (${r.vehicleNumber ?? "Bus"})', style: GoogleFonts.poppins(fontSize: 12)),
                                  ))
                              .toList(),
                          onChanged: (routeId) async {
                            if (routeId != null) {
                              final dbService = ref.read(databaseServiceProvider);
                              final stops = await dbService.getStopsForRoute(routeId);
                              setDialogState(() {
                                selectedRouteId = routeId;
                                availableStops = stops;
                                selectedStopId = stops.isNotEmpty ? stops.first.id : null;
                              });
                            }
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error loading routes: $e'),
                    ),
                    const SizedBox(height: 12),

                    Text('Select Route Stop *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: selectedStopId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      hint: Text(availableStops.isEmpty ? 'Select a route first' : 'Choose Stop', style: GoogleFonts.poppins(fontSize: 12)),
                      items: availableStops
                          .map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text('${s.stopOrder}. ${s.stopName} (${s.pickupTime ?? "-"})', style: GoogleFonts.poppins(fontSize: 12)),
                              ))
                          .toList(),
                      onChanged: (stopId) => setDialogState(() => selectedStopId = stopId),
                    ),
                    const SizedBox(height: 12),

                    Text('Monthly Transport Fee (₹) *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: feeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedRouteId == null || selectedStopId == null) return;
                    final fee = double.tryParse(feeController.text) ?? 1500;

                    final dbService = ref.read(databaseServiceProvider);
                    await dbService.assignStudentToRoute(
                      studentId: student.id,
                      routeId: selectedRouteId!,
                      stopId: selectedStopId!,
                      monthlyFee: fee,
                      academicYear: academicYear,
                    );

                    final param = StudentYearParam(studentId: student.id, academicYear: academicYear);
                    final studentClassYearParam = StudentClassYearParam(studentId: student.id, className: student.gradeLevel, academicYear: academicYear);
                    ref.invalidate(studentTransportProvider(param));
                    ref.invalidate(studentFeeLedgerProvider(param));
                    ref.invalidate(studentNetFeeBreakdownProvider(studentClassYearParam));

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transport assigned & fee synced to ledger!'), backgroundColor: AppTheme.primaryPurple),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                  child: const Text('Save Assignment'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}