import 'dart:io';
import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/auth/permission_helper.dart';
import '../../../services/report_card_generator.dart';

/// Examination & Reports Management View — Exams Setup, Marks Entry,
/// Report Cards, Term Aggregation, and Grade Scale Config.
class ExamManagementView extends ConsumerStatefulWidget {
  const ExamManagementView({super.key});

  @override
  ConsumerState<ExamManagementView> createState() => _ExamManagementViewState();
}

class _ExamManagementViewState extends ConsumerState<ExamManagementView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _dateFormat = DateFormat('dd MMM yyyy');

  String _selectedClassFilter = 'All';
  String _selectedAcademicYear = '2024-2025';

  // Marks Entry Tab state
  String? _selectedExamIdForMarks;
  String? _selectedSubjectIdForMarks;
  List<Marks> _currentMarksSheet = [];
  bool _isSavingMarks = false;

  // Report Card Tab state
  String? _selectedReportExamId;
  String? _selectedReportStudentId;

  // Dashboard Tab state
  String? _selectedDashboardExamId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          _buildHeader(context),

          // Navigation TabBar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryPurple,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primaryPurple,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: 'Exams & Schedule Setup'),
                Tab(text: 'Marks Entry Roster'),
                Tab(text: 'Report Cards & Term Results'),
                Tab(text: 'Grading Scale Config'),
                Tab(text: 'Results Dashboard'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildExamsSetupTab(),
                _buildMarksEntryTab(),
                _buildReportCardsTab(),
                _buildGradingScaleTab(),
                _buildResultsDashboardTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Examination & Performance Reports',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                'Configure exam schedules, assign subject papers, enter student marks, compute grades & term results, and print report cards.',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 1: EXAMS & SCHEDULE SETUP
  // ============================================================================

  Widget _buildExamsSetupTab() {
    final param = ExamClassYearParam(className: _selectedClassFilter, academicYear: _selectedAcademicYear);
    final examsAsync = ref.watch(examsProvider(param));
    final classesAsync = ref.watch(classListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Filter Dropdowns
              Row(
                children: [
                  Text('Class Filter: ', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  classesAsync.when(
                    data: (classes) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedClassFilter,
                          underline: const SizedBox(),
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('All Classes')),
                            ...classes.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedClassFilter = val);
                          },
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),

              ElevatedButton.icon(
                onPressed: () => _showAddEditExamDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Create Exam Event', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          examsAsync.when(
            data: (exams) {
              if (exams.isEmpty) {
                return _buildEmptyCard('No examinations scheduled yet. Click "Create Exam Event" to set up tests or term exams.');
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: exams.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final exam = exams[index];
                  return Consumer(
                    builder: (context, ref, _) {
                      final subjectsAsync = ref.watch(examSubjectsProvider(exam.id));

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.assignment_rounded, color: AppTheme.primaryPurple, size: 22),
                                    const SizedBox(width: 10),
                                    Text(
                                      exam.name,
                                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        exam.examTypeName ?? 'Exam',
                                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.bgSurface,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.divider),
                                      ),
                                      child: Text(
                                        'Class: ${exam.className} ${exam.section != null ? "(${exam.section})" : ""}',
                                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _showAddSubjectDialog(context, exam),
                                      icon: const Icon(Icons.add_task_rounded, size: 16),
                                      label: Text('Add Subject Paper', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.primaryPurple,
                                        side: const BorderSide(color: AppTheme.primaryPurple),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      onPressed: () => _showAddEditExamDialog(context, exam: exam),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                                      onPressed: () {
                                        if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.deleteRecord)) return;
                                        _confirmDeleteExam(context, exam);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Schedule: ${_dateFormat.format(exam.startDate)} ➔ ${_dateFormat.format(exam.endDate)}  •  Academic Year: ${exam.academicYear}',
                              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: AppTheme.divider),
                            const SizedBox(height: 12),

                            // Exam Subjects List
                            subjectsAsync.when(
                              data: (subjects) {
                                if (subjects.isEmpty) {
                                  return Text('No subject papers added to this exam yet.',
                                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint, fontStyle: FontStyle.italic));
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: subjects.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                                  itemBuilder: (context, sIdx) {
                                    final sub = subjects[sIdx];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.menu_book_rounded, size: 16, color: AppTheme.primaryPurple),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 3,
                                            child: Text(sub.subject, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text('Date: ${_dateFormat.format(sub.examDate)}', style: GoogleFonts.poppins(fontSize: 12)),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text('Max: ${sub.maxMarks.toStringAsFixed(0)}  (Pass: ${sub.passingMarks.toStringAsFixed(0)})',
                                                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text('Evaluator: ${sub.staffName ?? "Unassigned"}',
                                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500)),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.error),
                                            onPressed: () async {
                                              if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.deleteRecord)) return;
                                              final dbService = ref.read(databaseServiceProvider);
                                              await dbService.deleteExamSubject(sub.id);
                                              ref.invalidate(examSubjectsProvider(exam.id));
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => Text('Error loading subjects: $e'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Text('Error loading exams: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 2: MARKS ENTRY ROSTER
  // ============================================================================

  Widget _buildMarksEntryTab() {
    final param = ExamClassYearParam(className: 'All', academicYear: _selectedAcademicYear);
    final examsAsync = ref.watch(examsProvider(param));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selectors Row
          Row(
            children: [
              // Select Exam
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Examination Event *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    examsAsync.when(
                      data: (exams) {
                        if (exams.isEmpty) {
                          _selectedExamIdForMarks = null;
                        } else if (_selectedExamIdForMarks == null || !exams.any((e) => e.id == _selectedExamIdForMarks)) {
                          _selectedExamIdForMarks = exams.first.id;
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedExamIdForMarks,
                            underline: const SizedBox(),
                            hint: Text('Select Exam', style: GoogleFonts.poppins(fontSize: 12)),
                            items: exams
                                .map((e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text('${e.name} (${e.className})', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedExamIdForMarks = val;
                                  _selectedSubjectIdForMarks = null;
                                  _currentMarksSheet = [];
                                });
                              }
                            },
                          ),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Select Subject Paper
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Subject Paper *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    _selectedExamIdForMarks == null
                        ? Container(
                            height: 42,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppTheme.divider), borderRadius: BorderRadius.circular(8)),
                            child: Text('Select an exam first', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint)),
                          )
                        : Consumer(
                            builder: (context, ref, _) {
                              final subjectsAsync = ref.watch(examSubjectsProvider(_selectedExamIdForMarks!));

                              return subjectsAsync.when(
                                data: (subjects) {
                                  var filteredSubjects = subjects;
                                  final currentUser = ref.watch(authProvider).currentUser;
                                  if (currentUser?.role == UserRole.teacher && currentUser?.staffId != null) {
                                    filteredSubjects = subjects.where((s) => s.staffId == currentUser!.staffId).toList();
                                  }

                                  if (filteredSubjects.isEmpty) {
                                    return Container(
                                      height: 42,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppTheme.divider), borderRadius: BorderRadius.circular(8)),
                                      child: Text('No subjects assigned to you', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint)),
                                    );
                                  }

                                  if (_selectedSubjectIdForMarks == null || !filteredSubjects.any((s) => s.id == _selectedSubjectIdForMarks)) {
                                    _selectedSubjectIdForMarks = filteredSubjects.first.id;
                                  }

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.divider),
                                    ),
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: _selectedSubjectIdForMarks,
                                      underline: const SizedBox(),
                                      hint: Text('Select Subject', style: GoogleFonts.poppins(fontSize: 12)),
                                      items: filteredSubjects
                                          .map((s) => DropdownMenuItem(
                                                value: s.id,
                                                child: Text('${s.subject} (Max: ${s.maxMarks.toStringAsFixed(0)})', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedSubjectIdForMarks = val;
                                            _currentMarksSheet = [];
                                          });
                                        }
                                      },
                                    ),
                                  );
                                },
                                loading: () => const LinearProgressIndicator(),
                                error: (e, _) => Text('Error: $e'),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Marks Sheet Table
          if (_selectedSubjectIdForMarks == null)
            _buildEmptyCard('Select an examination event and subject paper to load the student roster for marks entry.')
          else
            Consumer(
              builder: (context, ref, _) {
                final sheetAsync = ref.watch(marksSheetProvider(_selectedSubjectIdForMarks!));

                return sheetAsync.when(
                  data: (roster) {
                    if (_currentMarksSheet.isEmpty && roster.isNotEmpty) {
                      _currentMarksSheet = List.from(roster);
                    }

                    if (_currentMarksSheet.isEmpty) {
                      return _buildEmptyCard('No enrolled students found in this class/section roster.');
                    }

                    final firstSub = roster.first;
                    final maxMarks = firstSub.maxMarks ?? 100.0;
                    final passMarks = firstSub.passingMarks ?? 35.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Marks Sheet — ${firstSub.subject} (Max: ${maxMarks.toStringAsFixed(0)} | Pass: ${passMarks.toStringAsFixed(0)})',
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            ElevatedButton.icon(
                              onPressed: _isSavingMarks
                                  ? null
                                  : () async {
                                      setState(() => _isSavingMarks = true);
                                      final dbService = ref.read(databaseServiceProvider);
                                      await dbService.bulkUpdateMarks(_selectedSubjectIdForMarks!, _currentMarksSheet);
                                      ref.invalidate(marksSheetProvider(_selectedSubjectIdForMarks!));
                                      setState(() => _isSavingMarks = false);

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Marks sheet saved successfully!'), backgroundColor: AppTheme.success),
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.save_rounded, size: 18),
                              label: Text(_isSavingMarks ? 'Saving...' : 'Save Marks Sheet', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: const BoxDecoration(
                                  color: AppTheme.bgSurface,
                                  borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                                ),
                                child: Row(
                                  children: [
                                    _th('Roll #', flex: 2),
                                    _th('Student Name', flex: 5),
                                    _th('Class & Sec', flex: 3),
                                    _th('Marks Obtained', flex: 3),
                                    _th('Absent?', flex: 2),
                                    _th('Result Status', flex: 3),
                                    _th('Remarks', flex: 4),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: AppTheme.divider),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _currentMarksSheet.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                                itemBuilder: (context, index) {
                                  final m = _currentMarksSheet[index];
                                  final obtainedController = TextEditingController(
                                    text: m.marksObtained != null ? m.marksObtained!.toStringAsFixed(1) : '',
                                  );
                                  final remarksController = TextEditingController(text: m.remarks ?? '');

                                  final isAbsent = m.isAbsent;
                                  final double val = m.marksObtained ?? 0.0;
                                  final bool pass = !isAbsent && m.marksObtained != null && val >= passMarks;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(m.rollNumber ?? 'N/A', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        Expanded(
                                          flex: 5,
                                          child: Text(m.studentName ?? 'Student', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text('${m.gradeLevel ?? ""} ${m.section ?? ""}', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: SizedBox(
                                            height: 36,
                                            child: TextField(
                                              enabled: !isAbsent,
                                              controller: obtainedController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                                              decoration: InputDecoration(
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                                hintText: '/ ${maxMarks.toStringAsFixed(0)}',
                                              ),
                                              onChanged: (text) {
                                                final parsed = double.tryParse(text);
                                                _currentMarksSheet[index] = m.copyWith(marksObtained: parsed);
                                                setState(() {});
                                              },
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Checkbox(
                                            value: isAbsent,
                                            activeColor: AppTheme.error,
                                            onChanged: (val) {
                                              setState(() {
                                                _currentMarksSheet[index] = m.copyWith(isAbsent: val ?? false);
                                              });
                                            },
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isAbsent
                                                  ? AppTheme.error.withValues(alpha: 0.1)
                                                  : (pass ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1)),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isAbsent ? 'ABSENT' : (m.marksObtained != null ? (pass ? 'PASS' : 'FAIL') : 'PENDING'),
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isAbsent ? AppTheme.error : (pass ? AppTheme.success : AppTheme.error),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 4,
                                          child: SizedBox(
                                            height: 36,
                                            child: TextField(
                                              controller: remarksController,
                                              style: GoogleFonts.poppins(fontSize: 11),
                                              decoration: InputDecoration(
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                                hintText: 'Optional remark',
                                              ),
                                              onChanged: (text) {
                                                _currentMarksSheet[index] = m.copyWith(remarks: text);
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (e, _) => Text('Error loading marks sheet: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
                );
              },
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 3: REPORT CARDS & TERM RESULTS
  // ============================================================================

  Widget _buildReportCardsTab() {
    final param = ExamClassYearParam(className: _selectedClassFilter, academicYear: _selectedAcademicYear);
    final examsAsync = ref.watch(examsProvider(param));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Exam Event', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    examsAsync.when(
                      data: (exams) {
                        if (exams.isEmpty) {
                          _selectedReportExamId = null;
                        } else if (_selectedReportExamId == null || !exams.any((e) => e.id == _selectedReportExamId)) {
                          _selectedReportExamId = exams.first.id;
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedReportExamId,
                            underline: const SizedBox(),
                            hint: Text('Choose Exam', style: GoogleFonts.poppins(fontSize: 12)),
                            items: exams
                                .map((e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text('${e.name} (${e.className})', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedReportExamId = val);
                            },
                          ),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Student Roster', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Consumer(
                      builder: (context, ref, _) {
                        final studentDirAsync = ref.watch(studentsListProvider);
                        return studentDirAsync.when(
                          data: (allStudents) {
                            final exams = examsAsync.value ?? [];
                            final selectedExam = exams.where((e) => e.id == _selectedReportExamId).firstOrNull;
                            
                            List<Student> students = allStudents;
                            if (selectedExam != null && selectedExam.className != 'All') {
                               students = allStudents.where((s) => s.gradeLevel == selectedExam.className || s.classId == selectedExam.className).toList();
                            }

                            if (students.isEmpty) {
                              _selectedReportStudentId = null;
                            } else if (_selectedReportStudentId == null || !students.any((s) => s.id == _selectedReportStudentId)) {
                              _selectedReportStudentId = students.first.id;
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedReportStudentId,
                                underline: const SizedBox(),
                                hint: Text('Choose Student', style: GoogleFonts.poppins(fontSize: 12)),
                                items: students
                                    .map((s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Text('${s.name} (${s.gradeLevel} - ${s.section ?? "A"})', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedReportStudentId = val);
                                },
                              ),
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Error: $e'),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_selectedReportExamId == null || _selectedReportStudentId == null)
            _buildEmptyCard('Select an examination event and student from the dropdowns above to generate their report card.')
          else
            Consumer(
              builder: (context, ref, _) {
                final studentExamParam = StudentExamParam(studentId: _selectedReportStudentId!, examId: _selectedReportExamId!);
                final resultAsync = ref.watch(examResultProvider(studentExamParam));
                final rankingsAsync = ref.watch(classExamRankingsProvider(_selectedReportExamId!));

                return resultAsync.when(
                  data: (examRes) {
                    if (examRes == null) {
                      return _buildEmptyCard('No exam subjects or marks found for this student in the selected exam event.');
                    }

                    final int? rank = rankingsAsync.value?[_selectedReportStudentId!];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Report Card Preview Card
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        examRes.studentName,
                                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                      ),
                                      Text(
                                        'Roll #: ${examRes.rollNumber}  •  Class: ${examRes.className} ${examRes.section != null ? "(${examRes.section})" : ""}  •  Academic Year: ${examRes.academicYear}',
                                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final File file = await ReportCardGenerator.generateReportCard(
                                        examResult: examRes,
                                        rankInClass: rank,
                                      );

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Report Card PDF exported to ${file.path}'),
                                            backgroundColor: AppTheme.primaryPurple,
                                            duration: const Duration(seconds: 4),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                                    label: Text('Download / Print PDF Report Card', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Subject Marks Table
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.divider),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      color: AppTheme.bgSurface,
                                      child: Row(
                                        children: [
                                          _th('Subject', flex: 4),
                                          _th('Max Marks', flex: 2),
                                          _th('Pass Marks', flex: 2),
                                          _th('Obtained', flex: 2),
                                          _th('Grade', flex: 2),
                                          _th('Result Status', flex: 2),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1, color: AppTheme.divider),
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: examRes.subjectResults.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                                      itemBuilder: (context, idx) {
                                        final sub = examRes.subjectResults[idx];
                                        return Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              Expanded(flex: 4, child: Text(sub.subject, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13))),
                                              Expanded(flex: 2, child: Text(sub.maxMarks.toStringAsFixed(0), style: GoogleFonts.poppins(fontSize: 12))),
                                              Expanded(flex: 2, child: Text(sub.passingMarks.toStringAsFixed(0), style: GoogleFonts.poppins(fontSize: 12))),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  sub.isAbsent ? 'ABSENT' : (sub.marksObtained?.toStringAsFixed(1) ?? 'N/A'),
                                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: sub.isAbsent ? AppTheme.error : AppTheme.textPrimary),
                                                ),
                                              ),
                                              Expanded(flex: 2, child: Text(sub.grade, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  sub.isPassed ? 'PASS' : 'FAIL',
                                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: sub.isPassed ? AppTheme.success : AppTheme.error),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Exam Summary Row Cards
                              Row(
                                children: [
                                  _resultSummaryBox('TOTAL MARKS', '${examRes.totalMarksObtained.toStringAsFixed(1)} / ${examRes.totalMaxMarks.toStringAsFixed(0)}', AppTheme.primaryPurple),
                                  const SizedBox(width: 12),
                                  _resultSummaryBox('PERCENTAGE', '${examRes.percentage.toStringAsFixed(2)}%', AppTheme.info),
                                  const SizedBox(width: 12),
                                  _resultSummaryBox('OVERALL GRADE', examRes.grade, AppTheme.primaryPurple),
                                  const SizedBox(width: 12),
                                  _resultSummaryBox('CLASS RANK', rank != null ? '$rank' : 'N/A', AppTheme.success),
                                  const SizedBox(width: 12),
                                  _resultSummaryBox('FINAL RESULT', examRes.isPassed ? 'PASSED' : 'FAILED', examRes.isPassed ? AppTheme.success : AppTheme.error),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (e, _) => Text('Error loading report card: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
                );
              },
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 4: GRADING SCALE CONFIG
  // ============================================================================

  Widget _buildGradingScaleTab() {
    final scaleAsync = ref.watch(gradeScalesProvider(_selectedAcademicYear));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Academic Grading Scale Configuration (${_selectedAcademicYear})',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddGradeScaleDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Add Grade Threshold', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),

          scaleAsync.when(
            data: (scales) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: const BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          _th('Grade Letter', flex: 2),
                          _th('Min Percentage (%)', flex: 3),
                          _th('Max Percentage (%)', flex: 3),
                          _th('Grade Point (GPA)', flex: 3),
                          _th('Actions', flex: 2),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.divider),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: scales.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                      itemBuilder: (context, index) {
                        final gs = scales[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(gs.grade, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryPurple)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text('${gs.minPercent.toStringAsFixed(1)}%', style: GoogleFonts.poppins(fontSize: 13)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text('${gs.maxPercent.toStringAsFixed(1)}%', style: GoogleFonts.poppins(fontSize: 13)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(gs.gradePoint != null ? gs.gradePoint!.toStringAsFixed(1) : 'N/A', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                              Expanded(
                                flex: 2,
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                                  onPressed: () async {
                                    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.editGradeScale)) return;
                                    final dbService = ref.read(databaseServiceProvider);
                                    await dbService.deleteGradeScaleRow(gs.id);
                                    ref.invalidate(gradeScalesProvider(_selectedAcademicYear));
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Text('Error loading grade scales: $e'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // DIALOGS
  // ============================================================================

  void _showAddEditExamDialog(BuildContext context, {Exam? exam}) {
    final isEdit = exam != null;
    final nameController = TextEditingController(text: exam?.name ?? '');
    String? selectedTypeId = exam?.examTypeId;
    String selectedClass = exam?.className ?? 'Grade 8';
    String? selectedSection = exam?.section;
    DateTime startDate = exam?.startDate ?? DateTime.now();
    DateTime endDate = exam?.endDate ?? DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final typesAsync = ref.watch(examTypesProvider);
          final classesAsync = ref.watch(classListProvider);

          return StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(isEdit ? 'Edit Examination Event' : 'Create Examination Event', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Exam Event Name *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Mid-Term Examination 2024-25',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text('Exam Category / Type *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    typesAsync.when(
                      data: (types) {
                        if (selectedTypeId == null && types.isNotEmpty) {
                          selectedTypeId = types.first.id;
                        }

                        return DropdownButtonFormField<String>(
                          value: selectedTypeId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: types
                              .map((t) => DropdownMenuItem(
                                    value: t.id,
                                    child: Text('${t.name} (${t.weightagePercent}% weightage)', style: GoogleFonts.poppins(fontSize: 12)),
                                  ))
                              .toList(),
                          onChanged: (val) => setDialogState(() => selectedTypeId = val),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Class *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              classesAsync.when(
                                data: (classes) {
                                  return DropdownButtonFormField<String>(
                                    value: classes.any((c) => c.name == selectedClass) ? selectedClass : (classes.isNotEmpty ? classes.first.name : 'Grade 8'),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    items: classes.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name, style: GoogleFonts.poppins(fontSize: 12)))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setDialogState(() => selectedClass = val);
                                    },
                                  );
                                },
                                loading: () => const LinearProgressIndicator(),
                                error: (e, _) => Text('Error: $e'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Section (Optional)', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String?>(
                                value: selectedSection,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: const [
                                  DropdownMenuItem(value: null, child: Text('All Sections')),
                                  DropdownMenuItem(value: 'A', child: Text('Section A')),
                                  DropdownMenuItem(value: 'B', child: Text('Section B')),
                                  DropdownMenuItem(value: 'C', child: Text('Section C')),
                                ],
                                onChanged: (val) => setDialogState(() => selectedSection = val),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                              if (d != null) setDialogState(() => startDate = d);
                            },
                            icon: const Icon(Icons.calendar_month_rounded, size: 16),
                            label: Text('Start: ${_dateFormat.format(startDate)}', style: GoogleFonts.poppins(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(context: context, initialDate: endDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                              if (d != null) setDialogState(() => endDate = d);
                            },
                            icon: const Icon(Icons.event_rounded, size: 16),
                            label: Text('End: ${_dateFormat.format(endDate)}', style: GoogleFonts.poppins(fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty || selectedTypeId == null) return;

                    final dbService = ref.read(databaseServiceProvider);
                    if (isEdit) {
                      final updated = exam.copyWith(
                        name: nameController.text.trim(),
                        examTypeId: selectedTypeId,
                        className: selectedClass,
                        section: selectedSection,
                        startDate: startDate,
                        endDate: endDate,
                      );
                      await dbService.updateExam(updated);
                    } else {
                      final newExam = Exam.create(
                        name: nameController.text.trim(),
                        examTypeId: selectedTypeId!,
                        className: selectedClass,
                        section: selectedSection,
                        academicYear: _selectedAcademicYear,
                        startDate: startDate,
                        endDate: endDate,
                      );
                      await dbService.insertExam(newExam);
                    }

                    ref.invalidate(examsProvider);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                  child: Text(isEdit ? 'Save Exam' : 'Create Exam', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteExam(BuildContext context, Exam exam) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${exam.name}?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure? This will remove all subject papers and student marks associated with this exam event.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final dbService = ref.read(databaseServiceProvider);
              await dbService.deleteExam(exam.id);
              final param = ExamClassYearParam(className: _selectedClassFilter, academicYear: _selectedAcademicYear);
              ref.invalidate(examsProvider(param));
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddSubjectDialog(BuildContext context, Exam exam) {
    final subjectController = TextEditingController();
    final maxMarksController = TextEditingController(text: '100');
    final passMarksController = TextEditingController(text: '35');
    DateTime examDate = exam.startDate;
    String? selectedStaffId;

    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final staffAsync = ref.watch(staffListProvider);

          return StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Add Subject Paper to ${exam.name}', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Subject Name *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: subjectController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Mathematics, Science, English',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Max Marks *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: maxMarksController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Passing Marks *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: passMarksController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Text('Responsible Evaluator (Teacher)', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    staffAsync.when(
                      data: (staffList) {
                        return DropdownButtonFormField<String?>(
                          value: selectedStaffId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          hint: Text('Select Evaluator', style: GoogleFonts.poppins(fontSize: 12)),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                            ...staffList.map((st) => DropdownMenuItem<String?>(
                                  value: st.id,
                                  child: Text('${st.fullName} (${st.designation ?? "Teacher"})', style: GoogleFonts.poppins(fontSize: 12)),
                                )),
                          ],
                          onChanged: (val) => setDialogState(() => selectedStaffId = val),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(context: context, initialDate: examDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (d != null) setDialogState(() => examDate = d);
                      },
                      icon: const Icon(Icons.event_rounded, size: 16),
                      label: Text('Exam Date: ${_dateFormat.format(examDate)}', style: GoogleFonts.poppins(fontSize: 11)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (subjectController.text.trim().isEmpty) return;
                    final maxM = double.tryParse(maxMarksController.text) ?? 100.0;
                    final passM = double.tryParse(passMarksController.text) ?? 35.0;

                    final newSub = ExamSubject.create(
                      examId: exam.id,
                      subject: subjectController.text.trim(),
                      examDate: examDate,
                      maxMarks: maxM,
                      passingMarks: passM,
                      staffId: selectedStaffId,
                    );

                    final dbService = ref.read(databaseServiceProvider);
                    await dbService.insertExamSubject(newSub);
                    ref.invalidate(examSubjectsProvider(exam.id));
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                  child: Text('Add Subject', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddGradeScaleDialog(BuildContext context) {
    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.editGradeScale)) return;
    final gradeController = TextEditingController();
    final minController = TextEditingController(text: '0');
    final maxController = TextEditingController(text: '100');
    final gpaController = TextEditingController(text: '4.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Add Grade Scale Threshold', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Grade Letter *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TextField(
                controller: gradeController,
                decoration: InputDecoration(
                  hintText: 'e.g. A+, A, B, C',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Min % *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: minController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Max % *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: maxController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text('Grade Point (GPA)', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TextField(
                controller: gpaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 4.0',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (gradeController.text.trim().isEmpty) return;
              final minP = double.tryParse(minController.text) ?? 0.0;
              final maxP = double.tryParse(maxController.text) ?? 100.0;
              final gpa = double.tryParse(gpaController.text);

              final scale = GradeScale.create(
                academicYear: _selectedAcademicYear,
                minPercent: minP,
                maxPercent: maxP,
                grade: gradeController.text.trim(),
                gradePoint: gpa,
              );

              final dbService = ref.read(databaseServiceProvider);
              await dbService.saveGradeScaleRow(scale);
              ref.invalidate(gradeScalesProvider(_selectedAcademicYear));
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
            child: Text('Save Threshold', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _resultSummaryBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _th(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, letterSpacing: 0.5)),
    );
  }

  Widget _buildEmptyCard(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Center(
        child: Text(msg, style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13)),
      ),
    );
  }
  // ============================================================================
  // TAB 5: RESULTS DASHBOARD
  // ============================================================================

  Widget _buildResultsDashboardTab() {
    final param = ExamClassYearParam(className: _selectedClassFilter, academicYear: _selectedAcademicYear);
    final examsAsync = ref.watch(examsProvider(param));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Exam Event', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    examsAsync.when(
                      data: (exams) {
                        if (exams.isEmpty) {
                          _selectedDashboardExamId = null;
                        } else if (_selectedDashboardExamId == null || !exams.any((e) => e.id == _selectedDashboardExamId)) {
                          _selectedDashboardExamId = exams.first.id;
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedDashboardExamId,
                            underline: const SizedBox(),
                            hint: Text('Choose Exam', style: GoogleFonts.poppins(fontSize: 12)),
                            items: exams
                                .map((e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text('${e.name} (${e.className})', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedDashboardExamId = val);
                            },
                          ),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                    ),
                  ],
                ),
              ),
              const Expanded(child: SizedBox()), // spacer
            ],
          ),
          const SizedBox(height: 24),

          if (_selectedDashboardExamId != null)
            Consumer(
              builder: (context, ref, _) {
                final dashboardAsync = ref.watch(examResultsDashboardProvider(_selectedDashboardExamId!));

                return dashboardAsync.when(
                  data: (data) {
                    final double overallAvg = data['overallAverage'] ?? 0.0;
                    final double overallPassPct = data['overallPassPercentage'] ?? 0.0;
                    final List topPerformers = data['topPerformers'] ?? [];
                    final List subjectPerformance = data['subjectPerformance'] ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Key Metrics Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                'Overall Average',
                                '${overallAvg.toStringAsFixed(1)}%',
                                Icons.analytics_outlined,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildMetricCard(
                                'Overall Pass %',
                                '${overallPassPct.toStringAsFixed(1)}%',
                                Icons.verified_user_outlined,
                                overallPassPct >= 50 ? AppTheme.success : AppTheme.error,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildMetricCard(
                                'Top Performer',
                                topPerformers.isNotEmpty ? topPerformers.first['studentName'] : 'N/A',
                                Icons.star_border_rounded,
                                Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Subject Performance & Top Performers
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildSubjectPerformanceCard(subjectPerformance),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: _buildTopPerformersCard(topPerformers),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (e, _) => Text('Error loading dashboard: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectPerformanceCard(List subjectPerformance) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Subject Performance',
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          if (subjectPerformance.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No subject data available.', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subjectPerformance.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
              itemBuilder: (context, index) {
                final sub = subjectPerformance[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(sub['subject'], style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text('Avg: ${sub['averageMarks'].toStringAsFixed(1)} / ${sub['maxMarks'].toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 12)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text('Pass: ${sub['passPercentage'].toStringAsFixed(1)}%', style: GoogleFonts.poppins(fontSize: 12, color: sub['passPercentage'] >= 50 ? AppTheme.success : AppTheme.error)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopPerformersCard(List topPerformers) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Top Performers',
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          if (topPerformers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No performers data available.', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topPerformers.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
              itemBuilder: (context, index) {
                final tp = topPerformers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: index == 0 ? Colors.orange.withValues(alpha: 0.2) : AppTheme.bgSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: index == 0 ? Colors.orange : AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tp['studentName'], style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('${tp['percentage'].toStringAsFixed(1)}%', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      Text(
                        '${tp['totalMarks'].toStringAsFixed(1)}/${tp['totalMaxMarks'].toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

}
