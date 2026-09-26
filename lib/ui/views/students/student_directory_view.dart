import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../services/csv_export_service.dart';
import '../../../services/file_storage_service.dart';
import '../../../services/report_generator.dart';
import '../../../services/settings_service.dart';
import '../../widgets/pdf_preview_dialog.dart';
import '../../widgets/blobatar.dart';
import '../../widgets/thinking_orb_widget.dart';
import '../../../services/app_logger.dart';
import '../fees/student_fee_ledger_view.dart';
import '../attendance/student_attendance_history_dialog.dart';
import '../../../core/auth/permission_helper.dart';

final studentSearchQueryProvider = StateProvider<String>((ref) => '');
final studentGradeFilterProvider = StateProvider<String>((ref) => 'All');
final studentStatusFilterProvider = StateProvider<String>((ref) => 'Active');

final studentDirectoryStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(studentsListProvider);
  final dbService = ref.watch(databaseServiceProvider);
  final all = await dbService.getAllStudents(activeOnly: false);
  final now = DateTime.now();

  final activeCount = all.where((s) => s.isActive && !s.isAlumni).length;
  final alumniCount = all.where((s) => s.isAlumni || !s.isActive).length;
  final pendingCount = all.where((s) => s.currentBalance > 0).length;
  final paidCount = all.where((s) => s.currentBalance == 0).length;

  final newThisMonth = all.where((s) {
    if (s.admissionDate != null) {
      try {
        final d = DateTime.parse(s.admissionDate!);
        return d.year == now.year && d.month == now.month;
      } catch (_) {}
    }
    return s.createdAt.year == now.year && s.createdAt.month == now.month;
  }).length;

  final boysCount = all.where((s) => s.gender?.toLowerCase() == 'male' || s.gender?.toLowerCase() == 'boy').length;
  final girlsCount = all.where((s) => s.gender?.toLowerCase() == 'female' || s.gender?.toLowerCase() == 'girl').length;
  final uniqueGrades = all.map((s) => s.gradeLevel).where((g) => g.isNotEmpty).toSet().length;

  return {
    'total': all.length,
    'active': activeCount,
    'alumni': alumniCount,
    'pending': pendingCount,
    'paid': paidCount,
    'newThisMonth': newThisMonth,
    'boys': boysCount,
    'girls': girlsCount,
    'uniqueGrades': uniqueGrades == 0 ? 12 : uniqueGrades,
  };
});

bool _matchesGrade(String studentGrade, String targetGrade) {
  if (targetGrade.trim().toLowerCase() == 'all') return true;

  final sGrade = studentGrade.trim();
  final tGrade = targetGrade.trim();

  // 1. Direct case-insensitive match
  if (sGrade.toLowerCase() == tGrade.toLowerCase()) return true;

  // 2. Normalization function
  String normalize(String input) {
    var s = input.trim().toLowerCase();
    // Strip section if appended like '1 - A' or 'Class 1-A' or '1 (A)'
    s = s.replaceAll(RegExp(r'\s*[-–(].*$'), '').trim();
    // Strip prefix 'grade', 'class', 'standard', 'std'
    s = s.replaceAll(RegExp(r'^(grade|class|standard|std\.?)\s*', caseSensitive: false), '').trim();
    // Normalize ordinal numbers: 1st -> 1, 2nd -> 2, 3rd -> 3, 4th -> 4, etc.
    s = s.replaceAllMapped(RegExp(r'^(\d+)(st|nd|rd|th)$', caseSensitive: false), (m) => m[1]!);
    // Normalize Roman numerals to digits
    const romanToNum = {
      'i': '1', 'ii': '2', 'iii': '3', 'iv': '4', 'v': '5',
      'vi': '6', 'vii': '7', 'viii': '8', 'ix': '9', 'x': '10',
      'xi': '11', 'xii': '12',
    };
    if (romanToNum.containsKey(s)) {
      s = romanToNum[s]!;
    }
    return s;
  }

  final normStudent = normalize(sGrade);
  final normTarget = normalize(tGrade);

  if (normStudent.isNotEmpty && normStudent == normTarget) {
    return true;
  }

  // 3. Substring / word check
  if (normTarget.isNotEmpty) {
    final sWords = sGrade.toLowerCase().split(RegExp(r'[\s\-_]+'));
    if (sWords.contains(normTarget)) return true;
  }

  return false;
}

