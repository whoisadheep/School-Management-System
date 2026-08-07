import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/models.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/services_provider.dart';
import '../../../services/csv_export_service.dart';
import '../../../services/app_logger.dart';

final ledgerEntriesProvider = FutureProvider<List<LedgerEntry>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getAllLedgerEntries();
});

class ExpensesView extends ConsumerStatefulWidget {
  const ExpensesView({super.key});

  @override
  ConsumerState<ExpensesView> createState() => _ExpensesViewState();
}

class _ExpensesViewState extends ConsumerState<ExpensesView> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _glowAnimation;

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountFocusNode = FocusNode();
  final _categoryFocusNode = FocusNode();
  final _descFocusNode = FocusNode();

  String _selectedCategory = 'Electricity';
  bool _isProcessing = false;

  final List<String> _expenseCategories = [
    'Electricity',
    'Salaries & Staff',
    'Building Maintenance',
    'Stationery & Office Supplies',
    'Laboratory Supplies',
    'Sports Equipment',
    'Internet & Telecom',
    'Miscellaneous Expense',
  ];

  static const _primaryPurple = Color(0xFF4C3BCF);
  static const _lightPurple = Color(0xFF7B68EE);
  static const _softPurple = Color(0xFFE8E4FF);
  static const _bgLavender = Color(0xFFF5F3FF);
  static const _textPrimary = Color(0xFF1E1E2D);
  static const _textSecondary = Color(0xFF6B7280);
  static const _successGreen = Color(0xFF22C55E);
  static const _errorRed = Color(0xFFEF4444);
  static const _white = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.7, end: 1.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutQuad),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _amountFocusNode.dispose();
    _categoryFocusNode.dispose();
    _descFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ledgerAsync = ref.watch(ledgerEntriesProvider);
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormatter = DateFormat('dd MMM yyyy');

    return Container(
      color: _bgLavender,
      child: Stack(
        children: [
          Positioned(
            top: 100,
            left: -100,
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _glowAnimation.value,
                  child: Container(
                    width: 600,
                    height: 600,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _lightPurple.withValues(alpha: 0.08),
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
            bottom: -50,
            right: -50,
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.8 - _glowAnimation.value,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _primaryPurple.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Ledger Header ──
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
                          color: _primaryPurple.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Operational Expense Logger',
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: _white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'RAPID KEYBOARD DATA ENTRY (TAB NAVIGATION) FOR OPERATING EXPENSES',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: _white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final entries = await ref.read(ledgerEntriesProvider.future);
                              final exporter = CsvExportService();
                              final file = await exporter.exportLedgerToCsv(entries);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('General Ledger exported to CSV: ${file.path}', style: GoogleFonts.poppins(color: _white, fontWeight: FontWeight.w600)),
                                    backgroundColor: _primaryPurple,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error exporting ledger: $e', style: GoogleFonts.poppins()), backgroundColor: _errorRed),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.file_download_rounded, size: 16),
                          label: Text(
                            'EXPORT LEDGER CSV',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                              fontSize: 11,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primaryPurple,
                            side: const BorderSide(color: Colors.transparent),
                            backgroundColor: _white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
        
                  const SizedBox(height: 32),
        
                  // ── Keyboard-Optimized Expense Form ──
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _softPurple,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _primaryPurple.withValues(alpha: 0.2)),
                              ),
                              child: const Icon(Icons.post_add_rounded, color: _primaryPurple, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'LOG NEW EXPENSE ENTRY',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: _textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
        
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isSmallScreen = constraints.maxWidth < 600;
        
                            return Flex(
                              direction: isSmallScreen ? Axis.vertical : Axis.horizontal,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Expense Category Dropdown
                                Expanded(
                                  flex: isSmallScreen ? 0 : 1,
                                  child: DropdownButtonFormField<String>(
                                    focusNode: _categoryFocusNode,
                                    value: _selectedCategory,
                                    isExpanded: true, 
                                    dropdownColor: _white,
                                    style: GoogleFonts.poppins(color: _textPrimary),
                                    decoration: _buildInputDecoration('Category (Tab 1)'),
                                    items: _expenseCategories.map((cat) {
                                      return DropdownMenuItem(value: cat, child: Text(cat));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedCategory = val);
                                    },
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 0 : 16, height: isSmallScreen ? 16 : 0),
        
                                // Amount Input
                                Expanded(
                                  flex: isSmallScreen ? 0 : 1,
                                  child: TextField(
                                    focusNode: _amountFocusNode,
                                    controller: _amountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textInputAction: TextInputAction.next,
                                    style: GoogleFonts.poppins(color: _textPrimary, fontSize: 16),
                                    decoration: _buildInputDecoration('Amount (₹) (Tab 2)', prefix: '₹ '),
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 0 : 16, height: isSmallScreen ? 16 : 0),
        
                                // Description / Memo
                                Expanded(
                                  flex: isSmallScreen ? 0 : 2,
                                  child: TextField(
                                    focusNode: _descFocusNode,
                                    controller: _descriptionController,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _handleSaveExpense(),
                                    style: GoogleFonts.poppins(color: _textPrimary),
                                    decoration: _buildInputDecoration('Description / Payee Memo (Tab 3)'),
                                  ),
                                ),
                              ],
                            );
                          }
                        ),
        
                        const SizedBox(height: 32),
                        Divider(color: Colors.black.withValues(alpha: 0.05), height: 1, thickness: 1),
                        const SizedBox(height: 24),
        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isProcessing ? null : _handleSaveExpense,
                              icon: _isProcessing
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _white))
                                  : const Icon(Icons.save_rounded, size: 18),
                              label: Text(
                                'RECORD EXPENSE [ENTER]',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  fontSize: 11,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: _white,
                                backgroundColor: _primaryPurple,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
        
                  const SizedBox(height: 48),
        
                  // ── Ledger Entries Data Table ──
                  Container(
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GENERAL LEDGER LOG (INCOME & EXPENSES)',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Historical master record of all operating transactions',
                                style: GoogleFonts.poppins(color: _textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Divider(color: Colors.black.withValues(alpha: 0.05), height: 1, thickness: 1),
        
                        ledgerAsync.when(
                          data: (entries) {
                            if (entries.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(64),
                                child: Center(
                                  child: Text(
                                    'No ledger entries recorded yet.',
                                    style: GoogleFonts.poppins(
                                      color: _textSecondary,
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              );
                            }
        
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: MediaQuery.of(context).size.width - 320,
                                ),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(_softPurple.withValues(alpha: 0.5)),
                                  dataRowMinHeight: 60,
                                  dataRowMaxHeight: 60,
                                  headingTextStyle: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    letterSpacing: 1.0,
                                    color: _primaryPurple,
                                  ),
                                  dividerThickness: 1,
                                  horizontalMargin: 32,
                                  columns: const [
                                    DataColumn(label: Text('DATE')),
                                    DataColumn(label: Text('TYPE')),
                                    DataColumn(label: Text('CATEGORY')),
                                    DataColumn(label: Text('AMOUNT')),
                                    DataColumn(label: Text('DESCRIPTION')),
                                  ],
                                  rows: entries.map((entry) {
                                    final isIncome = entry.type == LedgerType.income;
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(
                                          dateFormatter.format(entry.date),
                                          style: GoogleFonts.poppins(color: _textPrimary, fontWeight: FontWeight.w500),
                                        )),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isIncome ? _successGreen.withValues(alpha: 0.1) : _errorRed.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: isIncome ? _successGreen.withValues(alpha: 0.3) : _errorRed.withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              entry.type.displayName.toUpperCase(),
                                              style: GoogleFonts.poppins(
                                                color: isIncome ? _successGreen : _errorRed,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 10,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(
                                          entry.category,
                                          style: GoogleFonts.poppins(
                                            color: _textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        )),
                                        DataCell(Text(
                                          '${isIncome ? "+" : "-"}${currencyFormatter.format(entry.amount)}',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: isIncome ? _successGreen : _errorRed,
                                          ),
                                        )),
                                        DataCell(Text(
                                          entry.description ?? '—',
                                          style: GoogleFonts.poppins(color: _textSecondary),
                                        )),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.all(64.0),
                            child: Center(child: CircularProgressIndicator(color: _primaryPurple, strokeWidth: 2)),
                          ),
                          error: (err, stack) => Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text('Error: $err', style: GoogleFonts.poppins(color: _errorRed)),
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
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, {String? prefix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
      prefixText: prefix,
      prefixStyle: GoogleFonts.poppins(color: _textPrimary),
      filled: true,
      fillColor: _bgLavender.withValues(alpha: 0.5),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _lightPurple.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _primaryPurple, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _handleSaveExpense() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid expense amount.', style: GoogleFonts.poppins()),
          backgroundColor: _errorRed,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final dbService = ref.read(databaseServiceProvider);

      final entry = LedgerEntry.create(
        date: DateTime.now(),
        type: LedgerType.expense,
        category: _selectedCategory,
        amount: amount,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : 'Operational Expense',
      );

      await dbService.insertLedgerEntry(entry);
      ref.invalidate(ledgerEntriesProvider);
      ref.invalidate(dashboardMetricsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense logged to general ledger successfully.', style: GoogleFonts.poppins(color: _white, fontWeight: FontWeight.w600)),
            backgroundColor: _primaryPurple, 
          ),
        );
      }

      _amountController.clear();
      _descriptionController.clear();
      _categoryFocusNode.requestFocus();

      ref.invalidate(ledgerEntriesProvider);
    } catch (e, stackTrace) {
      AppLogger.instance.error('Failed to record expense', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording expense: $e', style: GoogleFonts.poppins()),
            backgroundColor: _errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
