import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/ai_message_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/fee_collection_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/license_provider.dart';
import '../../../providers/services_provider.dart';
import '../../../services/bulk_invoice_service.dart';
import '../../../services/report_generator.dart';
import '../../widgets/pdf_preview_dialog.dart';
import '../../widgets/payment_receipt_dialog.dart';
import '../../../services/settings_service.dart';
import '../../../services/app_logger.dart';
import '../../layout/widgets/glass_card.dart';
import '../fees/student_fee_ledger_view.dart';

class FeeCollectionView extends ConsumerStatefulWidget {
  const FeeCollectionView({super.key});

  @override
  ConsumerState<FeeCollectionView> createState() => _FeeCollectionViewState();
}

class _FeeCollectionViewState extends ConsumerState<FeeCollectionView> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _glowAnimation;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

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

  void _showBulkInvoiceDialog(BuildContext context) {
    String selectedGrade = 'All Grades';
    final amountController = TextEditingController(text: '1500');
    final titleController = TextEditingController(text: 'Monthly Tuition & Facility Fee');

    final grades = [
      'All Grades',
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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: AppTheme.divider)),
            title: Row(
              children: [
                const Icon(Icons.library_add_rounded, color: AppTheme.primaryPurple, size: 20),
                const SizedBox(width: 10),
                Text(
                  'BATCH FEE INVOICE GENERATOR',
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedGrade,
                    dropdownColor: Colors.white,
                    style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Select Grade Level',
                      labelStyle: GoogleFonts.poppins(color: AppTheme.textHint),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppTheme.divider)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppTheme.primaryPurple)),
                    ),
                    items: grades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedGrade = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Fee Amount (₹)',
                      prefixText: '₹ ',
                      labelStyle: GoogleFonts.poppins(color: AppTheme.textHint),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppTheme.divider)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppTheme.primaryPurple)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Invoice Description / Fee Title',
                      labelStyle: GoogleFonts.poppins(color: AppTheme.textHint),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppTheme.divider)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppTheme.primaryPurple)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textSecondary, side: const BorderSide(color: AppTheme.divider)),
                child: Text('CANCEL', style: GoogleFonts.poppins(fontSize: 11)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amt = double.tryParse(amountController.text) ?? 0.0;
                  if (amt <= 0) return;
                  
                  final bulkService = BulkInvoiceService();
                  final count = await bulkService.generateBulkInvoicesForGrade(
                    gradeLevel: selectedGrade,
                    feeAmount: amt,
                    dueDate: DateTime.now().add(const Duration(days: 15)),
                    feeTitle: titleController.text,
                  );

                  if (context.mounted) {
                    ref.invalidate(studentsListProvider);
                    ref.invalidate(selectedStudentInvoicesProvider);
                    ref.invalidate(dashboardMetricsProvider);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Successfully generated $count invoice(s) for $selectedGrade!', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                        backgroundColor: AppTheme.primaryPurple,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                child: Text('GENERATE BATCH', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsListProvider);
    final selectedStudent = ref.watch(selectedStudentProvider);
    final searchQuery = ref.watch(studentSearchQueryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent, // Background handled by MainLayout
      body: Stack(
        children: [
          Positioned(
            top: -150,
            left: 200,
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
          Row(
            children: [
              // ── LEFT PANE: Searchable Students List ──
              Container(
                width: 360,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                ),
            child: Column(
              children: [
                // Search & Filter Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Student Directory',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _showBulkInvoiceDialog(context),
                            icon: const Icon(Icons.post_add_rounded, size: 14),
                            label: Text('BULK INVOICE', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryPurple,
                              side: const BorderSide(color: AppTheme.primaryPurple),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                        onChanged: (val) {
                          if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                            ref.read(studentSearchQueryProvider.notifier).state = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by name, phone, or class...',
                          hintStyle: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: AppTheme.textSecondary),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(studentSearchQueryProvider.notifier).state = '';
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: AppTheme.primaryPurple),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1, color: AppTheme.divider),

                // Student List
                Expanded(
                  child: studentsAsync.when(
                    data: (students) {
                      final filteredStudents = students.where((s) {
                        if (searchQuery.isEmpty) return true;
                        final q = searchQuery.toLowerCase();
                        return s.name.toLowerCase().contains(q) ||
                            (s.guardianPhone != null && s.guardianPhone!.contains(q)) ||
                            s.gradeLevel.toLowerCase().contains(q);
                      }).toList();

                      if (filteredStudents.isEmpty) {
                        return Center(
                          child: Text(
                            'No students found',
                            style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: filteredStudents.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: AppTheme.divider),
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          final isSelected = selectedStudent?.id == student.id;

                          return Material(
                            color: isSelected ? AppTheme.bgMain : Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                ref.read(selectedStudentProvider.notifier).state = student;
                              },
                              hoverColor: AppTheme.bgMain,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isSelected ? AppTheme.primaryPurple : Colors.white,
                                      child: Text(
                                        student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                                        style: GoogleFonts.poppins(
                                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student.name,
                                            style: GoogleFonts.poppins(
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                              color: isSelected ? AppTheme.primaryPurple : AppTheme.textPrimary,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${student.gradeLevel} • ${student.guardianPhone ?? "No Phone"}',
                                            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${student.currentBalance.toStringAsFixed(2)}',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: student.currentBalance > 0 ? AppTheme.error : AppTheme.success,
                                          ),
                                        ),
                                        Text(
                                          student.currentBalance > 0 ? 'DUE' : 'CLEARED',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: student.currentBalance > 0 ? AppTheme.error : AppTheme.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple, strokeWidth: 2)),
                    error: (err, stack) => Center(child: Text('Error: $err', style: GoogleFonts.poppins(color: AppTheme.error))),
                  ),
                ),
              ],
            ),
          ),

          // ── RIGHT PANE: Dynamic Student View & Payment Form ──
          Expanded(
            child: selectedStudent == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: const BoxDecoration(
                            color: AppTheme.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 64,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'No Student Selected',
                          style: GoogleFonts.poppins(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select a student from the directory\nto process payments & view fee profile.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : _StudentDetailPane(student: selectedStudent),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentDetailPane extends ConsumerStatefulWidget {
  final Student student;

  const _StudentDetailPane({required this.student});

  @override
  ConsumerState<_StudentDetailPane> createState() => _StudentDetailPaneState();
}

class _StudentDetailPaneState extends ConsumerState<_StudentDetailPane> {
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  bool _isProcessing = false;
  String? _selectedAcademicYear;
  final Set<String> _selectedLedgerIds = {};
  String? _fromMonth;
  String? _toMonth;

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    super.dispose();
  }

  int _getMonthIndex(String? label) {
    if (label == null) return -1;
    final l = label.toLowerCase();
    if (l.contains('apr')) return 0;
    if (l.contains('may')) return 1;
    if (l.contains('jun')) return 2;
    if (l.contains('jul')) return 3;
    if (l.contains('aug')) return 4;
    if (l.contains('sep')) return 5;
    if (l.contains('oct')) return 6;
    if (l.contains('nov')) return 7;
    if (l.contains('dec')) return 8;
    if (l.contains('jan')) return 9;
    if (l.contains('feb')) return 10;
    if (l.contains('mar')) return 11;
    return -1;
  }

  void _applyMonthRange(List<StudentFeeLedger> allUnpaid) {
    if (_fromMonth == null || _toMonth == null) return;
    final fromIdx = _getMonthIndex(_fromMonth);
    final toIdx = _getMonthIndex(_toMonth);
    if (fromIdx == -1 || toIdx == -1) return;

    final minIdx = fromIdx <= toIdx ? fromIdx : toIdx;
    final maxIdx = fromIdx <= toIdx ? toIdx : fromIdx;

    final monthlyItems = allUnpaid.where((l) => _getMonthIndex(l.monthLabel) != -1).toList();
    for (final item in monthlyItems) {
      final idx = _getMonthIndex(item.monthLabel);
      if (idx >= minIdx && idx <= maxIdx) {
        _selectedLedgerIds.add(item.id);
      } else {
        _selectedLedgerIds.remove(item.id);
      }
    }

    _recalculateTotal(allUnpaid);
  }

  void _recalculateTotal(List<StudentFeeLedger> allUnpaid) {
    double total = 0.0;
    for (var id in _selectedLedgerIds) {
      final match = allUnpaid.where((l) => l.id == id);
      if (match.isNotEmpty) total += match.first.remainingAmount;
    }
    _amountController.text = total.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(selectedStudentInvoicesProvider);
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormatter = DateFormat('dd MMM yyyy');

    final yearsAsync = ref.watch(academicYearsProvider);
    final yearList = yearsAsync.value?.map((y) => y.name).toList() ?? ['2024-2025', '2025-2026'];
    if (_selectedAcademicYear == null || !_selectedAcademicYear!.contains('-')) {
      final currentYear = ref.watch(currentAcademicYearProvider).value?.name;
      _selectedAcademicYear = currentYear ?? (yearList.isNotEmpty ? yearList.first : '2024-2025');
    }

    final activeYear = _selectedAcademicYear!;
    final double enterAmount = double.tryParse(_amountController.text) ?? 0.0;
    final double realTimeBalancePreview = widget.student.currentBalance - enterAmount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Student Header Card ──
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          widget.student.name[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.student.name,
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Grade Level: ${widget.student.gradeLevel} • Guardian Phone: ${widget.student.guardianPhone ?? "N/A"}',
                              style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('OUTSTANDING BALANCE', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8))),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormatter.format(widget.student.currentBalance),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: widget.student.currentBalance > 0 ? const Color(0xFFFFB3B3) : const Color(0xFFB3FFB3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Action Buttons & Session Selector ──
          Row(
            children: [
              // Session Switcher
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 16, color: AppTheme.primaryPurple),
                    const SizedBox(width: 6),
                    DropdownButton<String>(
                      value: yearList.contains(activeYear) ? activeYear : null,
                      underline: const SizedBox(),
                      isDense: true,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      items: yearList
                          .map((y) => DropdownMenuItem(value: y, child: Text('Session $y')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedAcademicYear = val;
                            _selectedLedgerIds.clear();
                            _fromMonth = null;
                            _toMonth = null;
                            _amountController.text = '0.0';
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudentFeeLedgerView(student: widget.student, academicYear: activeYear),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: Text(
                    'View Full Ledger',
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
              
              if (widget.student.currentBalance > 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final phone = widget.student.fatherPhone?.isNotEmpty == true
                          ? widget.student.fatherPhone!
                          : (widget.student.motherPhone ?? '');

                      if (phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('No phone number found for ${widget.student.name}', style: GoogleFonts.poppins()), backgroundColor: const Color(0xFFF59E0B)),
                        );
                        return;
                      }

                      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
                      final finalPhone = cleanPhone.startsWith('+') ? cleanPhone : '+91$cleanPhone';

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Generating smart message...', style: GoogleFonts.poppins()), duration: const Duration(milliseconds: 1500)),
                      );

                      final aiService = ref.read(aiMessageServiceProvider);
                      final text = await aiService.generateOverdueReminder(
                        studentName: widget.student.name,
                        amountStr: currencyFormatter.format(widget.student.currentBalance),
                        grade: '${widget.student.gradeLevel} - ${widget.student.section}',
                      );

                      final url = Uri.parse('https://wa.me/$finalPhone?text=${Uri.encodeComponent(text)}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not launch WhatsApp.', style: GoogleFonts.poppins()), backgroundColor: const Color(0xFFEF4444)),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    label: Text(
                      'WhatsApp Reminder',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
              ]
            ],
          ),

          const SizedBox(height: 32),

          // ── Payment Processing Form Box ──
          GlassCard(
            padding: const EdgeInsets.all(24),
            borderRadius: 16.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.point_of_sale_rounded, color: AppTheme.primaryPurple, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'UNIFIED FEE PAYMENT (SESSION $activeYear)',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Fee Selection Across All Fee Heads ──
                Consumer(
                  builder: (context, ref, child) {
                    final ledgerAsync = ref.watch(studentFeeLedgerProvider(StudentYearParam(studentId: widget.student.id, academicYear: activeYear)));
                    
                    return ledgerAsync.when(
                      data: (ledgers) {
                        final unpaidLedgers = ledgers.where((l) => l.remainingAmount > 0).toList();
                        
                        if (ledgers.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: AppTheme.primaryPurple),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No fee dues recorded for session $activeYear.',
                                    style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final dbService = ref.read(databaseServiceProvider);
                                    await dbService.generateLedgerForStudent(widget.student.id, widget.student.gradeLevel, activeYear);
                                    await dbService.recalculateOverdueLedgerEntries();
                                    ref.invalidate(studentFeeLedgerProvider);
                                    ref.invalidate(studentLedgerSummaryProvider);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Generated fee dues for $activeYear!'), backgroundColor: AppTheme.primaryPurple),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                                  label: Text('Generate Dues', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryPurple,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (unpaidLedgers.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: AppTheme.success),
                                const SizedBox(width: 12),
                                Text(
                                  'All fees for academic session $activeYear are fully cleared!',
                                  style: GoogleFonts.poppins(color: AppTheme.success, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }

                        // Separate Monthly fees from Non-Monthly fees (Exam, Admission, Annual, etc.)
                        final monthlyLedgers = unpaidLedgers.where((l) => _getMonthIndex(l.monthLabel) != -1).toList();
                        monthlyLedgers.sort((a, b) => _getMonthIndex(a.monthLabel).compareTo(_getMonthIndex(b.monthLabel)));
                        
                        final nonMonthlyLedgers = unpaidLedgers.where((l) => _getMonthIndex(l.monthLabel) == -1).toList();

                        // Unique month labels available
                        final availableMonths = <String>[];
                        for (final l in monthlyLedgers) {
                          if (l.monthLabel != null && !availableMonths.contains(l.monthLabel!)) {
                            availableMonths.add(l.monthLabel!);
                          }
                        }

                        // Default from/to months if not set
                        if (_fromMonth == null && availableMonths.isNotEmpty) {
                          _fromMonth = availableMonths.first;
                        }
                        if (_toMonth == null && availableMonths.isNotEmpty) {
                          _toMonth = availableMonths.first;
                        }

                        final double totalAllUnpaid = unpaidLedgers.fold(0.0, (sum, l) => sum + l.remainingAmount);
                        final bool isAllSelected = unpaidLedgers.isNotEmpty && unpaidLedgers.every((l) => _selectedLedgerIds.contains(l.id));

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── FROM - TO MONTH RANGE SELECTOR BOX ──
                            if (availableMonths.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPurple.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.date_range_rounded, color: AppTheme.primaryPurple, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          'SELECT MONTH RANGE (TUITION / MONTHLY FEES):',
                                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: AppTheme.primaryPurple),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        // FROM MONTH
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                                                items: availableMonths
                                                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                                    .toList(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setState(() {
                                                      _fromMonth = val;
                                                      _applyMonthRange(unpaidLedgers);
                                                    });
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),

                                        const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.primaryPurple),

                                        // TO MONTH
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                                                items: availableMonths
                                                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                                    .toList(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setState(() {
                                                      _toMonth = val;
                                                      _applyMonthRange(unpaidLedgers);
                                                    });
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Quick Presets
                                        OutlinedButton(
                                          onPressed: () {
                                            setState(() {
                                              _fromMonth = availableMonths.first;
                                              _toMonth = availableMonths.length >= 3 ? availableMonths[2] : availableMonths.last;
                                              _applyMonthRange(unpaidLedgers);
                                            });
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.primaryPurple,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            side: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
                                          ),
                                          child: Text('Next 3 Months', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                                        ),

                                        OutlinedButton(
                                          onPressed: () {
                                            setState(() {
                                              _fromMonth = availableMonths.first;
                                              _toMonth = availableMonths.length >= 6 ? availableMonths[5] : availableMonths.last;
                                              _applyMonthRange(unpaidLedgers);
                                            });
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.primaryPurple,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            side: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
                                          ),
                                          child: Text('6 Months (Half-Year)', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                                        ),

                                        ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _fromMonth = availableMonths.first;
                                              _toMonth = availableMonths.last;
                                              _applyMonthRange(unpaidLedgers);
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryPurple,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          child: Text('All Months (${availableMonths.length})', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // ── NON-MONTHLY / OTHER FEES (Exam Fee, Annual Charges, etc.) ──
                            if (nonMonthlyLedgers.isNotEmpty) ...[
                              Text(
                                'ADDITIONAL / OTHER FEES:',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: nonMonthlyLedgers.map((l) {
                                  final isSelected = _selectedLedgerIds.contains(l.id);
                                  final name = l.feeHeadName ?? l.feeHeadId;
                                  final amt = currencyFormatter.format(l.remainingAmount);

                                  return FilterChip(
                                    selected: isSelected,
                                    label: Text(
                                      '$name: $amt',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                                      ),
                                    ),
                                    backgroundColor: Colors.white,
                                    selectedColor: AppTheme.primaryPurple,
                                    checkmarkColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: isSelected ? AppTheme.primaryPurple : AppTheme.divider),
                                    ),
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedLedgerIds.add(l.id);
                                        } else {
                                          _selectedLedgerIds.remove(l.id);
                                        }
                                        _recalculateTotal(unpaidLedgers);
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // ── QUICK ACTION TOOLBAR (SELECT ALL DUES / DESELECT) ──
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.bgSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryPurple, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedLedgerIds.isEmpty
                                          ? 'No fees selected yet. Select a month range or fee items above.'
                                          : 'Selected ${_selectedLedgerIds.length} item(s) • Total: ${currencyFormatter.format(enterAmount)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: _selectedLedgerIds.isEmpty ? FontWeight.w500 : FontWeight.bold,
                                        color: _selectedLedgerIds.isEmpty ? AppTheme.textSecondary : AppTheme.primaryPurple,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        if (isAllSelected) {
                                          _selectedLedgerIds.clear();
                                          _fromMonth = null;
                                          _toMonth = null;
                                        } else {
                                          _selectedLedgerIds.addAll(unpaidLedgers.map((l) => l.id));
                                          if (availableMonths.isNotEmpty) {
                                            _fromMonth = availableMonths.first;
                                            _toMonth = availableMonths.last;
                                          }
                                        }
                                        _recalculateTotal(unpaidLedgers);
                                      });
                                    },
                                    icon: Icon(isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded, size: 14),
                                    label: Text(
                                      isAllSelected ? 'Clear All' : 'Select Everything (${currencyFormatter.format(totalAllUnpaid)})',
                                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.primaryPurple,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── ITEMIZED LIVE SUMMARY CARD ──
                            if (_selectedLedgerIds.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.25)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('FEE COLLECTION BREAKDOWN', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple, letterSpacing: 0.5)),
                                        Text('${_selectedLedgerIds.length} item(s) included', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    const Divider(height: 1, color: AppTheme.divider),
                                    const SizedBox(height: 8),
                                    ...unpaidLedgers.where((l) => _selectedLedgerIds.contains(l.id)).map((item) {
                                      final title = item.monthLabel ?? item.feeHeadName ?? 'Fee Item';
                                      final sub = item.feeHeadName != null && item.monthLabel != null ? item.feeHeadName : null;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.success),
                                                const SizedBox(width: 8),
                                                Text(title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                                if (sub != null) ...[
                                                  const SizedBox(width: 6),
                                                  Text('• $sub', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                                                ],
                                              ],
                                            ),
                                            Text(currencyFormatter.format(item.remainingAmount), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                          ],
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 10),
                                    const Divider(height: 1, color: AppTheme.divider),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('SUM TOTAL:', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                        Text(currencyFormatter.format(enterAmount), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ],
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple, strokeWidth: 2)),
                      ),
                      error: (err, stack) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text('Error loading fee details: $err', style: GoogleFonts.poppins(color: AppTheme.error)),
                      ),
                    );
                  },
                ),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmallScreen = constraints.maxWidth < 600;
                    
                    return Flex(
                      direction: isSmallScreen ? Axis.vertical : Axis.horizontal,
                      children: [
                        // Payment Amount Input
                        Expanded(
                          flex: isSmallScreen ? 0 : 1,
                          child: TextField(
                            controller: _amountController,
                            readOnly: true,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                            decoration: _buildInputDecoration('Total Payment Amount (₹)', prefix: '₹ ').copyWith(
                              fillColor: AppTheme.primarySoft.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 0 : 16, height: isSmallScreen ? 16 : 0),

                        // Payment Method Dropdown
                        Expanded(
                          flex: isSmallScreen ? 0 : 1,
                          child: DropdownButtonFormField<PaymentMethod>(
                            value: _selectedMethod,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                            decoration: _buildInputDecoration('Payment Method'),
                            items: PaymentMethod.values.map((method) {
                              return DropdownMenuItem(
                                value: method,
                                child: Text(method.displayName),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedMethod = val);
                            },
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 0 : 16, height: isSmallScreen ? 16 : 0),

                        // Reference Number
                        Expanded(
                          flex: isSmallScreen ? 0 : 1,
                          child: TextField(
                            controller: _refController,
                            style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                            decoration: _buildInputDecoration('Ref / Cheque / Txn No.'),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Real-time Balance Preview Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Real-time Balance Preview: Current (${currencyFormatter.format(widget.student.currentBalance)}) - Payment (${currencyFormatter.format(enterAmount)})',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'New Balance: ${currencyFormatter.format(realTimeBalancePreview)}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: realTimeBalancePreview > 0 ? AppTheme.error : AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(color: AppTheme.divider, height: 1, thickness: 1),
                const SizedBox(height: 24),

                // Submit Payment Button (Disabled in Read-Only Soft-Lock mode)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Consumer(
                      builder: (context, ref, child) {
                        final isReadOnly = ref.watch(licenseStateProvider).value?.status.isReadOnly ?? false;
                        final isDisabled = _isProcessing || enterAmount <= 0 || isReadOnly;

                        return ElevatedButton.icon(
                          onPressed: isDisabled ? null : _handleProcessPayment,
                          icon: _isProcessing
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Icon(isReadOnly ? Icons.lock_rounded : Icons.check_circle_rounded, size: 16),
                          label: Text(
                            isReadOnly ? 'SOFT-LOCK ACTIVE (READ-ONLY)' : 'CONFIRM PAYMENT & GENERATE RECEIPT (${currencyFormatter.format(enterAmount)})',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, letterSpacing: 1.0, fontSize: 11),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white,
                            disabledForegroundColor: AppTheme.textHint,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                              side: BorderSide(color: isDisabled ? AppTheme.divider : AppTheme.primaryPurple),
                            ),
                            elevation: 0,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // ── Invoice History Section ──
          GlassCard(
            padding: EdgeInsets.zero,
            borderRadius: 16.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Text(
                    'INVOICE HISTORY',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const Divider(color: AppTheme.divider, height: 1, thickness: 1),

                invoicesAsync.when(
                  data: (invoices) {
                    if (invoices.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(48.0),
                        child: Center(
                          child: Text(
                            'No invoices recorded for this student.',
                            style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 14, fontStyle: FontStyle.italic),
                          ),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width - 480,
                        ),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.02)),
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
                            DataColumn(label: Text('INVOICE ID')),
                            DataColumn(label: Text('DUE DATE')),
                            DataColumn(label: Text('NOTES')),
                            DataColumn(label: Text('NET AMOUNT')),
                            DataColumn(label: Text('STATUS')),
                          ],
                          rows: invoices.map((inv) {
                            return DataRow(
                              cells: [
                                DataCell(Text(
                                  inv.id.substring(0, 8).toUpperCase(),
                                  style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                                )),
                                DataCell(Text(
                                  dateFormatter.format(inv.dueDate),
                                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                                )),
                                DataCell(Text(
                                  inv.notes ?? '—',
                                  style: GoogleFonts.poppins(color: AppTheme.textSecondary),
                                )),
                                DataCell(Text(
                                  currencyFormatter.format(inv.netAmount),
                                  style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                                )),
                                DataCell(_buildStatusBadge(inv.status)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple, strokeWidth: 2)),
                  ),
                  error: (err, stack) => Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('Error: $err', style: GoogleFonts.poppins(color: AppTheme.error)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, {String? prefix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 13),
      prefixText: prefix,
      prefixStyle: GoogleFonts.poppins(color: AppTheme.textSecondary),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.03),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildStatusBadge(InvoiceStatus status) {
    Color bg = AppTheme.error.withValues(alpha: 0.1);
    Color border = AppTheme.error.withValues(alpha: 0.3);
    Color text = AppTheme.error;
    String label = status.displayName.toUpperCase();

    if (status == InvoiceStatus.paid) {
      bg = AppTheme.success.withValues(alpha: 0.1);
      border = AppTheme.success.withValues(alpha: 0.3);
      text = AppTheme.success;
    } else if (status == InvoiceStatus.partial) {
      bg = AppTheme.primaryPurple.withValues(alpha: 0.1);
      border = AppTheme.primaryPurple.withValues(alpha: 0.3);
      text = AppTheme.primaryPurple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(color: text, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    );
  }

  Future<void> _handleProcessPayment() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) return;
    
    if (_selectedLedgerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one fee item/month to pay.', style: GoogleFonts.poppins()),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final dbService = ref.read(databaseServiceProvider);
      final activeYear = _selectedAcademicYear ?? '2024-2025';
      
      final updatedLedgers = await dbService.recordMultiMonthPayment(
        studentId: widget.student.id,
        academicYear: activeYear,
        ledgerIds: _selectedLedgerIds.toList(),
        paymentMethod: _selectedMethod,
        referenceNumber: _refController.text.isNotEmpty ? _refController.text : null,
      );

      if (updatedLedgers.isEmpty) {
        throw Exception('Payment recording failed.');
      }
      
      final receiptNumber = await dbService.getNextReceiptNumber();

      ref.invalidate(studentsListProvider);
      ref.invalidate(selectedStudentInvoicesProvider);
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(studentFeeLedgerProvider);
      ref.invalidate(studentLedgerSummaryProvider);

      final selectedMethodUsed = _selectedMethod;
      final refNumUsed = _refController.text.trim();

      _amountController.clear();
      _refController.clear();
      setState(() {
        _selectedLedgerIds.clear();
      });

      if (mounted) {
        await PaymentReceiptDialog.show(
          context: context,
          student: widget.student,
          paidLedgers: updatedLedgers,
          totalAmount: amount,
          paymentMethod: selectedMethodUsed,
          referenceNumber: refNumUsed.isNotEmpty ? refNumUsed : null,
          academicYear: activeYear,
          receiptNumber: receiptNumber,
        );
      }

    } catch (e, stackTrace) {
      AppLogger.instance.error('Payment processing failed', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing payment: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
