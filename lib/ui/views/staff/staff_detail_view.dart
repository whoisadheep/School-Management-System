import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/report_generator.dart';
import '../../../core/auth/permission_helper.dart';
import '../../../providers/services_provider.dart';
import '../attendance/teacher_attendance_history_dialog.dart';

class StaffDetailView extends ConsumerStatefulWidget {
  final Staff staff;
  final VoidCallback onEdit;
  final VoidCallback onBack;

  const StaffDetailView({
    super.key,
    required this.staff,
    required this.onEdit,
    required this.onBack,
  });

  @override
  ConsumerState<StaffDetailView> createState() => _StaffDetailViewState();
}

class _StaffDetailViewState extends ConsumerState<StaffDetailView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _timetableScrollController = ScrollController();
  int _selectedAttendanceMonth = DateTime.now().month;
  int _selectedAttendanceYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timetableScrollController.dispose();
    super.dispose();
  }

  Future<void> _exportIdCard() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue900, width: 2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text('SCHOOL MANAGEMENT SYSTEM',
                      style: const pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900)),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    width: 80,
                    height: 80,
                    decoration: const pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      color: PdfColors.grey300,
                    ),
                    child: pw.Center(
                      child: pw.Text(widget.staff.firstName[0].toUpperCase(),
                          style: const pw.TextStyle(
                              fontSize: 40, color: PdfColors.white)),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(widget.staff.fullName.toUpperCase(),
                      style: const pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      widget.staff.designation ??
                          widget.staff.role.toUpperCase(),
                      style: const pw.TextStyle(
                          fontSize: 12, color: PdfColors.grey700)),
                  pw.SizedBox(height: 10),
                  pw.Divider(color: PdfColors.grey400),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('EMP CODE:',
                          style: const pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text(widget.staff.staffCode ?? 'N/A',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('BLOOD GRP:',
                          style: const pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text(widget.staff.bloodGroup ?? 'N/A',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('Valid for current academic year only',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${widget.staff.staffCode ?? "staff"}_id_card.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(staffSubjectsProvider(widget.staff.id));
    final salaryAsync = ref.watch(salaryComponentsProvider(widget.staff.id));
    final classInChargeAsync = ref.watch(classTeacherAssignmentProvider(widget.staff.id));
    final workloadAsync = ref.watch(teacherWorkloadProvider(widget.staff.id));
    final timetableAsync = ref.watch(staffTimetableProvider(widget.staff.id));

    final attParam = MonthlyAttendanceParam(
      staffId: widget.staff.id,
      month: _selectedAttendanceMonth,
      year: _selectedAttendanceYear,
    );
    final attSummaryAsync = ref.watch(teacherMonthlyAttendanceSummaryProvider(attParam));
    final attRecordsAsync = ref.watch(teacherMonthlyAttendanceRecordsProvider(attParam));

    final leaveAppsAsync = ref.watch(staffLeaveApplicationsProvider(widget.staff.id));
    final leaveBalanceAsync = ref.watch(staffLeaveBalanceProvider(StaffYearParam(staffId: widget.staff.id, year: DateTime.now().year)));
    final examDutiesAsync = ref.watch(staffExamDutiesProvider(widget.staff.id));

    final userAsync = ref.watch(staffUserProvider(widget.staff.id));
    final circularsAsync = ref.watch(staffCircularsProvider(StaffDeptParam(staffId: widget.staff.id, departmentId: widget.staff.departmentId)));

    final appraisalsAsync = ref.watch(staffAppraisalsProvider(widget.staff.id));
    final trainingsAsync = ref.watch(staffTrainingsProvider(widget.staff.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 16),
              Text(
                'Staff Profile',
                style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showApplyLeaveDialog(context),
                icon: const Icon(Icons.time_to_leave_rounded, size: 18),
                label: Text('Apply Leave',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.primaryPurple,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showMarkAttendanceDialog(context, widget.staff),
                icon: const Icon(Icons.event_available_rounded, size: 18),
                label: Text('Mark Attendance',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.primaryPurple,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => TeacherAttendanceHistoryDialog(staff: widget.staff),
                  );
                },
                icon: const Icon(Icons.history_rounded, size: 18),
                label: Text('Attendance History',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.primaryPurple,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _exportIdCard,
                icon: const Icon(Icons.badge_rounded, size: 18),
                label: Text('Generate ID Card',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryPurple,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: Text('Edit Profile',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column - Profile Summary & Workload (Phase 1)
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildProfileCard(),
                      const SizedBox(height: 24),
                      _buildContactCard(),
                      const SizedBox(height: 24),
                      // Phase 1: Workload Summary Widget
                      _buildWorkloadSummaryCard(workloadAsync, subjectsAsync),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // Right Column - Tabbed View
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: AppTheme.primaryPurple,
                          unselectedLabelColor: AppTheme.textSecondary,
                          indicatorColor: AppTheme.primaryPurple,
                          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 10.5),
                          tabs: const [
                            Tab(text: 'Overview'),
                            Tab(text: 'My Timetable'),
                            Tab(text: 'Attendance'),
                            Tab(text: 'Leaves'),
                            Tab(text: 'Exam Duties'),
                            Tab(text: 'Portal & Circulars'),
                            Tab(text: 'Appraisal & Training'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        height: 850,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Tab 1: Overview & Teaching
                            SingleChildScrollView(
                              child: Column(
                                children: [
                                  _buildClassInChargeCard(classInChargeAsync),
                                  const SizedBox(height: 24),
                                  if (widget.staff.role == 'teacher') ...[
                                    _buildSubjectsCard(subjectsAsync),
                                    const SizedBox(height: 24),
                                  ],
                                  _buildSalaryCard(salaryAsync),
                                ],
                              ),
                            ),

                            // Tab 2: Phase 2 - My Timetable
                            SingleChildScrollView(
                              child: _buildTimetableSection(timetableAsync),
                            ),

                            // Tab 3: Phase 3 - Teacher Attendance
                            SingleChildScrollView(
                              child: _buildAttendanceSection(attSummaryAsync, attRecordsAsync),
                            ),

                            // Tab 4: Phase 4 - Leaves & Balance
                            SingleChildScrollView(
                              child: _buildLeavesSection(leaveBalanceAsync, leaveAppsAsync),
                            ),

                            // Tab 5: Phase 6 - Exam Duties
                            SingleChildScrollView(
                              child: _buildExamDutiesSection(examDutiesAsync),
                            ),

                            // Tab 6: Phase 7 (RBAC) & Phase 8 (Circulars)
                            SingleChildScrollView(
                              child: _buildRbacAndCircularsSection(userAsync, circularsAsync),
                            ),

                            // Tab 7: Phase 9 (Appraisals) & Phase 10 (Trainings)
                            SingleChildScrollView(
                              child: _buildAppraisalsAndTrainingsSection(appraisalsAsync, trainingsAsync),
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
      ],
    );
  }

  // ============================================================================
  // PHASE 9 & 10 WIDGETS & DIALOGS: Performance Appraisals & Professional Development
  // ============================================================================

  Widget _buildAppraisalsAndTrainingsSection(AsyncValue<List<Appraisal>> appraisalsAsync, AsyncValue<List<Training>> trainingsAsync) {
    return Column(
      children: [
        _buildAppraisalsCard(appraisalsAsync),
        const SizedBox(height: 24),
        _buildTrainingsCard(trainingsAsync),
      ],
    );
  }

  Widget _buildAppraisalsCard(AsyncValue<List<Appraisal>> appraisalsAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
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
                  const Icon(Icons.star_half_rounded, color: AppTheme.primaryPurple, size: 22),
                  const SizedBox(width: 10),
                  Text('Performance Appraisals & Reviews',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddAppraisalDialog(context),
                icon: const Icon(Icons.rate_review_rounded, size: 16),
                label: Text('New Appraisal', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          appraisalsAsync.when(
            data: (appraisals) {
              if (appraisals.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: Text('No appraisal records logged.', style: GoogleFonts.poppins(color: AppTheme.textHint, fontStyle: FontStyle.italic))),
                );
              }
              return Column(
                children: appraisals.map((app) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Review Period: ${app.reviewPeriod}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                            Row(
                              children: [
                                Row(
                                  children: List.generate(5, (starIndex) {
                                    return Icon(
                                      starIndex < app.rating ? Icons.star_rounded : Icons.star_border_rounded,
                                      color: Colors.amber.shade700,
                                      size: 18,
                                    );
                                  }),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.error),
                                  onPressed: () async {
                                    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.deleteRecord)) return;
                                    final dbService = ref.read(databaseServiceProvider);
                                    await dbService.deleteAppraisal(app.id);
                                    ref.invalidate(staffAppraisalsProvider(widget.staff.id));
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Self Assessment:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                        Text(app.selfAssessment, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        Text('Principal / Admin Remarks:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        Text(app.principalRemarks, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('Evaluated on: ${app.createdAt.split("T").first}', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('Error loading appraisals: $e'),
          ),
        ],
      ),
    );
  }

  void _showAddAppraisalDialog(BuildContext context) {
    final periodController = TextEditingController(text: 'Annual Review 2025-2026');
    final selfController = TextEditingController();
    final remarksController = TextEditingController();
    int rating = 4;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Record Performance Appraisal', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: periodController,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Review Period (e.g. 2024-2025 Q1) *'),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Performance Rating (1 to 5 Stars):', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                    Row(
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        return IconButton(
                          icon: Icon(
                            starValue <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                            color: Colors.amber.shade700,
                            size: 24,
                          ),
                          onPressed: () => setDialogState(() => rating = starValue),
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: selfController,
                  maxLines: 2,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Self Assessment / Key Accomplishments *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksController,
                  maxLines: 2,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Principal / Admin Remarks *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final prd = periodController.text.trim();
                final self = selfController.text.trim();
                final rem = remarksController.text.trim();
                if (prd.isEmpty || self.isEmpty || rem.isEmpty) return;

                final appraisal = Appraisal(
                  id: const Uuid().v4(),
                  staffId: widget.staff.id,
                  reviewPeriod: prd,
                  selfAssessment: self,
                  principalRemarks: rem,
                  rating: rating,
                  createdAt: DateTime.now().toIso8601String(),
                );

                final dbService = ref.read(databaseServiceProvider);
                await dbService.addAppraisal(appraisal);
                ref.invalidate(staffAppraisalsProvider(widget.staff.id));

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Performance appraisal recorded successfully!'), backgroundColor: AppTheme.primaryPurple),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: const Text('Save Appraisal'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingsCard(AsyncValue<List<Training>> trainingsAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
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
                  const Icon(Icons.school_rounded, color: AppTheme.primaryPurple, size: 22),
                  const SizedBox(width: 10),
                  Text('Professional Development & Trainings',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddTrainingDialog(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Add Training', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          trainingsAsync.when(
            data: (trainings) {
              if (trainings.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: Text('No professional training records registered.', style: GoogleFonts.poppins(color: AppTheme.textHint, fontStyle: FontStyle.italic))),
                );
              }
              return Column(
                children: trainings.map((tr) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr.trainingName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                            const SizedBox(height: 4),
                            Text('Provider: ${tr.provider}  •  Completed: ${tr.date}', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                            if (tr.certificatePath != null && tr.certificatePath!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.verified_rounded, size: 14, color: AppTheme.success),
                                  const SizedBox(width: 4),
                                  Text('Certificate Attached: ${tr.certificatePath!.split("/").last}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                          onPressed: () async {
                            if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.deleteRecord)) return;
                            final dbService = ref.read(databaseServiceProvider);
                            await dbService.deleteTraining(tr.id);
                            ref.invalidate(staffTrainingsProvider(widget.staff.id));
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('Error loading trainings: $e'),
          ),
        ],
      ),
    );
  }

  void _showAddTrainingDialog(BuildContext context) {
    final nameController = TextEditingController();
    final providerController = TextEditingController();
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    String? pickedCertPath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Add Training / Workshop Record', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Training Course / Workshop Title *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: providerController,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Training Provider / Institute *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Completion Date (YYYY-MM-DD) *'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                    );
                    if (result != null && result.files.single.path != null) {
                      setDialogState(() {
                        pickedCertPath = result.files.single.path;
                      });
                    }
                  },
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(pickedCertPath == null ? 'Upload Certificate (PDF/Image)' : 'File: ${pickedCertPath!.split("/").last}', style: GoogleFonts.poppins(fontSize: 12)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final nm = nameController.text.trim();
                final prv = providerController.text.trim();
                final dt = dateController.text.trim();
                if (nm.isEmpty || prv.isEmpty || dt.isEmpty) return;

                final training = Training(
                  id: const Uuid().v4(),
                  staffId: widget.staff.id,
                  trainingName: nm,
                  provider: prv,
                  date: dt,
                  certificatePath: pickedCertPath,
                );

                final dbService = ref.read(databaseServiceProvider);
                await dbService.addTraining(training);
                ref.invalidate(staffTrainingsProvider(widget.staff.id));

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Registered training: $nm'), backgroundColor: AppTheme.primaryPurple),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: const Text('Save Training'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // PHASE 7 & 8 WIDGETS & DIALOGS: Portal Access RBAC & Circulars
  // ============================================================================

  Widget _buildRbacAndCircularsSection(AsyncValue<User?> userAsync, AsyncValue<List<Circular>> circularsAsync) {
    return Column(
      children: [
        _buildRbacPermissionEditorCard(userAsync),
        const SizedBox(height: 24),
        _buildCircularsCard(circularsAsync),
      ],
    );
  }

  Widget _buildRbacPermissionEditorCard(AsyncValue<User?> userAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryPurple, size: 22),
              const SizedBox(width: 10),
              Text('Portal Access & Role Permissions (RBAC)',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          userAsync.when(
            data: (user) {
              if (user == null) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('No portal account linked to this staff member.', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                      ElevatedButton(
                        onPressed: () async {
                          final newUser = User.create(
                            username: widget.staff.email ?? widget.staff.staffCode ?? widget.staff.firstName.toLowerCase(),
                            fullName: widget.staff.fullName,
                            role: widget.staff.role == 'teacher' ? UserRole.teacher : UserRole.accountant,
                            rawPin: '1234',
                            staffId: widget.staff.id,
                          );
                          final dbService = ref.read(databaseServiceProvider);
                          await dbService.rawQuery(
                            'INSERT INTO users (id, username, full_name, role, pin_hash, staff_id, can_view_finance, can_mark_own_attendance, can_upload_marks, can_view_all_students, can_approve_leave, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0, 1, ?, ?)',
                            [newUser.id, newUser.username, newUser.fullName, newUser.role.name, newUser.pinHash, newUser.staffId, newUser.createdAt.toIso8601String(), newUser.updatedAt.toIso8601String()],
                          );
                          ref.invalidate(staffUserProvider(widget.staff.id));
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                        child: const Text('Create User Account'),
                      ),
                    ],
                  ),
                );
              }

              return StatefulBuilder(
                builder: (context, setPermissionState) {
                  bool canViewFinance = user.canViewFinance;
                  bool canMarkOwnAttendance = user.canMarkOwnAttendance;
                  bool canUploadMarks = user.canUploadMarks;
                  bool canViewAllStudents = user.canViewAllStudents;
                  bool canApproveLeave = user.canApproveLeave;

                  return Column(
                    children: [
                      SwitchListTile(
                        title: Text('Can View Finance & Financial Dashboards', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Allows access to Financial Dashboard, Fee Collection, Expenses & Ledger', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                        value: canViewFinance,
                        activeTrackColor: AppTheme.primaryPurple,
                        onChanged: (val) async {
                          setPermissionState(() => canViewFinance = val);
                          final dbService = ref.read(databaseServiceProvider);
                          await dbService.updateUserPermissions(user.id, {'can_view_finance': val});
                          ref.invalidate(staffUserProvider(widget.staff.id));
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: Text('Can Mark Own Attendance', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Allows self check-in and check-out from portal', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                        value: canMarkOwnAttendance,
                        activeTrackColor: AppTheme.primaryPurple,
                        onChanged: (val) async {
                          setPermissionState(() => canMarkOwnAttendance = val);
                          final dbService = ref.read(databaseServiceProvider);
                          await dbService.updateUserPermissions(user.id, {'can_mark_own_attendance': val});
                          ref.invalidate(staffUserProvider(widget.staff.id));
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: Text('Can Upload Marks & Grades', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Allows entering subject marks and report cards', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                        value: canUploadMarks,
                        activeTrackColor: AppTheme.primaryPurple,
                        onChanged: (val) async {
                          setPermissionState(() => canUploadMarks = val);
                          final dbService = ref.read(databaseServiceProvider);
                          await dbService.updateUserPermissions(user.id, {'can_upload_marks': val});
                          ref.invalidate(staffUserProvider(widget.staff.id));
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: Text('Can View All Student Records', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Allows viewing profiles of students outside assigned classes', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                        value: canViewAllStudents,
                        activeTrackColor: AppTheme.primaryPurple,
                        onChanged: (val) async {
                          setPermissionState(() => canViewAllStudents = val);
                          final dbService = ref.read(databaseServiceProvider);
                          await dbService.updateUserPermissions(user.id, {'can_view_all_students': val});
                          ref.invalidate(staffUserProvider(widget.staff.id));
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: Text('Can Approve Teacher Leave Requests', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Grants access to review and approve leave applications', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                        value: canApproveLeave,
                        activeTrackColor: AppTheme.primaryPurple,
                        onChanged: (val) async {
                          setPermissionState(() => canApproveLeave = val);
                          final dbService = ref.read(databaseServiceProvider);
                          await dbService.updateUserPermissions(user.id, {'can_approve_leave': val});
                          ref.invalidate(staffUserProvider(widget.staff.id));
                        },
                      ),
                    ],
                  );
                },
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('Error loading user permissions: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularsCard(AsyncValue<List<Circular>> circularsAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
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
                  const Icon(Icons.campaign_rounded, color: AppTheme.primaryPurple, size: 22),
                  const SizedBox(width: 10),
                  Text('Circulars & Announcements', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showComposeCircularDialog(context),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text('Compose Circular', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          circularsAsync.when(
            data: (circulars) {
              if (circulars.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: Text('No circulars or notices published.', style: GoogleFonts.poppins(color: AppTheme.textHint, fontStyle: FontStyle.italic))),
                );
              }
              return Column(
                children: circulars.map((c) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(c.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                            Text(c.sentAt.split('T').first, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(c.body, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Target: ${c.targetType.toUpperCase()}  •  Sent By: ${c.sentBy}', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.primaryPurple, fontWeight: FontWeight.w600)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.error),
                              onPressed: () async {
                                if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.deleteRecord)) return;
                                final dbService = ref.read(databaseServiceProvider);
                                await dbService.deleteCircular(c.id);
                                ref.invalidate(allCircularsProvider);
                                ref.invalidate(staffCircularsProvider(StaffDeptParam(staffId: widget.staff.id, departmentId: widget.staff.departmentId)));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('Error loading circulars: $e'),
          ),
        ],
      ),
    );
  }

  void _showComposeCircularDialog(BuildContext context) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String targetType = 'all';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Compose Circular Notice', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Notice Title *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: targetType,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Target Audience *'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Staff Members')),
                    DropdownMenuItem(value: 'department', child: Text('Specific Department')),
                    DropdownMenuItem(value: 'individual', child: Text('Individual Teacher')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => targetType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  maxLines: 4,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Notice Content & Description *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final ttl = titleController.text.trim();
                final bdy = bodyController.text.trim();
                if (ttl.isEmpty || bdy.isEmpty) return;

                final circular = Circular(
                  id: const Uuid().v4(),
                  title: ttl,
                  body: bdy,
                  sentBy: 'Admin',
                  sentAt: DateTime.now().toIso8601String(),
                  targetType: targetType,
                  targetId: targetType == 'department' ? widget.staff.departmentId : widget.staff.id,
                );

                final dbService = ref.read(databaseServiceProvider);
                await dbService.sendCircular(circular);

                ref.invalidate(allCircularsProvider);
                ref.invalidate(staffCircularsProvider(StaffDeptParam(staffId: widget.staff.id, departmentId: widget.staff.departmentId)));

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Circular published successfully!'), backgroundColor: AppTheme.primaryPurple),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: const Text('Broadcast Notice'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // PHASE 4 & 6 WIDGETS
  // ============================================================================

  Widget _buildLeavesSection(AsyncValue<List<LeaveBalance>> balanceAsync, AsyncValue<List<LeaveApplication>> appsAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
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
                  const Icon(Icons.beach_access_rounded, color: AppTheme.primaryPurple, size: 22),
                  const SizedBox(width: 10),
                  Text('Leave Balances & History', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showApplyLeaveDialog(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Apply for Leave', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),

          balanceAsync.when(
            data: (balances) {
              return Row(
                children: balances.map((b) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.leaveType.name, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                          const SizedBox(height: 6),
                          Text('${b.remainingDays} / ${b.allowedDays} Days', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                          const SizedBox(height: 2),
                          Text('${b.usedDays} Days Used', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('Error loading leave balance: $e'),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text('Leave Applications History', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),

          appsAsync.when(
            data: (apps) {
              if (apps.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: Text('No leave applications submitted yet.', style: GoogleFonts.poppins(color: AppTheme.textHint, fontStyle: FontStyle.italic))),
                );
              }
              return Column(
                children: apps.map((app) {
                  final statusColor = app.status == 'approved'
                      ? AppTheme.success
                      : app.status == 'rejected'
                          ? AppTheme.error
                          : Colors.orange.shade800;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${app.startDate} to ${app.endDate}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                            const SizedBox(height: 4),
                            Text('Reason: ${app.reason}', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(app.status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('Error loading leave history: $e'),
          ),
        ],
      ),
    );
  }

  void _showApplyLeaveDialog(BuildContext context) {
    final startController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final endController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1))));
    final reasonController = TextEditingController();
    String selectedLeaveTypeId = 'lt-casual';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Apply for Leave', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedLeaveTypeId,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Leave Type *'),
                  items: const [
                    DropdownMenuItem(value: 'lt-casual', child: Text('Casual Leave (12 days/yr)')),
                    DropdownMenuItem(value: 'lt-sick', child: Text('Sick Leave (10 days/yr)')),
                    DropdownMenuItem(value: 'lt-earned', child: Text('Earned Leave (15 days/yr)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedLeaveTypeId = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startController,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: 'Start Date (YYYY-MM-DD) *'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: endController,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: 'End Date (YYYY-MM-DD) *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Reason for Leave *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final rsn = reasonController.text.trim();
                final st = startController.text.trim();
                final ed = endController.text.trim();
                if (rsn.isEmpty || st.isEmpty || ed.isEmpty) return;

                final app = LeaveApplication(
                  id: const Uuid().v4(),
                  staffId: widget.staff.id,
                  leaveTypeId: selectedLeaveTypeId,
                  startDate: st,
                  endDate: ed,
                  reason: rsn,
                  status: 'pending',
                  appliedAt: DateTime.now().toIso8601String(),
                );

                final dbService = ref.read(databaseServiceProvider);
                await dbService.applyForLeave(app);

                ref.invalidate(staffLeaveApplicationsProvider(widget.staff.id));
                ref.invalidate(pendingLeaveApplicationsProvider);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Leave application submitted for approval!'), backgroundColor: AppTheme.primaryPurple),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: const Text('Submit Application'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamDutiesSection(AsyncValue<List<ExamDuty>> dutiesAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
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
                  const Icon(Icons.assignment_turned_in_rounded, color: AppTheme.primaryPurple, size: 22),
                  const SizedBox(width: 10),
                  Text('Assigned Exam Duties', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAssignExamDutyDialog(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Assign Exam Duty', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),

          dutiesAsync.when(
            data: (duties) {
              if (duties.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: Text('No exam duties assigned.', style: GoogleFonts.poppins(color: AppTheme.textHint, fontStyle: FontStyle.italic))),
                );
              }
              return Column(
                children: duties.map((duty) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(duty.examName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                            const SizedBox(height: 4),
                            Text('Date: ${duty.date}  •  Time: ${duty.timeSlot}  •  Room: ${duty.roomOrClass}', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.primaryPurple),
                              ),
                              child: Text(duty.dutyType.replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                              onPressed: () async {
                                if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.deleteRecord)) return;
                                final dbService = ref.read(databaseServiceProvider);
                                await dbService.deleteExamDuty(duty.id);
                                ref.invalidate(staffExamDutiesProvider(widget.staff.id));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('Error loading exam duties: $e'),
          ),
        ],
      ),
    );
  }

  void _showAssignExamDutyDialog(BuildContext context) {
    final examNameController = TextEditingController(text: 'Mid-Term Examinations 2026');
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 7))));
    final timeSlotController = TextEditingController(text: '09:00 AM - 12:00 PM');
    final roomController = TextEditingController(text: 'Hall 101');
    String dutyType = 'invigilation';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Assign Exam Duty', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: examNameController,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Exam Name *'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dateController,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD) *'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: timeSlotController,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: 'Time Slot *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: roomController,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: 'Room / Hall *'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: dutyType,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: 'Duty Type *'),
                        items: const [
                          DropdownMenuItem(value: 'invigilation', child: Text('Invigilation')),
                          DropdownMenuItem(value: 'paper_setting', child: Text('Paper Setting')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => dutyType = val);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final exName = examNameController.text.trim();
                final dt = dateController.text.trim();
                final ts = timeSlotController.text.trim();
                final rm = roomController.text.trim();
                if (exName.isEmpty || dt.isEmpty || ts.isEmpty || rm.isEmpty) return;

                final duty = ExamDuty(
                  id: const Uuid().v4(),
                  staffId: widget.staff.id,
                  examName: exName,
                  date: dt,
                  timeSlot: ts,
                  roomOrClass: rm,
                  dutyType: dutyType,
                );

                final dbService = ref.read(databaseServiceProvider);
                await dbService.addExamDuty(duty);

                ref.invalidate(staffExamDutiesProvider(widget.staff.id));
                ref.invalidate(allExamDutiesProvider);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Assigned ${dutyType.toUpperCase()} duty to ${widget.staff.fullName}'), backgroundColor: AppTheme.primaryPurple),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: const Text('Save Exam Duty'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // PHASE 1, 2, 3 WIDGETS
  // ============================================================================

  Widget _buildClassInChargeCard(AsyncValue<ClassTeacherAssignment?> classInChargeAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
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
                  const Icon(Icons.supervisor_account_rounded, color: AppTheme.primaryPurple, size: 22),
                  const SizedBox(width: 10),
                  Text('Class In-Charge Assignment',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => _showAssignClassTeacherDialog(context),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: Text('Assign / Edit', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryPurple,
                  side: const BorderSide(color: AppTheme.primaryPurple),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          classInChargeAsync.when(
            data: (assignment) {
              if (assignment == null) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppTheme.textHint, size: 18),
                      const SizedBox(width: 12),
                      Text('No Class Teacher assignment. Click "Assign" to set as Class In-Charge.',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                );
              }
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryPurple,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.class_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Class In-Charge: ${assignment.classAssigned} - Sec ${assignment.section}',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        Text('Academic Year: ${assignment.academicYear}',
                            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ],
                ),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('Error loading class in-charge info: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkloadSummaryCard(AsyncValue<int> workloadAsync, AsyncValue<List<StaffSubjectAssignment>> subjectsAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.work_history_rounded, color: AppTheme.primaryPurple, size: 22),
              const SizedBox(width: 10),
              Text('Weekly Workload Summary',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          workloadAsync.when(
            data: (weeklyPeriods) {
              final subjectCount = subjectsAsync.value?.length ?? 0;
              return Row(
                children: [
                  Expanded(
                    child: _buildWorkloadStatBox('Weekly Load', '$weeklyPeriods Periods', Icons.calendar_view_week_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildWorkloadStatBox('Subjects', '$subjectCount Classes', Icons.menu_book_rounded),
                  ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('Error loading workload: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkloadStatBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primaryPurple),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  void _showAssignClassTeacherDialog(BuildContext context) {
    final classController = TextEditingController(text: 'Grade 10');
    final sectionController = TextEditingController(text: 'A');
    final yearController = TextEditingController(text: '${DateTime.now().year}-${DateTime.now().year + 1}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Assign Class In-Charge', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: classController,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Class (e.g. Grade 10, Grade 9)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sectionController,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Section (e.g. A, B, C)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearController,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Academic Year (e.g. 2024-2025)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final className = classController.text.trim();
              final sec = sectionController.text.trim();
              final year = yearController.text.trim();
              if (className.isEmpty || sec.isEmpty || year.isEmpty) return;

              final assignment = ClassTeacherAssignment(
                id: const Uuid().v4(),
                staffId: widget.staff.id,
                classAssigned: className,
                section: sec,
                academicYear: year,
              );

              final dbService = ref.read(databaseServiceProvider);
              await dbService.assignClassTeacher(assignment);
              ref.invalidate(classTeacherAssignmentProvider(widget.staff.id));

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Assigned Class In-Charge to $className-$sec'), backgroundColor: AppTheme.primaryPurple),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
            child: const Text('Save Assignment'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableSection(AsyncValue<List<TimetableEntry>> timetableAsync) {
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    return Container(
      padding: const EdgeInsets.all(24),
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
                  const Icon(Icons.table_chart_rounded, color: AppTheme.primaryPurple, size: 22),
                  const SizedBox(width: 10),
                  Text('Weekly Teaching Timetable', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddTimetableDialog(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Add Period Entry', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),

          timetableAsync.when(
            data: (entries) {
              return ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: Scrollbar(
                  controller: _timetableScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _timetableScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      width: 1200,
                      child: Table(
                        defaultColumnWidth: const FixedColumnWidth(130),
                        border: TableBorder.all(color: AppTheme.divider, borderRadius: BorderRadius.circular(8)),
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: AppTheme.bgSurface),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text('Day / Period', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary)),
                        ),
                        ...List.generate(8, (pIndex) => Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text('Period ${pIndex + 1}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary), textAlign: TextAlign.center),
                        )),
                      ],
                    ),
                    ...List.generate(6, (dayIndex) {
                      final dayNum = dayIndex + 1;
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(dayNames[dayIndex], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 11, color: AppTheme.textPrimary)),
                          ),
                          ...List.generate(8, (periodIndex) {
                            final periodNum = periodIndex + 1;
                            final match = entries.where((e) => e.dayOfWeek == dayNum && e.periodNumber == periodNum).toList();
                            if (match.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.white,
                                child: Center(
                                  child: Text('Free', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint, fontStyle: FontStyle.italic)),
                                ),
                              );
                            }
                            final item = match.first;
                            return Container(
                              padding: const EdgeInsets.all(6),
                              color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(item.subject, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.primaryPurple), textAlign: TextAlign.center),
                                  Text('${item.classAssigned}-${item.section}', style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.textSecondary), textAlign: TextAlign.center),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.error),
                                    onPressed: () async {
                                      if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.deleteRecord)) return;
                                      final dbService = ref.read(databaseServiceProvider);
                                      await dbService.deleteTimetableEntry(item.id);
                                      ref.invalidate(staffTimetableProvider(widget.staff.id));
                                      ref.invalidate(teacherWorkloadProvider(widget.staff.id));
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Text('Error loading timetable: $e'),
          ),
        ],
      ),
    );
  }

  void _showAddTimetableDialog(BuildContext context) {
    final classController = TextEditingController(text: 'Grade 10');
    final secController = TextEditingController(text: 'A');
    final subjectController = TextEditingController(text: 'Mathematics');
    final startController = TextEditingController(text: '09:00 AM');
    final endController = TextEditingController(text: '09:45 AM');
    int selectedDay = 1;
    int selectedPeriod = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Add Period to Timetable', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedDay,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: 'Day of Week'),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Monday')),
                          DropdownMenuItem(value: 2, child: Text('Tuesday')),
                          DropdownMenuItem(value: 3, child: Text('Wednesday')),
                          DropdownMenuItem(value: 4, child: Text('Thursday')),
                          DropdownMenuItem(value: 5, child: Text('Friday')),
                          DropdownMenuItem(value: 6, child: Text('Saturday')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedDay = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedPeriod,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: 'Period'),
                        items: List.generate(8, (i) => DropdownMenuItem(value: i + 1, child: Text('Period ${i + 1}'))),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedPeriod = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectController,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Subject Name *'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: classController,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: 'Class *'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: secController,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: 'Section *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startController,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: 'Start Time'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: endController,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: 'End Time'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final sub = subjectController.text.trim();
                final cls = classController.text.trim();
                final sec = secController.text.trim();
                if (sub.isEmpty || cls.isEmpty || sec.isEmpty) return;

                final entry = TimetableEntry(
                  id: const Uuid().v4(),
                  classAssigned: cls,
                  section: sec,
                  dayOfWeek: selectedDay,
                  periodNumber: selectedPeriod,
                  startTime: startController.text.trim(),
                  endTime: endController.text.trim(),
                  subject: sub,
                  staffId: widget.staff.id,
                );

                final dbService = ref.read(databaseServiceProvider);
                await dbService.addTimetableEntry(entry);
                ref.invalidate(staffTimetableProvider(widget.staff.id));
                ref.invalidate(teacherWorkloadProvider(widget.staff.id));

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Timetable entry added successfully!'), backgroundColor: AppTheme.primaryPurple),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: const Text('Save Entry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSection(AsyncValue<TeacherAttendanceSummary> summaryAsync, AsyncValue<List<TeacherAttendance>> recordsAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
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
                  const Icon(Icons.rule_rounded, color: AppTheme.primaryPurple, size: 22),
                  const SizedBox(width: 10),
                  Text('Monthly Attendance Record', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                ],
              ),
              Row(
                children: [
                  DropdownButton<int>(
                    value: _selectedAttendanceMonth,
                    items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat('MMMM').format(DateTime(2024, i + 1))))),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedAttendanceMonth = val);
                    },
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _selectedAttendanceYear,
                    items: [2024, 2025, 2026].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedAttendanceYear = val);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          summaryAsync.when(
            data: (summary) {
              return Row(
                children: [
                  Expanded(child: _buildAttendanceStatCard('Present', '${summary.presentCount}', AppTheme.success)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAttendanceStatCard('Absent', '${summary.absentCount}', AppTheme.error)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAttendanceStatCard('Late', '${summary.lateCount}', Colors.orange.shade800)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAttendanceStatCard('Half Day', '${summary.halfDayCount}', Colors.amber.shade900)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAttendanceStatCard('Attendance %', '${summary.attendancePercentage.toStringAsFixed(1)}%', AppTheme.primaryPurple)),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('Error loading attendance summary: $e'),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text('Attendance Logs', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),

          recordsAsync.when(
            data: (records) {
              if (records.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: Text('No attendance records logged for this month.', style: GoogleFonts.poppins(color: AppTheme.textHint, fontStyle: FontStyle.italic))),
                );
              }
              return Column(
                children: records.map((record) {
                  final statusColor = record.status == 'present'
                      ? AppTheme.success
                      : record.status == 'absent'
                          ? AppTheme.error
                          : record.status == 'late'
                              ? Colors.orange.shade800
                              : Colors.amber.shade900;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryPurple),
                            const SizedBox(width: 10),
                            Text(record.date, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                          ],
                        ),
                        Row(
                          children: [
                            if (record.checkIn != null) ...[
                              Text('In: ${record.checkIn}  •  Out: ${record.checkOut ?? "—"}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                              const SizedBox(width: 16),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(record.status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('Error loading attendance logs: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showMarkAttendanceDialog(BuildContext context, Staff staff) {
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final checkInController = TextEditingController(text: '08:30 AM');
    final checkOutController = TextEditingController(text: '03:30 PM');
    String status = 'present';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Mark Teacher Attendance', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateController,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD) *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Attendance Status *'),
                  items: const [
                    DropdownMenuItem(value: 'present', child: Text('Present')),
                    DropdownMenuItem(value: 'absent', child: Text('Absent')),
                    DropdownMenuItem(value: 'late', child: Text('Late')),
                    DropdownMenuItem(value: 'half_day', child: Text('Half Day')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => status = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: checkInController,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: 'Check In Time'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: checkOutController,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(labelText: 'Check Out Time'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final dt = dateController.text.trim();
                if (dt.isEmpty) return;

                final attendance = TeacherAttendance(
                  id: const Uuid().v4(),
                  staffId: staff.id,
                  date: dt,
                  checkIn: checkInController.text.trim(),
                  checkOut: checkOutController.text.trim(),
                  status: status,
                  markedBy: 'Admin',
                );

                final dbService = ref.read(databaseServiceProvider);
                await dbService.markTeacherAttendance(attendance);

                final attParam = MonthlyAttendanceParam(
                  staffId: staff.id,
                  month: _selectedAttendanceMonth,
                  year: _selectedAttendanceYear,
                );
                ref.invalidate(teacherMonthlyAttendanceSummaryProvider(attParam));
                ref.invalidate(teacherMonthlyAttendanceRecordsProvider(attParam));

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Attendance marked as ${status.toUpperCase()} for ${staff.fullName}'), backgroundColor: AppTheme.primaryPurple),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: const Text('Save Attendance'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // EXISTING CARDS & HELPERS
  // ============================================================================

  void _showAddSubjectDialog(BuildContext context) {
    final subjectController = TextEditingController();
    final classController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Subject & Class', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectController,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Subject Name (e.g. Mathematics, Physics)',
                  labelStyle: GoogleFonts.poppins(fontSize: 13),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: classController,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Class / Section (e.g. Grade 10-A, Grade 9-B)',
                  labelStyle: GoogleFonts.poppins(fontSize: 13),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              final sub = subjectController.text.trim();
              final cls = classController.text.trim();
              if (sub.isEmpty || cls.isEmpty) return;

              final dbService = ref.read(databaseServiceProvider);
              final assignment = StaffSubjectAssignment(
                id: 'sub-${DateTime.now().millisecondsSinceEpoch}',
                staffId: widget.staff.id,
                subject: sub,
                classAssigned: cls,
              );

              await dbService.insertStaffSubject(assignment);
              ref.invalidate(staffSubjectsProvider(widget.staff.id));
              ref.invalidate(teacherWorkloadProvider(widget.staff.id));

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Assigned $sub to ${widget.staff.fullName}'), backgroundColor: AppTheme.success),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
            child: Text('Assign Subject', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddSalaryComponentDialog(BuildContext context) {
    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.editSalaryComponent)) return;
    final amountController = TextEditingController();
    String selectedType = 'hra';
    final types = [
      {'val': 'hra', 'label': 'HRA (House Rent Allowance)'},
      {'val': 'da', 'label': 'DA (Dearness Allowance)'},
      {'val': 'deduction', 'label': 'General Deduction'},
      {'val': 'pf', 'label': 'Provident Fund (PF)'},
      {'val': 'other', 'label': 'Other Special Allowance'},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Add Salary Component', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Component Type',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      border: const OutlineInputBorder(),
                    ),
                    items: types.map((t) => DropdownMenuItem(value: t['val'], child: Text(t['label']!))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monthly Amount (₹)',
                      prefixText: '₹ ',
                      labelStyle: GoogleFonts.poppins(fontSize: 13),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                  if (amt <= 0) return;

                  final dbService = ref.read(databaseServiceProvider);
                  final component = SalaryComponent(
                    id: 'salcomp-${DateTime.now().millisecondsSinceEpoch}',
                    staffId: widget.staff.id,
                    componentType: selectedType,
                    amount: amt,
                    effectiveFrom: DateTime.now().toIso8601String().split('T').first,
                  );

                  await dbService.insertSalaryComponent(component);
                  ref.invalidate(salaryComponentsProvider(widget.staff.id));

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added ${selectedType.toUpperCase()} component (₹$amt)'), backgroundColor: AppTheme.success),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                child: Text('Save Component', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
            child: Text(
              widget.staff.firstName[0].toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: 40,
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.staff.fullName,
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary),
            textAlign: TextAlign.center,
          ),
          Text(
            widget.staff.designation ?? widget.staff.role.toUpperCase(),
            style: GoogleFonts.poppins(
                fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _buildInfoRow('Emp Code', widget.staff.staffCode ?? 'N/A'),
          _buildInfoRow('Role', widget.staff.role.toUpperCase()),
          _buildInfoRow('Department', widget.staff.departmentId ?? 'N/A'),
          _buildInfoRow('Qualification', widget.staff.qualification ?? 'N/A'),
          _buildInfoRow('Experience', widget.staff.experienceYears != null ? '${widget.staff.experienceYears} Years' : 'N/A'),
          _buildInfoRow('Joining Date', widget.staff.joiningDate ?? 'N/A'),
          _buildInfoRow('Date of Birth', widget.staff.dob ?? 'N/A'),
          _buildInfoRow('Gender / Blood', '${widget.staff.gender ?? "N/A"} / ${widget.staff.bloodGroup ?? "N/A"}'),
          _buildInfoRow('Aadhaar Number', widget.staff.aadhaarNumber ?? 'N/A'),
          _buildInfoRow('PAN Number', widget.staff.panNumber ?? 'N/A'),
          _buildInfoRow('Bank Account', widget.staff.bankAccountNumber != null ? '${widget.staff.bankAccountNumber} (${widget.staff.bankIfsc ?? ""})' : 'N/A'),
          _buildInfoRow('Status', widget.staff.isActive ? 'Active' : 'Inactive',
              color: widget.staff.isActive ? AppTheme.success : AppTheme.error),
          if (!widget.staff.isActive)
            _buildInfoRow('Exit Reason', widget.staff.exitReason ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contact & Address Details',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          _buildInfoRow('Phone', widget.staff.phone ?? 'N/A'),
          _buildInfoRow('Email', widget.staff.email ?? 'N/A'),
          _buildInfoRow('Emergency Contact', widget.staff.emergencyContact ?? 'N/A'),
          _buildInfoRow('Address', widget.staff.address ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildSubjectsCard(AsyncValue<List<StaffSubjectAssignment>> subjectsAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Assigned Subjects & Classes',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              ElevatedButton.icon(
                onPressed: () => _showAddSubjectDialog(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Assign Subject',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          subjectsAsync.when(
            data: (subjects) {
              if (subjects.isEmpty) {
                return Text('No subjects or classes assigned yet.',
                    style: GoogleFonts.poppins(
                        color: AppTheme.textHint, fontStyle: FontStyle.italic));
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: subjects.map((sub) {
                  return Chip(
                    backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                    deleteIcon: const Icon(Icons.cancel, size: 16, color: AppTheme.primaryPurple),
                    onDeleted: () async {
                      final dbService = ref.read(databaseServiceProvider);
                      await dbService.deleteStaffSubject(sub.id);
                      ref.invalidate(staffSubjectsProvider(widget.staff.id));
                      ref.invalidate(teacherWorkloadProvider(widget.staff.id));
                    },
                    label: Text('${sub.subject} (${sub.classAssigned})',
                        style: GoogleFonts.poppins(
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  );
                }).toList(),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('Error loading subjects: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryCard(AsyncValue<List<SalaryComponent>> salaryAsync) {
    final basicSalary = widget.staff.basicSalary ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payroll & Salary Structure',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              ElevatedButton.icon(
                onPressed: () => _showAddSalaryComponentDialog(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Add Component',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Basic Monthly Salary', '₹${basicSalary.toStringAsFixed(2)}'),
          const Divider(),
          salaryAsync.when(
            data: (components) {
              double totalAdditions = basicSalary;
              double totalDeductions = 0.0;

              for (final c in components) {
                if (c.componentType == 'deduction' || c.componentType == 'pf') {
                  totalDeductions += c.amount;
                } else {
                  totalAdditions += c.amount;
                }
              }

              final netSalary = totalAdditions - totalDeductions;

              return Column(
                children: [
                  ...components.map((c) {
                    final isDeduction = c.componentType == 'deduction' || c.componentType == 'pf';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(c.componentType.toUpperCase(),
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: AppTheme.textSecondary)),
                          Row(
                            children: [
                              Text(
                                '${isDeduction ? "-" : "+"}₹${c.amount.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDeduction ? AppTheme.error : AppTheme.success),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.textHint),
                                onPressed: () async {
                                  if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.editSalaryComponent)) return;
                                  final dbService = ref.read(databaseServiceProvider);
                                  await dbService.deleteSalaryComponent(c.id);
                                  ref.invalidate(salaryComponentsProvider(widget.staff.id));
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  _buildInfoRow('Gross Salary', '₹${totalAdditions.toStringAsFixed(2)}'),
                  _buildInfoRow('Total Deductions', '₹${totalDeductions.toStringAsFixed(2)}', color: AppTheme.error),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Net Monthly Take-Home',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryPurple)),
                        Text('₹${netSalary.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryPurple)),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('Error loading salary components: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppTheme.textSecondary)),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color ?? AppTheme.textPrimary),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
