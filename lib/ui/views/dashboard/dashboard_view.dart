import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../../services/ai_message_service.dart';
import '../../../services/sound_service.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/services_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../layout/widgets/hover_scale.dart';
import '../../widgets/thinking_orb_widget.dart';
import '../../widgets/motion_effects.dart';
import '../../widgets/satisfying_button.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  // Centerpiece chart active tab: 0: Cash Flow (Collections vs Expenses), 1: Fee Heads, 2: Class Strength
  int _activeChartTab = 0;

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Time-Aware Welcome Greeting & Fast Action Header
            _buildHeaderGreeting().motionEntrance(slideOffsetY: -0.05),
            const SizedBox(height: 20),

            // 2. Urgent Vehicle Renewal Alert (if any)
            _buildVehicleRenewalAlertBanner(),

            metricsAsync.when(
              data: (metrics) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 3. Four Clear, High-Impact Metric Cards (Not 6 cramped ones)
                  _buildFourKeyMetrics(metrics),
                  const SizedBox(height: 24),

                  // 4. THE ONE CENTERPIECE CHART (Interactive, uncluttered, story-driven)
                  _buildOneCenterpieceChart(metrics).motionEntrance(index: 2, stagger: const Duration(milliseconds: 70)),
                  const SizedBox(height: 24),

                  // 5. Bottom Split: Needs Attention (60%) + Quick Action Launcher (40%)
                  _buildBottomSplitSection(metrics).motionEntrance(index: 3, stagger: const Duration(milliseconds: 70)),
                  const SizedBox(height: 20),
                ],
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(64.0),
                  child: ThinkingLoadingCard(
                    message: 'Loading dashboard...',
                    subMessage: 'Calculating live academic & financial metrics',
                    state: OrbState.working,
                    size: 48,
                  ),
                ),
              ),
              error: (e, s) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text('Error loading dashboard: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TIME-AWARE GREETING & FAST ACTIONS HEADER
  // ---------------------------------------------------------------------------
  Widget _buildHeaderGreeting() {
    final schoolName = ref.watch(schoolNameProvider).value ?? 'Eduvia';
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final formattedDate = DateFormat('EEEE, MMMM d, y').format(now);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryPurple, AppTheme.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting, $schoolName 👋',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            formattedDate,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Text(
                            'Live Academic & Financial Pulse',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.primaryPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              SatisfyingButton(
                isSecondary: true,
                icon: Icons.person_search_rounded,
                text: 'Find Student',
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onPressed: () {
                  ref.read(selectedTabProvider.notifier).state = NavigationTab.students;
                },
              ),
              const SizedBox(width: 10),
              SatisfyingButton(
                icon: Icons.add_rounded,
                text: 'Collect Fee',
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onPressed: () {
                  ref.read(selectedTabProvider.notifier).state = NavigationTab.feeCollection;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. FLEET COMPLIANCE ALERT BANNER
  // ---------------------------------------------------------------------------
  Widget _buildVehicleRenewalAlertBanner() {
    final vehiclesAsync = ref.watch(vehiclesNeedingRenewalProvider);
    return vehiclesAsync.when(
      data: (vehicles) {
        if (vehicles.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fleet Compliance Alert: ${vehicles.length} Vehicle(s) Require Renewal',
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
                SatisfyingButton(
                  text: 'Manage Fleet',
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: const Color(0xFFDC2626),
                  onPressed: () {
                    ref.read(selectedTabProvider.notifier).state = NavigationTab.transport;
                  },
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

  // ---------------------------------------------------------------------------
  // 3. FOUR CLEAR, HIGH-IMPACT METRIC CARDS
  // ---------------------------------------------------------------------------
  Widget _buildFourKeyMetrics(DashboardMetrics metrics) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    final cards = [
      _buildSingleKpiCard(
        title: "Today's Collection",
        value: currencyFormatter.format(metrics.todaysCollections),
        subtitle: '${metrics.todaysTransactionCount} payments collected today',
        icon: Icons.payments_rounded,
        accentColor: const Color(0xFF10B981), // Emerald
        onTap: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.feeCollection,
      ),
      _buildSingleKpiCard(
        title: 'Pending Dues',
        value: currencyFormatter.format(metrics.pendingDues),
        subtitle: '${metrics.overdueInvoices.length} invoices overdue',
        icon: Icons.pending_actions_rounded,
        accentColor: const Color(0xFFF59E0B), // Amber
        onTap: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.feeCollection,
      ),
      _buildSingleKpiCard(
        title: 'School Community',
        value: '${metrics.totalStudents} Students',
        subtitle: '${metrics.totalStaff} Faculty & Staff Members',
        icon: Icons.groups_rounded,
        accentColor: AppTheme.primaryPurple, // Royal Purple
        onTap: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.students,
      ),
      _buildSingleKpiCard(
        title: 'Collection Efficiency',
        value: '${metrics.collectionRate.toStringAsFixed(1)}%',
        subtitle: 'Annual collection rate',
        icon: Icons.trending_up_rounded,
        accentColor: const Color(0xFF0D9488), // Teal
        onTap: () => ref.read(selectedTabProvider.notifier).state = NavigationTab.feeReports,
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(
            child: cards[i].motionEntrance(index: i, stagger: const Duration(milliseconds: 50)),
          ),
        ],
      ],
    );
  }

  Widget _buildSingleKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          SoundService().playClick();
          onTap();
        },
        child: HoverScale(
          scale: 1.02,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: accentColor, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  // ---------------------------------------------------------------------------
  // 4. THE ONE CENTERPIECE CHART (Story-Driven & Interactive)
  // ---------------------------------------------------------------------------
  Widget _buildOneCenterpieceChart(DashboardMetrics metrics) {
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
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart Header & Interactive Tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.analytics_rounded, color: AppTheme.primaryPurple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'School Analytics & Financial Health',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        _activeChartTab == 0
                            ? 'Monthly Fee Collections vs Operational Expenses'
                            : _activeChartTab == 1
                                ? 'Fee Collections by Category (Tuition, Transport, etc.)'
                                : 'Student Distribution Across Classes',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),

              // Segmented Tabs Switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.bgMain,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    _buildChartTabButton(0, 'Cash Flow', Icons.waterfall_chart_rounded),
                    const SizedBox(width: 4),
                    _buildChartTabButton(1, 'Fee Categories', Icons.pie_chart_outline_rounded),
                    const SizedBox(width: 4),
                    _buildChartTabButton(2, 'Class Strength', Icons.bar_chart_rounded),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart Display (Animated Switcher between perspectives)
          SizedBox(
            height: 300,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey<int>(_activeChartTab),
                child: _activeChartTab == 0
                    ? _buildCashFlowChart(metrics)
                    : _activeChartTab == 1
                        ? _buildFeeHeadBreakdownView(metrics)
                        : _buildClassStrengthChartView(metrics),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTabButton(int index, String title, IconData icon) {
    final isSelected = _activeChartTab == index;
    return GestureDetector(
      onTap: () {
        SoundService().playClick();
        setState(() => _activeChartTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Perspective 1: Cash Flow (Collections vs Expenses) ---
  Widget _buildCashFlowChart(DashboardMetrics metrics) {
    final currencyFormatter = NumberFormat.compactCurrency(symbol: '₹', decimalDigits: 0);
    final monthlyData = metrics.monthlyFinancials;

    if (monthlyData.isEmpty) {
      return Center(
        child: Text('No financial data available for the current session.', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
      );
    }

    double maxY = 0;
    for (var m in monthlyData) {
      if (m.collections > maxY) maxY = m.collections;
      if (m.expenses > maxY) maxY = m.expenses;
    }
    maxY = maxY > 0 ? (maxY * 1.25) : 1000;

    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildChartLegendItem('Collections', AppTheme.primaryPurple),
            const SizedBox(width: 20),
            _buildChartLegendItem('Expenses', const Color(0xFFFF6B6B)),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppTheme.divider.withValues(alpha: 0.6),
                  strokeWidth: 1,
                  dashArray: [4, 4],
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
                            style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 11),
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
                    reservedSize: 56,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        currencyFormatter.format(value),
                        style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 11),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: monthlyData.length > 1 ? (monthlyData.length - 1).toDouble() : 1.0,
              minY: 0,
              maxY: maxY,
              lineBarsData: [
                // Collections Line
                LineChartBarData(
                  spots: monthlyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.collections)).toList(),
                  isCurved: true,
                  color: AppTheme.primaryPurple,
                  barWidth: 3.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryPurple.withValues(alpha: 0.22),
                        AppTheme.primaryPurple.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // Expenses Line
                LineChartBarData(
                  spots: monthlyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.expenses)).toList(),
                  isCurved: true,
                  color: const Color(0xFFFF6B6B),
                  barWidth: 2.5,
                  dashArray: [5, 4],
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final isCollection = spot.barIndex == 0;
                      return LineTooltipItem(
                        '${isCollection ? "Collections" : "Expenses"}: ₹${spot.y.toInt()}',
                        GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Perspective 2: Fee Head Distribution ---
  Widget _buildFeeHeadBreakdownView(DashboardMetrics metrics) {
    final feeHeadData = metrics.feeHeadWiseCollection;
    final currencyFormatter = NumberFormat.compactCurrency(symbol: '₹', decimalDigits: 0);
    final total = feeHeadData.values.fold<double>(0, (p, c) => p + c);

    if (feeHeadData.isEmpty || total <= 0) {
      return Center(
        child: Text('No fee head collection data recorded yet.', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
      );
    }

    final colors = [
      AppTheme.primaryPurple,
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF0D9488),
    ];

    return ListView.separated(
      itemCount: feeHeadData.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final head = feeHeadData.keys.elementAt(index);
        final val = feeHeadData[head]!;
        final proportion = total > 0 ? (val / total) : 0.0;
        final color = colors[index % colors.length];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(head, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                    const SizedBox(width: 8),
                    Text('(${(proportion * 100).toStringAsFixed(1)}%)', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
                Text(currencyFormatter.format(val), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 6),
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
    );
  }

  // --- Perspective 3: Class Strength ---
  Widget _buildClassStrengthChartView(DashboardMetrics metrics) {
    final Map<String, int> classData = metrics.classWiseStudentCount;
    if (classData.isEmpty || !classData.values.any((v) => v > 0)) {
      return Center(
        child: Text('No student class distribution data available.', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
      );
    }

    final entries = classData.entries.toList();
    final maxCount = entries.fold<int>(0, (prev, e) => e.value > prev ? e.value : prev);

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 3.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: entries.length,
      itemBuilder: (context, idx) {
        final item = entries[idx];
        final ratio = maxCount > 0 ? (item.value / maxCount) : 0.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.bgMain,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.key, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                  Text('${item.value} Students', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.primaryPurple)),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: ratio,
                backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. BOTTOM SPLIT: NEEDS ATTENTION (60%) + QUICK ACTION LAUNCHER (40%)
  // ---------------------------------------------------------------------------
  Widget _buildBottomSplitSection(DashboardMetrics metrics) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Needs Attention (Overdue Dues)
        Expanded(
          flex: 60,
          child: _buildNeedsAttentionCard(metrics.overdueInvoices),
        ),
        const SizedBox(width: 24),

        // Right Column: Quick Action Launcher with Satisfying Buttons
        Expanded(
          flex: 40,
          child: _buildQuickActionLauncher(),
        ),
      ],
    );
  }

  Widget _buildNeedsAttentionCard(List<OverdueInvoiceInfo> overdueList) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final dateFormatter = DateFormat('dd MMM yyyy');

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
          ),
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
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Needs Attention',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Top pending fee defaulters requiring follow-up',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              if (overdueList.isNotEmpty)
                TextButton(
                  onPressed: () {
                    SoundService().playClick();
                    ref.read(selectedTabProvider.notifier).state = NavigationTab.feeCollection;
                  },
                  child: Text(
                    'See All (${overdueList.length}) →',
                    style: GoogleFonts.poppins(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          if (overdueList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 40),
                  const SizedBox(height: 10),
                  Text(
                    'All Caught Up! 🎉',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF15803D)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'There are no overdue fee payments pending right now.',
                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF166534)),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: overdueList.take(5).length,
              separatorBuilder: (_, __) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, idx) {
                final info = overdueList[idx];
                final stu = info.student;
                final inv = info.invoice;
                final studentName = stu?.name ?? 'Unknown Student';
                final studentClass = stu != null ? '${stu.gradeLevel} - ${stu.section}' : 'N/A';
                final amount = currencyFormatter.format(inv.netAmount);
                final dueDate = dateFormatter.format(inv.dueDate);

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFFEF3C7),
                      child: Text(
                        studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                        style: GoogleFonts.poppins(color: const Color(0xFFB45309), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$studentClass  •  Due: $dueDate',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          amount,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFFDC2626)),
                        ),
                        Text('Overdue', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // WhatsApp Smart Reminder Action
                    IconButton(
                      icon: const Icon(Icons.send_rounded, size: 18, color: Color(0xFF25D366)),
                      tooltip: 'Send WhatsApp Reminder',
                      onPressed: () => _sendWhatsAppReminder(studentName, studentClass, amount, stu),
                    ),

                    // Satisfying Collect Fee Button
                    SatisfyingButton(
                      text: 'Collect',
                      icon: Icons.receipt_rounded,
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      color: AppTheme.primaryPurple,
                      onPressed: () {
                        ref.read(selectedTabProvider.notifier).state = NavigationTab.feeCollection;
                      },
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionLauncher() {
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
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded, color: AppTheme.primaryPurple, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  Text(
                    'Instant access to frequent school workflows',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4 Tactile, Deeply Satisfying Action Cards
          SatisfyingActionCard(
            title: 'Collect Fee',
            subtitle: 'Search student, apply discount & print receipt',
            icon: Icons.receipt_long_rounded,
            iconColor: AppTheme.primaryPurple,
            onTap: () {
              ref.read(selectedTabProvider.notifier).state = NavigationTab.feeCollection;
            },
          ),
          const SizedBox(height: 12),

          SatisfyingActionCard(
            title: 'Student Directory',
            subtitle: 'Manage admissions, roll numbers & profiles',
            icon: Icons.school_rounded,
            iconColor: const Color(0xFF3B82F6),
            onTap: () {
              ref.read(selectedTabProvider.notifier).state = NavigationTab.students;
            },
          ),
          const SizedBox(height: 12),

          SatisfyingActionCard(
            title: 'Mark Attendance',
            subtitle: 'Daily student roll call & teacher tracking',
            icon: Icons.fact_check_rounded,
            iconColor: const Color(0xFF10B981),
            onTap: () {
              ref.read(selectedTabProvider.notifier).state = NavigationTab.attendance;
            },
          ),
          const SizedBox(height: 12),

          SatisfyingActionCard(
            title: 'AI Assistant',
            subtitle: 'Query attendance, fees, ledger & reports',
            icon: Icons.auto_awesome_rounded,
            iconColor: const Color(0xFFF59E0B),
            onTap: () {
              ref.read(selectedTabProvider.notifier).state = NavigationTab.assistant;
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SMART WHATSAPP REMINDER LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _sendWhatsAppReminder(String studentName, String studentClass, String amount, dynamic stu) async {
    final phone = stu?.fatherPhone?.isNotEmpty == true
        ? stu!.fatherPhone!
        : (stu?.motherPhone ?? '');

    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No contact phone number found for $studentName', style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFFF59E0B),
          ),
        );
      }
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final finalPhone = cleanPhone.startsWith('+') ? cleanPhone : '+91$cleanPhone';

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generating smart reminder...', style: GoogleFonts.poppins()),
          duration: const Duration(milliseconds: 1500),
        ),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch WhatsApp.', style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}
