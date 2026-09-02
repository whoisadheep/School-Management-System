import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../core/auth/permission_helper.dart';
import '../../../providers/services_provider.dart';

/// Transport Management View — Fleet Overview, Vehicle Setup,
/// Route & Stop Configuration, and Driver Route Manifest.
class TransportView extends ConsumerStatefulWidget {
  const TransportView({super.key});

  @override
  ConsumerState<TransportView> createState() => _TransportViewState();
}

class _TransportViewState extends ConsumerState<TransportView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _dateFormat = DateFormat('dd MMM yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  String? _selectedManifestRouteId;

  String _allocationSearchQuery = '';
  String _allocationClassFilter = 'All Classes';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

          // Navigation TabBar
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
                Tab(text: 'Fleet Overview & Vehicles'),
                Tab(text: 'Routes & Ordered Stops'),
                Tab(text: 'Student Allocations & Fees'),
                Tab(text: 'Driver Route Manifest'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFleetOverviewTab(),
                _buildRoutesAndStopsTab(),
                _buildStudentAllocationsTab(),
                _buildRouteManifestTab(),
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
                'Transport Management',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                'Manage vehicle fleet, assign staff drivers, configure routes & stops, and view driver manifests.',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 1: FLEET OVERVIEW & VEHICLES
  // ============================================================================

  Widget _buildFleetOverviewTab() {
    final fleetAsync = ref.watch(fleetOverviewProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fleet Overview Stats
          fleetAsync.when(
            data: (fleetList) {
              int totalCapacity = 0;
              int totalAssigned = 0;
              int renewalAlerts = 0;
              for (final item in fleetList) {
                totalCapacity += (item['capacity'] as int? ?? 0);
                totalAssigned += (item['assigned_students'] as int? ?? 0);
                if (item['needs_renewal'] == true) renewalAlerts++;
              }

              return Row(
                children: [
                  _statCard('Total Fleet Vehicles', '${fleetList.length}', Icons.directions_bus_rounded, AppTheme.primaryPurple),
                  const SizedBox(width: 16),
                  _statCard('Total Seating Capacity', '$totalCapacity seats', Icons.airline_seat_recline_normal_rounded, AppTheme.info),
                  const SizedBox(width: 16),
                  _statCard('Enrolled Students', '$totalAssigned assigned', Icons.people_alt_rounded, AppTheme.success),
                  const SizedBox(width: 16),
                  _statCard('Compliance Renewal Alerts', '$renewalAlerts vehicle(s)', Icons.warning_amber_rounded,
                      renewalAlerts > 0 ? AppTheme.error : AppTheme.success),
                ],
              );
            },
            loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (e, _) => Text('Error loading fleet stats: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
          ),
          const SizedBox(height: 24),

          // Header + Add Vehicle Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fleet Vehicles List',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditVehicleDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Add Vehicle', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vehicles Table
          vehiclesAsync.when(
            data: (vehicles) {
              if (vehicles.isEmpty) {
                return _buildEmptyCard('No vehicles added yet. Click "Add Vehicle" to register fleet buses or vans.');
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
                          _th('Vehicle Number', flex: 3),
                          _th('Type', flex: 2),
                          _th('Capacity', flex: 2),
                          _th('Assigned Driver (Staff)', flex: 4),
                          _th('Conductor', flex: 3),
                          _th('Insurance Expiry', flex: 3),
                          _th('Fitness Expiry', flex: 3),
                          _th('Status', flex: 2),
                          _th('Actions', flex: 2),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.divider),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: vehicles.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                      itemBuilder: (context, index) {
                        final v = vehicles[index];
                        final insAlert = v.insuranceExpiry != null && v.insuranceExpiry!.isBefore(DateTime.now().add(const Duration(days: 30)));
                        final fitAlert = v.fitnessExpiry != null && v.fitnessExpiry!.isBefore(DateTime.now().add(const Duration(days: 30)));

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(v.vehicleNumber, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(v.vehicleType.toUpperCase(),
                                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('${v.capacity} seats', style: GoogleFonts.poppins(fontSize: 12)),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(v.driverName ?? 'Unassigned',
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: v.driverName != null ? FontWeight.w600 : FontWeight.normal)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(v.conductorName ?? 'N/A', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  v.insuranceExpiry != null ? _dateFormat.format(v.insuranceExpiry!) : 'N/A',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: insAlert ? FontWeight.bold : FontWeight.normal,
                                    color: insAlert ? AppTheme.error : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  v.fitnessExpiry != null ? _dateFormat.format(v.fitnessExpiry!) : 'N/A',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: fitAlert ? FontWeight.bold : FontWeight.normal,
                                    color: fitAlert ? AppTheme.error : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  v.isActive ? 'Active' : 'Inactive',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: v.isActive ? AppTheme.success : AppTheme.textHint,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      onPressed: () => _showAddEditVehicleDialog(context, vehicle: v),
                                      tooltip: 'Edit Vehicle',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                                      onPressed: () {
                                        if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.deleteRecord)) return;
                                        _confirmDeleteVehicle(context, v);
                                      },
                                      tooltip: 'Delete Vehicle',
                                    ),
                                  ],
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
            error: (e, _) => Text('Error loading vehicles: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 2: ROUTES & STOPS SETUP
  // ============================================================================

  Widget _buildRoutesAndStopsTab() {
    final routesAsync = ref.watch(routesListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transport Routes Configuration',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditRouteDialog(context),
                icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                label: Text('Create New Route', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          routesAsync.when(
            data: (routes) {
              if (routes.isEmpty) {
                return _buildEmptyCard('No transport routes configured. Click "Create New Route" to set up pick-up and drop-off lines.');
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: routes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final route = routes[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.alt_route_rounded, color: AppTheme.primaryPurple, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  route.routeName,
                                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgSurface,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.divider),
                                  ),
                                  child: Text(
                                    'Vehicle: ${route.vehicleNumber ?? "Unassigned"}',
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showManageStopsDialog(context, route),
                                  icon: const Icon(Icons.edit_road_rounded, size: 16),
                                  label: Text('Manage Stops (${route.stops.length})', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryPurple,
                                    side: const BorderSide(color: AppTheme.primaryPurple),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _showAddEditRouteDialog(context, route: route),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                                  onPressed: () {
                                    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.deleteRecord)) return;
                                    _confirmDeleteRoute(context, route);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start Point: ${route.startPoint}  ➔  End Point: ${route.endPoint}',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppTheme.divider),
                        const SizedBox(height: 12),

                        // Ordered Stops Preview Chips
                        Text('Ordered Stops (${route.stops.length}):',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textHint)),
                        const SizedBox(height: 8),
                        route.stops.isEmpty
                            ? Text('No stops defined for this route yet.', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint))
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: route.stops.map((stop) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bgSurface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.divider),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 9,
                                          backgroundColor: AppTheme.primaryPurple,
                                          child: Text('${stop.stopOrder}',
                                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(stop.stopName, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                                        if (stop.fee > 0)
                                          Text(
                                            ' (₹${stop.fee.toStringAsFixed(0)}/mo)',
                                            style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.success, fontWeight: FontWeight.w600),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Text('Error loading routes: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 3: STUDENT ALLOCATIONS & TRANSPORT FEES
  // ============================================================================

  Widget _buildStudentAllocationsTab() {
    final currentYear = ref.watch(currentAcademicYearProvider).value?.name;
    final academicYear = currentYear ?? '2024-2025';
    final transportsAsync = ref.watch(allStudentTransportsProvider(academicYear));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student Transport Allocations & Fees',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Assign students to routes and stops. Monthly fees are derived automatically from the stop configuration.',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAssignStudentTransportDialog(context),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text('Assign Student', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Overview Stats
          transportsAsync.when(
            data: (transports) {
              final totalAssigned = transports.length;
              final double totalMonthlyFee = transports.fold(0.0, (sum, st) => sum + st.monthlyFee);

              return Row(
                children: [
                  _statCard('Total Students on Transport', '$totalAssigned', Icons.directions_bus_rounded, AppTheme.primaryPurple),
                  const SizedBox(width: 16),
                  _statCard('Monthly Transport Revenue', _currencyFormat.format(totalMonthlyFee), Icons.payments_rounded, AppTheme.success),
                  const SizedBox(width: 16),
                  _statCard('Average Fee per Student', totalAssigned > 0 ? _currencyFormat.format(totalMonthlyFee / totalAssigned) : '₹0', Icons.analytics_rounded, AppTheme.info),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),

          // Search & Class Filter Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search assigned student by name, roll number, or stop...',
                    hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.divider)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.divider)),
                  ),
                  onChanged: (val) => setState(() => _allocationSearchQuery = val.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _allocationClassFilter,
                      isExpanded: true,
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                      items: [
                        'All Classes',
                        'Nursery', 'LKG', 'UKG',
                        'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5',
                        'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10',
                        'Grade 11', 'Grade 12',
                      ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _allocationClassFilter = val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Allocations Table
          transportsAsync.when(
            data: (transports) {
              final filtered = transports.where((st) {
                if (_allocationClassFilter != 'All Classes' && st.gradeLevel != _allocationClassFilter) {
                  return false;
                }
                if (_allocationSearchQuery.isEmpty) return true;
                final name = (st.studentName ?? '').toLowerCase();
                final roll = (st.rollNumber ?? '').toLowerCase();
                final grade = (st.gradeLevel ?? '').toLowerCase();
                final route = (st.routeName ?? '').toLowerCase();
                final stop = (st.stopName ?? '').toLowerCase();
                return name.contains(_allocationSearchQuery) ||
                    roll.contains(_allocationSearchQuery) ||
                    grade.contains(_allocationSearchQuery) ||
                    route.contains(_allocationSearchQuery) ||
                    stop.contains(_allocationSearchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return _buildEmptyCard('No transport allocations found. Click "Assign Student" to assign a student to a route and stop.');
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
                          _th('Student Name', flex: 4),
                          _th('Roll No', flex: 2),
                          _th('Class & Sec', flex: 2),
                          _th('Assigned Route', flex: 3),
                          _th('Assigned Stop', flex: 3),
                          _th('Monthly Fee', flex: 3),
                          _th('Actions', flex: 2),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.divider),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                      itemBuilder: (context, index) {
                        final st = filtered[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(st.studentName ?? 'Student', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(st.rollNumber ?? 'N/A', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('${st.gradeLevel ?? "-"} ${st.section ?? ""}', style: GoogleFonts.poppins(fontSize: 12)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(st.routeName ?? 'Unassigned Route', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(st.stopName ?? 'N/A', style: GoogleFonts.poppins(fontSize: 12)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_currencyFormat.format(st.monthlyFee)}/mo',
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.success),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      tooltip: 'Change Route / Stop',
                                      onPressed: () => _showAssignStudentTransportDialog(context, existing: st),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.person_remove_rounded, size: 18, color: AppTheme.error),
                                      tooltip: 'Remove Transport',
                                      onPressed: () => _confirmRemoveTransport(context, st),
                                    ),
                                  ],
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
            error: (e, _) => Text('Error loading student transport: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  void _showAssignStudentTransportDialog(BuildContext context, {StudentTransport? existing}) {
    final currentYear = ref.watch(currentAcademicYearProvider).value?.name;
    final academicYear = existing?.academicYear ?? currentYear ?? '2024-2025';
    String? selectedStudentId = existing?.studentId;
    Student? selectedStudentObj;
    String filterClass = 'All Classes';
    String? selectedRouteId = existing?.routeId;
    String? selectedStopId = existing?.stopId;
    double currentStopFee = existing?.monthlyFee ?? 0;
    List<RouteStop> availableStops = [];

    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final studentsAsync = ref.watch(studentsListProvider);
          final routesAsync = ref.watch(routesListProvider);

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Row(
                  children: [
                    const Icon(Icons.directions_bus_rounded, color: AppTheme.primaryPurple, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      existing != null ? 'Edit Transport Assignment' : 'Assign Student to Transport',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Select Student
                      Text('Select Student *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      studentsAsync.when(
                        data: (students) {
                          if (existing != null) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.bgSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppTheme.primaryPurple,
                                    child: Text(
                                      existing.studentName?.isNotEmpty == true ? existing.studentName![0].toUpperCase() : 'S',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(existing.studentName ?? "Student", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                                        Text('Class: ${existing.gradeLevel ?? "-"} ${existing.section ?? ""} • Roll: ${existing.rollNumber ?? "N/A"}',
                                            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // If already chosen in this dialog:
                          if (selectedStudentObj != null) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppTheme.primaryPurple,
                                    child: Text(
                                      selectedStudentObj!.name.isNotEmpty ? selectedStudentObj!.name[0].toUpperCase() : 'S',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(selectedStudentObj!.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                        Text(
                                          'Class: ${selectedStudentObj!.gradeLevel} ${selectedStudentObj!.section ?? ""} • Roll: ${selectedStudentObj!.rollNumber ?? "N/A"} • ID: ${selectedStudentObj!.id.substring(0, 8)}',
                                          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      setDialogState(() {
                                        selectedStudentObj = null;
                                        selectedStudentId = null;
                                      });
                                    },
                                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                                    label: const Text('Change'),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Search + Class filter when picking student
                          final availableClasses = ['All Classes', ...{for (var s in students) s.gradeLevel}];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Class Filter Dropdown
                                  SizedBox(
                                    width: 140,
                                    child: DropdownButtonFormField<String>(
                                      value: availableClasses.contains(filterClass) ? filterClass : 'All Classes',
                                      isDense: true,
                                      decoration: InputDecoration(
                                        labelText: 'Class',
                                        labelStyle: GoogleFonts.poppins(fontSize: 11),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      ),
                                      items: availableClasses.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.poppins(fontSize: 12)))).toList(),
                                      onChanged: (val) {
                                        if (val != null) setDialogState(() => filterClass = val);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Search Field with Autocomplete
                                  Expanded(
                                    child: Autocomplete<Student>(
                                      displayStringForOption: (s) => '${s.name} (${s.gradeLevel} - ${s.rollNumber ?? "N/A"})',
                                      optionsBuilder: (textEditingValue) {
                                        final q = textEditingValue.text.toLowerCase().trim();
                                        Iterable<Student> pool = students;
                                        if (filterClass != 'All Classes') {
                                          pool = pool.where((s) => s.gradeLevel == filterClass);
                                        }
                                        if (q.isEmpty) {
                                          return pool.take(12);
                                        }
                                        return pool.where((s) {
                                          return s.name.toLowerCase().contains(q) ||
                                              (s.rollNumber != null && s.rollNumber!.toLowerCase().contains(q)) ||
                                              s.id.toLowerCase().contains(q);
                                        }).take(15);
                                      },
                                      onSelected: (student) {
                                        setDialogState(() {
                                          selectedStudentObj = student;
                                          selectedStudentId = student.id;
                                        });
                                      },
                                      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                                        return TextField(
                                          controller: textController,
                                          focusNode: focusNode,
                                          decoration: InputDecoration(
                                            hintText: 'Type Name, Roll, or ID...',
                                            hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
                                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.primaryPurple),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          ),
                                        );
                                      },
                                      optionsViewBuilder: (context, onSelected, options) {
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Material(
                                            elevation: 6,
                                            borderRadius: BorderRadius.circular(8),
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 350),
                                              child: ListView.builder(
                                                padding: EdgeInsets.zero,
                                                shrinkWrap: true,
                                                itemCount: options.length,
                                                itemBuilder: (context, i) {
                                                  final s = options.elementAt(i);
                                                  return ListTile(
                                                    dense: true,
                                                    leading: CircleAvatar(
                                                      radius: 12,
                                                      backgroundColor: AppTheme.primaryPurple,
                                                      child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                                    ),
                                                    title: Text(s.name, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                                                    subtitle: Text('${s.gradeLevel} ${s.section ?? ""} • Roll: ${s.rollNumber ?? "N/A"}',
                                                        style: GoogleFonts.poppins(fontSize: 10.5, color: AppTheme.textSecondary)),
                                                    onTap: () => onSelected(s),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Quickly find any student among thousands by class filter or typing.',
                                  style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint)),
                            ],
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error loading students: $e'),
                      ),
                      const SizedBox(height: 12),

                      // Select Route
                      Text('Select Route *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      routesAsync.when(
                        data: (routes) {
                          return DropdownButtonFormField<String>(
                            value: selectedRouteId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            hint: Text('Choose Route', style: GoogleFonts.poppins(fontSize: 12)),
                            items: routes.map((r) {
                              return DropdownMenuItem(
                                value: r.id,
                                child: Text('${r.routeName} (${r.vehicleNumber ?? "Unassigned Vehicle"})',
                                    style: GoogleFonts.poppins(fontSize: 12), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (routeId) async {
                              if (routeId != null) {
                                final dbService = ref.read(databaseServiceProvider);
                                final stops = await dbService.getStopsForRoute(routeId);
                                setDialogState(() {
                                  selectedRouteId = routeId;
                                  availableStops = stops;
                                  selectedStopId = stops.isNotEmpty ? stops.first.id : null;
                                  currentStopFee = stops.isNotEmpty ? stops.first.fee : 0;
                                });
                              }
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error loading routes: $e'),
                      ),
                      const SizedBox(height: 12),

                      // Select Stop
                      Text('Select Stop *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: selectedStopId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        hint: Text(availableStops.isEmpty ? 'Select a route first to load stops' : 'Choose Stop',
                            style: GoogleFonts.poppins(fontSize: 12)),
                        items: availableStops.map((s) {
                          return DropdownMenuItem(
                            value: s.id,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${s.stopOrder}. ${s.stopName}', style: GoogleFonts.poppins(fontSize: 12)),
                                Text('₹${s.fee.toStringAsFixed(0)}/mo',
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (stopId) {
                          if (stopId != null) {
                            final match = availableStops.where((s) => s.id == stopId);
                            setDialogState(() {
                              selectedStopId = stopId;
                              if (match.isNotEmpty) currentStopFee = match.first.fee;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Fee Info Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: AppTheme.primaryPurple, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Monthly Transport Fee: ${_currencyFormat.format(currentStopFee)}',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
                                  ),
                                  Text(
                                    'Fee is auto-configured from this stop and applies only to this student in Fee Collection.',
                                    style: GoogleFonts.poppins(fontSize: 10.5, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedStudentId == null || selectedRouteId == null || selectedStopId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a student, route, and stop.'), backgroundColor: AppTheme.warning),
                        );
                        return;
                      }

                      final dbService = ref.read(databaseServiceProvider);
                      await dbService.assignStudentToRoute(
                        studentId: selectedStudentId!,
                        routeId: selectedRouteId!,
                        stopId: selectedStopId!,
                        academicYear: academicYear,
                      );

                      ref.invalidate(allStudentTransportsProvider(academicYear));
                      ref.invalidate(fleetOverviewProvider);
                      ref.invalidate(routesListProvider);

                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Transport assigned! Monthly fee ${_currencyFormat.format(currentStopFee)} synced.'),
                            backgroundColor: AppTheme.primaryPurple,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                    child: Text(existing != null ? 'Update Assignment' : 'Save Assignment', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _confirmRemoveTransport(BuildContext context, StudentTransport st) {
    final academicYear = st.academicYear;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove Transport Assignment?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to unassign ${st.studentName ?? "this student"} from transport? Unpaid transport dues will be removed from their ledger.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final dbService = ref.read(databaseServiceProvider);
              await dbService.removeStudentTransport(st.studentId, academicYear);
              ref.invalidate(allStudentTransportsProvider(academicYear));
              ref.invalidate(fleetOverviewProvider);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transport removed successfully.'), backgroundColor: AppTheme.primaryPurple),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 4: ROUTE MANIFEST / DRIVER SHEET
  // ============================================================================

  Widget _buildRouteManifestTab() {
    final routesAsync = ref.watch(routesListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Driver Route Manifest & Student Passenger List',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Select a route to view ordered stops with assigned students, roll numbers, and timings.',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Route Selector Dropdown
              routesAsync.when(
                data: (routes) {
                  if (_selectedManifestRouteId == null && routes.isNotEmpty) {
                    _selectedManifestRouteId = routes.first.id;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedManifestRouteId,
                      hint: Text('Select Route', style: GoogleFonts.poppins(fontSize: 13)),
                      underline: const SizedBox(),
                      items: routes
                          .map((r) => DropdownMenuItem(
                                value: r.id,
                                child: Text('${r.routeName} (${r.vehicleNumber ?? "No Bus"})',
                                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedManifestRouteId = val);
                      },
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_selectedManifestRouteId == null)
            _buildEmptyCard('Select a route from the dropdown above to view driver manifest.')
          else
            Consumer(
              builder: (context, ref, _) {
                final manifestAsync = ref.watch(routeWithStudentsProvider(_selectedManifestRouteId!));

                return manifestAsync.when(
                  data: (data) {
                    final Route? route = data['route'] as Route?;
                    final List<Map<String, dynamic>> stopsWithStudents =
                        (data['stops_with_students'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

                    if (route == null) return Text('Route not found', style: GoogleFonts.poppins());

                    int totalStudents = 0;
                    for (final s in stopsWithStudents) {
                      totalStudents += (s['students'] as List<dynamic>).length;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Manifest Card Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5B4BC4), Color(0xFF7B68EE)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('DRIVER MANIFEST — ${route.routeName.toUpperCase()}',
                                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Vehicle: ${route.vehicleNumber ?? "Unassigned"}  •  Route: ${route.startPoint} ➔ ${route.endPoint}',
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('TOTAL PASSENGERS', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                    Text('$totalStudents Students', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Stops with assigned students list
                        stopsWithStudents.isEmpty
                            ? _buildEmptyCard('No stops defined for this route.')
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: stopsWithStudents.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final item = stopsWithStudents[index];
                                  final RouteStop stop = item['stop'] as RouteStop;
                                  final List<StudentTransport> students = item['students'] as List<StudentTransport>;

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.divider),
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 12,
                                              backgroundColor: AppTheme.primaryPurple,
                                              child: Text('${stop.stopOrder}',
                                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(stop.stopName, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                            const Spacer(),
                                            if (stop.fee > 0)
                                              Chip(
                                                avatar: const Icon(Icons.currency_rupee_rounded, size: 14, color: AppTheme.success),
                                                label: Text('₹${stop.fee.toStringAsFixed(0)}/mo', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                                                backgroundColor: AppTheme.successLight,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        students.isEmpty
                                            ? Padding(
                                                padding: const EdgeInsets.only(left: 34),
                                                child: Text('No students assigned to this stop.', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
                                              )
                                            : ListView.builder(
                                                shrinkWrap: true,
                                                physics: const NeverScrollableScrollPhysics(),
                                                itemCount: students.length,
                                                itemBuilder: (context, sIdx) {
                                                  final st = students[sIdx];
                                                  return Padding(
                                                    padding: const EdgeInsets.only(left: 34, top: 6, bottom: 6),
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.person_pin_circle_rounded, size: 16, color: AppTheme.primaryPurple),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            '${st.studentName ?? "Student"} (${st.gradeLevel ?? "Class"} - ${st.section ?? "A"})',
                                                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                                          ),
                                                        ),
                                                        Text(
                                                          'Roll #${st.rollNumber ?? "N/A"}',
                                                          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                                                        ),
                                                        const SizedBox(width: 16),
                                                        Text(
                                                          'Fee: ${_currencyFormat.format(st.monthlyFee)}/mo',
                                                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.success),
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
                              ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (e, _) => Text('Error loading manifest: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
                );
              },
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // DIALOGS & ACTIONS
  // ============================================================================

  void _showAddEditVehicleDialog(BuildContext context, {Vehicle? vehicle}) {
    final isEdit = vehicle != null;
    final numController = TextEditingController(text: vehicle?.vehicleNumber ?? '');
    final capController = TextEditingController(text: vehicle != null ? '${vehicle.capacity}' : '30');
    final conductorController = TextEditingController(text: vehicle?.conductorName ?? '');
    String vehicleType = vehicle?.vehicleType ?? 'bus';
    String? selectedDriverId = vehicle?.driverStaffId;
    DateTime? insuranceExp = vehicle?.insuranceExpiry;
    DateTime? fitnessExp = vehicle?.fitnessExpiry;

    ref.invalidate(driversListProvider);

    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final driversAsync = ref.watch(driversListProvider);

          return StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(Icons.directions_bus_rounded, color: AppTheme.primaryPurple, size: 20),
                  const SizedBox(width: 10),
                  Text(isEdit ? 'Edit Vehicle' : 'Add Fleet Vehicle', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vehicle Registration Number *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: numController,
                        decoration: InputDecoration(
                          hintText: 'e.g. KA-01-AB-1234',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Vehicle Type', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  value: vehicleType,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'bus', child: Text('Bus')),
                                    DropdownMenuItem(value: 'van', child: Text('Van')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => vehicleType = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Seating Capacity *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: capController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Staff Driver Dropdown (Role = 'driver' or Designation = 'Driver')
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Assigned Driver (Staff with Driver role)', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                          InkWell(
                            onTap: () => ref.invalidate(driversListProvider),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.primaryPurple),
                                  const SizedBox(width: 4),
                                  Text('Refresh', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.primaryPurple, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      driversAsync.when(
                        data: (drivers) {
                          final hasMatch = selectedDriverId == null || drivers.any((d) => d.id == selectedDriverId);
                          final safeValue = hasMatch ? selectedDriverId : null;

                          return DropdownButtonFormField<String?>(
                            value: safeValue,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            hint: Text(drivers.isEmpty ? 'No drivers found (Role = driver)' : 'Select Driver',
                                style: GoogleFonts.poppins(fontSize: 12)),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                              ...drivers.map((d) => DropdownMenuItem<String?>(
                                    value: d.id,
                                    child: Text('${d.fullName} (${d.phone ?? "No Phone"})', style: GoogleFonts.poppins(fontSize: 12)),
                                  )),
                            ],
                            onChanged: (val) => setDialogState(() => selectedDriverId = val),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error drivers: $e', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.error)),
                      ),
                      const SizedBox(height: 12),

                      Text('Conductor Name (Optional)', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: conductorController,
                        decoration: InputDecoration(
                          hintText: 'Enter conductor name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Expiry pickers
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: insuranceExp ?? DateTime.now().add(const Duration(days: 365)),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (d != null) setDialogState(() => insuranceExp = d);
                              },
                              icon: const Icon(Icons.shield_outlined, size: 16),
                              label: Text(
                                insuranceExp != null ? 'Insurance: ${_dateFormat.format(insuranceExp!)}' : 'Insurance Expiry',
                                style: GoogleFonts.poppins(fontSize: 11),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: fitnessExp ?? DateTime.now().add(const Duration(days: 365)),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (d != null) setDialogState(() => fitnessExp = d);
                              },
                              icon: const Icon(Icons.verified_outlined, size: 16),
                              label: Text(
                                fitnessExp != null ? 'Fitness: ${_dateFormat.format(fitnessExp!)}' : 'Fitness Expiry',
                                style: GoogleFonts.poppins(fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (numController.text.trim().isEmpty) return;
                    final cap = int.tryParse(capController.text) ?? 30;

                    final dbService = ref.read(databaseServiceProvider);
                    if (isEdit) {
                      final updated = vehicle.copyWith(
                        vehicleNumber: numController.text.trim(),
                        vehicleType: vehicleType,
                        capacity: cap,
                        driverStaffId: selectedDriverId,
                        conductorName: conductorController.text.trim().isEmpty ? null : conductorController.text.trim(),
                        insuranceExpiry: insuranceExp,
                        fitnessExpiry: fitnessExp,
                      );
                      if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.updateRecord)) return;
                      await dbService.updateVehicle(updated);
                    } else {
                      final newV = Vehicle.create(
                        vehicleNumber: numController.text.trim(),
                        vehicleType: vehicleType,
                        capacity: cap,
                        driverStaffId: selectedDriverId,
                        conductorName: conductorController.text.trim().isEmpty ? null : conductorController.text.trim(),
                        insuranceExpiry: insuranceExp,
                        fitnessExpiry: fitnessExp,
                      );
                      await dbService.insertVehicle(newV);
                    }

                    ref.invalidate(vehiclesProvider);
                    ref.invalidate(vehiclesNeedingRenewalProvider);
                    ref.invalidate(fleetOverviewProvider);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                  child: Text(isEdit ? 'Save Changes' : 'Add Vehicle', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteVehicle(BuildContext context, Vehicle v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Vehicle ${v.vehicleNumber}?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove this vehicle from the fleet?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final dbService = ref.read(databaseServiceProvider);
              await dbService.deleteVehicle(v.id);
              ref.invalidate(vehiclesProvider);
              ref.invalidate(vehiclesNeedingRenewalProvider);
              ref.invalidate(fleetOverviewProvider);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddEditRouteDialog(BuildContext context, {Route? route}) {
    final isEdit = route != null;
    final nameController = TextEditingController(text: route?.routeName ?? '');
    final startController = TextEditingController(text: route?.startPoint ?? '');
    final endController = TextEditingController(text: route?.endPoint ?? '');
    String? selectedVehicleId = route?.vehicleId;

    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final vehiclesAsync = ref.watch(vehiclesProvider);

          return StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(isEdit ? 'Edit Route' : 'Create Transport Route', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Route Name *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Route 1 - North City Line',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text('Assigned Fleet Vehicle', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    vehiclesAsync.when(
                      data: (vehicles) {
                        return DropdownButtonFormField<String?>(
                          value: selectedVehicleId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          hint: Text('Select Vehicle', style: GoogleFonts.poppins(fontSize: 12)),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                            ...vehicles.map((v) => DropdownMenuItem<String?>(
                                  value: v.id,
                                  child: Text('${v.vehicleNumber} (${v.vehicleType.toUpperCase()} - ${v.capacity} seats)', style: GoogleFonts.poppins(fontSize: 12)),
                                )),
                          ],
                          onChanged: (val) => setDialogState(() => selectedVehicleId = val),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error loading vehicles: $e'),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Point *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: startController,
                                decoration: InputDecoration(
                                  hintText: 'e.g. City Bus Depot',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('End Point *', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: endController,
                                decoration: InputDecoration(
                                  hintText: 'e.g. School Campus',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    final dbService = ref.read(databaseServiceProvider);

                    if (isEdit) {
                      final updated = route.copyWith(
                        routeName: nameController.text.trim(),
                        vehicleId: selectedVehicleId,
                        startPoint: startController.text.trim(),
                        endPoint: endController.text.trim(),
                      );
                      if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.updateRecord)) return;
                      await dbService.updateRouteDetails(updated);
                    } else {
                      final newRoute = Route.create(
                        routeName: nameController.text.trim(),
                        vehicleId: selectedVehicleId,
                        startPoint: startController.text.trim(),
                        endPoint: endController.text.trim(),
                      );
                      await dbService.insertRoute(newRoute);
                    }

                    ref.invalidate(routesListProvider);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                  child: Text(isEdit ? 'Save Route' : 'Create Route', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteRoute(BuildContext context, Route r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Route ${r.routeName}?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure? This will remove all stops associated with this route.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final dbService = ref.read(databaseServiceProvider);
              await dbService.deleteRoute(r.id);
              ref.invalidate(routesListProvider);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showManageStopsDialog(BuildContext context, Route route) {
    final List<RouteStop> localStops = List.from(route.stops);
    final stopNameController = TextEditingController();
    final stopFeeController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.edit_road_rounded, color: AppTheme.primaryPurple, size: 20),
              const SizedBox(width: 10),
              Text('Manage Ordered Stops — ${route.routeName}', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Add Stop Form Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add New Stop', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: stopNameController,
                              decoration: InputDecoration(
                                hintText: 'Stop Name / Landmark (e.g. Central Market)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: stopFeeController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Monthly Fee (₹)',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (stopNameController.text.trim().isEmpty) return;
                              setDialogState(() {
                                localStops.add(RouteStop.create(
                                  routeId: route.id,
                                  stopName: stopNameController.text.trim(),
                                  stopOrder: localStops.length + 1,
                                  fee: double.tryParse(stopFeeController.text) ?? 0,
                                ));
                                stopNameController.clear();
                                stopFeeController.text = '0';
                              });
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Re-orderable Stops List
                Text('Stops in Sequence (Reorder as needed):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 240,
                  child: localStops.isEmpty
                      ? Center(child: Text('No stops added yet.', style: GoogleFonts.poppins(color: AppTheme.textHint)))
                      : ReorderableListView(
                          onReorder: (oldIdx, newIdx) {
                            setDialogState(() {
                              if (newIdx > oldIdx) newIdx -= 1;
                              final item = localStops.removeAt(oldIdx);
                              localStops.insert(newIdx, item);
                            });
                          },
                          children: [
                            for (int i = 0; i < localStops.length; i++)
                              ListTile(
                                key: ValueKey('stop-$i-${localStops[i].stopName}'),
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 11,
                                  backgroundColor: AppTheme.primaryPurple,
                                  child: Text('${i + 1}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                title: Text(localStops[i].stopName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                                subtitle: Text('Fee: ₹${localStops[i].fee.toStringAsFixed(0)}/mo',
                                    style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppTheme.error),
                                      onPressed: () {
                                        setDialogState(() => localStops.removeAt(i));
                                      },
                                    ),
                                    const Icon(Icons.drag_handle, size: 18, color: AppTheme.textHint),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final dbService = ref.read(databaseServiceProvider);
                await dbService.saveRouteStops(route.id, localStops);
                ref.invalidate(routesListProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: Text('Save Stops Sequence', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String val, IconData icon, Color color) {
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
                Text(val, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              ],
            ),
          ],
        ),
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
