import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final TextEditingController _invoiceSearchController = TextEditingController();
  Student? _selectedStudent;

  // Rapid Express Counter State & Controllers
  final TextEditingController _rapidSearchController = TextEditingController();
  late final FocusNode _rapidSearchFocusNode;
  int _rapidHighlightedSuggestionIndex = 0;
  int _rapidSuggestionsCount = 0;
  final TextEditingController _rapidPaidAmountController = TextEditingController();
  final FocusNode _rapidPaidFocusNode = FocusNode();
  final TextEditingController _rapidTenderedController = TextEditingController();
  final FocusNode _rapidTenderedFocusNode = FocusNode();
  final TextEditingController _rapidReferenceController = TextEditingController();
  PaymentMethod _rapidPaymentMethod = PaymentMethod.cash;
  Student? _rapidStudent;
  List<StudentFeeLedger> _rapidStudentDues = [];
  final Set<String> _rapidSelectedLedgerIds = {};
  bool _rapidIsProcessing = false;
  String? _rapidFromMonth;
  String? _rapidToMonth;
  bool _rapidIncludeOneTimeDues = true;

  // Last receipt tracker for quick re-print & WhatsApp
  String? _lastReceiptNumber;
  Student? _lastReceiptStudent;
  double? _lastReceiptAmount;
  PaymentMethod? _lastReceiptMethod;
  List<StudentFeeLedger>? _lastReceiptLedgers;
  String? _lastReceiptReference;
  String? _lastReceiptPeriod;

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
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);

    _rapidSearchFocusNode = FocusNode(
      debugLabel: 'RapidSearchFocusNode',
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (_rapidSuggestionsCount > 0) {
              setState(() {
                _rapidHighlightedSuggestionIndex =
                    (_rapidHighlightedSuggestionIndex + 1) % _rapidSuggestionsCount;
              });
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (_rapidSuggestionsCount > 0) {
              setState(() {
                _rapidHighlightedSuggestionIndex =
                    (_rapidHighlightedSuggestionIndex - 1 + _rapidSuggestionsCount) % _rapidSuggestionsCount;
              });
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusRapidSearch();
    });
  }

  void _handleTabChange() {
    if (_tabController.index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusRapidSearch();
      });
    }
  }

  void _focusRapidSearch() {
    if (mounted && _rapidSearchFocusNode.canRequestFocus) {
      _rapidSearchFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _studentSearchController.dispose();
    _invoiceSearchController.dispose();
    _paidAmountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    _rapidSearchController.dispose();
    _rapidSearchFocusNode.dispose();
    _rapidPaidAmountController.dispose();
    _rapidPaidFocusNode.dispose();
    _rapidTenderedController.dispose();
    _rapidTenderedFocusNode.dispose();
    _rapidReferenceController.dispose();
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
    final yearList = yearsAsync.value?.map((y) => y.name).toList() ?? ['2026-2027'];

    if (_selectedAcademicYear == null || !_selectedAcademicYear!.contains('-')) {
      _selectedAcademicYear = currentYear ?? (yearList.isNotEmpty ? yearList.first : '2026-2027');
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
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 18, color: Colors.amber),
                      SizedBox(width: 6),
                      Text('Rapid Express Counter'),
                    ],
                  ),
                ),
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
                _buildRapidCounterTab(),
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

  void _rapidPreset1Month() {
    final available = _getRapidAvailableMonths();
    if (available.isNotEmpty) {
      setState(() {
        _rapidFromMonth = available.first;
        _rapidToMonth = available.first;
        _applyRapidMonthRange();
      });
    }
  }

  void _rapidPresetQuarter() {
    final available = _getRapidAvailableMonths();
    if (available.isNotEmpty) {
      setState(() {
        _rapidFromMonth = available.first;
        _rapidToMonth = available.length >= 3 ? available[2] : available.last;
        _applyRapidMonthRange();
      });
    }
  }

  void _rapidPresetHalfYear() {
    final available = _getRapidAvailableMonths();
    if (available.isNotEmpty) {
      setState(() {
        _rapidFromMonth = available.first;
        _rapidToMonth = available.length >= 6 ? available[5] : available.last;
        _applyRapidMonthRange();
      });
    }
  }

  void _rapidPresetAllMonths() {
    final available = _getRapidAvailableMonths();
    if (available.isNotEmpty) {
      setState(() {
        _rapidFromMonth = available.first;
        _rapidToMonth = available.last;
        _applyRapidMonthRange();
      });
    }
  }

  void _rapidToggleAnnualFees() {
    setState(() {
      _rapidIncludeOneTimeDues = !_rapidIncludeOneTimeDues;
      _applyRapidMonthRange();
    });
  }

  // ============================================================================
  // TAB 0: RAPID EXPRESS FEE COUNTER (HIGH-SPEED KEYBOARD WORKFLOW)
  // ============================================================================

  Widget _buildRapidCounterTab() {
    final studentsAsync = ref.watch(studentsListProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final allStudents = studentsAsync.value ?? <Student>[];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _resetRapidCounter,
        const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () => _setRapidPaymentMethod(PaymentMethod.cash),
        const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () => _setRapidPaymentMethod(PaymentMethod.online),
        const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () => _setRapidPaymentMethod(PaymentMethod.cheque),
        const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () => _setRapidPaymentMethod(PaymentMethod.bankTransfer),
        const SingleActivator(LogicalKeyboardKey.f1): _rapidPreset1Month,
        const SingleActivator(LogicalKeyboardKey.f2): _shareLastReceiptWhatsApp,
        const SingleActivator(LogicalKeyboardKey.f3): _rapidPresetQuarter,
        const SingleActivator(LogicalKeyboardKey.f4): _rapidPresetHalfYear,
        const SingleActivator(LogicalKeyboardKey.f5): _rapidPresetAllMonths,
        const SingleActivator(LogicalKeyboardKey.keyA, alt: true): _rapidToggleAnnualFees,
        const SingleActivator(LogicalKeyboardKey.f9): _executeRapidPayment,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _executeRapidPayment,
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): _reprintLastReceipt,
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildRapidCounterHeader(metricsAsync),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Search, Student Snapshot, Payment Mode
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildRapidSearchCard(allStudents),
                          const SizedBox(height: 12),
                          _buildRapidStudentCard(),
                          const SizedBox(height: 12),
                          _buildRapidPaymentMethodCard(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Right Column: Outstanding Dues & Tendered / Change Checkout
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildRapidDuesCard(),
                          const SizedBox(height: 12),
                          _buildRapidCheckoutCard(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRapidKeyboardHintsFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRapidCounterHeader(AsyncValue<DashboardMetrics> metricsAsync) {
    final metrics = metricsAsync.value;
    final todaysColl = metrics?.todaysCollections ?? 0.0;
    final todaysCount = metrics?.todaysTransactionCount ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryPurple, Color(0xFF6C5CE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bolt_rounded, size: 28, color: Colors.amberAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'RAPID EXPRESS FEE COUNTER',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '10-Sec POS Mode',
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Scan/Enter roll or admission number ➔ Verify dues ➔ Hit [Enter] to collect & issue dual 2-in-1 A4 receipt.',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Today's Counter Tally
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'TODAY COLLECTED',
                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.5),
                ),
                Text(
                  _currencyFormat.format(todaysColl),
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  '$todaysCount receipts issued',
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.white60),
                ),
              ],
            ),
          ),
          if (_lastReceiptNumber != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LAST RECEIPT', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                      Text(_lastReceiptNumber!, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.print_rounded, size: 18, color: AppTheme.primaryPurple),
                    tooltip: 'Reprint Last Receipt',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: _reprintLastReceipt,
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF25D366)),
                    tooltip: 'Share on WhatsApp',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: _shareLastReceiptWhatsApp,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRapidSearchCard(List<Student> allStudents) {
    final query = _rapidSearchController.text.trim().toLowerCase();
    final suggestions = query.isNotEmpty && _rapidStudent == null
        ? allStudents.where((s) {
            final adm = s.admissionNumber?.toLowerCase() ?? '';
            final roll = s.rollNumber?.toLowerCase() ?? '';
            final name = s.name.toLowerCase();
            return adm.contains(query) || roll.contains(query) || name.contains(query);
          }).take(4).toList()
        : <Student>[];
    _rapidSuggestionsCount = suggestions.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _rapidStudent != null ? AppTheme.success.withValues(alpha: 0.5) : AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1. QUICK LOOKUP / SCAN',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple, letterSpacing: 0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(6)),
                child: Text('Press [Enter] to Lock', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _rapidSearchController,
            focusNode: _rapidSearchFocusNode,
            autofocus: true,
            onChanged: (_) => setState(() {
              _rapidHighlightedSuggestionIndex = 0;
            }),
            onSubmitted: (val) => _handleRapidSearchSubmit(val, allStudents, suggestions),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.flash_on_rounded, color: Colors.amber[700]),
              suffixIcon: _rapidSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _rapidSearchController.clear();
                        setState(() {
                          _rapidHighlightedSuggestionIndex = 0;
                        });
                      },
                    )
                  : null,
              hintText: 'Type Roll No, Adm No, or Student Name...',
              hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
              filled: true,
              fillColor: AppTheme.bgSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          // Suggestions dropdown list with keyboard navigation
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                    itemBuilder: (context, idx) {
                      final s = suggestions[idx];
                      final isHighlighted = idx == _rapidHighlightedSuggestionIndex;

                      return InkWell(
                        onTap: () => _selectRapidStudent(s),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          color: isHighlighted ? AppTheme.primaryPurple.withValues(alpha: 0.08) : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: isHighlighted ? AppTheme.primaryPurple : AppTheme.primaryPurple.withValues(alpha: 0.1),
                                child: Text(
                                  s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isHighlighted ? Colors.white : AppTheme.primaryPurple,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Adm: ${s.admissionNumber ?? 'N/A'} • Roll: ${s.rollNumber ?? 'N/A'} • ${s.gradeLevel}',
                                      style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              if (isHighlighted)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryPurple,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Enter',
                                    style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                )
                              else
                                const Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.textHint),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: const BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Use ↑ ↓ to navigate, [Enter] to select', style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.textHint)),
                        Text('${suggestions.length} matches', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRapidStudentCard() {
    if (_rapidStudent == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search_rounded, size: 36, color: AppTheme.textHint.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text('No Student Selected', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              Text(
                'Type roll/adm number above or select from suggestions.',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final s = _rapidStudent!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryPurple,
                child: Text(
                  s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildBadge(s.gradeLevel, AppTheme.primaryPurple.withValues(alpha: 0.1), AppTheme.primaryPurple),
                        if (s.rollNumber != null && s.rollNumber!.isNotEmpty)
                          _buildBadge('Roll: ${s.rollNumber}', Colors.blue.withValues(alpha: 0.1), Colors.blue[800]!),
                        if (s.admissionNumber != null && s.admissionNumber!.isNotEmpty)
                          _buildBadge('Adm: ${s.admissionNumber}', Colors.grey.withValues(alpha: 0.15), AppTheme.textPrimary),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                tooltip: 'Clear Student [Esc]',
                onPressed: _resetRapidCounter,
              ),
            ],
          ),
          const Divider(height: 20, color: AppTheme.divider),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FATHER / GUARDIAN', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                    Text(s.fatherName ?? s.motherName ?? 'Not Specified', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (s.fatherPhone != null || s.guardianPhone != null) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MOBILE NUMBER', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                      Row(
                        children: [
                          const Icon(Icons.phone_android_rounded, size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(s.fatherPhone ?? s.guardianPhone ?? '', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRapidPaymentMethodCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '2. PAYMENT METHOD',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple, letterSpacing: 0.5),
              ),
              Text(
                'Alt + [1-4]',
                style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildModeOption(PaymentMethod.cash, 'Cash', Icons.money_rounded, 'Alt+1'),
              const SizedBox(width: 8),
              _buildModeOption(PaymentMethod.online, 'UPI / QR', Icons.qr_code_scanner_rounded, 'Alt+2'),
              const SizedBox(width: 8),
              _buildModeOption(PaymentMethod.cheque, 'Cheque', Icons.receipt_long_rounded, 'Alt+3'),
              const SizedBox(width: 8),
              _buildModeOption(PaymentMethod.bankTransfer, 'Bank', Icons.account_balance_rounded, 'Alt+4'),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _rapidReferenceController,
            decoration: InputDecoration(
              hintText: 'Reference / Cheque / UTR # (Optional)',
              hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
              isDense: true,
              filled: true,
              fillColor: AppTheme.bgSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
            style: GoogleFonts.poppins(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(PaymentMethod method, String label, IconData icon, String shortcut) {
    final isSelected = _rapidPaymentMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () => _setRapidPaymentMethod(method),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryPurple : AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppTheme.primaryPurple : AppTheme.divider),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : AppTheme.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                shortcut,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: isSelected ? Colors.white70 : AppTheme.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setRapidPaymentMethod(PaymentMethod method) {
    setState(() => _rapidPaymentMethod = method);
    if (_rapidStudent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (method == PaymentMethod.cash) {
          if (_rapidTenderedFocusNode.canRequestFocus) {
            _rapidTenderedFocusNode.requestFocus();
          }
        } else {
          if (_rapidPaidFocusNode.canRequestFocus) {
            _rapidPaidFocusNode.requestFocus();
          }
        }
      });
    }
  }

  Widget _buildRapidDuesCard() {
    final availableMonths = _getRapidAvailableMonths();
    final nonMonthlyCount = _rapidStudentDues.where((l) => _monthIndex(l.monthLabel) == -1).length;
    final selectedDues = _rapidStudentDues.where((l) => _rapidSelectedLedgerIds.contains(l.id)).toList();
    final double totalSelectedDue = selectedDues.fold(0.0, (sum, l) => sum + l.remainingAmount);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '3. OUTSTANDING DUES & BREAKDOWN',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple, letterSpacing: 0.5),
              ),
              if (_rapidStudentDues.isNotEmpty)
                Text(
                  '${selectedDues.length} fees selected • Total: ${_currencyFormat.format(totalSelectedDue)}',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_rapidStudent == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_outlined, size: 36, color: AppTheme.textHint.withValues(alpha: 0.4)),
                    const SizedBox(height: 8),
                    Text('No dues loaded', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    Text('Scan/Type student roll or admission number above.', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
                  ],
                ),
              ),
            )
          else if (_rapidStudentDues.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('All Fees Fully Cleared!', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.success)),
                        Text('There are no outstanding fee dues for this student in $_selectedAcademicYear.', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Period / Month Range Selector Bar (NO CHECKMARKS)
            if (availableMonths.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // FROM MONTH
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('From: ', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                          DropdownButton<String>(
                            value: availableMonths.contains(_rapidFromMonth) ? _rapidFromMonth : availableMonths.first,
                            underline: const SizedBox(),
                            isDense: true,
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            items: availableMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _rapidFromMonth = val;
                                  if (_monthIndex(_rapidToMonth) < _monthIndex(val)) {
                                    _rapidToMonth = val;
                                  }
                                  _applyRapidMonthRange();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.primaryPurple),
                    // TO MONTH
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('To: ', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                          DropdownButton<String>(
                            value: availableMonths.contains(_rapidToMonth) ? _rapidToMonth : availableMonths.last,
                            underline: const SizedBox(),
                            isDense: true,
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            items: availableMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _rapidToMonth = val;
                                  if (_monthIndex(_rapidFromMonth) > _monthIndex(val)) {
                                    _rapidFromMonth = val;
                                  }
                                  _applyRapidMonthRange();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    // PRESET CHIPS WITH SHORTCUT BADGES
                    _buildRapidMonthPresetChip(
                      shortcut: 'F1',
                      label: '1 Mo',
                      onTap: _rapidPreset1Month,
                    ),
                    _buildRapidMonthPresetChip(
                      shortcut: 'F3',
                      label: '3 Mo (Qtr)',
                      onTap: _rapidPresetQuarter,
                    ),
                    _buildRapidMonthPresetChip(
                      shortcut: 'F4',
                      label: '6 Mo (Half)',
                      onTap: _rapidPresetHalfYear,
                    ),
                    _buildRapidMonthPresetChip(
                      shortcut: 'F5',
                      label: 'All (${availableMonths.length})',
                      isHighlight: true,
                      onTap: _rapidPresetAllMonths,
                    ),
                    if (nonMonthlyCount > 0)
                      InkWell(
                        onTap: _rapidToggleAnnualFees,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _rapidIncludeOneTimeDues ? AppTheme.primaryPurple.withValues(alpha: 0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _rapidIncludeOneTimeDues ? AppTheme.primaryPurple : AppTheme.divider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _rapidIncludeOneTimeDues ? AppTheme.primaryPurple.withValues(alpha: 0.2) : AppTheme.bgSurface,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  'Alt+A',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: _rapidIncludeOneTimeDues ? AppTheme.primaryPurple : AppTheme.textHint,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Annual Fees: ${_rapidIncludeOneTimeDues ? "ON" : "OFF"}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _rapidIncludeOneTimeDues ? AppTheme.primaryPurple : AppTheme.textSecondary,
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
            // Professional Financial Ledger Table (NO CHECKMARKS, BOUNDED HEIGHT)
            Container(
              constraints: const BoxConstraints(maxHeight: 185),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: const BoxDecoration(
                      color: Color(0xFFECEBFA),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text('#', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text('FEE HEAD', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('PERIOD', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('DUE DATE', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('STATUS', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple), textAlign: TextAlign.center),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('AMOUNT', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple), textAlign: TextAlign.end),
                        ),
                      ],
                    ),
                  ),
                  // Table Rows
                  Expanded(
                    child: selectedDues.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No fees in current selection. Press [F1..F5] to select fee months.',
                                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint),
                              ),
                            ),
                          )
                        : Scrollbar(
                            thumbVisibility: true,
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: selectedDues.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                              itemBuilder: (context, idx) {
                                final l = selectedDues[idx];
                                final isOverdue = l.dueDate.isBefore(DateTime.now()) && l.status != LedgerStatus.paid;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 26,
                                        child: Text('${idx + 1}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          l.feeHeadName ?? l.feeHeadId,
                                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          l.monthLabel ?? "Annual",
                                          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          _dateFormat.format(l.dueDate),
                                          style: GoogleFonts.poppins(fontSize: 10, color: isOverdue ? AppTheme.error : AppTheme.textSecondary),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isOverdue ? AppTheme.error.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isOverdue ? 'OVERDUE' : 'DUE',
                                              style: GoogleFonts.poppins(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: isOverdue ? AppTheme.error : Colors.amber[900],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          _currencyFormat.format(l.remainingAmount),
                                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRapidMonthPresetChip({
    required String shortcut,
    required String label,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isHighlight ? AppTheme.primaryPurple : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isHighlight ? AppTheme.primaryPurple : AppTheme.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isHighlight ? Colors.white.withValues(alpha: 0.25) : AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                shortcut,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isHighlight ? Colors.white : AppTheme.primaryPurple,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isHighlight ? Colors.white : AppTheme.primaryPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRapidCheckoutCard() {
    final paid = double.tryParse(_rapidPaidAmountController.text.trim()) ?? 0.0;
    final tendered = double.tryParse(_rapidTenderedController.text.trim()) ?? 0.0;
    final change = (tendered > paid) ? (tendered - paid) : 0.0;
    final isCash = _rapidPaymentMethod == PaymentMethod.cash;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '4. TENDERED & CHANGE CHECKOUT',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AMOUNT TO PAY', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _rapidPaidAmountController,
                      focusNode: _rapidPaidFocusNode,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        if (!isCash || _rapidTenderedController.text.trim().isNotEmpty) {
                          _executeRapidPayment();
                        } else {
                          _rapidTenderedFocusNode.requestFocus();
                        }
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 16),
                        isDense: true,
                        filled: true,
                        fillColor: AppTheme.bgSurface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              if (isCash) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CASH TENDERED (RECEIVED)', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _rapidTenderedController,
                        focusNode: _rapidTenderedFocusNode,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _executeRapidPayment(),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.payments_rounded, size: 16, color: Colors.green),
                          hintText: 'e.g. 2000',
                          hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
                          isDense: true,
                          filled: true,
                          fillColor: AppTheme.bgSurface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green[800]),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Return Change Banner
          if (isCash && change > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.currency_exchange_rounded, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'RETURN CHANGE TO PARENT:',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[800]),
                      ),
                    ],
                  ),
                  Text(
                    _currencyFormat.format(change),
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[900]),
                  ),
                ],
              ),
            )
          else if (isCash && tendered > 0 && tendered < paid)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[400]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.amber[800], size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Short payment: ${_currencyFormat.format(paid - tendered)} balance will remain in student ledger.',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber[900]),
                  ),
                ],
              ),
            ),
          // Primary Instant Action Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: (_rapidStudent == null || paid <= 0 || _rapidIsProcessing)
                  ? null
                  : _executeRapidPayment,
              icon: _rapidIsProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.print_rounded, size: 18),
              label: Text(
                _rapidIsProcessing
                    ? 'Processing Payment...'
                    : '[ENTER] RECORD & ISSUE 2-IN-1 RECEIPT',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRapidKeyboardHintsFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          _buildShortcutPill('Enter', 'Confirm & Pay'),
          _buildShortcutPill('F1', '1 Month'),
          _buildShortcutPill('F3', '3 Mo (Qtr)'),
          _buildShortcutPill('F4', '6 Mo (Half)'),
          _buildShortcutPill('F5', 'All Mo'),
          _buildShortcutPill('Alt+1..4', 'Mode'),
          _buildShortcutPill('Alt+A', 'Annual Fees'),
          _buildShortcutPill('Esc', 'Reset / Next'),
          _buildShortcutPill('F2', 'WhatsApp'),
          _buildShortcutPill('Ctrl+P', 'Reprint'),
        ],
      ),
    );
  }

  Widget _buildShortcutPill(String keyLabel, String desc) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Text(keyLabel, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
        ),
        const SizedBox(width: 6),
        Text(desc, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  Future<void> _handleRapidSearchSubmit(
    String query,
    List<Student> allStudents, [
    List<Student> currentSuggestions = const [],
  ]) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return;

    Student? matched;
    // 1. If suggestions dropdown is visible, select the highlighted item
    if (currentSuggestions.isNotEmpty) {
      final idx = _rapidHighlightedSuggestionIndex.clamp(0, currentSuggestions.length - 1);
      matched = currentSuggestions[idx];
    } else {
      // 2. Exact match on Admission Number
      final exactAdm = allStudents.where((s) => s.admissionNumber?.toLowerCase() == q).toList();
      if (exactAdm.isNotEmpty) {
        matched = exactAdm.first;
      } else {
        // 3. Exact match on Roll Number
        final exactRoll = allStudents.where((s) => s.rollNumber?.toLowerCase() == q).toList();
        if (exactRoll.isNotEmpty) {
          matched = exactRoll.first;
        } else {
          // 4. Partial match on Adm, Roll, or Name
          final matches = allStudents.where((s) {
            final adm = s.admissionNumber?.toLowerCase() ?? '';
            final roll = s.rollNumber?.toLowerCase() ?? '';
            final name = s.name.toLowerCase();
            return adm.contains(q) || roll.contains(q) || name.contains(q);
          }).toList();

          if (matches.isNotEmpty) {
            matched = matches.first;
          }
        }
      }
    }

    if (matched != null) {
      await _selectRapidStudent(matched);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No student found matching "$query"', style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
        _focusRapidSearch();
      }
    }
  }

  List<String> _getRapidAvailableMonths() {
    final months = <String>[];
    for (final l in _rapidStudentDues) {
      if (l.monthLabel != null && !months.contains(l.monthLabel!)) {
        months.add(l.monthLabel!);
      }
    }
    months.sort((a, b) => _monthIndex(a).compareTo(_monthIndex(b)));
    return months;
  }

  void _applyRapidMonthRange() {
    final available = _getRapidAvailableMonths();
    if (available.isEmpty) {
      _rapidSelectedLedgerIds.clear();
      if (_rapidIncludeOneTimeDues) {
        for (final l in _rapidStudentDues) {
          _rapidSelectedLedgerIds.add(l.id);
        }
      }
      _updateRapidCalculations();
      return;
    }

    if (_rapidFromMonth == null || !available.contains(_rapidFromMonth)) {
      _rapidFromMonth = available.first;
    }
    if (_rapidToMonth == null || !available.contains(_rapidToMonth)) {
      _rapidToMonth = available.last;
    }

    final fromIdx = _monthIndex(_rapidFromMonth);
    final toIdx = _monthIndex(_rapidToMonth);
    final minIdx = fromIdx <= toIdx ? fromIdx : toIdx;
    final maxIdx = fromIdx <= toIdx ? toIdx : fromIdx;

    _rapidSelectedLedgerIds.clear();
    for (final l in _rapidStudentDues) {
      final idx = _monthIndex(l.monthLabel);
      if (idx != -1) {
        if (idx >= minIdx && idx <= maxIdx) {
          _rapidSelectedLedgerIds.add(l.id);
        }
      } else {
        if (_rapidIncludeOneTimeDues) {
          _rapidSelectedLedgerIds.add(l.id);
        }
      }
    }

    _updateRapidCalculations();
  }

  Future<void> _selectRapidStudent(Student student) async {
    setState(() {
      _rapidStudent = student;
      _rapidStudentDues = [];
      _rapidSelectedLedgerIds.clear();
      _rapidPaidAmountController.clear();
      _rapidTenderedController.clear();
      _rapidReferenceController.clear();
      _rapidFromMonth = null;
      _rapidToMonth = null;
      _rapidIncludeOneTimeDues = true;
    });

    final dbService = ref.read(databaseServiceProvider);
    final ledgers = await dbService.getStudentFeeLedger(
      student.id,
      _selectedAcademicYear ?? '2026-2027',
    );

    final unpaid = ledgers.where((l) => l.status != LedgerStatus.paid && l.remainingAmount > 0).toList();
    unpaid.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    if (mounted) {
      setState(() {
        _rapidStudentDues = unpaid;
        final available = _getRapidAvailableMonths();
        if (available.isNotEmpty) {
          _rapidFromMonth = available.first;
          _rapidToMonth = available.last;
        }
        _applyRapidMonthRange();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_rapidPaymentMethod == PaymentMethod.cash) {
          if (_rapidTenderedFocusNode.canRequestFocus) {
            _rapidTenderedFocusNode.requestFocus();
          }
        } else {
          if (_rapidPaidFocusNode.canRequestFocus) {
            _rapidPaidFocusNode.requestFocus();
          }
        }
      });
    }
  }

  void _updateRapidCalculations() {
    double total = 0.0;
    for (final l in _rapidStudentDues) {
      if (_rapidSelectedLedgerIds.contains(l.id)) {
        total += l.remainingAmount;
      }
    }
    _rapidPaidAmountController.text = total > 0 ? total.toStringAsFixed(0) : '0';
    setState(() {});
  }

  Future<void> _executeRapidPayment() async {
    if (_rapidStudent == null) return;
    if (_rapidIsProcessing) return;

    final licenseState = ref.read(licenseStateProvider).value;
    if (licenseState?.status.isReadOnly ?? false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Action blocked: Eduvia is currently in Read-Only mode due to license status.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    if (_rapidPaymentMethod == PaymentMethod.cash && _rapidTenderedController.text.trim().isEmpty) {
      _rapidTenderedController.text = _rapidPaidAmountController.text.trim();
    }

    final paidAmount = double.tryParse(_rapidPaidAmountController.text.trim()) ?? 0.0;
    if (paidAmount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid payment amount.', style: GoogleFonts.poppins()), backgroundColor: AppTheme.error),
        );
      }
      return;
    }

    final selectedLedgers = _rapidStudentDues.where((l) => _rapidSelectedLedgerIds.contains(l.id)).toList();
    if (selectedLedgers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fee dues selected to pay.', style: GoogleFonts.poppins()), backgroundColor: AppTheme.error),
        );
      }
      return;
    }

    setState(() => _rapidIsProcessing = true);
    final dbService = ref.read(databaseServiceProvider);
    final student = _rapidStudent!;
    final acadYear = _selectedAcademicYear ?? '2026-2027';

    final periodInfo = (_rapidFromMonth != null && _rapidToMonth != null && _getRapidAvailableMonths().isNotEmpty)
        ? (_rapidFromMonth == _rapidToMonth ? _rapidFromMonth! : '$_rapidFromMonth to $_rapidToMonth')
        : null;
    final userRef = _rapidReferenceController.text.trim();
    final combinedRef = userRef.isNotEmpty
        ? (periodInfo != null ? '$userRef (Period: $periodInfo)' : userRef)
        : (periodInfo != null ? 'Period: $periodInfo' : null);

    try {
      final updatedLedgers = await dbService.recordMultiMonthPayment(
        studentId: student.id,
        academicYear: acadYear,
        ledgerIds: selectedLedgers.map((l) => l.id).toList(),
        paymentMethod: _rapidPaymentMethod,
        paidAmount: paidAmount,
        referenceNumber: combinedRef,
      );

      final receiptNumber = await dbService.getNextReceiptNumber();

      _lastReceiptNumber = receiptNumber;
      _lastReceiptStudent = student;
      _lastReceiptAmount = paidAmount;
      _lastReceiptMethod = _rapidPaymentMethod;
      _lastReceiptLedgers = updatedLedgers;
      _lastReceiptReference = combinedRef;
      _lastReceiptPeriod = periodInfo;

      ref.invalidate(studentsListProvider);
      ref.invalidate(studentFeeLedgerProvider);
      ref.invalidate(studentPaymentHistoryProvider);
      ref.invalidate(invoicesListProvider);
      ref.invalidate(dashboardMetricsProvider);

      if (mounted) {
        await PaymentReceiptDialog.show(
          context: context,
          student: student,
          paidLedgers: updatedLedgers,
          totalAmount: paidAmount,
          paymentMethod: _rapidPaymentMethod,
          referenceNumber: combinedRef,
          academicYear: acadYear,
          receiptNumber: receiptNumber,
        );

        _resetRapidCounter();
      }
    } catch (e, stack) {
      AppLogger.instance.error('Rapid payment processing failed', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment error: $e', style: GoogleFonts.poppins()), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _rapidIsProcessing = false);
      }
    }
  }

  void _resetRapidCounter() {
    setState(() {
      _rapidSearchController.clear();
      _rapidPaidAmountController.clear();
      _rapidTenderedController.clear();
      _rapidReferenceController.clear();
      _rapidStudent = null;
      _rapidStudentDues = [];
      _rapidSelectedLedgerIds.clear();
      _rapidPaymentMethod = PaymentMethod.cash;
      _rapidFromMonth = null;
      _rapidToMonth = null;
      _rapidIncludeOneTimeDues = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_rapidSearchFocusNode.canRequestFocus) {
        _rapidSearchFocusNode.requestFocus();
      }
    });
  }

  Future<void> _shareLastReceiptWhatsApp() async {
    if (_lastReceiptStudent == null || _lastReceiptNumber == null) return;
    final phone = _lastReceiptStudent!.guardianPhone ??
        _lastReceiptStudent!.fatherPhone ??
        _lastReceiptStudent!.motherPhone ??
        '';
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final periodLine = _lastReceiptPeriod != null ? 'Fee Period: $_lastReceiptPeriod\n' : '';
    final msg = '''*FEE PAYMENT RECEIPT*
Student: ${_lastReceiptStudent!.name} (${_lastReceiptStudent!.gradeLevel})
Receipt No: $_lastReceiptNumber
${periodLine}Amount Paid: ${_currencyFormat.format(_lastReceiptAmount ?? 0)}
Payment Mode: ${_lastReceiptMethod?.displayName ?? 'Cash'}
Date: $dateStr

Thank you for your payment!''';

    final encoded = Uri.encodeComponent(msg);
    final url = cleanPhone.isNotEmpty
        ? Uri.parse('https://wa.me/$cleanPhone?text=$encoded')
        : Uri.parse('https://wa.me/?text=$encoded');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _reprintLastReceipt() async {
    if (_lastReceiptStudent == null || _lastReceiptNumber == null) return;
    await PaymentReceiptDialog.show(
      context: context,
      student: _lastReceiptStudent!,
      paidLedgers: _lastReceiptLedgers ?? [],
      totalAmount: _lastReceiptAmount ?? 0,
      paymentMethod: _lastReceiptMethod ?? PaymentMethod.cash,
      academicYear: _selectedAcademicYear,
      receiptNumber: _lastReceiptNumber!,
      referenceNumber: _lastReceiptReference,
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
    final activeYear = _selectedAcademicYear ?? '2026-2027';

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
                title: '1. Select Student (Search by Adm No, Name, or Roll No)',
                icon: Icons.person_search_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    studentsAsync.when(
                      data: (students) {
                        return Autocomplete<Student>(
                          displayStringForOption: (s) => '${s.name} (${s.gradeLevel} - Adm No: ${s.admissionNumber ?? "N/A"}) [ID: ${s.id.substring(0, 8)}]',
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) return const Iterable<Student>.empty();
                            final q = textEditingValue.text.toLowerCase().trim();
                            return students.where((s) {
                              return s.name.toLowerCase().contains(q) ||
                                  (s.admissionNumber != null && s.admissionNumber!.toLowerCase().contains(q)) ||
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
                                    (s.admissionNumber != null && s.admissionNumber!.toLowerCase().contains(q)) ||
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
                                hintText: 'Type Student Name, Admission No, or ID and press Enter...',
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
                                        subtitle: Text('Class: ${s.gradeLevel} ${s.section ?? ""} • Adm No: ${s.admissionNumber ?? "N/A"} • ID: ${s.id.substring(0, 8)}',
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
    final discountsAsync = ref.watch(studentDiscountsProvider(transportParam));
    final discountTypesAsync = ref.watch(discountTypesProvider);

    // Watch student from studentsListProvider to keep outstanding balance reactive
    final allStudents = ref.watch(studentsListProvider).valueOrNull ?? [];
    final currentStudent = allStudents.firstWhere((s) => s.id == student.id, orElse: () => student);

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
                  'Adm No: ${student.admissionNumber ?? "N/A"}  •  Guardian Phone: ${student.guardianPhone ?? "N/A"}  •  ID: ${student.id.substring(0, 8)}',
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
                // Active Discounts / Scholarships Indicator
                discountsAsync.when(
                  data: (discounts) {
                    if (discounts.isEmpty) return const SizedBox.shrink();
                    final types = discountTypesAsync.value ?? [];
                    final typeMap = {for (var t in types) t.id: t};

                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
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

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.card_giftcard_rounded, size: 13, color: AppTheme.warning),
                                const SizedBox(width: 4),
                                Text(
                                  '$name ($valStr$modeStr)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.warning,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
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
                  _currencyFormat.format(currentStudent.currentBalance),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: currentStudent.currentBalance > 0 ? AppTheme.error : AppTheme.success,
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
                              initialValue: _selectedMethod,
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
      ref.invalidate(studentPaymentHistoryProvider);
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

        if (!mounted) return;
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
    final studentsAsync = ref.watch(studentsListProvider);

    final studentMap = {
      for (final s in (studentsAsync.value ?? <Student>[])) s.id: s
    };

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

              final query = _invoiceSearchController.text.trim().toLowerCase();
              final filteredInvoices = invoices.where((inv) {
                if (query.isEmpty) return true;
                final student = studentMap[inv.studentId];
                final studentName = student?.name.toLowerCase() ?? '';
                final admissionNo = student?.admissionNumber?.toLowerCase() ?? '';
                final rollNo = student?.rollNumber?.toLowerCase() ?? '';
                final invoiceId = 'inv-${inv.id.toLowerCase()}';
                final notes = inv.notes?.toLowerCase() ?? '';
                return studentName.contains(query) ||
                    admissionNo.contains(query) ||
                    rollNo.contains(query) ||
                    invoiceId.contains(query) ||
                    notes.contains(query);
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Filter / Search Toolbar
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 20, color: AppTheme.primaryPurple),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _invoiceSearchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search by Student Name, Admission No, Roll No, or Invoice ID...',
                              hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                        ),
                        if (_invoiceSearchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppTheme.textSecondary),
                            onPressed: () {
                              _invoiceSearchController.clear();
                              setState(() {});
                            },
                          ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Text(
                            '${filteredInvoices.length} / ${invoices.length} records',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Table Container
                  if (filteredInvoices.isEmpty)
                    _buildEmptyCard('No invoices match the search filter "$query".')
                  else
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
                                _th('Invoice ID', flex: 2),
                                _th('Date', flex: 2),
                                _th('Student Details', flex: 3),
                                _th('Description / Notes', flex: 3),
                                _th('Amount Paid', flex: 2),
                                _th('Status', flex: 1, textAlign: TextAlign.center),
                                _th('Receipt', flex: 1, textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: AppTheme.divider),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredInvoices.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                            itemBuilder: (context, idx) {
                              final inv = filteredInvoices[idx];
                              final student = studentMap[inv.studentId];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'INV-${inv.id.substring(0, 8).toUpperCase()}',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(_dateFormat.format(inv.createdAt), style: GoogleFonts.poppins(fontSize: 12)),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student?.name ?? 'Student ID: ${inv.studentId.substring(0, 8)}',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textPrimary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (student != null)
                                            Text(
                                              'Adm: ${student.admissionNumber ?? 'N/A'} • ${student.gradeLevel}',
                                              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(inv.notes ?? 'Fee Collection', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currencyFormat.format(inv.totalAmount),
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.success),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.successLight,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            inv.status.name.toUpperCase(),
                                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.success),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Center(
                                        child: IconButton(
                                          icon: const Icon(Icons.print_rounded, size: 18, color: AppTheme.primaryPurple),
                                          tooltip: 'Print Fee Receipt',
                                          onPressed: () => _printReceiptForInvoice(inv, student),
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
            error: (e, _) => Text('Error loading invoices: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
          ),
        ),
      ),
    );
  }

  Future<void> _printReceiptForInvoice(Invoice inv, Student? student) async {
    final dbService = ref.read(databaseServiceProvider);

    Student? resolvedStudent = student;
    if (resolvedStudent == null) {
      final fetched = await dbService.getStudentById(inv.studentId);
      if (fetched != null) {
        resolvedStudent = fetched;
      }
    }

    if (resolvedStudent == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Student information could not be found for this invoice.', style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    final paymentRecord = await dbService.getPaymentRecordByInvoiceId(inv.id);
    List<StudentFeeLedger> paidLedgers;
    PaymentMethod method = PaymentMethod.cash;
    String rctNum = 'RCT-${inv.id.substring(0, 8).toUpperCase()}';
    String acadYear = inv.academicYearId?.replaceFirst('ay-', '') ?? _selectedAcademicYear ?? '2026-2027';

    if (paymentRecord != null) {
      paidLedgers = paymentRecord.paidLedgers.isNotEmpty
          ? paymentRecord.paidLedgers
          : [
              StudentFeeLedger(
                id: inv.ledgerId ?? inv.id,
                studentId: resolvedStudent.id,
                feeHeadId: 'fh-composite',
                academicYear: paymentRecord.academicYear,
                amountDue: paymentRecord.totalAmountPaid,
                amountPaid: paymentRecord.totalAmountPaid,
                dueDate: paymentRecord.timestamp,
                status: LedgerStatus.paid,
                feeHeadName: paymentRecord.notes ?? inv.notes ?? 'Fee Collection',
                createdAt: paymentRecord.timestamp,
                updatedAt: paymentRecord.timestamp,
              )
            ];
      method = paymentRecord.paymentMethod;
      rctNum = paymentRecord.receiptNumber;
      acadYear = paymentRecord.academicYear;
    } else {
      paidLedgers = [
        StudentFeeLedger(
          id: inv.ledgerId ?? inv.id,
          studentId: resolvedStudent.id,
          feeHeadId: 'fh-composite',
          academicYear: acadYear,
          amountDue: inv.totalAmount,
          amountPaid: inv.totalAmount,
          dueDate: inv.dueDate,
          status: LedgerStatus.paid,
          feeHeadName: inv.notes ?? 'Fee Collection',
          createdAt: inv.createdAt,
          updatedAt: inv.updatedAt,
        )
      ];
    }

    if (!mounted) return;
    await PaymentReceiptDialog.show(
      context: context,
      student: resolvedStudent,
      paidLedgers: paidLedgers,
      totalAmount: inv.totalAmount,
      paymentMethod: method,
      referenceNumber: rctNum,
      academicYear: acadYear,
      receiptNumber: rctNum,
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
                  initialValue: selectedGrade,
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

                      if (mounted) {
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

  Widget _th(String label, {int flex = 1, TextAlign textAlign = TextAlign.start}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: textAlign,
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, letterSpacing: 0.5),
      ),
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
