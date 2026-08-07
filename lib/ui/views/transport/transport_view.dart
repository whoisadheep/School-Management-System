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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
                                        if (stop.pickupTime != null || stop.dropTime != null)
                                          Text(
                                            ' (${stop.pickupTime ?? "-"} / ${stop.dropTime ?? "-"})',
                                            style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint),
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
  // TAB 3: ROUTE MANIFEST / DRIVER SHEET
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
                                            if (stop.pickupTime != null)
                                              Chip(
                                                avatar: const Icon(Icons.wb_sunny_outlined, size: 14, color: AppTheme.primaryPurple),
                                                label: Text('Pickup: ${stop.pickupTime}', style: GoogleFonts.poppins(fontSize: 11)),
                                                backgroundColor: AppTheme.bgSurface,
                                              ),
                                            if (stop.dropTime != null) ...[
                                              const SizedBox(width: 8),
                                              Chip(
                                                avatar: const Icon(Icons.nights_stay_outlined, size: 14, color: AppTheme.info),
                                                label: Text('Drop: ${stop.dropTime}', style: GoogleFonts.poppins(fontSize: 11)),
                                                backgroundColor: AppTheme.bgSurface,
                                              ),
                                            ],
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

                      // Staff Driver Dropdown (Role = 'driver')
                      Text('Assigned Driver (Staff with Driver role)', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      driversAsync.when(
                        data: (drivers) {
                          return DropdownButtonFormField<String?>(
                            value: selectedDriverId,
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
                      await dbService.updateRoute(updated);
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
    final pickupTimeController = TextEditingController(text: '07:30 AM');
    final dropTimeController = TextEditingController(text: '03:30 PM');

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
                      TextField(
                        controller: stopNameController,
                        decoration: InputDecoration(
                          hintText: 'Stop Name / Landmark (e.g. Central Market)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: pickupTimeController,
                              decoration: InputDecoration(
                                labelText: 'Pickup Time',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: dropTimeController,
                              decoration: InputDecoration(
                                labelText: 'Drop Time',
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
                                  pickupTime: pickupTimeController.text.trim(),
                                  dropTime: dropTimeController.text.trim(),
                                ));
                                stopNameController.clear();
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
                                subtitle: Text('Pickup: ${localStops[i].pickupTime ?? "-"}  |  Drop: ${localStops[i].dropTime ?? "-"}',
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
