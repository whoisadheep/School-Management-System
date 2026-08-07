import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:intl/intl.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/services_provider.dart';
import '../../layout/widgets/hover_scale.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  final primaryPurple = const Color(0xFF4C3BCF);
  final bgPurple = const Color(0xFFF5F3FF);
  final _inviteEmailController = TextEditingController();

  @override
  void dispose() {
    _inviteEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      backgroundColor: bgPurple,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column - 65%
            Expanded(
              flex: 65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildWelcomeBanner(),
                  const SizedBox(height: 20),
                  _buildVehicleRenewalAlertBanner(),
                  metricsAsync.when(
                    data: (metrics) => Column(
                      children: [
                        _buildStatsCardsRow(metrics),
                        const SizedBox(height: 20),
                        _buildStudentInfoTable(metrics.overdueInvoices),
                      ],
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Error: $e')),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Right column - 35%
            Expanded(
              flex: 35,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  metricsAsync.when(
                    data: (metrics) => _buildFinancialOverviewChart(metrics),
                    loading: () => const SizedBox(
                        height: 250,
                        child: Center(child: CircularProgressIndicator())),
                    error: (e, s) =>
                        Center(child: Text('Error loading chart: $e')),
                  ),
                  const SizedBox(height: 20),
                  _buildAddTeachersSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    final user = ref.watch(authProvider).currentUser;
    final userName = user?.fullName ?? user?.username ?? 'Robert';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B4BC4), Color(0xFF7B68EE)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello $userName,',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Navigate the Future of Education with Intuitive School Management Software.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Welcome to Antigravity SMS',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold)),
                        content: Text(
                            'This is your central dashboard. From here you can manage students, staff, and financial metrics at a glance.',
                            style: GoogleFonts.poppins()),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Got it',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold))),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Learn More',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCardsRow(DashboardMetrics metrics) {
    final currencyFormatter =
        NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Students',
            metrics.totalStudents.toString(),
            onTap: () {
              ref.read(selectedTabProvider.notifier).state =
                  NavigationTab.students;
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            "Today's Collection",
            currencyFormatter.format(metrics.todaysCollections),
            onTap: () {
              ref.read(selectedTabProvider.notifier).state =
                  NavigationTab.feeCollection;
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Pending Dues',
            currencyFormatter.format(metrics.pendingDues),
            onTap: () {
              ref.read(selectedTabProvider.notifier).state =
                  NavigationTab.feeCollection;
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Revenue',
            currencyFormatter.format(metrics.totalRevenueCurrentYear),
            onTap: () {
              ref.read(selectedTabProvider.notifier).state =
                  NavigationTab.expenses;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, {VoidCallback? onTap}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: HoverScale(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5B4BC4), Color(0xFF7B68EE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryPurple.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentInfoTable(List<OverdueInvoiceInfo> invoices) {
    final currencyFormatter =
        NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormatter = DateFormat('MM/dd/yyyy');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overdue Invoices',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(selectedTabProvider.notifier).state =
                      NavigationTab.feeCollection;
                },
                child: Text(
                  'See All →',
                  style: GoogleFonts.poppins(
                    color: primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (invoices.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No overdue invoices! 🎉',
                  style: GoogleFonts.poppins(color: const Color(0xFF6B7280)),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
                dataTextStyle: GoogleFonts.poppins(
                  color: const Color(0xFF1F2937),
                ),
                columns: const [
                  DataColumn(label: Text('Student Name')),
                  DataColumn(label: Text('Class')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Due Date')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: invoices.map((info) {
                  final inv = info.invoice;
                  final stu = info.student;

                  final studentName = stu?.name ?? 'Unknown Student';
                  final studentClass = stu != null
                      ? '${stu.gradeLevel} - ${stu.section}'
                      : 'N/A';
                  final amount = currencyFormatter.format(inv.netAmount);
                  final dueDate = dateFormatter.format(inv.dueDate);

                  Color statusColor = const Color(0xFFD97706);
                  Color statusBg = const Color(0xFFFEF3C7);
                  String statusText = 'Overdue';

                  return DataRow(
                    cells: [
                      DataCell(Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                primaryPurple.withValues(alpha: 0.2),
                            child: Text(
                              studentName[0].toUpperCase(),
                              style: GoogleFonts.poppins(color: primaryPurple),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            studentName,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      )),
                      DataCell(Text(studentClass)),
                      DataCell(Text(amount)),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusText,
                            style: GoogleFonts.poppins(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(dueDate)),
                      DataCell(
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              color: Color(0xFF9CA3AF)),
                          onSelected: (value) {
                            if (value == 'remind') {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text('Reminder sent to $studentName'),
                                backgroundColor: const Color(0xFF22C55E),
                              ));
                            } else if (value == 'view') {
                              ref.read(selectedTabProvider.notifier).state =
                                  NavigationTab.feeCollection;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'remind', child: Text('Send Reminder')),
                            const PopupMenuItem(
                                value: 'view', child: Text('View Invoice')),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFinancialOverviewChart(DashboardMetrics metrics) {
    final currencyFormatter =
        NumberFormat.compactCurrency(symbol: '₹', decimalDigits: 0);
    final largestValue = metrics.monthlyFinancials.fold<double>(
      0,
      (largest, month) => [largest, month.collections, month.expenses].reduce(
        (currentLargest, value) =>
            currentLargest > value ? currentLargest : value,
      ),
    );
    final hasFinancialData = largestValue > 0;
    // Leave headroom above the highest bar and keep a practical scale for low values.
    final maxY = hasFinancialData ? (largestValue * 1.2).ceilToDouble() : 100.0;
    final gridInterval = maxY / 4;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Overview',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fee Collections vs Operating Expenses',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildLegendItem('Collections', primaryPurple),
              const SizedBox(width: 16),
              _buildLegendItem('Expenses', const Color(0xFFFF6B6B)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: hasFinancialData
                ? BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final isCollection = rodIndex == 0;
                            final type =
                                isCollection ? 'Collections' : 'Expenses';
                            return BarTooltipItem(
                              '$type: ₹${rod.toY.toInt()}',
                              GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 &&
                                  idx < metrics.monthlyFinancials.length) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(
                                    metrics.monthlyFinancials[idx].month,
                                    style: GoogleFonts.poppins(
                                        color: const Color(0xFF6B7280),
                                        fontSize: 12),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                            reservedSize: 28,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 48,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                currencyFormatter.format(value),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF6B7280),
                                  fontSize: 11,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        checkToShowHorizontalLine: (value) =>
                            value % gridInterval < 0.01,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withValues(alpha: 0.2),
                          strokeWidth: 1,
                        ),
                        drawVerticalLine: false,
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: metrics.monthlyFinancials
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final data = entry.value;
                        return _buildBarGroup(
                            index, data.collections, data.expenses);
                      }).toList(),
                    ),
                  )
                : Center(
                    child: Text(
                      'No collections or expenses recorded in the last 6 months.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  BarChartGroupData _buildBarGroup(int x, double collections, double expenses) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: collections,
          color: primaryPurple,
          width: 16,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
        BarChartRodData(
          toY: expenses,
          color: const Color(0xFFFF6B6B),
          width: 16,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildAddTeachersSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Teachers',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Teacher List',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4B5563),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(selectedTabProvider.notifier).state =
                      NavigationTab.staff;
                },
                child: Text(
                  'See All',
                  style: GoogleFonts.poppins(
                    color: primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ref.watch(staffListProvider).when(
                data: (staffList) {
                  final activeTeachers = staffList
                      .where((s) =>
                          s.role.toLowerCase() == 'teacher' && s.isActive)
                      .take(4)
                      .toList();

                  if (activeTeachers.isEmpty) {
                    return Text('No teachers found.',
                        style: GoogleFonts.poppins(color: Colors.grey));
                  }

                  final colors = [
                    (const Color(0xFFFECACA), const Color(0xFFDC2626)),
                    (const Color(0xFFBFDBFE), const Color(0xFF2563EB)),
                    (const Color(0xFFD1FAE5), const Color(0xFF059669)),
                    (const Color(0xFFFDE68A), const Color(0xFFD97706)),
                  ];

                  return Row(
                    children: [
                      ...List.generate(activeTeachers.length, (index) {
                        final t = activeTeachers[index];
                        final initials = t.firstName.isNotEmpty
                            ? t.firstName[0].toUpperCase()
                            : '?';
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildTeacherAvatar(
                              initials,
                              colors[index % colors.length].$1,
                              colors[index % colors.length].$2),
                        );
                      }),
                      InkWell(
                        onTap: () {
                          ref.read(selectedTabProvider.notifier).state =
                              NavigationTab.staff;
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.grey.shade300,
                                style: BorderStyle.solid),
                          ),
                          child: Center(
                            child: Icon(Icons.add,
                                color: Colors.grey.shade600, size: 20),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, s) => Text('Error loading teachers',
                    style: GoogleFonts.poppins(color: Colors.red)),
              ),
          const SizedBox(height: 32),
          Text(
            'Add Teachers Via E-Mail',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inviteEmailController,
                  decoration: InputDecoration(
                    hintText: 'Enter Email Address',
                    hintStyle: GoogleFonts.poppins(
                        color: const Color(0xFF9CA3AF), fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  if (_inviteEmailController.text.isNotEmpty &&
                      _inviteEmailController.text.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'Invitation sent to ${_inviteEmailController.text}!'),
                      backgroundColor: const Color(0xFF22C55E),
                    ));
                    _inviteEmailController.clear();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Please enter a valid email address.'),
                      backgroundColor: Color(0xFFEF4444),
                    ));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'Invite',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleRenewalAlertBanner() {
    final vehiclesAsync = ref.watch(vehiclesNeedingRenewalProvider);
    return vehiclesAsync.when(
      data: (vehicles) {
        if (vehicles.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fleet Compliance Alert: ${vehicles.length} Vehicle(s) Require Immediate Renewal',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF991B1B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Insurance or Fitness certificates for (${vehicles.map((v) => v.vehicleNumber).join(', ')}) expire within 30 days.',
                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF7F1D1D)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(selectedTabProvider.notifier).state = NavigationTab.transport;
                  },
                  child: Text(
                    'Manage Fleet →',
                    style: GoogleFonts.poppins(color: const Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildTeacherAvatar(String initials, Color bgColor, Color textColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