final studentDirectoryProvider =
    FutureProvider<List<Student>>((ref) async {
  ref.watch(studentsListProvider);
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
        .where((s) => _matchesGrade(s.gradeLevel, grade))
        .toList();
  }

  if (statusFilter == 'Active') {
    list = list.where((s) => s.isActive && !s.isAlumni).toList();
  } else if (statusFilter == 'Alumni') {
    list = list.where((s) => s.isAlumni || !s.isActive).toList();
  } else if (statusFilter == 'Pending Dues') {
    list = list.where((s) => s.currentBalance > 0).toList();
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
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _glowAnimation;

  late final AnimationController _collapseController;
  late final Animation<double> _collapseAnimation;
  bool _isHeaderCollapsed = false;

  final _searchController = TextEditingController();
  final _chipsScrollController = ScrollController();
  Timer? _debounceTimer;
  Timer? _autoRefreshTimer;
  int? _lastStudentCount;
  String? _lastUpdated;
  int _currentPage = 0;
  int _itemsPerPage = 24;
  String _viewMode = 'grid'; // 'grid' or 'table'

  int _compareClassNames(String a, String b) {
    int rank(String name) {
      final lower = name.toLowerCase().trim();
      if (lower.contains('nursery') || lower.contains('play')) return 1;
      if (lower.contains('lkg') || lower.contains('jr')) return 2;
      if (lower.contains('ukg') || lower.contains('sr') || lower.contains('kg')) return 3;
      final match = RegExp(r'\d+').firstMatch(lower);
      if (match != null) {
        return 10 + (int.tryParse(match.group(0)!) ?? 0);
      }
      return 100;
    }
    final rA = rank(a);
    final rB = rank(b);
    if (rA != rB) return rA.compareTo(rB);
    return a.compareTo(b);
  }

  Color _initialsColor(String name) {
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF10B981), // Green
      const Color(0xFFEF4444), // Coral
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFF97316), // Orange
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF10B981), // Emerald
      const Color(0xFFEC4899), // Pink
      const Color(0xFF14B8A6), // Teal
    ];
    final hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }

  String _formatGradeSection(String grade, String? section) {
    final clean = grade.trim();
    if (section != null && section.isNotEmpty) {
      return '$clean - $section';
    }
    return clean;
  }

  void _collapseHeader() {
    if (!_isHeaderCollapsed) {
      setState(() => _isHeaderCollapsed = true);
      _collapseController.forward();
    }
  }

  void _expandHeader() {
    if (_isHeaderCollapsed) {
      setState(() => _isHeaderCollapsed = false);
      _collapseController.reverse();
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    try {
      final students = await ref.read(studentDirectoryProvider.future);
      final exporter = CsvExportService();
      final file = await exporter.exportStudentsToCsv(students);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Directory exported to CSV: ${file.path}',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
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
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

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

    _collapseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _collapseAnimation = CurvedAnimation(
      parent: _collapseController,
      curve: Curves.easeInOutCubic,
    );

    _startAutoRefreshTimer();
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkForDataChanges();
    });
  }

  Future<void> _checkForDataChanges({bool force = false}) async {
    if (!mounted) return;
    try {
      final db = await ref.read(databaseServiceProvider).rawDb;
      final res = await db.rawQuery('SELECT COUNT(*) as count, MAX(updated_at) as last_updated FROM students');
      if (res.isNotEmpty && mounted) {
        final count = res.first['count'] as int? ?? 0;
        final lastUpdated = res.first['last_updated']?.toString() ?? '';
        if (force || (_lastStudentCount != null && (count != _lastStudentCount || lastUpdated != _lastUpdated))) {
          _lastStudentCount = count;
          _lastUpdated = lastUpdated;
          ref.invalidate(studentsListProvider);
          ref.invalidate(studentDirectoryProvider);
          ref.invalidate(studentDirectoryStatsProvider);
        } else if (_lastStudentCount == null) {
          _lastStudentCount = count;
          _lastUpdated = lastUpdated;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _debounceTimer?.cancel();
    _animController.dispose();
    _collapseController.dispose();
    _searchController.dispose();
    _chipsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NavigationTab>(selectedTabProvider, (previous, next) {
      if (next == NavigationTab.students) {
        _checkForDataChanges(force: true);
      }
    });

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
    final classesAsync = ref.watch(classListProvider);
    final classModels = classesAsync.value ?? [];
    final classNames = classModels
        .map((c) => c.name.trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    final allStudentsList = ref.watch(studentsListProvider).value ?? [];
    for (final s in allStudentsList) {
      final clean = s.gradeLevel.trim();
      if (clean.isNotEmpty && !classNames.contains(clean)) {
        classNames.add(clean);
      }
    }
    if (classNames.isEmpty) {
      classNames.addAll([
        'Class 1st',
        'Class 2nd',
        'Class 3rd',
        'Class 4th',
        'Class 5th',
        'Class 6th',
        'Class 7th',
        'Class 8th',
        'Class 9th',
        'Class 10th',
        'Class 11th',
        'Class 12th',
      ]);
    }
    classNames.sort(_compareClassNames);
    final availableClasses = ['All', ...classNames];

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
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: _isHeaderCollapsed ? 20 : 28,
            vertical: _isHeaderCollapsed ? 10 : 20,
          ),
          child: Column(
            children: [
              // ── Collapsible Top Section (Header + Stat Cards) ──
              SizeTransition(
                sizeFactor: Tween<double>(begin: 1.0, end: 0.0).animate(_collapseAnimation),
                alignment: Alignment.topCenter,
                child: FadeTransition(
                  opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_collapseAnimation),
                  child: Column(
                    children: [
                      // ── Top Header ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Students Directory',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                ref.watch(studentDirectoryStatsProvider).maybeWhen(
                                  data: (stats) {
                                    final total = stats['total'] ?? 0;
                                    final newThisMonth = stats['newThisMonth'] ?? 0;
                                    final uniqueGrades = stats['uniqueGrades'] ?? 12;
                                    final numberFormat = NumberFormat('#,###');
                                    return Text(
                                      '${numberFormat.format(total)} enrolled • $newThisMonth new admissions this month • $uniqueGrades classes',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  },
                                  orElse: () => Text(
                                    'Search, filter, and manage all registered student records',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _exportCsv(context),
                                icon: const Icon(Icons.file_download_outlined, size: 16),
                                label: Text(
                                  'Export CSV',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  backgroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () {
                                  ref.read(selectedTabProvider.notifier).state =
                                      NavigationTab.admission;
                                },
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: Text(
                                  'Enroll student',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryPurple,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ── 4 Top Stat Cards ──
                      ref.watch(studentDirectoryStatsProvider).when(
                        data: (stats) => _buildTopStatCards(context, stats),
                        loading: () => const SizedBox(height: 100),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),

              // ── Roster Container ──
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification) {
                      final delta = notification.scrollDelta ?? 0;
                      if (delta > 12 && notification.metrics.pixels > 20 && !_isHeaderCollapsed) {
                        _collapseHeader();
                      } else if (delta < -12 && _isHeaderCollapsed) {
                        _expandHeader();
                      }
                    } else if (notification is ScrollEndNotification) {
                      if (notification.metrics.pixels <= 10 && _isHeaderCollapsed) {
                        _expandHeader();
                      }
                    }
                    return false;
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Roster Header & Toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Roster',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (_isHeaderCollapsed) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primarySoft,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Full Screen',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryPurple,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Browse, filter, and manage student records',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            // Actions + View Toggle [ Grid | List ] + Fullscreen Button
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isHeaderCollapsed) ...[
                                  IconButton(
                                    onPressed: () => _exportCsv(context),
                                    icon: const Icon(Icons.file_download_outlined, size: 18),
                                    tooltip: 'Export CSV',
                                    style: IconButton.styleFrom(
                                      foregroundColor: const Color(0xFF0F172A),
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      padding: const EdgeInsets.all(8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      ref.read(selectedTabProvider.notifier).state = NavigationTab.admission;
                                    },
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: Text(
                                      'Enroll',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryPurple,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                // View Toggle [ Grid | List ]
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.all(3),
                                  child: Row(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          if (_viewMode != 'grid') {
                                            setState(() => _viewMode = 'grid');
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _viewMode == 'grid'
                                                ? Colors.white
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                            boxShadow: _viewMode == 'grid'
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(alpha: 0.05),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 1),
                                                    )
                                                  ]
                                                : null,
                                          ),
                                          child: Text(
                                            'Grid',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: _viewMode == 'grid'
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: _viewMode == 'grid'
                                                  ? const Color(0xFF0F172A)
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          if (_viewMode != 'table') {
                                            setState(() => _viewMode = 'table');
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _viewMode == 'table'
                                                ? Colors.white
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                            boxShadow: _viewMode == 'table'
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(alpha: 0.05),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 1),
                                                    )
                                                  ]
                                                : null,
                                          ),
                                          child: Text(
                                            'List',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: _viewMode == 'table'
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: _viewMode == 'table'
                                                  ? const Color(0xFF0F172A)
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Fullscreen / Restore Toggle Button
                                Tooltip(
                                  message: _isHeaderCollapsed
                                      ? 'Restore normal size (or scroll up)'
                                      : 'Cover whole screen (or scroll down)',
                                  child: InkWell(
                                    onTap: () {
                                      if (_isHeaderCollapsed) {
                                        _expandHeader();
                                      } else {
                                        _collapseHeader();
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: _isHeaderCollapsed
                                            ? AppTheme.primarySoft
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _isHeaderCollapsed
                                              ? AppTheme.primaryPurple
                                                  .withValues(alpha: 0.3)
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isHeaderCollapsed
                                                ? Icons.fullscreen_exit_rounded
                                                : Icons.fullscreen_rounded,
                                            size: 18,
                                            color: _isHeaderCollapsed
                                                ? AppTheme.primaryPurple
                                                : const Color(0xFF64748B),
                                          ),
                                          if (_isHeaderCollapsed) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              'Restore',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.primaryPurple,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                      // Filter Row: Search Field + Grade Chips + More Filters
                      Row(
                        children: [
                          // Search Box
                          SizedBox(
                            width: 220,
                            height: 38,
                            child: TextField(
                              controller: _searchController,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: const Color(0xFF0F172A)),
                              onChanged: (val) {
                                if (_debounceTimer?.isActive ?? false) {
                                  _debounceTimer!.cancel();
                                }
                                _debounceTimer =
                                    Timer(const Duration(milliseconds: 300), () {
                                  ref
                                      .read(studentSearchQueryProvider.notifier)
                                      .state = val.trim();
                                  if (_currentPage != 0) {
                                    setState(() => _currentPage = 0);
                                  }
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search by name or id...',
                                hintStyle: GoogleFonts.poppins(
                                    color: const Color(0xFF94A3B8), fontSize: 12),
                                prefixIcon: const Icon(Icons.search_rounded,
                                    size: 16, color: Color(0xFF94A3B8)),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded,
                                            size: 14, color: Color(0xFF94A3B8)),
                                        onPressed: () {
                                          _searchController.clear();
                                          ref
                                              .read(studentSearchQueryProvider
                                                  .notifier)
                                              .state = '';
                                          setState(() => _currentPage = 0);
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 0),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: AppTheme.primaryPurple),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Scrollable Class Chips with Left/Right Buttons & Mouse Wheel / Drag
                          Expanded(
                            child: Row(
                              children: [
                                // Left Scroll Button
                                InkWell(
                                  onTap: () {
                                    if (_chipsScrollController.hasClients) {
                                      _chipsScrollController.animateTo(
                                        (_chipsScrollController.offset - 220)
                                            .clamp(0.0, _chipsScrollController.position.maxScrollExtent),
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeOutCubic,
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 36,
                                    width: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Icon(Icons.chevron_left_rounded,
                                        size: 18, color: Color(0xFF64748B)),
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Scrollable Chips with Mouse Wheel Support
                                Expanded(
                                  child: Listener(
                                    onPointerSignal: (pointerSignal) {
                                      if (pointerSignal is PointerScrollEvent && _chipsScrollController.hasClients) {
                                        final delta = pointerSignal.scrollDelta.dy != 0
                                            ? pointerSignal.scrollDelta.dy
                                            : pointerSignal.scrollDelta.dx;
                                        final target = (_chipsScrollController.offset + delta)
                                            .clamp(0.0, _chipsScrollController.position.maxScrollExtent);
                                        _chipsScrollController.jumpTo(target);
                                      }
                                    },
                                    child: ScrollConfiguration(
                                      behavior: ScrollConfiguration.of(context).copyWith(
                                        dragDevices: {
                                          PointerDeviceKind.touch,
                                          PointerDeviceKind.mouse,
                                          PointerDeviceKind.trackpad,
                                          PointerDeviceKind.stylus,
                                        },
                                      ),
                                      child: SingleChildScrollView(
                                        controller: _chipsScrollController,
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        child: Row(
                                          children: availableClasses.map((className) {
                                            final isSelected = className == 'All'
                                                ? selectedGrade == 'All'
                                                : (selectedGrade != 'All' &&
                                                    _matchesGrade(selectedGrade, className));
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 8),
                                              child: InkWell(
                                                onTap: () {
                                                  ref
                                                      .read(studentGradeFilterProvider
                                                          .notifier)
                                                      .state = className;
                                                  if (_currentPage != 0) {
                                                    setState(() => _currentPage = 0);
                                                  }
                                                },
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 12, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? Colors.white
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? AppTheme.primaryPurple
                                                          : const Color(0xFFE2E8F0),
                                                      width: isSelected ? 1.5 : 1,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    className == 'All' ? 'All Classes' : className,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      fontWeight: isSelected
                                                          ? FontWeight.w600
                                                          : FontWeight.w500,
                                                      color: isSelected
                                                          ? AppTheme.primaryPurple
                                                          : const Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 6),
                                // Right Scroll Button
                                InkWell(
                                  onTap: () {
                                    if (_chipsScrollController.hasClients) {
                                      _chipsScrollController.animateTo(
                                        (_chipsScrollController.offset + 220)
                                            .clamp(0.0, _chipsScrollController.position.maxScrollExtent),
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeOutCubic,
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 36,
                                    width: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Icon(Icons.chevron_right_rounded,
                                        size: 18, color: Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // More Filters Menu
                          PopupMenuButton<String>(
                            tooltip: 'More filters',
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'status_active',
                                child: Text('Active Students Only'),
                              ),
                              const PopupMenuItem(
                                value: 'status_alumni',
                                child: Text('Alumni / Inactive'),
                              ),
                              const PopupMenuItem(
                                value: 'status_pending',
                                child: Text('Pending Dues Only'),
                              ),
                              const PopupMenuItem(
                                value: 'status_all',
                                child: Text('All Student Records'),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'promotions',
                                child: Row(
                                  children: [
                                    Icon(Icons.published_with_changes_rounded,
                                        size: 16,
                                        color: AppTheme.primaryPurple),
                                    SizedBox(width: 8),
                                    Text('Class Promotions'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'refresh',
                                child: Row(
                                  children: [
                                    Icon(Icons.sync_rounded,
                                        size: 16, color: Color(0xFF64748B)),
                                    SizedBox(width: 8),
                                    Text('Refresh Directory'),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (val) {
                              if (val == 'status_active') {
                                ref
                                    .read(studentStatusFilterProvider.notifier)
                                    .state = 'Active';
                              } else if (val == 'status_alumni') {
                                ref
                                    .read(studentStatusFilterProvider.notifier)
                                    .state = 'Alumni';
                              } else if (val == 'status_pending') {
                                ref
                                    .read(studentStatusFilterProvider.notifier)
                                    .state = 'Pending Dues';
                              } else if (val == 'status_all') {
                                ref
                                    .read(studentStatusFilterProvider.notifier)
                                    .state = 'All';
                              } else if (val == 'promotions') {
                                _showClassPromotionDialog(context);
                              } else if (val == 'refresh') {
                                ref.invalidate(studentDirectoryProvider);
                                ref.invalidate(studentDirectoryStatsProvider);
                              }
                              setState(() => _currentPage = 0);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.filter_list_rounded,
                                      size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'More filters',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Main Directory Content (Grid / List)
                      Expanded(
                        child: studentsAsync.when(
                          data: (students) {
                            if (students.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primarySoft,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.search_off_rounded,
                                        size: 40,
                                        color: AppTheme.primaryPurple,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No students found',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF0F172A),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Try adjusting your search terms or class filter.',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF64748B),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        _searchController.clear();
                                        ref
                                            .read(studentSearchQueryProvider
                                                .notifier)
                                            .state = '';
                                        ref
                                            .read(studentGradeFilterProvider
                                                .notifier)
                                            .state = 'All';
                                        ref
                                            .read(studentStatusFilterProvider
                                                .notifier)
                                            .state = 'Active';
                                        setState(() => _currentPage = 0);
                                      },
                                      icon: const Icon(Icons.restart_alt_rounded,
                                          size: 14),
                                      label: Text('Reset Filters',
                                          style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.primaryPurple,
                                        side: const BorderSide(
                                            color: AppTheme.primaryPurple),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return _viewMode == 'grid'
                                ? _buildStudentGrid(context, students)
                                : _buildStudentTable(context, students);
                          },
                          loading: () => const ThinkingLoadingCard(
                            message: 'Loading student directory...',
                            subMessage: 'Retrieving student profiles & enrollments',
                            state: OrbState.working,
                            size: 48,
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
            ),
          ],
        ),
      ),
    ],
  );
  }

  Widget _buildTopStatCards(BuildContext context, Map<String, dynamic> stats) {
    final numberFormat = NumberFormat('#,###');
    final total = stats['total'] ?? 0;
    final active = stats['active'] ?? 0;
    final newThisMonth = stats['newThisMonth'] ?? 0;
    final boys = stats['boys'] ?? 0;
    final girls = stats['girls'] ?? 0;
    final uniqueGrades = stats['uniqueGrades'] ?? 12;

    final activePct =
        total == 0 ? '100' : ((active / total) * 100).toStringAsFixed(1);
    final totalGender = boys + girls;
    final boysPct =
        totalGender == 0 ? 50 : ((boys / totalGender) * 100).round();
    final girlsPct = totalGender == 0 ? 50 : (100 - boysPct);

    return Row(
      children: [
        // 1. Total enrolled
        Expanded(
          child: _buildMetricCard(
            icon: Icons.people_outline_rounded,
            iconBg: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFF8B5CF6),
            label: 'Total enrolled',
            value: numberFormat.format(total),
            trend: '$uniqueGrades classes',
            trendColor: const Color(0xFF8B5CF6),
          ),
        ),
        const SizedBox(width: 14),

        // 2. New this month
        Expanded(
          child: _buildMetricCard(
            icon: Icons.auto_awesome_outlined,
            iconBg: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFD97706),
            label: 'New this month',
            value: numberFormat.format(newThisMonth),
            trend: 'Recent admissions',
            trendColor: const Color(0xFFD97706),
          ),
        ),
        const SizedBox(width: 14),

        // 3. Boys / Girls
        Expanded(
          child: _buildMetricCard(
            icon: Icons.wc_outlined,
            iconBg: const Color(0xFFCFFAFE),
            iconColor: const Color(0xFF06B6D4),
            label: 'Boys / Girls',
            value: '${numberFormat.format(boys)} / ${numberFormat.format(girls)}',
            trend: '$boysPct% • $girlsPct%',
            trendColor: const Color(0xFF06B6D4),
          ),
        ),
        const SizedBox(width: 14),

        // 4. Active students
        Expanded(
          child: _buildMetricCard(
            icon: Icons.check_circle_outline_rounded,
            iconBg: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF16A34A),
            label: 'Active students',
            value: numberFormat.format(active),
            trend: '$activePct% active',
            trendColor: const Color(0xFF16A34A),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    required String trend,
    required Color trendColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              trend,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: trendColor,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentGrid(BuildContext context, List<Student> students) {
    final totalStudents = students.length;
    final totalPages = (totalStudents / _itemsPerPage).ceil().clamp(1, 999999);
    if (_currentPage >= totalPages) {
      _currentPage = totalPages - 1;
    }
    if (_currentPage < 0) {
      _currentPage = 0;
    }
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalStudents);
    final pagedStudents = totalStudents == 0
        ? <Student>[]
        : students.sublist(startIndex, endIndex);

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 215,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: pagedStudents.length,
            itemBuilder: (context, index) {
              final student = pagedStudents[index];
              return _buildStudentCard(context, student);
            },
          ),
        ),
        if (totalPages > 1)
          _buildPaginationFooter(
              totalPages, totalStudents, startIndex, endIndex),
      ],
    );
  }

  Widget _buildStudentCard(BuildContext context, Student student) {
    final name =
        '${student.firstName ?? student.name} ${student.lastName ?? ""}'.trim();
    final gradePill =
        _formatGradeSection(student.gradeLevel, student.section);
    final phone = student.guardianPhone ??
        student.fatherPhone ??
        student.motherPhone ??
        '—';
    final guardianName =
        student.fatherName ?? student.motherName ?? 'Guardian';
    final hasPhoto = student.photographPath != null &&
        student.photographPath!.isNotEmpty &&
        File(student.photographPath!).existsSync();

    final statusText = student.isAlumni
        ? 'Alumni'
        : student.isActive
            ? 'Active'
            : 'Inactive';
    final statusBg = student.isAlumni
        ? const Color(0xFFFEF3C7)
        : student.isActive
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFF1F5F9);
    final statusColor = student.isAlumni
        ? const Color(0xFFD97706)
        : student.isActive
            ? const Color(0xFF16A34A)
            : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showStudentProfileDialog(context, student),
        borderRadius: BorderRadius.circular(16),
        hoverColor: const Color(0xFFF8FAFC),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Avatar + Name/ID + Grade pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    hasPhoto
                        ? CircleAvatar(
                            radius: 19,
                            backgroundColor: AppTheme.primarySoft,
                            backgroundImage:
                                FileImage(File(student.photographPath!)),
                          )
                        : AppAvatar(
                            seed: student.admissionNumber ?? student.name,
                            name: student.name,
                            size: 38,
                            borderRadius: 19,
                            fallbackColor: _initialsColor(student.name),
                          ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            student.admissionNumber ??
                                'STU-${student.id.length >= 4 ? student.id.substring(0, 4) : student.id}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          gradePill,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Row 2: Status badge + Roll Number / Gender badge
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: GoogleFonts.poppins(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (student.rollNumber != null &&
                        student.rollNumber!.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Roll: ${student.rollNumber}',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF475569),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ] else if (student.gender != null &&
                        student.gender!.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          student.gender!,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 10),

                // Row 3: Guardian Name & Phone
                Text(
                  guardianName,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentTable(BuildContext context, List<Student> students) {
    final totalStudents = students.length;
    final totalPages = (totalStudents / _itemsPerPage).ceil().clamp(1, 999999);
    if (_currentPage >= totalPages) {
      _currentPage = totalPages - 1;
    }
    if (_currentPage < 0) {
      _currentPage = 0;
    }
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalStudents);
    final pagedStudents = totalStudents == 0
        ? <Student>[]
        : students.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 320,
                ),
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  dataRowMinHeight: 75,
                  dataRowMaxHeight: 75,
                  headingTextStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: const Color(0xFF64748B),
                  ),
                  dividerThickness: 1,
                  horizontalMargin: 20,
                  columns: const [
                    DataColumn(label: Text('STUDENT')),
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('ROLL NO')),
                    DataColumn(label: Text('CLASS')),
                    DataColumn(label: Text('STATUS')),
                    DataColumn(label: Text('PARENT / PHONE')),
                    DataColumn(label: Text('ACTIONS')),
                  ],
                  rows: pagedStudents.map((student) {
                    final name =
                        '${student.firstName ?? student.name} ${student.lastName ?? ""}'
                            .trim();
                    final gradePill = _formatGradeSection(
                        student.gradeLevel, student.section);
                    final phone = student.guardianPhone ??
                        student.fatherPhone ??
                        student.motherPhone ??
                        '—';
                    final guardianName = student.fatherName ??
                        student.motherName ??
                        'Guardian';
                    final hasPhoto = student.photographPath != null &&
                        student.photographPath!.isNotEmpty &&
                        File(student.photographPath!).existsSync();

                    final statusText = student.isAlumni
                        ? 'Alumni'
                        : student.isActive
                            ? 'Active'
                            : 'Inactive';
                    final statusBg = student.isAlumni
                        ? const Color(0xFFFEF3C7)
                        : student.isActive
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9);
                    final statusColor = student.isAlumni
                        ? const Color(0xFFD97706)
                        : student.isActive
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF64748B);

                    return DataRow(
                      color: WidgetStateProperty.resolveWith<Color?>(
                          (states) {
                        if (states.contains(WidgetState.hovered)) {
                          return const Color(0xFFF8FAFC);
                        }
                        return null;
                      }),
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              hasPhoto
                                  ? CircleAvatar(
                                      radius: 19,
                                      backgroundColor: AppTheme.primarySoft,
                                      backgroundImage: FileImage(
                                          File(student.photographPath!)),
                                    )
                                  : AppAvatar(
                                      seed: student.admissionNumber ??
                                          student.name,
                                      name: student.name,
                                      size: 38,
                                      borderRadius: 19,
                                      fallbackColor:
                                          _initialsColor(student.name),
                                    ),
                              const SizedBox(width: 12),
                              Text(
                                name,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            student.admissionNumber ??
                                'STU-${student.id.length >= 4 ? student.id.substring(0, 4) : student.id}',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            (student.rollNumber != null &&
                                    student.rollNumber!.trim().isNotEmpty)
                                ? student.rollNumber!
                                : '—',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              gradePill,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF475569),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusText,
                              style: GoogleFonts.poppins(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                guardianName,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF475569),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                phone,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton(
                                onPressed: () =>
                                    _showStudentProfileDialog(context, student),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryPurple,
                                  side: const BorderSide(
                                      color: Color(0xFFCBD5E1)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(6)),
                                ),
                                child: Text(
                                  'View',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton.filledTonal(
                                tooltip: 'Fee Ledger',
                                icon: const Icon(Icons.receipt_long_rounded,
                                    size: 14),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFF3F0FF),
                                  foregroundColor: AppTheme.primaryPurple,
                                  padding: const EdgeInsets.all(6),
                                  minimumSize: const Size(30, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(6)),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => StudentFeeLedgerView(
                                          student: student),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              IconButton.filledTonal(
                                icon: Icon(
                                  student.isActive
                                      ? Icons.block_rounded
                                      : Icons.check_circle_outline_rounded,
                                  size: 14,
                                ),
                                tooltip: student.isActive
                                    ? 'Deactivate Student'
                                    : 'Reactivate Student',
                                style: IconButton.styleFrom(
                                  backgroundColor: student.isActive
                                      ? const Color(0xFFFEF2F2)
                                      : const Color(0xFFF0FDF4),
                                  foregroundColor: student.isActive
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF16A34A),
                                  padding: const EdgeInsets.all(6),
                                  minimumSize: const Size(30, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(6)),
                                ),
                                onPressed: () =>
                                    _toggleStudentStatus(student),
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
          ),
        ),
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildPaginationFooter(
                totalPages, totalStudents, startIndex, endIndex),
          ),
      ],
    );
  }

  Widget _buildPaginationFooter(
      int totalPages, int totalStudents, int startIndex, int endIndex) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${startIndex + 1}–$endIndex of $totalStudents students',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          Row(
            children: [
              Text(
                'Per page: ',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              DropdownButton<int>(
                value: _itemsPerPage,
                underline: const SizedBox.shrink(),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
                items: const [
                  DropdownMenuItem(value: 12, child: Text('12')),
                  DropdownMenuItem(value: 24, child: Text('24')),
                  DropdownMenuItem(value: 48, child: Text('48')),
                  DropdownMenuItem(value: 96, child: Text('96')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _itemsPerPage = val;
                      _currentPage = 0;
                    });
                  }
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 20),
                tooltip: 'First Page',
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage = 0)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                tooltip: 'Previous Page',
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_currentPage + 1} / $totalPages',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: 'Next Page',
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 20),
                tooltip: 'Last Page',
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage = totalPages - 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
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
                      child: (student.photographPath != null &&
                              student.photographPath!.isNotEmpty &&
                              File(student.photographPath!).existsSync())
                          ? CircleAvatar(
                              radius: 50,
                              backgroundColor: AppTheme.primarySoft,
                              backgroundImage: FileImage(File(student.photographPath!)),
                            )
                          : AppAvatar(
                              seed: student.admissionNumber ?? student.name,
                              name: student.name,
                              size: 100,
                              borderRadius: 50,
                              fallbackColor: AppTheme.primarySoft,
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
                                _buildDetailRow('Class', student.gradeLevel),
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
                            Consumer(
                              builder: (context, ref, _) {
                                final studentsAsync = ref.watch(studentsListProvider);
                                final freshStudent = studentsAsync.value?.where((s) => s.id == student.id).firstOrNull ?? student;
                                final bal = freshStudent.currentBalance;
                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: bal > 0 ? AppTheme.error.withValues(alpha: 0.05) : AppTheme.success.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: bal > 0 ? AppTheme.error.withValues(alpha: 0.3) : AppTheme.success.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: bal > 0 ? AppTheme.error.withValues(alpha: 0.1) : AppTheme.success.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          bal > 0 ? Icons.account_balance_wallet_rounded : Icons.check_circle_rounded,
                                          color: bal > 0 ? AppTheme.error : AppTheme.success,
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
                                              '₹${bal.toStringAsFixed(2)}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: bal > 0 ? AppTheme.error : AppTheme.success,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            _buildStudentDiscountsAndNetFeeCard(context, student),
                            const SizedBox(height: 16),
                            // Transport assignment is now managed from the Transport section
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
                            value: selectedGender,
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
                            value: selectedBlood,
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
                                    value: currentClass?.id,
                                    dropdownColor: Colors.white,
                                    style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                                    decoration: _buildEditInputDecoration('Class *'),
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
                                              value: currentSec?.id,
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
                                  decoration: _buildEditInputDecoration('Class'),
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
                    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.updateRecord)) return;
                    await dbService.updateStudent(updatedStudent);

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ref.invalidate(studentDirectoryProvider);
                      ref.invalidate(studentsListProvider);
                      ref.invalidate(dashboardMetricsProvider);
                          ref.invalidate(sectionStudentCountProvider);
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
                          ref.invalidate(sectionStudentCountProvider);
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
      final logoBytes = await SettingsService().getSchoolLogoBytes();
      final pdfBytes = await ReportGenerator.buildStudentIdCardPdfBytes(schoolLogo: logoBytes, student: student);
      if (context.mounted) {
        final savedFile = await PdfPreviewDialog.show(
          context: context,
          title: 'Student ID Card — ${student.name}',
          pdfBytes: pdfBytes,
          defaultFileName: 'ID_Card_${student.admissionNumber ?? student.id.substring(0, 6)}.pdf',
          defaultSubDirectory: 'ID_Cards',
        );
        if (context.mounted && savedFile != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ID Card saved to: ${savedFile.path}', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
              backgroundColor: AppTheme.primaryPurple,
            ),
          );
        }
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

                final logoBytes = await SettingsService().getSchoolLogoBytes();
                final pdfBytes = await ReportGenerator.buildTransferCertificatePdfBytes(
                  schoolLogo: logoBytes,
                  student: student,
                  tcNumber: tcNum,
                  tcDate: tcDate,
                  reasonForLeaving: reason,
                );

                ref.invalidate(studentDirectoryProvider);
                ref.invalidate(studentsListProvider);
                ref.invalidate(dashboardMetricsProvider);
                          ref.invalidate(sectionStudentCountProvider);

                if (context.mounted) {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Close profile modal
                  final savedFile = await PdfPreviewDialog.show(
                    context: context,
                    title: 'Transfer Certificate — $tcNum',
                    pdfBytes: pdfBytes,
                    defaultFileName: 'TC_${student.admissionNumber ?? student.id.substring(0, 6)}.pdf',
                    defaultSubDirectory: 'Certificates',
                  );
                  if (context.mounted && savedFile != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('TC Issued for ${student.name}! Saved to: ${savedFile.path}', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                        backgroundColor: AppTheme.primaryPurple,
                      ),
                    );
                  }
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
                value: selectedType,
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
    return Consumer(
      builder: (context, ref, child) {
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
      },
    );
  }

  Future<void> _showClassPromotionDialog(BuildContext context) async {
    final dbService = ref.read(databaseServiceProvider);

    // 1. Fetch all classes configured in Class & Section setup
    final fetchedClasses = await dbService.getAllClasses();
    final allClasses = List<ClassModel>.from(fetchedClasses)
      ..sort((a, b) => _compareClassNames(a.name, b.name));

    // Also include any class names stored on students
    final classNames = allClasses.map((c) => c.name.trim()).where((n) => n.isNotEmpty).toSet().toList();
    final allStudentsList = ref.read(studentsListProvider).value ?? [];
    for (final s in allStudentsList) {
      final clean = s.gradeLevel.trim();
      if (clean.isNotEmpty && !classNames.contains(clean)) {
        classNames.add(clean);
      }
    }
    if (classNames.isEmpty) {
      classNames.addAll([
        'Class 1st', 'Class 2nd', 'Class 3rd', 'Class 4th', 'Class 5th',
        'Class 6th', 'Class 7th', 'Class 8th', 'Class 9th', 'Class 10th',
        'Class 11th', 'Class 12th',
      ]);
    }
    classNames.sort(_compareClassNames);

    // Initial fromClass: use active filter if specific class, else first class
    final currentGradeFilter = ref.read(studentGradeFilterProvider);
    String fromClass = classNames.first;
    if (currentGradeFilter != 'All' && classNames.any((cn) => _matchesGrade(cn, currentGradeFilter))) {
      fromClass = classNames.firstWhere((cn) => _matchesGrade(cn, currentGradeFilter));
    }

    // Initial toClass: next class in sequence or Alumni / Graduated
    String toClass = 'Alumni / Graduated';
    final fromIdx = classNames.indexOf(fromClass);
    if (fromIdx != -1 && fromIdx + 1 < classNames.length) {
      toClass = classNames[fromIdx + 1];
    }

    // Preload students for fromClass
    List<Student> currentStudents = await dbService.getStudentsByGrade(fromClass);
    Set<String> selectedStudentIds = currentStudents.map((s) => s.id).toSet();

    // Auto-match target class & section for toClass
    List<Section> classSections = [];
    String? targetClassId;
    String? targetSectionId;
    String? targetSectionName;

    if (toClass != 'Alumni / Graduated') {
      final match = allClasses.where((c) => _matchesGrade(c.name, toClass)).firstOrNull;
      if (match != null) {
        targetClassId = match.id;
        classSections = await dbService.getSectionsForClass(match.id);
        if (classSections.isNotEmpty) {
          targetSectionId = classSections.first.id;
          targetSectionName = classSections.first.name;
        }
      }
    }

    bool isLoading = false;
    bool isLoadingSections = false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isAlumni = toClass == 'Alumni / Graduated';

          return AlertDialog(
            backgroundColor: Colors.white,
            title: Row(
              children: [
                const Icon(Icons.published_with_changes_rounded, color: AppTheme.primaryPurple),
                const SizedBox(width: 10),
                Text('STUDENT PROMOTION TOOL', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            content: SizedBox(
              width: 650,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Promote students to a new academic session and assign them to a class/section.', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: fromClass,
                            style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                            decoration: const InputDecoration(labelText: 'From Class (Current)'),
                            items: classNames.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) async {
                              if (val != null && val != fromClass) {
                                setDialogState(() {
                                  fromClass = val;
                                  isLoading = true;
                                });
                                final students = await dbService.getStudentsByGrade(val);
                                setDialogState(() {
                                  currentStudents = students;
                                  selectedStudentIds = students.map((s) => s.id).toSet();
                                  isLoading = false;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: toClass,
                            style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                            decoration: const InputDecoration(labelText: 'To Class (Target)'),
                            items: [...classNames, 'Alumni / Graduated'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) async {
                              if (val != null) {
                                setDialogState(() {
                                  toClass = val;
                                  targetClassId = null;
                                  targetSectionId = null;
                                  targetSectionName = null;
                                  classSections.clear();
                                  isLoadingSections = true;
                                });

                                if (val != 'Alumni / Graduated') {
                                  final match = allClasses.where((c) => _matchesGrade(c.name, val)).firstOrNull;
                                  if (match != null) {
                                    final secs = await dbService.getSectionsForClass(match.id);
                                    setDialogState(() {
                                      targetClassId = match.id;
                                      classSections = secs;
                                      isLoadingSections = false;
                                      if (secs.isNotEmpty) {
                                        targetSectionId = secs.first.id;
                                        targetSectionName = secs.first.name;
                                      }
                                    });
                                    return;
                                  }
                                }
                                setDialogState(() {
                                  isLoadingSections = false;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (!isAlumni) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Assignment Details (Optional but Recommended)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: targetClassId,
                                    style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                                    decoration: const InputDecoration(labelText: 'Target Class (Session)', filled: true, fillColor: Colors.white),
                                    items: allClasses.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.academicYear ?? "Any Session"})'))).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() {
                                          targetClassId = val;
                                          targetSectionId = null;
                                          targetSectionName = null;
                                          isLoadingSections = true;
                                          dbService.getSectionsForClass(val).then((secs) {
                                            setDialogState(() {
                                              classSections = secs;
                                              isLoadingSections = false;
                                              if (secs.isNotEmpty) {
                                                targetSectionId = secs.first.id;
                                                targetSectionName = secs.first.name;
                                              }
                                            });
                                          });
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: isLoadingSections
                                      ? const Center(child: CircularProgressIndicator())
                                      : DropdownButtonFormField<String>(
                                          value: targetSectionId,
                                          style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                                          decoration: const InputDecoration(labelText: 'Target Section', filled: true, fillColor: Colors.white),
                                          items: classSections.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setDialogState(() {
                                                targetSectionId = val;
                                                targetSectionName = classSections.firstWhere((s) => s.id == val).name;
                                              });
                                            }
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (currentStudents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(child: Text('No active students found in $fromClass.', style: GoogleFonts.poppins(color: AppTheme.textHint))),
                      )
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Students in $fromClass (${currentStudents.length}):', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
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
          ),
          actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: selectedStudentIds.isEmpty || (isLoading || isLoadingSections)
                    ? null
                    : () async {
                        try {
                          setDialogState(() => isLoading = true);
                          final currentAy = await dbService.getCurrentAcademicYear();
                          final fromYear = currentAy?.name ?? '2026-2027';

                          // Determine target academic year
                          String targetYear;
                          if (targetClassId != null) {
                            try {
                              final match = allClasses.firstWhere((c) => c.id == targetClassId);
                              targetYear = match.academicYear ?? _nextAcademicYear(fromYear);
                            } catch (_) {
                              targetYear = _nextAcademicYear(fromYear);
                            }
                          } else {
                            targetYear = _nextAcademicYear(fromYear);
                          }

                          // Query unpaid fee dues summary for all selected students
                          final duesMap = await dbService.getStudentsUnpaidDuesSummary(
                            studentIds: selectedStudentIds.toList(),
                            academicYear: fromYear,
                          );

                          final studentsWithDues = duesMap.values.where((s) => s.unpaidBalance > 0.01).toList();

                          if (studentsWithDues.isEmpty) {
                            // All selected students are fee-cleared! Proceed directly
                            await dbService.promoteStudentsWithArrearsRollover(
                              studentIds: selectedStudentIds.toList(),
                              targetGrade: isAlumni ? fromClass : toClass,
                              classId: isAlumni ? null : targetClassId,
                              sectionId: isAlumni ? null : targetSectionId,
                              sectionName: isAlumni ? null : targetSectionName,
                              markAsAlumni: isAlumni,
                              fromAcademicYear: fromYear,
                              toAcademicYear: targetYear,
                              rolloverArrears: false,
                            );

                            ref.invalidate(studentDirectoryProvider);
                            ref.invalidate(studentsListProvider);
                            ref.invalidate(dashboardMetricsProvider);
                            ref.invalidate(sectionStudentCountProvider);

                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Fee Clearance Verified: Successfully promoted ${selectedStudentIds.length} student(s) to $toClass!', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                                  backgroundColor: AppTheme.primaryPurple,
                                ),
                              );
                            }
                          } else {
                            // Uncleared dues detected: trigger Step 2 Warning Modal
                            setDialogState(() => isLoading = false);
                            if (context.mounted) {
                              _showFeeClearanceWarningDialog(
                                parentContext: context,
                                studentsWithDues: studentsWithDues,
                                allSelectedIds: selectedStudentIds,
                                fromClass: fromClass,
                                toClass: toClass,
                                fromYear: fromYear,
                                targetYear: targetYear,
                                targetClassId: targetClassId,
                                targetSectionId: targetSectionId,
                                targetSectionName: targetSectionName,
                                isAlumni: isAlumni,
                              );
                            }
                          }
                        } catch (e, stackTrace) {
                          setDialogState(() => isLoading = false);
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

  String _nextAcademicYear(String currentYear) {
    final clean = currentYear.replaceFirst('ay-', '');
    final parts = clean.split('-');
    if (parts.length == 2) {
      final start = int.tryParse(parts[0]);
      final end = int.tryParse(parts[1]);
      if (start != null && end != null) {
        return '${start + 1}-${end + 1}';
      }
    }
    return '2027-2028';
  }

  void _showFeeClearanceWarningDialog({
    required BuildContext parentContext,
    required List<StudentFeeDuesSummary> studentsWithDues,
    required Set<String> allSelectedIds,
    required String fromClass,
    required String toClass,
    required String fromYear,
    required String targetYear,
    required String? targetClassId,
    required String? targetSectionId,
    required String? targetSectionName,
    required bool isAlumni,
  }) {
    final totalUnpaid = studentsWithDues.fold(0.0, (sum, s) => sum + s.unpaidBalance);
    final unpaidStudentIds = studentsWithDues.map((s) => s.studentId).toSet();
    final clearedStudentIds = allSelectedIds.difference(unpaidStudentIds);

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (modalCtx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Fee Clearance & Arrears Warning', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF92400E))),
                  Text('Step 2: Session End Financial Audit ($fromYear)', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 450),
              child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Alert Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${studentsWithDues.length} of ${allSelectedIds.length} student(s) have uncleared dues totaling ₹${totalUnpaid.toStringAsFixed(0)} in session $fromYear.',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Students with Uncleared Fee Obligations:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  // List of unpaid students
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: studentsWithDues.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                      itemBuilder: (context, idx) {
                        final item = studentsWithDues[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFFFEF3C7),
                                child: Text('${idx + 1}', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFB45309))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.studentName, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    Text(
                                      'Roll: ${item.rollNumber ?? "N/A"} • ${item.unpaidDetails.join(', ')}',
                                      style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${item.unpaidBalance.toStringAsFixed(0)} Due',
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.error),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Policy options explanation
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Choose Resolution Policy:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                        const SizedBox(height: 4),
                        Text('• Strict Policy: Collect all pending dues before promoting students.', style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade800)),
                        Text('• Rollover Policy: Carry forward dues as "Previous Session Arrears" in $targetYear.', style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
            // Action 1: Cancel
            TextButton(
              onPressed: () => Navigator.of(modalCtx).pop(),
              child: Text('Cancel & Collect Dues', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
            ),
            // Action 2: Promote Cleared Only
            if (clearedStudentIds.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () async {
                  final dbService = ref.read(databaseServiceProvider);
                  Navigator.of(modalCtx).pop(); // close warning
                  Navigator.of(parentContext).pop(); // close promotion tool

                  try {
                    await dbService.promoteStudentsWithArrearsRollover(
                      studentIds: clearedStudentIds.toList(),
                      targetGrade: isAlumni ? fromClass : toClass,
                      classId: isAlumni ? null : targetClassId,
                      sectionId: isAlumni ? null : targetSectionId,
                      sectionName: isAlumni ? null : targetSectionName,
                      markAsAlumni: isAlumni,
                      fromAcademicYear: fromYear,
                      toAcademicYear: targetYear,
                      rolloverArrears: false,
                    );

                    ref.invalidate(studentDirectoryProvider);
                    ref.invalidate(studentsListProvider);
                    ref.invalidate(dashboardMetricsProvider);
                    ref.invalidate(sectionStudentCountProvider);

                    if (parentContext.mounted) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Promoted ${clearedStudentIds.length} fee-cleared student(s) to $toClass. ${studentsWithDues.length} student(s) with dues withheld in $fromClass.',
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: AppTheme.primaryPurple,
                        ),
                      );
                    }
                  } catch (e) {
                    if (parentContext.mounted) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Text('Promote Cleared Only (${clearedStudentIds.length})', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryPurple),
              ),
            // Action 3: Promote All with Rollover
            ElevatedButton.icon(
              onPressed: () async {
                final dbService = ref.read(databaseServiceProvider);
                Navigator.of(modalCtx).pop(); // close warning
                Navigator.of(parentContext).pop(); // close promotion tool

                try {
                  await dbService.promoteStudentsWithArrearsRollover(
                    studentIds: allSelectedIds.toList(),
                    targetGrade: isAlumni ? fromClass : toClass,
                    classId: isAlumni ? null : targetClassId,
                    sectionId: isAlumni ? null : targetSectionId,
                    sectionName: isAlumni ? null : targetSectionName,
                    markAsAlumni: isAlumni,
                    fromAcademicYear: fromYear,
                    toAcademicYear: targetYear,
                    rolloverArrears: true,
                  );

                  ref.invalidate(studentDirectoryProvider);
                  ref.invalidate(studentsListProvider);
                  ref.invalidate(dashboardMetricsProvider);
                  ref.invalidate(sectionStudentCountProvider);

                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Promoted all ${allSelectedIds.length} student(s) to $toClass! Rolled over ₹${totalUnpaid.toStringAsFixed(0)} dues as Previous Session Arrears into $targetYear.',
                        ),
                        backgroundColor: AppTheme.primaryPurple,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                } catch (e) {
                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                    );
                  }
                }
              },
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: Text('Promote & Rollover Arrears', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStudentDiscountsAndNetFeeCard(BuildContext context, Student student) {
    const academicYear = '2026-2027';
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
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.discount_rounded, color: AppTheme.primaryPurple, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Fee Discounts & Net Fee', 
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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
                      final name = sd.customName ?? dt?.name ?? "Discount";
                      final kind = sd.customKind ?? dt?.discountKind ?? 'percentage';
                      final val = sd.customValue ?? dt?.value ?? 0.0;
                      final valStr = kind == 'percentage'
                          ? '${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1)}%'
                          : '₹${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 2)}';
                      final modeStr = kind == 'flat'
                          ? (sd.flatMode == 'earliest' ? ' • Earliest' : ' • Monthly')
                          : '';

                      return Chip(
                        backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.08),
                        side: const BorderSide(color: AppTheme.primaryPurple),
                        avatar: const Icon(Icons.card_giftcard_rounded, size: 14, color: AppTheme.primaryPurple),
                        label: Text('$name ($valStr$modeStr)',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                        onDeleted: () async {
                          final dbService = ref.read(databaseServiceProvider);
                          await dbService.removeStudentDiscount(sd.id);
                          ref.invalidate(studentDiscountsProvider(studentYearParam));
                          ref.invalidate(studentNetFeeBreakdownProvider(studentClassYearParam));
                          ref.invalidate(studentsListProvider);
                          ref.invalidate(studentFeeLedgerProvider);
                          ref.invalidate(dashboardMetricsProvider);
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
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Text('No fee structure configured for ${student.gradeLevel}. Once fee heads are defined in Fee Structure setup, net dues will auto-calculate here.',
                          style: GoogleFonts.poppins(fontSize: 11.5, color: AppTheme.textHint, fontStyle: FontStyle.italic)),
                    );
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

    bool isCustom = types.isEmpty;
    String selectedTypeId = types.isNotEmpty ? types.first.id : 'custom';
    String customKind = 'percentage';
    String flatMode = 'evenly'; // 'evenly' or 'earliest'

    final customNameController = TextEditingController();
    final customValueController = TextEditingController();
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentPreset = types.where((t) => t.id == selectedTypeId).firstOrNull;
          final isFlat = isCustom ? customKind == 'flat' : currentPreset?.discountKind == 'flat';

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.card_giftcard_rounded, color: AppTheme.primaryPurple, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Apply Discount / Scholarship',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preset vs Custom Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.bgMain,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (types.isNotEmpty) {
                                  setDialogState(() => isCustom = false);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !isCustom ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: !isCustom
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Standard Presets',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: !isCustom ? FontWeight.bold : FontWeight.w500,
                                    color: !isCustom ? AppTheme.primaryPurple : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(() => isCustom = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isCustom ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: isCustom
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Custom Discount',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: isCustom ? FontWeight.bold : FontWeight.w500,
                                    color: isCustom ? AppTheme.primaryPurple : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (!isCustom) ...[
                      DropdownButtonFormField<String>(
                        value: selectedTypeId,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Select Discount Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: types.map((dt) {
                          final valStr = dt.discountKind == 'percentage' ? '${dt.value}%' : '₹${dt.value}';
                          return DropdownMenuItem(value: dt.id, child: Text('${dt.name} ($valStr)'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedTypeId = val);
                        },
                      ),
                    ] else ...[
                      TextField(
                        controller: customNameController,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Scholarship / Discount Title *',
                          hintText: 'e.g. Sports Concession, Special Waiver',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Percentage (%)'),
                              selected: customKind == 'percentage',
                              onSelected: (sel) {
                                if (sel) setDialogState(() => customKind = 'percentage');
                              },
                              selectedColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
                              labelStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: customKind == 'percentage' ? FontWeight.bold : FontWeight.normal,
                                color: customKind == 'percentage' ? AppTheme.primaryPurple : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Flat Amount (₹)'),
                              selected: customKind == 'flat',
                              onSelected: (sel) {
                                if (sel) setDialogState(() => customKind = 'flat');
                              },
                              selectedColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
                              labelStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: customKind == 'flat' ? FontWeight.bold : FontWeight.normal,
                                color: customKind == 'flat' ? AppTheme.primaryPurple : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: customValueController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: customKind == 'percentage' ? 'Percentage (e.g. 15 for 15%) *' : 'Flat Amount in ₹ (e.g. 5000) *',
                          border: const OutlineInputBorder(),
                          prefixText: customKind == 'flat' ? '₹ ' : null,
                          suffixText: customKind == 'percentage' ? '%' : null,
                        ),
                      ),
                    ],

                    // Flat Mode Choice (if flat discount)
                    if (isFlat) ...[
                      const SizedBox(height: 16),
                      Text('How should this flat discount be applied?',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.bgMain,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text('Distribute evenly across months',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                              subtitle: Text('Divides discount equally each cycle (e.g. ₹6,000 ÷ 12 = ₹500 off each month)',
                                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                              value: 'evenly',
                              groupValue: flatMode,
                              onChanged: (val) {
                                if (val != null) setDialogState(() => flatMode = val);
                              },
                            ),
                            const Divider(height: 12),
                            RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text('Deduct from earliest dues first',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                              subtitle: Text('Waives earliest months fully until the discount pool is exhausted',
                                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                              value: 'earliest',
                              groupValue: flatMode,
                              onChanged: (val) {
                                if (val != null) setDialogState(() => flatMode = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    TextField(
                      controller: remarksController,
                      style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Remarks / Approval Note (Optional)',
                        hintText: 'e.g. Approved by Principal on 10 Aug',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (isCustom) {
                    if (customNameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a scholarship / discount name.'), backgroundColor: AppTheme.error),
                      );
                      return;
                    }
                    final val = double.tryParse(customValueController.text.trim());
                    if (val == null || val <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid positive discount amount/percentage.'), backgroundColor: AppTheme.error),
                      );
                      return;
                    }
                    if (customKind == 'percentage' && val > 100) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Percentage cannot exceed 100%.'), backgroundColor: AppTheme.error),
                      );
                      return;
                    }
                  }

                  const academicYear = '2026-2027';
                  final sd = StudentDiscount.create(
                    studentId: student.id,
                    discountTypeId: isCustom ? 'custom' : selectedTypeId,
                    academicYear: academicYear,
                    customName: isCustom ? customNameController.text.trim() : null,
                    customKind: isCustom ? customKind : null,
                    customValue: isCustom ? double.tryParse(customValueController.text.trim()) : null,
                    flatMode: flatMode,
                    remarks: remarksController.text.trim().isNotEmpty ? remarksController.text.trim() : null,
                  );

                  final dbService = ref.read(databaseServiceProvider);
                  await dbService.applyStudentDiscount(sd);

                  final studentYearParam = StudentYearParam(studentId: student.id, academicYear: academicYear);
                  final studentClassYearParam = StudentClassYearParam(studentId: student.id, className: student.gradeLevel, academicYear: academicYear);
                  ref.invalidate(studentDiscountsProvider(studentYearParam));
                  ref.invalidate(studentNetFeeBreakdownProvider(studentClassYearParam));
                  ref.invalidate(studentsListProvider);
                  ref.invalidate(studentFeeLedgerProvider);
                  ref.invalidate(dashboardMetricsProvider);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Discount applied and dues recalculated!'),
                          ],
                        ),
                        backgroundColor: AppTheme.primaryPurple,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Apply Discount'),
              ),
            ],
          );
        },
      ),
    );
  }
}