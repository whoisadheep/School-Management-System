import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/license_provider.dart';
import '../../../providers/services_provider.dart';
import '../../../services/bulk_invoice_service.dart';
import '../../widgets/payment_receipt_dialog.dart';
import '../../../services/app_logger.dart';

/// Remade Form-Based Fee Collection View:
/// Features:
/// 1. Auto-complete student lookup by ID, Roll No, or Name with instant profile & transport badge.
/// 2. Session & From-To Month range selector with quick presets.
/// 3. Auto-populated itemized due fees (Tuition, Transport Fee if assigned, Exam Fee, etc.).
/// 4. Total Amount Due display & EDITABLE Paid Amount input field.
/// 5. Partial payment handling: remaining dues automatically roll over to next month until session end.
/// 6. Invoices & Receipts history tab and Batch Invoicing tool.
class FeeCollectionView extends ConsumerStatefulWidget {
  const FeeCollectionView({super.key});

  @override
  ConsumerState<FeeCollectionView> createState() => _FeeCollectionViewState();
}

class _FeeCollectionViewState extends ConsumerState<FeeCollectionView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Student Search / Lookup
  final TextEditingController _studentSearchController = TextEditingController();
  Student? _selectedStudent;

  // Session & Month Range
  String? _selectedAcademicYear;
  String? _fromMonth;
  String? _toMonth;

  // Selected Dues & Payment Calculations
  final Set<String> _selectedLedgerIds = {};
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  PaymentMethod _selectedMethod = PaymentMethod.cash;

  bool _isProcessing = false;
  bool _manuallyEditedPaidAmount = false;

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _dateFormat = DateFormat('dd MMM yyyy');

  final List<String> _monthNames = const [
    'April', 'May', 'June', 'July', 'August', 'September',
    'October', 'November', 'December', 'January', 'February', 'March'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _studentSearchController.dispose();
    _paidAmountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int _monthIndex(String? label) {
    if (label == null) return -1;
    final lower = label.toLowerCase();
    for (int i = 0; i < _monthNames.length; i++) {
      if (lower.contains(_monthNames[i].toLowerCase().substring(0, 3))) {
        return i;
      }
    }
    return -1;
  }

  void _applyMonthRange(List<StudentFeeLedger> unpaidLedgers) {
    if (_fromMonth == null || _toMonth == null) return;
    final fromIdx = _monthIndex(_fromMonth);
    final toIdx = _monthIndex(_toMonth);
    if (fromIdx == -1 || toIdx == -1) return;

    final minIdx = fromIdx <= toIdx ? fromIdx : toIdx;
    final maxIdx = fromIdx <= toIdx ? toIdx : fromIdx;

    _selectedLedgerIds.clear();
    for (final l in unpaidLedgers) {
      final idx = _monthIndex(l.monthLabel);
      if (idx != -1 && idx >= minIdx && idx <= maxIdx) {
        _selectedLedgerIds.add(l.id);
      }
      // Also automatically include transport fees that fall in this period or have no month label
      final isTransport = l.feeHeadId == 'fh-transport' || (l.feeHeadName?.toLowerCase().contains('transport') ?? false);
      if (isTransport) {
        if (idx == -1 || (idx >= minIdx && idx <= maxIdx)) {
          _selectedLedgerIds.add(l.id);
        }
      }
    }

    _updateCalculations(unpaidLedgers);
  }

  void _updateCalculations(List<StudentFeeLedger> unpaidLedgers) {
    double totalDue = 0.0;
    for (final id in _selectedLedgerIds) {
      final match = unpaidLedgers.where((l) => l.id == id);
      if (match.isNotEmpty) {
        totalDue += match.first.remainingAmount;
      }
    }

    if (!_manuallyEditedPaidAmount) {
      _paidAmountController.text = totalDue > 0 ? totalDue.toStringAsFixed(0) : '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(academicYearsProvider);
    final currentYear = ref.watch(currentAcademicYearProvider).value?.name;
    final yearList = yearsAsync.value?.map((y) => y.name).toList() ?? ['2024-2025', '2025-2026'];

    if (_selectedAcademicYear == null || !_selectedAcademicYear!.contains('-')) {
      _selectedAcademicYear = currentYear ?? (yearList.isNotEmpty ? yearList.first : '2024-2025');
    }

    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
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
                      'Fee Collection Counter',
                      style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lookup student by ID, select month range, verify due fees, and record payment with flexible rollover dues.',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                // Session Switcher
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 16, color: AppTheme.primaryPurple),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: yearList.contains(_selectedAcademicYear) ? _selectedAcademicYear : null,
                        underline: const SizedBox(),
                        isDense: true,
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        items: yearList.map((y) => DropdownMenuItem(value: y, child: Text('Session $y'))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedAcademicYear = val;
                              _selectedLedgerIds.clear();
                              _manuallyEditedPaidAmount = false;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

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
                Tab(text: 'Fee Collection Form'),
                Tab(text: 'Invoices & Payment Records'),
                Tab(text: 'Batch Fee Invoicing'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCollectionFormTab(),
                _buildInvoicesRecordTab(),
                _buildBatchInvoicingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 1: FORM-BASED FEE COLLECTION
  // ============================================================================

  void _selectStudent(Student student, String activeYear) {
    setState(() {
      _selectedStudent = student;
      _selectedLedgerIds.clear();
      _manuallyEditedPaidAmount = false;
      _fromMonth = null;
      _toMonth = null;
    });

    // Background sync ledgers & transport
    Future.microtask(() async {
      try {
        final dbService = ref.read(databaseServiceProvider);
        await dbService.generateLedgerForStudent(student.id, student.gradeLevel, activeYear);
        await dbService.ensureStudentTransportMonthlyLedgers(student.id, activeYear);
        ref.invalidate(studentFeeLedgerProvider);
        ref.invalidate(studentTransportProvider);
      } catch (e) {
        debugPrint('Error syncing student ledgers: $e');
      }
    });
  }

  Widget _buildCollectionFormTab() {
    final studentsAsync = ref.watch(studentsListProvider);
    final activeYear = _selectedAcademicYear ?? '2024-2025';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. STUDENT LOOKUP SECTION ──
              _buildCardContainer(
                title: '1. Select Student (Search by ID, Name, or Roll No)',
                icon: Icons.person_search_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    studentsAsync.when(
                      data: (students) {
                        return Autocomplete<Student>(
                          displayStringForOption: (s) => '${s.name} (${s.gradeLevel} - Roll: ${s.rollNumber ?? "N/A"}) [ID: ${s.id.substring(0, 8)}]',
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) return const Iterable<Student>.empty();
                            final q = textEditingValue.text.toLowerCase().trim();
                            return students.where((s) {
                              return s.name.toLowerCase().contains(q) ||
                                  (s.rollNumber != null && s.rollNumber!.toLowerCase().contains(q)) ||
                                  (s.guardianPhone != null && s.guardianPhone!.contains(q)) ||
                                  s.id.toLowerCase().contains(q) ||
                                  s.gradeLevel.toLowerCase().contains(q);
                            });
                          },
                          onSelected: (student) => _selectStudent(student, activeYear),
                          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onEditingComplete: onEditingComplete,
                              onSubmitted: (val) {
                                final q = val.trim().toLowerCase();
                                if (q.isNotEmpty) {
                                  final matches = students.where((s) =>
                                    s.name.toLowerCase().contains(q) ||
                                    (s.rollNumber != null && s.rollNumber!.toLowerCase().contains(q)) ||
                                    s.id.toLowerCase().contains(q)
                                  ).toList();
                                  if (matches.isNotEmpty) {
                                    _selectStudent(matches.first, activeYear);
                                    controller.text = matches.first.name;
                                  }
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Type Student Name, Admission Roll No, or ID and press Enter...',
                                hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
                                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryPurple),
                                suffixIcon: _selectedStudent != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () {
                                          controller.clear();
                                          setState(() {
                                            _selectedStudent = null;
                                            _selectedLedgerIds.clear();
                                            _manuallyEditedPaidAmount = false;
                                          });
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: AppTheme.bgSurface,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.divider)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 1.5)),
                              ),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 8,
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 280, maxWidth: 650),
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                                    itemBuilder: (context, i) {
                                      final s = options.elementAt(i);
                                      return ListTile(
                                        dense: true,
                                        leading: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: AppTheme.primaryPurple,
                                          child: Text(
                                            s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                        title: Text(s.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                        subtitle: Text('Class: ${s.gradeLevel} ${s.section ?? ""} • Roll: ${s.rollNumber ?? "N/A"} • ID: ${s.id.substring(0, 8)}',
                                            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textHint),
                                        onTap: () => onSelected(s),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error loading students: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
                    ),

                    // Student Details Badge
                    if (_selectedStudent != null) ...[
                      const SizedBox(height: 16),
                      _buildSelectedStudentBadge(_selectedStudent!, activeYear),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_selectedStudent == null) ...[
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.badge_rounded, size: 48, color: AppTheme.primaryPurple.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text('Search and select a student above to load their due fees.',
                            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // ── 2. DUES & MONTH RANGE SECTION ──
                _buildDuesAndPaymentSection(_selectedStudent!, activeYear),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedStudentBadge(Student student, String academicYear) {
    final transportParam = StudentYearParam(studentId: student.id, academicYear: academicYear);
    final transportAsync = ref.watch(studentTransportProvider(transportParam));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primaryPurple,
            child: Text(
              student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(student.name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Class: ${student.gradeLevel} ${student.section ?? ""}',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Roll No: ${student.rollNumber ?? "N/A"}  •  Guardian Phone: ${student.guardianPhone ?? "N/A"}  •  ID: ${student.id.substring(0, 8)}',
                  style: GoogleFonts.poppins(fontSize: 11.5, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                // Transport Assignment Indicator
                transportAsync.when(
                  data: (st) {
                    if (st != null && st.isActive) {
                      return Row(
                        children: [
                          const Icon(Icons.directions_bus_rounded, size: 14, color: AppTheme.success),
                          const SizedBox(width: 6),
                          Text(
                            'Transport Assigned: ${st.routeName ?? "Route"} • Stop: ${st.stopName ?? "Stop"} (${_currencyFormat.format(st.monthlyFee)}/month)',
                            style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.success),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        const Icon(Icons.directions_walk_rounded, size: 14, color: AppTheme.textHint),
                        const SizedBox(width: 6),
                        Text('No Transport Assigned (Standard Tuition & Academic Fees Only)',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          // Total Student Balance Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('TOTAL OUTSTANDING', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textHint)),
                const SizedBox(height: 2),
                Text(
                  _currencyFormat.format(student.currentBalance),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: student.currentBalance > 0 ? AppTheme.error : AppTheme.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuesAndPaymentSection(Student student, String academicYear) {
    final ledgerParam = StudentYearParam(studentId: student.id, academicYear: academicYear);
    final ledgerAsync = ref.watch(studentFeeLedgerProvider(ledgerParam));

    return ledgerAsync.when(
      data: (allLedgers) {
        if (allLedgers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_rounded, color: AppTheme.primaryPurple.withValues(alpha: 0.5), size: 48),
                  const SizedBox(height: 12),
                  Text('No Fee Records Found for $academicYear',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Fee dues have not been initialized for this student yet.',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final dbService = ref.read(databaseServiceProvider);
                      await dbService.generateLedgerForStudent(student.id, student.gradeLevel, academicYear);
                      await dbService.ensureStudentTransportMonthlyLedgers(student.id, academicYear);
                      ref.invalidate(studentFeeLedgerProvider);
                      ref.invalidate(studentTransportProvider);
                    },
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: Text('Generate Fee Dues for $academicYear', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final unpaid = allLedgers.where((l) => l.status != LedgerStatus.paid && l.remainingAmount > 0.01).toList();

        if (unpaid.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 48),
                  const SizedBox(height: 12),
                  Text('All fees for session $academicYear are completely paid!',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.success)),
                  const SizedBox(height: 4),
                  Text('This student has no pending fee obligations.', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          );
        }

        // Distinct available months with pending fees
        final monthlyLedgers = unpaid.where((l) => _monthIndex(l.monthLabel) != -1).toList();
        monthlyLedgers.sort((a, b) => _monthIndex(a.monthLabel).compareTo(_monthIndex(b.monthLabel)));

        final availableMonths = <String>[];
        for (final l in monthlyLedgers) {
          if (l.monthLabel != null && !availableMonths.contains(l.monthLabel!)) {
            availableMonths.add(l.monthLabel!);
          }
        }

        // Set default month range
        if (_fromMonth == null && availableMonths.isNotEmpty) {
          _fromMonth = availableMonths.first;
        }
        if (_toMonth == null && availableMonths.isNotEmpty) {
          _toMonth = availableMonths.first;
        }

        // Auto-select initial range if empty
        if (_selectedLedgerIds.isEmpty && availableMonths.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _applyMonthRange(unpaid));
            }
          });
        }

        // Calculations
        final selectedItems = unpaid.where((l) => _selectedLedgerIds.contains(l.id)).toList();
        final double totalSelectedDue = selectedItems.fold(0.0, (sum, l) => sum + l.remainingAmount);

        final double enteredPaidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;
        final double remainingRollover = (totalSelectedDue - enteredPaidAmount).clamp(0.0, double.infinity);
        final nonMonthly = unpaid.where((l) => _monthIndex(l.monthLabel) == -1).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 2. MONTH RANGE SELECTOR BOX ──
            _buildCardContainer(
              title: '2. Select Month Range (From — To)',
              icon: Icons.date_range_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // FROM MONTH
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('From: ', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                            DropdownButton<String>(
                              value: availableMonths.contains(_fromMonth) ? _fromMonth : (availableMonths.isNotEmpty ? availableMonths.first : null),
                              underline: const SizedBox(),
                              isDense: true,
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              items: availableMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _fromMonth = val;
                                    _manuallyEditedPaidAmount = false;
                                    _applyMonthRange(unpaid);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      const Icon(Icons.arrow_forward_rounded, size: 18, color: AppTheme.primaryPurple),

                      // TO MONTH
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('To: ', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                            DropdownButton<String>(
                              value: availableMonths.contains(_toMonth) ? _toMonth : (availableMonths.isNotEmpty ? availableMonths.last : null),
                              underline: const SizedBox(),
                              isDense: true,
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              items: availableMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _toMonth = val;
                                    _manuallyEditedPaidAmount = false;
                                    _applyMonthRange(unpaid);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      // Quick Shortcuts
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _fromMonth = availableMonths.first;
                            _toMonth = availableMonths.first;
                            _manuallyEditedPaidAmount = false;
                            _applyMonthRange(unpaid);
                          });
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryPurple),
                        child: const Text('Single Month'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _fromMonth = availableMonths.first;
                            _toMonth = availableMonths.length >= 3 ? availableMonths[2] : availableMonths.last;
                            _manuallyEditedPaidAmount = false;
                            _applyMonthRange(unpaid);
                          });
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryPurple),
                        child: const Text('Quarter (3 Months)'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _fromMonth = availableMonths.first;
                            _toMonth = availableMonths.length >= 6 ? availableMonths[5] : availableMonths.last;
                            _manuallyEditedPaidAmount = false;
                            _applyMonthRange(unpaid);
                          });
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryPurple),
                        child: const Text('Half-Year (6 Months)'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _fromMonth = availableMonths.first;
                            _toMonth = availableMonths.last;
                            _manuallyEditedPaidAmount = false;
                            _applyMonthRange(unpaid);
                          });
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                        child: Text('All Months (${availableMonths.length})'),
                      ),
                    ],
                  ),

                  // Non-Monthly Dues Chips (Exam Fee, Annual Charges, etc.)
                  if (nonMonthly.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppTheme.divider),
                    const SizedBox(height: 12),
                    Text('Include Other Term / Annual Fees:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: nonMonthly.map((l) {
                        final isSelected = _selectedLedgerIds.contains(l.id);
                        return FilterChip(
                          selected: isSelected,
                          label: Text('${l.feeHeadName ?? "Fee"}: ${_currencyFormat.format(l.remainingAmount)}'),
                          labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                          selectedColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedLedgerIds.add(l.id);
                              } else {
                                _selectedLedgerIds.remove(l.id);
                              }
                              _updateCalculations(unpaid);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 3. ITEMIZED DUES BREAKDOWN TABLE ──
            _buildCardContainer(
              title: '3. Due Fees Breakdown for Selected Period (${selectedItems.length} items)',
              icon: Icons.receipt_long_rounded,
              child: selectedItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('No fee items selected for this range. Please adjust month range above.',
                            style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                            color: AppTheme.bgSurface,
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                          ),
                          child: Row(
                            children: [
                              _th('Fee Head / Description', flex: 4),
                              _th('Month / Term', flex: 3),
                              _th('Due Date', flex: 2),
                              _th('Total Obligation', flex: 2),
                              _th('Paid So Far', flex: 2),
                              _th('Net Due', flex: 2),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: AppTheme.divider),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: selectedItems.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                          itemBuilder: (context, idx) {
                            final item = selectedItems[idx];
                            final isTransport = item.feeHeadId == 'fh-transport' || (item.feeHeadName?.toLowerCase().contains('transport') ?? false);

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Row(
                                      children: [
                                        Icon(
                                          isTransport ? Icons.directions_bus_rounded : Icons.school_rounded,
                                          size: 16,
                                          color: isTransport ? AppTheme.warning : AppTheme.primaryPurple,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          item.feeHeadName ?? 'Fee Item',
                                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(item.monthLabel ?? 'Annual/One-Time', style: GoogleFonts.poppins(fontSize: 12)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(_dateFormat.format(item.dueDate), style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(_currencyFormat.format(item.amountDue), style: GoogleFonts.poppins(fontSize: 12)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(_currencyFormat.format(item.amountPaid), style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      _currencyFormat.format(item.remainingAmount),
                                      style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.error),
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
            const SizedBox(height: 24),

            // ── 4. PAYMENT FORM & ROLLOVER HANDLING ──
            _buildCardContainer(
              title: '4. Payment Form & Partial Settlement',
              icon: Icons.payments_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total Due Display Box
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TOTAL AMOUNT DUE', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                              const SizedBox(height: 4),
                              Text(
                                _currencyFormat.format(totalSelectedDue),
                                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                              Text('${selectedItems.length} selected item(s)', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Editable Paid Amount Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PAID AMOUNT (₹) *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _paidAmountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                prefixStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                                hintText: 'Enter amount paid...',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 1.5)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 2)),
                              ),
                              onChanged: (_) {
                                setState(() {
                                  _manuallyEditedPaidAmount = true;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rollover / Balance Status Box
                  if (enteredPaidAmount < totalSelectedDue) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_rounded, color: Color(0xFFD97706), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PARTIAL PAYMENT DETECTED: ${_currencyFormat.format(remainingRollover)} WILL ROLL OVER',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'The remaining ₹${remainingRollover.toStringAsFixed(0)} will carry forward to the next month and stay active on the student ledger until the end of the session.',
                                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFB45309)),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _paidAmountController.text = totalSelectedDue.toStringAsFixed(0);
                                _manuallyEditedPaidAmount = false;
                              });
                            },
                            child: const Text('Pay Full Amount'),
                          ),
                        ],
                      ),
                    ),
                  ] else if (enteredPaidAmount == totalSelectedDue && totalSelectedDue > 0) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.successLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
                          const SizedBox(width: 10),
                          Text('Full Settlement: All selected fee items will be completely cleared.',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF166534))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Payment Method, Reference & Notes
                  Row(
                    children: [
                      // Method
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Payment Method *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<PaymentMethod>(
                              value: _selectedMethod,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: PaymentMethod.values.map((m) {
                                return DropdownMenuItem(value: m, child: Text(m.displayName, style: GoogleFonts.poppins(fontSize: 12)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedMethod = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Reference / Cheque No
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cheque / UPI / Ref Number', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _referenceController,
                              decoration: InputDecoration(
                                hintText: 'Optional transaction or cheque no.',
                                hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedStudent = null;
                            _selectedLedgerIds.clear();
                            _paidAmountController.clear();
                            _referenceController.clear();
                            _notesController.clear();
                            _manuallyEditedPaidAmount = false;
                          });
                        },
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                        child: Text('Clear Form', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isProcessing || selectedItems.isEmpty || enteredPaidAmount <= 0
                            ? null
                            : () => _handleProcessPayment(student, academicYear, selectedItems, enteredPaidAmount),
                        icon: _isProcessing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.print_rounded, size: 18),
                        label: Text(
                          _isProcessing ? 'Processing...' : 'Collect Fee & Print Receipt',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple, strokeWidth: 2)),
      ),
      error: (e, _) => Text('Error loading fee ledger: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
    );
  }

  Future<void> _handleProcessPayment(
    Student student,
    String academicYear,
    List<StudentFeeLedger> selectedLedgers,
    double paidAmount,
  ) async {
    final licenseState = ref.read(licenseStateProvider).value;
    if (licenseState?.status.isReadOnly ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Action blocked: Eduvia is currently in Read-Only mode due to license status.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    final dbService = ref.read(databaseServiceProvider);

    try {
      final updatedLedgers = await dbService.recordMultiMonthPayment(
        studentId: student.id,
        academicYear: academicYear,
        ledgerIds: selectedLedgers.map((l) => l.id).toList(),
        paymentMethod: _selectedMethod,
        paidAmount: paidAmount,
        referenceNumber: _referenceController.text.trim().isNotEmpty ? _referenceController.text.trim() : null,
      );

      final receiptNumber = await dbService.getNextReceiptNumber();

      // Invalidate providers
      ref.invalidate(studentsListProvider);
      ref.invalidate(studentFeeLedgerProvider);
      ref.invalidate(invoicesListProvider);
      ref.invalidate(dashboardMetricsProvider);

      if (mounted) {
        await PaymentReceiptDialog.show(
          context: context,
          student: student,
          paidLedgers: updatedLedgers,
          totalAmount: paidAmount,
          paymentMethod: _selectedMethod,
          referenceNumber: _referenceController.text.trim().isNotEmpty ? _referenceController.text.trim() : null,
          academicYear: academicYear,
          receiptNumber: receiptNumber,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ${_currencyFormat.format(paidAmount)} recorded successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );

        // Reset inputs
        setState(() {
          _paidAmountController.clear();
          _referenceController.clear();
          _notesController.clear();
          _selectedLedgerIds.clear();
          _manuallyEditedPaidAmount = false;
        });
      }
    } catch (e, stack) {
      AppLogger.instance.error('Payment processing failed', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ============================================================================
  // TAB 2: INVOICE & RECEIPT RECORDS
  // ============================================================================

  Widget _buildInvoicesRecordTab() {
    final invoicesAsync = ref.watch(invoicesListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: invoicesAsync.when(
            data: (invoices) {
              if (invoices.isEmpty) {
                return _buildEmptyCard('No fee invoices or receipts recorded yet.');
              }

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
                          _th('Invoice ID', flex: 3),
                          _th('Date', flex: 3),
                          _th('Description / Notes', flex: 4),
                          _th('Amount Paid', flex: 2),
                          _th('Status', flex: 2),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.divider),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: invoices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                      itemBuilder: (context, idx) {
                        final inv = invoices[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text('INV-${inv.id.substring(0, 8).toUpperCase()}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(_dateFormat.format(inv.createdAt), style: GoogleFonts.poppins(fontSize: 12)),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(inv.notes ?? 'Fee Collection', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(_currencyFormat.format(inv.totalAmount), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.success)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('PAID', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.success)),
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
            error: (e, _) => Text('Error loading invoices: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 3: BATCH INVOICING
  // ============================================================================

  Widget _buildBatchInvoicingTab() {
    String selectedGrade = 'All Grades';
    final amountController = TextEditingController(text: '1500');
    final titleController = TextEditingController(text: 'Monthly Tuition & Facility Fee');

    final grades = [
      'All Grades', 'Nursery', 'LKG', 'UKG',
      'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5',
      'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _buildCardContainer(
            title: 'Batch Fee Invoice Generator',
            icon: Icons.library_add_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generate bulk invoices for all students in a grade or entire school at once.',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedGrade,
                  decoration: const InputDecoration(labelText: 'Target Grade / Class', border: OutlineInputBorder()),
                  items: grades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) {
                    if (val != null) selectedGrade = val;
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Invoice Title / Description', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Base Amount (₹)', prefixText: '₹ ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final amt = double.tryParse(amountController.text);
                      if (amt == null || amt <= 0) return;

                      final dbService = ref.read(databaseServiceProvider);
                      final count = await BulkInvoiceService(dbService: dbService).generateBulkInvoicesForGrade(
                        gradeLevel: selectedGrade,
                        feeTitle: titleController.text.trim(),
                        feeAmount: amt,
                        dueDate: DateTime.now().add(const Duration(days: 15)),
                      );

                      ref.invalidate(invoicesListProvider);
                      ref.invalidate(dashboardMetricsProvider);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Successfully generated $count invoices!'), backgroundColor: AppTheme.primaryPurple),
                        );
                      }
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text('Generate Invoices Now', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // UI HELPERS
  // ============================================================================

  Widget _buildCardContainer({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryPurple),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
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
}
