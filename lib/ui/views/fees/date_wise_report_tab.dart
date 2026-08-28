import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/services_provider.dart';

class DateWiseReportTab extends ConsumerStatefulWidget {
  final String academicYear;
  const DateWiseReportTab({super.key, required this.academicYear});

  @override
  ConsumerState<DateWiseReportTab> createState() => _DateWiseReportTabState();
}

class _DateWiseReportTabState extends ConsumerState<DateWiseReportTab> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String? _classId;
  String? _sectionId;
  String? _feeHeadId;

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
  final _shortDateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final dbService = ref.watch(databaseServiceProvider);
    final classesAsync = ref.watch(classesProvider);
    final feeHeadsAsync = ref.watch(feeHeadsProvider);

    return Column(
      children: [
        // Filters Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.divider)),
          ),
          child: Row(
            children: [
              // Date Range Picker
              InkWell(
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppTheme.primaryPurple,
                            onPrimary: Colors.white,
                            onSurface: AppTheme.textPrimary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (range != null) {
                    setState(() {
                      _startDate = range.start;
                      _endDate = range.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 18, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        '${_shortDateFormat.format(_startDate)} - ${_shortDateFormat.format(_endDate)}',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Class Filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: classesAsync.when(
                  data: (classes) => DropdownButton<String?>(
                    value: _classId,
                    hint: Text('All Classes', style: GoogleFonts.poppins(fontSize: 13)),
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text('All Classes', style: GoogleFonts.poppins(fontSize: 13))),
                      ...classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: GoogleFonts.poppins(fontSize: 13)))),
                    ],
                    onChanged: (val) => setState(() { _classId = val; _sectionId = null; }),
                  ),
                  loading: () => const SizedBox(width: 100, height: 40, child: Center(child: CircularProgressIndicator())),
                  error: (_, __) => const SizedBox(),
                ),
              ),
              const SizedBox(width: 16),

              // Fee Head Filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: feeHeadsAsync.when(
                  data: (heads) => DropdownButton<String?>(
                    value: _feeHeadId,
                    hint: Text('All Fee Heads', style: GoogleFonts.poppins(fontSize: 13)),
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text('All Fee Heads', style: GoogleFonts.poppins(fontSize: 13))),
                      ...heads.map((h) => DropdownMenuItem(value: h.id, child: Text(h.name, style: GoogleFonts.poppins(fontSize: 13)))),
                    ],
                    onChanged: (val) => setState(() => _feeHeadId = val),
                  ),
                  loading: () => const SizedBox(width: 100, height: 40, child: Center(child: CircularProgressIndicator())),
                  error: (_, __) => const SizedBox(),
                ),
              ),
            ],
          ),
        ),

        // Data View
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: dbService.getDateWiseFeeReport(
              widget.academicYear,
              _startDate,
              _endDate,
              classId: _classId,
              sectionId: _sectionId,
              feeHeadId: _feeHeadId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final data = snapshot.data!;
              final total = data['totalRevenue'] as double;
              final headBreakdown = data['headBreakdown'] as Map<String, double>;
              final methodBreakdown = data['methodBreakdown'] as Map<String, double>;
              final transactions = data['transactions'] as List<Map<String, dynamic>>;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Summary Cards
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Total Card
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Collection', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                                const SizedBox(height: 8),
                                Text(_currencyFormat.format(total), style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        
                        // Methods Card
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Payment Methods', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                ...methodBreakdown.entries.map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(e.key, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary)),
                                      Text(_currencyFormat.format(e.value), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                )),
                                if (methodBreakdown.isEmpty)
                                  Text('No data', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Heads Card
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Fee Heads Breakdown', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                ...headBreakdown.entries.map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(e.key, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
                                      Text(_currencyFormat.format(e.value), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                )),
                                if (headBreakdown.isEmpty)
                                  Text('No data', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    Text('Detailed Log', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 16),

                    // Data Table
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: transactions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(48.0),
                              child: Center(
                                child: Text('No collections in this period.', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
                              ),
                            )
                          : DataTable(
                              headingTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textSecondary),
                              dataTextStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary),
                              columns: const [
                                DataColumn(label: Text('DATE')),
                                DataColumn(label: Text('STUDENT')),
                                DataColumn(label: Text('CLASS')),
                                DataColumn(label: Text('FEE HEAD')),
                                DataColumn(label: Text('METHOD')),
                                DataColumn(label: Text('REF')),
                                DataColumn(label: Text('AMOUNT')),
                              ],
                              rows: transactions.map((t) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(_dateFormat.format(DateTime.parse(t['date'])))),
                                    DataCell(Text(t['student_name'] ?? '-')),
                                    DataCell(Text('${t['class_name'] ?? ''} ${t['section_name'] ?? ''}')),
                                    DataCell(Text(t['fee_head_name'] ?? 'Other')),
                                    DataCell(Text((t['payment_method'] ?? '-').toString().toUpperCase())),
                                    DataCell(Text(t['reference_number'] ?? '-')),
                                    DataCell(Text(_currencyFormat.format((t['amount_paid'] as num?)?.toDouble() ?? 0))),
                                  ],
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
