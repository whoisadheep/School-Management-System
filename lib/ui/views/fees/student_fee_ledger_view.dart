import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../services/report_generator.dart';
import '../../widgets/pdf_preview_dialog.dart';
import '../../../services/settings_service.dart';
import '../../../services/app_logger.dart';

/// Student Fee Ledger View — shows all fee head obligations, due dates,
/// paid/due amounts, status badges, with "Record Payment" actions.
/// Can record per-row payments or auto-allocate lump sums (oldest-due-first).
class StudentFeeLedgerView extends ConsumerStatefulWidget {
  final Student student;
  final String academicYear;

  const StudentFeeLedgerView({
    super.key,
    required this.student,
    this.academicYear = '2024-2025',
  });

  @override
  ConsumerState<StudentFeeLedgerView> createState() => _StudentFeeLedgerViewState();
}

class _StudentFeeLedgerViewState extends ConsumerState<StudentFeeLedgerView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessingPayment = false;
  final Set<String> _selectedMonthsForPayment = {};
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  StudentYearParam get _param => StudentYearParam(
        studentId: widget.student.id,
        academicYear: widget.academicYear,
      );

  @override
  Widget build(BuildContext context) {
    final ledgerAsync = ref.watch(studentFeeLedgerProvider(_param));
    final summaryAsync = ref.watch(studentLedgerSummaryProvider(_param));

    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(context),

          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryPurple,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primaryPurple,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: 'Ledger'),
                Tab(text: 'Monthly Status'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLedgerTab(summaryAsync, ledgerAsync),
                _buildMonthlyStatusTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerTab(AsyncValue<Map<String, double>> summaryAsync, AsyncValue<List<StudentFeeLedger>> ledgerAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Cards
        summaryAsync.when(
          data: (summary) => _buildSummaryRow(summary),
          loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error loading summary: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
          ),
        ),

        // Ledger Table
        Expanded(
          child: ledgerAsync.when(
            data: (entries) => entries.isEmpty
                ? _buildEmptyState(context)
                : _buildLedgerTable(context, entries),
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(
              child: Text('Error loading ledger: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyStatusTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(databaseServiceProvider).getMonthlyFeeStatus(widget.student.id, widget.academicYear),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading monthly status: ${snapshot.error}', style: GoogleFonts.poppins(color: AppTheme.error)));
        }

        final data = snapshot.data;
        if (data == null) {
          return Center(child: Text('No data found.', style: GoogleFonts.poppins(color: AppTheme.textSecondary)));
        }

        final monthlyStatus = data['monthly_status'] as Map<String, dynamic>? ?? {};
        final monthlyLedgers = data['monthly_ledgers'] as Map<String, dynamic>? ?? {};

        final months = [
          'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'
        ];

        double totalSelectedDue = 0;
        for (final m in _selectedMonthsForPayment) {
          final ledgers = monthlyLedgers[m] as List<dynamic>? ?? [];
          for (final l in ledgers) {
            if (l.status == LedgerStatus.pending || l.status == LedgerStatus.partial || l.status == LedgerStatus.overdue) {
              totalSelectedDue += (l.amountDue - l.amountPaid);
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Fee Status (AY ${widget.academicYear})',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      if (_selectedMonthsForPayment.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: _isProcessingPayment ? null : () => _processSelectedMonthsPayment(monthlyLedgers),
                          icon: const Icon(Icons.payment, size: 16),
                          label: Text('Pay ${_currencyFormat.format(totalSelectedDue)}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.divider),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: months.length,
                    itemBuilder: (context, index) {
                      final month = months[index];
                      final statusStr = monthlyStatus[month] as String? ?? 'none';
                      final ledgers = monthlyLedgers[month] as List<dynamic>? ?? [];

                      double monthDue = 0;
                      double monthCollected = 0;
                      for (final l in ledgers) {
                        monthCollected += l.amountPaid;
                        if (l.status == LedgerStatus.pending || l.status == LedgerStatus.partial || l.status == LedgerStatus.overdue) {
                          monthDue += (l.amountDue - l.amountPaid);
                        }
                      }

                      Color bgColor;
                      Color textColor;
                      Color borderColor;

                      switch (statusStr) {
                        case 'paid':
                          bgColor = AppTheme.success.withValues(alpha: 0.1);
                          borderColor = AppTheme.success.withValues(alpha: 0.3);
                          textColor = AppTheme.success;
                          break;
                        case 'pending':
                          bgColor = AppTheme.warning.withValues(alpha: 0.1);
                          borderColor = AppTheme.warning.withValues(alpha: 0.3);
                          textColor = AppTheme.warning;
                          break;
                        case 'overdue':
                          bgColor = AppTheme.error.withValues(alpha: 0.1);
                          borderColor = AppTheme.error.withValues(alpha: 0.3);
                          textColor = AppTheme.error;
                          break;
                        default:
                          bgColor = AppTheme.bgSurface;
                          borderColor = AppTheme.divider;
                          textColor = AppTheme.textHint;
                      }

                      final isSelected = _selectedMonthsForPayment.contains(month);
                      if (isSelected) {
                        borderColor = AppTheme.primaryPurple;
                        bgColor = AppTheme.primaryPurple.withValues(alpha: 0.1);
                      }

                      return InkWell(
                        onTap: (statusStr == 'pending' || statusStr == 'overdue') && ledgers.isNotEmpty
                            ? () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedMonthsForPayment.remove(month);
                                  } else {
                                    _selectedMonthsForPayment.add(month);
                                  }
                                });
                              }
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                month,
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                statusStr.toUpperCase(),
                                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: textColor),
                              ),
                              if (monthDue > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text('Due: ${_currencyFormat.format(monthDue)}', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.error)),
                                ),
                              if (monthCollected > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text('Paid: ${_currencyFormat.format(monthCollected)}', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.success)),
                                ),
                            ],
                          ),
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
            style: IconButton.styleFrom(foregroundColor: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fee Ledger — ${widget.student.name}',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              Text(
                '${widget.student.gradeLevel} • AY ${widget.academicYear} • Roll #${widget.student.rollNumber ?? 'N/A'}',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          // Generate Ledger Button
          OutlinedButton.icon(
            onPressed: _isGenerating ? null : () => _generateLedger(context),
            icon: _isGenerating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high_rounded, size: 16),
            label: Text(
              _isGenerating ? 'Generating...' : 'Generate Dues',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryPurple,
              side: const BorderSide(color: AppTheme.primaryPurple),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 12),
          // Lump Sum Payment Button
          ElevatedButton.icon(
            onPressed: _isProcessingPayment ? null : () => _showLumpSumPaymentDialog(context),
            icon: const Icon(Icons.payments_rounded, size: 16),
            label: Text(
              'Record Lump Sum',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(Map<String, double> summary) {
    final totalDue = summary['total_due'] ?? 0.0;
    final totalPaid = summary['total_paid'] ?? 0.0;
    final totalOverdue = summary['total_overdue'] ?? 0.0;
    final balance = totalDue - totalPaid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildSummaryCard('Total Due', totalDue, Icons.receipt_long_rounded, AppTheme.primaryPurple),
          const SizedBox(width: 16),
          _buildSummaryCard('Total Paid', totalPaid, Icons.check_circle_rounded, AppTheme.success),
          const SizedBox(width: 16),
          _buildSummaryCard('Outstanding', balance, Icons.pending_actions_rounded,
              balance > 0 ? AppTheme.warning : AppTheme.success),
          const SizedBox(width: 16),
          _buildSummaryCard('Overdue', totalOverdue, Icons.warning_amber_rounded, AppTheme.error),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, double amount, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
                Text(
                  _currencyFormat.format(amount),
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 64, color: AppTheme.textHint.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No fee ledger entries found',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Generate Dues" to auto-create fee obligations\nbased on the class fee structure & student discounts.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isGenerating ? null : () => _generateLedger(context),
            icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
            label: Text('Generate Dues Now', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerTable(BuildContext context, List<StudentFeeLedger> entries) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  _headerCell('Fee Head', flex: 3),
                  _headerCell('Frequency', flex: 2),
                  _headerCell('Due Date', flex: 2),
                  _headerCell('Amount Due', flex: 2),
                  _headerCell('Paid', flex: 2),
                  _headerCell('Remaining', flex: 2),
                  _headerCell('Status', flex: 2),
                  _headerCell('Action', flex: 2),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.divider),

            // Table Body
            Expanded(
              child: ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _buildLedgerRow(context, entry, index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildLedgerRow(BuildContext context, StudentFeeLedger entry, int index) {
    final remaining = entry.amountDue - entry.amountPaid;
    final isPaid = entry.status == LedgerStatus.paid;

    return Container(
      color: index % 2 == 0 ? Colors.white : AppTheme.bgSurface.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Fee Head Name
          Expanded(
            flex: 3,
            child: Text(
              entry.feeHeadName ?? entry.feeHeadId,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
            ),
          ),
          // Frequency
          Expanded(
            flex: 2,
            child: Text(
              _capitalizeFrequency(entry.frequency ?? 'N/A'),
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
          // Due Date
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('dd MMM yyyy').format(entry.dueDate),
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
          // Amount Due
          Expanded(
            flex: 2,
            child: Text(
              _currencyFormat.format(entry.amountDue),
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
            ),
          ),
          // Paid
          Expanded(
            flex: 2,
            child: Text(
              _currencyFormat.format(entry.amountPaid),
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.success),
            ),
          ),
          // Remaining
          Expanded(
            flex: 2,
            child: Text(
              _currencyFormat.format(remaining > 0 ? remaining : 0),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: remaining > 0 ? AppTheme.error : AppTheme.success,
              ),
            ),
          ),
          // Status Badge
          Expanded(
            flex: 2,
            child: _buildStatusBadge(entry.status),
          ),
          // Action Button
          Expanded(
            flex: 2,
            child: isPaid
                ? Text('✓ Cleared', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.success, fontWeight: FontWeight.w600))
                : SizedBox(
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () => _showRowPaymentDialog(context, entry),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        textStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Pay'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(LedgerStatus status) {
    Color bg, border, text;
    String label = status.displayName.toUpperCase();

    switch (status) {
      case LedgerStatus.paid:
        bg = AppTheme.success.withValues(alpha: 0.1);
        border = AppTheme.success.withValues(alpha: 0.3);
        text = AppTheme.success;
        break;
      case LedgerStatus.partial:
        bg = AppTheme.warning.withValues(alpha: 0.1);
        border = AppTheme.warning.withValues(alpha: 0.3);
        text = AppTheme.warning;
        break;
      case LedgerStatus.overdue:
        bg = AppTheme.error.withValues(alpha: 0.1);
        border = AppTheme.error.withValues(alpha: 0.3);
        text = AppTheme.error;
        break;
      case LedgerStatus.pending:
        bg = AppTheme.primaryPurple.withValues(alpha: 0.1);
        border = AppTheme.primaryPurple.withValues(alpha: 0.3);
        text = AppTheme.primaryPurple;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(color: text, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    );
  }

  String _capitalizeFrequency(String freq) {
    if (freq.isEmpty) return freq;
    return freq.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }

  // ============================================================================
  // ACTIONS
  // ============================================================================

  Future<void> _generateLedger(BuildContext context) async {
    setState(() => _isGenerating = true);
    try {
      final dbService = ref.read(databaseServiceProvider);
      final count = await dbService.generateLedgerForStudent(
        widget.student.id,
        widget.student.gradeLevel,
        widget.academicYear,
      );

      // Recalculate overdue statuses
      await dbService.recalculateOverdueLedgerEntries();

      // Refresh providers
      ref.invalidate(studentFeeLedgerProvider(_param));
      ref.invalidate(studentLedgerSummaryProvider(_param));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? '$count ledger entries generated successfully.'
                  : 'All fee entries already exist — nothing new to generate.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: count > 0 ? AppTheme.primaryPurple : AppTheme.textSecondary,
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.instance.error('Failed to generate ledger', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating ledger: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showRowPaymentDialog(BuildContext context, StudentFeeLedger entry) {
    final remaining = entry.amountDue - entry.amountPaid;
    final amountController = TextEditingController(text: remaining.toStringAsFixed(2));
    final refController = TextEditingController();
    PaymentMethod selectedMethod = PaymentMethod.cash;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.payment_rounded, color: AppTheme.primaryPurple, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Record Payment — ${entry.feeHeadName ?? entry.feeHeadId}',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amount Due', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint)),
                          Text(_currencyFormat.format(entry.amountDue),
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Already Paid', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint)),
                          Text(_currencyFormat.format(entry.amountPaid),
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.success)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Remaining', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint)),
                          Text(_currencyFormat.format(remaining),
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.error)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Amount field
                Text('Payment Amount', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Method
                Text('Payment Method', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<PaymentMethod>(
                  value: selectedMethod,
                  dropdownColor: Colors.white,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: PaymentMethod.values.map((m) => DropdownMenuItem(value: m, child: Text(m.displayName))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedMethod = val);
                  },
                ),
                const SizedBox(height: 16),

                // Reference
                Text('Reference / Receipt #', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: refController,
                  style: GoogleFonts.poppins(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Optional',
                    hintStyle: GoogleFonts.poppins(color: AppTheme.textHint),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0 || amount > remaining + 0.01) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Enter a valid amount (₹0 – ${_currencyFormat.format(remaining)})', style: GoogleFonts.poppins()),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                await _processRowPayment(entry, amount, selectedMethod, refController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
              ),
              child: Text('Process Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processRowPayment(
      StudentFeeLedger entry, double amount, PaymentMethod method, String ref_) async {
    setState(() => _isProcessingPayment = true);
    try {
      final dbService = ref.read(databaseServiceProvider);
      final paymentService = ref.read(paymentServiceProvider);

      // Record payment on ledger
      await dbService.recordLedgerPayment(entry.id, amount);

      // Also create invoice + transaction for accounting
      final invoice = Invoice.create(
        studentId: widget.student.id,
        academicYearId: widget.academicYear.startsWith('ay-') ? widget.academicYear : 'ay-${widget.academicYear}',
        totalAmount: amount,
        dueDate: entry.dueDate,
        ledgerId: entry.id,
        notes: 'Ledger payment: ${entry.feeHeadName ?? entry.feeHeadId}',
      );
      await dbService.insertInvoice(invoice);

      final paymentResult = await paymentService.processPayment(
        invoiceId: invoice.id,
        amountPaid: amount,
        paymentMethod: method,
        referenceNumber: ref_.isNotEmpty ? ref_ : null,
      );

      // Generate sequential RCT-{year}-{seq} PDF Receipt
      final receiptNumber = await dbService.getNextReceiptNumber();
      final settingsService = SettingsService();
      final schoolName = await settingsService.getSetting('school_name') ?? 'Kishan Company';
      final schoolAddress = await settingsService.getSetting('school_address') ?? '123 Education Boulevard, Academic District';
      final schoolContact = await settingsService.getSetting('school_contact') ?? 'Phone: +1 800 555-0199 | Email: finance@school.edu';

      final pdfBytes = await ReportGenerator.buildPaymentReceiptPdfBytes(
        transaction: paymentResult.transaction,
        invoice: invoice,
        student: widget.student,
        receiptNumber: receiptNumber,
        feeHeadName: entry.feeHeadName ?? entry.feeHeadId,
        schoolName: schoolName,
        schoolAddress: schoolAddress,
        schoolContact: schoolContact,
      );

      // Refresh providers
      ref.invalidate(studentFeeLedgerProvider(_param));
      ref.invalidate(studentLedgerSummaryProvider(_param));
      ref.invalidate(studentsListProvider);
      ref.invalidate(dashboardMetricsProvider);

      if (mounted) {
        final savedFile = await PdfPreviewDialog.show(
          context: context,
          title: 'Payment Receipt — $receiptNumber',
          pdfBytes: pdfBytes,
          defaultFileName: 'Receipt_${paymentResult.transaction.id.substring(0, 8)}.pdf',
          defaultSubDirectory: 'Receipts',
        );
        if (mounted && savedFile != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment of ${_currencyFormat.format(amount)} recorded! Receipt saved: ${savedFile.path}',
                  style: GoogleFonts.poppins(color: Colors.white)),
              backgroundColor: AppTheme.primaryPurple,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      AppLogger.instance.error('Failed to record row payment', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  void _showLumpSumPaymentDialog(BuildContext context) {
    final amountController = TextEditingController();
    final refController = TextEditingController();
    PaymentMethod selectedMethod = PaymentMethod.cash;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.payments_rounded, color: AppTheme.primaryPurple, size: 20),
              const SizedBox(width: 10),
              Text(
                'Record Lump Sum Payment',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.primaryPurple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This amount will be automatically allocated across open dues,\nstarting with the oldest due date first.',
                          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text('Total Amount', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    hintText: 'Enter total payment amount',
                    hintStyle: GoogleFonts.poppins(color: AppTheme.textHint),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),

                Text('Payment Method', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<PaymentMethod>(
                  value: selectedMethod,
                  dropdownColor: Colors.white,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: PaymentMethod.values.map((m) => DropdownMenuItem(value: m, child: Text(m.displayName))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedMethod = val);
                  },
                ),
                const SizedBox(height: 16),

                Text('Reference / Receipt #', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: refController,
                  style: GoogleFonts.poppins(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Optional',
                    hintStyle: GoogleFonts.poppins(color: AppTheme.textHint),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Enter a valid amount.', style: GoogleFonts.poppins()),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                await _processLumpSumPayment(amount, selectedMethod, refController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
              ),
              child: Text('Allocate & Pay', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectedMonthsPaymentDialog(List<StudentFeeLedger> ledgersToPay, double totalAmount) {
    PaymentMethod selectedMethod = PaymentMethod.cash;
    final refController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.payments_rounded, color: AppTheme.primaryPurple, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pay Selected Months',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text('Total Due for Selected Months', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primaryPurple)),
                          const SizedBox(height: 4),
                          Text(
                            _currencyFormat.format(totalAmount),
                            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Payment Method
                    Text('Payment Method', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<PaymentMethod>(
                      value: selectedMethod,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: PaymentMethod.values.map((m) => DropdownMenuItem(value: m, child: Text(m.displayName))).toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedMethod = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Reference Number (Optional)', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: refController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Check #, Txn ID',
                        hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: _isProcessingPayment
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _processSelectedLedgersPayment(ledgersToPay, totalAmount, selectedMethod, refController.text);
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                  child: Text('Process Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _processSelectedLedgersPayment(List<StudentFeeLedger> ledgersToPay, double totalAmount, PaymentMethod method, String ref_) async {
    setState(() => _isProcessingPayment = true);
    try {
      final dbService = ref.read(databaseServiceProvider);

      final updatedEntries = await dbService.recordMultiMonthPayment(
        studentId: widget.student.id,
        academicYear: widget.academicYear,
        ledgerIds: ledgersToPay.map((l) => l.id).toList(),
        paymentMethod: method,
        referenceNumber: ref_.isNotEmpty ? ref_ : null,
      );

      // Deselect all
      _selectedMonthsForPayment.clear();

      // Invalidate providers
      ref.invalidate(studentFeeLedgerProvider(_param));
      ref.invalidate(studentLedgerSummaryProvider(_param));
      ref.invalidate(studentsListProvider);
      ref.invalidate(dashboardMetricsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment of ${_currencyFormat.format(totalAmount)} allocated across ${updatedEntries.length} fee entries.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.instance.error('Failed to process multi-month payment', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process payment: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  void _processSelectedMonthsPayment(Map<String, dynamic> monthlyLedgers) {
    List<StudentFeeLedger> ledgersToPay = [];
    for (final month in _selectedMonthsForPayment) {
      final ledgers = monthlyLedgers[month] as List<dynamic>? ?? [];
      for (final l in ledgers) {
        if (l.status == LedgerStatus.pending || l.status == LedgerStatus.partial || l.status == LedgerStatus.overdue) {
          ledgersToPay.add(l as StudentFeeLedger);
        }
      }
    }

    if (ledgersToPay.isEmpty) return;

    double totalAmount = 0;
    for (final l in ledgersToPay) {
      totalAmount += (l.amountDue - l.amountPaid);
    }
    _showSelectedMonthsPaymentDialog(ledgersToPay, totalAmount);
  }

  Future<void> _processLumpSumPayment(double amount, PaymentMethod method, String ref_) async {
    setState(() => _isProcessingPayment = true);
    try {
      final dbService = ref.read(databaseServiceProvider);
      final updatedEntries = await dbService.recordLumpSumPayment(
        studentId: widget.student.id,
        academicYear: widget.academicYear,
        totalAmount: amount,
        paymentMethod: method,
        referenceNumber: ref_.isNotEmpty ? ref_ : null,
      );

      // Refresh providers
      ref.invalidate(studentFeeLedgerProvider(_param));
      ref.invalidate(studentLedgerSummaryProvider(_param));
      ref.invalidate(studentsListProvider);
      ref.invalidate(dashboardMetricsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_currencyFormat.format(amount)} allocated across ${updatedEntries.length} fee entries.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: AppTheme.primaryPurple,
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.instance.error('Failed to record lump sum payment', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }
}
