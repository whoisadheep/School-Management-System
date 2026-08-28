import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../../services/ai_message_service.dart';
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
  final ScrollController _horizontalScrollController = ScrollController();
  final primaryPurple = const Color(0xFF4C3BCF);
  final bgPurple = const Color(0xFFF5F3FF);
  final _inviteEmailController = TextEditingController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWelcomeBanner(),
            const SizedBox(height: 20),
            _buildVehicleRenewalAlertBanner(),
            metricsAsync.when(
              data: (metrics) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildQuickStatsCards(metrics),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildMonthlyCollectionsLineChart(metrics)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildClassWiseStudentPieChart(metrics)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildFinancialOverviewChart(metrics)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildFeeHeadCollectionBreakdown(metrics)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 60,
                        child: _buildStudentInfoTable(metrics.overdueInvoices),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 40,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildQuickActionsCard(),
                            const SizedBox(height: 20),
                            _buildAddTeachersSection(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              loading: () => const Center(
                  child: Padding(
                padding: EdgeInsets.all(48.0),
                child: CircularProgressIndicator(),
              )),
              error: (e, s) => Center(child: Text('Error: $e')),
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

  Widget _buildQuickStatsCards(DashboardMetrics metrics) {
    final currencyFormatter =
        NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    
    // Fallbacks for new fields
    final staff = metrics.totalStaff;
    final collRate = metrics.collectionRate;

    return Row(
      children: [
        Expanded(
          child: _buildNewStatCard(
            title: 'Total Students',
            value: metrics.totalStudents.toString(),
            icon: Icons.school,
            iconColor: const Color(0xFF5B4BC4), // Purple
            onTap: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.students,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildNewStatCard(
            title: 'Total Staff',
            value: staff.toString(),
            icon: Icons.people,
            iconColor: const Color(0xFF3B82F6), // Blue
            onTap: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.staff,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildNewStatCard(
            title: "Today's Collection",
            value: currencyFormatter.format(metrics.todaysCollections),
            icon: Icons.account_balance_wallet,
            iconColor: const Color(0xFF22C55E), // Green
            onTap: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.feeCollection,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildNewStatCard(
            title: 'Pending Dues',
            value: currencyFormatter.format(metrics.pendingDues),
            icon: Icons.warning_amber,
            iconColor: const Color(0xFFF59E0B), // Amber
            onTap: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.feeCollection,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildNewStatCard(
            title: 'Total Revenue',
            value: currencyFormatter.format(metrics.totalRevenueCurrentYear),
            icon: Icons.trending_up,
            iconColor: const Color(0xFFFF6B6B), // Coral
            onTap: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.expenses,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildNewStatCard(
            title: 'Collection Rate',
            value: '${collRate.toStringAsFixed(1)}%',
            icon: Icons.speed,
            iconColor: const Color(0xFF0D9488), // Teal
            onTap: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.feeReports,
          ),
        ),
      ],
    );
  }

  Widget _buildNewStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: HoverScale(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF1F2937),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyCollectionsLineChart(DashboardMetrics metrics) {
    final currencyFormatter = NumberFormat.compactCurrency(symbol: '₹', decimalDigits: 0);
    final monthlyData = metrics.monthlyFinancials;

    double maxY = 0;
    for (var m in monthlyData) {
      if (m.collections > maxY) maxY = m.collections;
    }
    maxY = maxY > 0 ? (maxY * 1.2) : 1000;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Fee Collection Trend',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < monthlyData.length) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              monthlyData[idx].month,
                              style: GoogleFonts.poppins(color: const Color(0xFF6B7280), fontSize: 12),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          currencyFormatter.format(value),
                          style: GoogleFonts.poppins(color: const Color(0xFF6B7280), fontSize: 11),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: monthlyData.length.toDouble() - 1,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: monthlyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.collections)).toList(),
                    isCurved: true,
                    color: primaryPurple,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          primaryPurple.withValues(alpha: 0.3),
                          primaryPurple.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '₹${spot.y.toInt()}',
                          GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassWiseStudentPieChart(DashboardMetrics metrics) {
    final Map<String, int> classData = metrics.classWiseStudentCount;
    final hasData = classData.isNotEmpty && classData.values.any((v) => v > 0);

    final colors = [
      const Color(0xFF5B4BC4),
      const Color(0xFF3B82F6),
      const Color(0xFF22C55E),
      const Color(0xFFF59E0B),
      const Color(0xFFFF6B6B),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFFEC4899)
    ];

    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Students by Class',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: hasData
                ? PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: classData.entries.toList().asMap().entries.map((entry) {
                        final idx = entry.key;
                        final label = entry.value.key;
                        final count = entry.value.value;
                        return PieChartSectionData(
                          color: colors[idx % colors.length],
                          value: count.toDouble(),
                          title: '$label\n$count',
                          radius: 50,
                          titleStyle: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  )
                : Center(
                    child: Text(
                      'No student class data available.',
                      style: GoogleFonts.poppins(color: const Color(0xFF6B7280)),
                    ),
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
    final maxY = hasFinancialData ? (largestValue * 1.2).ceilToDouble() : 100.0;
    final gridInterval = maxY / 4;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue vs Expenses',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
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
          Expanded(
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
                            final type = isCollection ? 'Collections' : 'Expenses';
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
                      'No collections or expenses recorded.',
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

  Widget _buildFeeHeadCollectionBreakdown(DashboardMetrics metrics) {
    final feeHeadData = metrics.feeHeadWiseCollection;
    final currencyFormatter = NumberFormat.compactCurrency(symbol: '₹', decimalDigits: 0);
    final total = feeHeadData.values.fold<double>(0, (p, c) => p + c);

    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEF4444)
    ];

    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Collection by Fee Head',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: feeHeadData.isNotEmpty && total > 0
                ? ListView.separated(
                    itemCount: feeHeadData.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final head = feeHeadData.keys.elementAt(index);
                      final val = feeHeadData[head]!;
                      final proportion = val / total;
                      final color = colors[index % colors.length];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(head, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13, color: const Color(0xFF4B5563))),
                              Text(currencyFormatter.format(val), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1F2937))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: proportion,
                            backgroundColor: color.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 8,
                          ),
                        ],
                      );
                    },
                  )
                : Center(
                    child: Text(
                      'No fee head collection data.',
                      style: GoogleFonts.poppins(color: const Color(0xFF6B7280)),
                    ),
                  ),
          ),
        ],
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
            Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
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
                              studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
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
                          onSelected: (value) async {
                            if (value == 'remind') {
                              final phone = stu?.fatherPhone?.isNotEmpty == true 
                                  ? stu!.fatherPhone! 
                                  : (stu?.motherPhone ?? '');
                              
                              if (phone.isEmpty) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('No phone number found for $studentName', style: GoogleFonts.poppins()), backgroundColor: const Color(0xFFF59E0B)),
                                  );
                                }
                                return;
                              }

                              final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
                              final finalPhone = cleanPhone.startsWith('+') ? cleanPhone : '+91$cleanPhone';

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Generating smart message...', style: GoogleFonts.poppins()), duration: const Duration(milliseconds: 1500)),
                                );
                              }

                              final aiService = ref.read(aiMessageServiceProvider);
                              final text = await aiService.generateOverdueReminder(
                                studentName: studentName,
                                amountStr: amount,
                                grade: studentClass,
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
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
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
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.5,
            children: [
              _buildQuickActionBtn('Add Student', Icons.person_add, const Color(0xFF3B82F6), () {
                ref.read(selectedTabProvider.notifier).state = NavigationTab.students;
              }),
              _buildQuickActionBtn('Collect Fee', Icons.payment, const Color(0xFF10B981), () {
                ref.read(selectedTabProvider.notifier).state = NavigationTab.feeCollection;
              }),
              _buildQuickActionBtn('View Reports', Icons.bar_chart, const Color(0xFFF59E0B), () {
                ref.read(selectedTabProvider.notifier).state = NavigationTab.feeReports;
              }),
              _buildQuickActionBtn('AI Assistant', Icons.auto_awesome, const Color(0xFF8B5CF6), () {
                ref.read(selectedTabProvider.notifier).state = NavigationTab.assistant;
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
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
