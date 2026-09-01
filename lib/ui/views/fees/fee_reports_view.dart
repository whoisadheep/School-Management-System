import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/ai_message_service.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/services_provider.dart';
import 'student_fee_ledger_view.dart';
import 'date_wise_report_tab.dart';

/// Fee Reports & Analytics View — Class-wise Dues, Overdue Students List,
/// and Collection Breakdown by Fee Head.
class FeeReportsView extends ConsumerStatefulWidget {
  const FeeReportsView({super.key});

  @override
  ConsumerState<FeeReportsView> createState() => _FeeReportsViewState();
}

class _FeeReportsViewState extends ConsumerState<FeeReportsView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _selectedAcademicYear = '2024-2025';
  DateTime? _startDate;
  DateTime? _endDate;

  String _selectedClass = 'Grade 1';
  String _selectedSection = 'A';
  String? _selectedMatrixFeeHeadId;
  String? _selectedClassWiseFeeHeadId;

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

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

          // Tab Bar
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
                Tab(text: 'Date-Wise Report'),
                Tab(text: 'Class-Wise Dues'),
                Tab(text: 'Overdue Students'),
                Tab(text: 'Collections by Fee Head'),
                Tab(text: 'Class Monthly Matrix'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                DateWiseReportTab(academicYear: _selectedAcademicYear),
                _buildClassWiseDuesTab(),
                _buildOverdueStudentsTab(),
                _buildCollectionByFeeHeadTab(),
                _buildClassMonthlyMatrixTab(),
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
                'Fee Reports & Analytics',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                'Track class-wide dues, overdue balances, and head-wise collection performance.',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          Row(
            children: [
              // Academic Year Filter Dropdown
              Consumer(
                builder: (context, ref, _) {
                  final yearsAsync = ref.watch(academicYearsProvider);
                  final yearList = yearsAsync.value?.map((y) => y.name).toList() ?? ['2023-2024', '2024-2025', '2025-2026'];
                  if (!yearList.contains(_selectedAcademicYear) && yearList.isNotEmpty) {
                    _selectedAcademicYear = yearList.first;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: DropdownButton<String>(
                      value: yearList.contains(_selectedAcademicYear) ? _selectedAcademicYear : null,
                      underline: const SizedBox(),
                      style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                      items: yearList
                          .map((y) => DropdownMenuItem(value: y, child: Text('Session $y')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedAcademicYear = val);
                        }
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 1: CLASS-WISE DUES
  // ============================================================================

  Widget _buildClassWiseDuesTab() {
    final duesAsync = ref.watch(classWiseDuesSummaryProvider(
        ClassWiseDuesParam(academicYear: _selectedAcademicYear, feeHeadId: _selectedClassWiseFeeHeadId)));

    return duesAsync.when(
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Text(
              'No class dues data found for AY $_selectedAcademicYear',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
          );
        }

        double grandTotalDue = 0;
        double grandTotalPaid = 0;
        double grandTotalOutstanding = 0;
        for (final r in rows) {
          grandTotalDue += (r['total_due'] as num).toDouble();
          grandTotalPaid += (r['total_paid'] as num).toDouble();
          grandTotalOutstanding += (r['outstanding_balance'] as num).toDouble();
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Filters
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Fee Head:', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(width: 8),
                  Consumer(
                    builder: (context, ref, child) {
                      final feeHeadsAsync = ref.watch(feeHeadsProvider);
                      return feeHeadsAsync.when(
                        data: (heads) {
                          final items = <DropdownMenuItem<String?>>[
                            const DropdownMenuItem(value: null, child: Text('All Together')),
                            ...heads.map((h) => DropdownMenuItem(value: h.id, child: Text(h.name))),
                          ];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: DropdownButton<String?>(
                              value: _selectedClassWiseFeeHeadId,
                              underline: const SizedBox(),
                              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary),
                              items: items,
                              onChanged: (val) {
                                setState(() => _selectedClassWiseFeeHeadId = val);
                              },
                            ),
                          );
                        },
                        loading: () => const SizedBox(width: 100, child: LinearProgressIndicator()),
                        error: (_, __) => const Text('Error loading fee heads'),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Metric cards
              Row(
                children: [
                  _summaryMiniCard('Total Class Demand', grandTotalDue, AppTheme.primaryPurple),
                  const SizedBox(width: 16),
                  _summaryMiniCard('Total Collected', grandTotalPaid, AppTheme.success),
                  const SizedBox(width: 16),
                  _summaryMiniCard('Total Outstanding', grandTotalOutstanding, AppTheme.error),
                ],
              ),
              const SizedBox(height: 20),

              // Table
              Expanded(
                child: Container(
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
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            _thCell('Class', flex: 3),
                            _thCell('Students', flex: 2),
                            _thCell('Total Demand', flex: 3),
                            _thCell('Collected', flex: 3),
                            _thCell('Outstanding', flex: 3),
                            _thCell('Collection Rate', flex: 3),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppTheme.divider),
                      Expanded(
                        child: ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            final totalDue = (row['total_due'] as num).toDouble();
                            final totalPaid = (row['total_paid'] as num).toDouble();
                            final outstanding = (row['outstanding_balance'] as num).toDouble();
                            final rate = totalDue > 0 ? (totalPaid / totalDue).clamp(0.0, 1.0) : 0.0;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      row['class_name'] as String? ?? 'N/A',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${row['total_students']}',
                                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      _currencyFormat.format(totalDue),
                                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      _currencyFormat.format(totalPaid),
                                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      _currencyFormat.format(outstanding),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: outstanding > 0 ? AppTheme.error : AppTheme.success,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: rate,
                                              backgroundColor: AppTheme.divider,
                                              color: rate > 0.7
                                                  ? AppTheme.success
                                                  : (rate > 0.4 ? AppTheme.warning : AppTheme.error),
                                              minHeight: 6,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${(rate * 100).toStringAsFixed(0)}%',
                                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Error loading class dues: $e', style: GoogleFonts.poppins(color: AppTheme.error))),
    );
  }

  // ============================================================================
  // TAB 2: OVERDUE STUDENTS
  // ============================================================================

  Widget _buildOverdueStudentsTab() {
    final overdueAsync = ref.watch(overdueStudentsProvider(_selectedAcademicYear));

    return overdueAsync.when(
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 64, color: AppTheme.success),
                const SizedBox(height: 16),
                Text('No overdue student balances! 🎉',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text('All enrolled students are up-to-date for AY $_selectedAcademicYear.',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          );
        }

        double totalOverdueSum = 0;
        for (final r in rows) {
          totalOverdueSum += (r['total_overdue_amount'] as num).toDouble();
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 24),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Overdue Outstanding',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w600)),
                        Text(_currencyFormat.format(totalOverdueSum),
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.error)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${rows.length} Overdue Student(s)',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Table
              Expanded(
                child: Container(
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
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            _thCell('Student Name', flex: 3),
                            _thCell('Class', flex: 2),
                            _thCell('Roll No', flex: 2),
                            _thCell('Overdue Items', flex: 2),
                            _thCell('Oldest Due Date', flex: 3),
                            _thCell('Overdue Amount', flex: 3),
                            _thCell('Action', flex: 3),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppTheme.divider),
                      Expanded(
                        child: ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            final amount = (row['total_overdue_amount'] as num).toDouble();
                            final oldestDueStr = row['oldest_due_date'] as String?;
                            final oldestDate = oldestDueStr != null ? DateTime.tryParse(oldestDueStr) : null;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      row['student_name'] as String? ?? 'N/A',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      row['grade_level'] as String? ?? 'N/A',
                                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${row['roll_number'] ?? "N/A"}',
                                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${row['overdue_count']} item(s)',
                                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      oldestDate != null ? _dateFormat.format(oldestDate) : 'N/A',
                                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      _currencyFormat.format(amount),
                                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.error),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        Tooltip(
                                          message: 'Send WhatsApp Reminder',
                                          child: InkWell(
                                            onTap: () async {
                                              final phone = (row['father_phone'] as String?)?.isNotEmpty == true 
                                                  ? row['father_phone'] as String 
                                                  : (row['mother_phone'] as String?) ?? '';
                                                  
                                              if (phone.isEmpty) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('No phone number found for ${row['student_name']}.', style: GoogleFonts.poppins()), 
                                                      backgroundColor: AppTheme.warning
                                                    )
                                                  );
                                                }
                                                return;
                                              }
                                              
                                              final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
                                              final finalPhone = cleanPhone.startsWith('+') ? cleanPhone : '+91$cleanPhone';
                                              
                                              final studentName = row['student_name'] as String? ?? 'Student';
                                              final amountStr = _currencyFormat.format(amount);
                                              
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Generating smart message...', style: GoogleFonts.poppins()), 
                                                    duration: const Duration(milliseconds: 1500)
                                                  )
                                                );
                                              }
                                              
                                              final aiService = ref.read(aiMessageServiceProvider);
                                              final text = await aiService.generateOverdueReminder(
                                                studentName: studentName,
                                                amountStr: amountStr,
                                                grade: row['grade_level'] as String? ?? 'N/A',
                                              );
                                              
                                              final url = Uri.parse('https://wa.me/$finalPhone?text=${Uri.encodeComponent(text)}');
                                              
                                              if (await canLaunchUrl(url)) {
                                                await launchUrl(url);
                                              } else {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Could not launch WhatsApp.', style: GoogleFonts.poppins()), 
                                                      backgroundColor: AppTheme.error
                                                    )
                                                  );
                                                }
                                              }
                                            },
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              height: 28,
                                              width: 28,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF25D366).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.5)),
                                              ),
                                              child: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF25D366)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: SizedBox(
                                            height: 28,
                                            child: OutlinedButton(
                                              onPressed: () async {
                                                final dbService = ref.read(databaseServiceProvider);
                                                final student = await dbService.getStudentById(row['student_id'] as String);
                                                if (student != null && context.mounted) {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) => StudentFeeLedgerView(student: student, academicYear: _selectedAcademicYear),
                                                    ),
                                                  );
                                                }
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppTheme.primaryPurple,
                                                side: const BorderSide(color: AppTheme.primaryPurple),
                                                padding: const EdgeInsets.symmetric(horizontal: 0),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                textStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
                                              ),
                                              child: const Text('View'),
                                            ),
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
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Error loading overdue list: $e', style: GoogleFonts.poppins(color: AppTheme.error))),
    );
  }

  // ============================================================================
  // TAB 3: COLLECTIONS BY FEE HEAD
  // ============================================================================

  Widget _buildCollectionByFeeHeadTab() {
    final param = CollectionFilterParam(
      academicYear: _selectedAcademicYear,
      startDate: _startDate,
      endDate: _endDate,
    );
    final collectionAsync = ref.watch(collectionSummaryByFeeHeadProvider(param));

    return collectionAsync.when(
      data: (rows) {
        double totalCollectionsSum = 0;
        int totalTxnCount = 0;
        for (final r in rows) {
          totalCollectionsSum += (r['total_collected'] as num).toDouble();
          totalTxnCount += (r['transaction_count'] as int? ?? 0);
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date filter bar
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        initialDateRange: _startDate != null && _endDate != null
                            ? DateTimeRange(start: _startDate!, end: _endDate!)
                            : null,
                      );
                      if (range != null) {
                        setState(() {
                          _startDate = range.start;
                          _endDate = range.end;
                        });
                      }
                    },
                    icon: const Icon(Icons.date_range_rounded, size: 16),
                    label: Text(
                      _startDate != null && _endDate != null
                          ? '${_dateFormat.format(_startDate!)} – ${_dateFormat.format(_endDate!)}'
                          : 'Filter Date Range',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryPurple,
                      side: const BorderSide(color: AppTheme.primaryPurple),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (_startDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() {
                        _startDate = null;
                        _endDate = null;
                      }),
                      tooltip: 'Clear Date Filter',
                    ),
                  ],
                  const Spacer(),
                  // Summary Badges
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Text('Total Collections: ', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                        Text(_currencyFormat.format(totalCollectionsSum),
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.success)),
                        const SizedBox(width: 16),
                        Text('Transactions: ', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('$totalTxnCount', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Table
              Expanded(
                child: Container(
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
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            _thCell('Fee Head Name', flex: 4),
                            _thCell('Frequency', flex: 3),
                            _thCell('Total Transactions', flex: 3),
                            _thCell('Total Revenue (₹)', flex: 4),
                            _thCell('Share %', flex: 3),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppTheme.divider),
                      Expanded(
                        child: rows.isEmpty
                            ? Center(child: Text('No collection data for this period', style: GoogleFonts.poppins(color: AppTheme.textHint)))
                            : ListView.separated(
                                itemCount: rows.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                                itemBuilder: (context, index) {
                                  final row = rows[index];
                                  final collected = (row['total_collected'] as num).toDouble();
                                  final share = totalCollectionsSum > 0 ? (collected / totalCollectionsSum) : 0.0;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            row['fee_head_name'] as String? ?? 'N/A',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            _capitalize(row['frequency'] as String? ?? 'N/A'),
                                            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            '${row['transaction_count']} txns',
                                            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            _currencyFormat.format(collected),
                                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.success),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: LinearProgressIndicator(
                                                    value: share,
                                                    backgroundColor: AppTheme.divider,
                                                    color: AppTheme.primaryPurple,
                                                    minHeight: 6,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${(share * 100).toStringAsFixed(1)}%',
                                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Error loading collection breakdown: $e', style: GoogleFonts.poppins(color: AppTheme.error))),
    );
  }

  Widget _summaryMiniCard(String title, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
              _currencyFormat.format(amount),
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, letterSpacing: 0.5),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }

  // ============================================================================
  // TAB 4: CLASS MONTHLY MATRIX
  // ============================================================================

  Widget _buildClassMonthlyMatrixTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Text('Class:', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(width: 8),
              Consumer(
                builder: (context, ref, child) {
                  final classesAsync = ref.watch(classesProvider);
                  return classesAsync.when(
                    data: (classes) {
                      if (classes.isEmpty) return const Text('No classes');
                      // Ensure selected class is valid
                      if (!classes.any((c) => c.name == _selectedClass)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _selectedClass = classes.first.name);
                        });
                      }
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedClass,
                          underline: const SizedBox(),
                          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary),
                          items: classes.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedClass = val);
                          },
                        ),
                      );
                    },
                    loading: () => const SizedBox(width: 80, child: LinearProgressIndicator()),
                    error: (_, __) => const Text('Error'),
                  );
                },
              ),
              const SizedBox(width: 24),
              Text('Section:', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: DropdownButton<String>(
                  value: _selectedSection,
                  underline: const SizedBox(),
                  style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary),
                  items: ['A', 'B', 'C']
                      .map((s) => DropdownMenuItem(value: s, child: Text('Sec $s')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSection = val);
                  },
                ),
              ),
              const SizedBox(width: 24),
              Text('Fee Head:', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(width: 8),
              Consumer(
                builder: (context, ref, child) {
                  final feeHeadsAsync = ref.watch(feeHeadsProvider);
                  return feeHeadsAsync.when(
                    data: (heads) {
                      final items = <DropdownMenuItem<String?>>[
                        const DropdownMenuItem(value: null, child: Text('All Together')),
                        ...heads.map((h) => DropdownMenuItem(value: h.id, child: Text(h.name))),
                      ];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: DropdownButton<String?>(
                          value: _selectedMatrixFeeHeadId,
                          underline: const SizedBox(),
                          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary),
                          items: items,
                          onChanged: (val) {
                            setState(() => _selectedMatrixFeeHeadId = val);
                          },
                        ),
                      );
                    },
                    loading: () => const SizedBox(width: 100, child: LinearProgressIndicator()),
                    error: (_, __) => const Text('Error loading fee heads'),
                  );
                },
              ),
            ],
          ),
        ),

        // Matrix Grid
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: ref.read(databaseServiceProvider).getClassMonthlyCollectionMatrix(_selectedClass, _selectedSection, _selectedAcademicYear, feeHeadId: _selectedMatrixFeeHeadId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading matrix: ${snapshot.error}', style: GoogleFonts.poppins(color: AppTheme.error)));
              }

              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return Center(child: Text('No student data found for Class $_selectedClass-$_selectedSection.', style: GoogleFonts.poppins(color: AppTheme.textSecondary)));
              }

              final months = ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: AppTheme.bgSurface,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('Student', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                            ),
                            for (final m in months)
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Text(m, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppTheme.divider),
                      
                      // Body
                      Expanded(
                        child: ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            final studentName = row['student_name'] as String? ?? 'Unknown';
                            final matrix = row['monthly_matrix'] as Map<String, dynamic>? ?? {};

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      studentName,
                                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  for (final m in months)
                                    Expanded(
                                      flex: 1,
                                      child: Center(
                                        child: _buildMatrixCell(matrix[m] as Map<String, dynamic>?),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMatrixCell(Map<String, dynamic>? data) {
    final status = data?['status'] as String? ?? 'none';
    final amountDue = data?['amount_due'] as double? ?? 0.0;
    final amountPaid = data?['amount_paid'] as double? ?? 0.0;

    Color color;
    switch (status) {
      case 'paid':
        color = AppTheme.success;
        break;
      case 'pending':
        color = AppTheme.warning;
        break;
      case 'overdue':
        color = AppTheme.error;
        break;
      case 'none':
      default:
        color = AppTheme.divider;
        break;
    }

    String tooltipMsg = status.toUpperCase();
    if (status != 'none') {
      tooltipMsg += '\nDue: ${_currencyFormat.format(amountDue)}\nPaid: ${_currencyFormat.format(amountPaid)}';
    } else {
      tooltipMsg = 'NONE';
    }

    return Tooltip(
      message: tooltipMsg,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
