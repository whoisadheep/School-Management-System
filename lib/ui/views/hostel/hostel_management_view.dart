import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/hostel_provider.dart';
import '../../../providers/services_provider.dart';

class HostelManagementView extends ConsumerStatefulWidget {
  const HostelManagementView({super.key});

  @override
  ConsumerState<HostelManagementView> createState() => _HostelManagementViewState();
}

class _HostelManagementViewState extends ConsumerState<HostelManagementView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Form Controllers - Setup
  final _blockNameCtrl = TextEditingController();
  final _wardenIdCtrl = TextEditingController();
  final _blockTotalRoomsCtrl = TextEditingController();
  
  final _roomNumCtrl = TextEditingController();
  final _roomFloorCtrl = TextEditingController();
  final _roomCapCtrl = TextEditingController();
  String? _selectedBlockId;

  // Form Controllers - Allocation
  final _allocStudentIdCtrl = TextEditingController();
  final _allocFeeCtrl = TextEditingController();
  String _allocYear = '2026-2027';
  String? _allocRoomId;

  // Form Controllers - Attendance
  String? _attBlockId;
  Map<String, String> _attendanceMap = {}; // studentId -> status

  // Form Controllers - Outpass
  final _opStudentIdCtrl = TextEditingController();
  final _opReasonCtrl = TextEditingController();
  final _opExpectedReturnCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _blockNameCtrl.dispose();
    _wardenIdCtrl.dispose();
    _blockTotalRoomsCtrl.dispose();
    _roomNumCtrl.dispose();
    _roomFloorCtrl.dispose();
    _roomCapCtrl.dispose();
    _allocStudentIdCtrl.dispose();
    _allocFeeCtrl.dispose();
    _opStudentIdCtrl.dispose();
    _opReasonCtrl.dispose();
    _opExpectedReturnCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.error));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.success));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bgMain,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.primarySoft.withValues(alpha: 0.5))),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.primaryPurple,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              indicatorColor: AppTheme.primaryPurple,
              indicatorWeight: 3,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Hostel Setup'),
                Tab(text: 'Room Allocation'),
                Tab(text: 'Attendance'),
                Tab(text: 'Outpasses'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSetupTab(),
                _buildAllocationTab(),
                _buildAttendanceTab(),
                _buildOutpassTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ====================== TAB 1: SETUP ======================
  Widget _buildSetupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _buildBlockForm(),
                const SizedBox(height: 24),
                _buildRoomForm(),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildBlocksList(),
                const SizedBox(height: 24),
                _buildRoomsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockForm() {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.divider)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Hostel Block', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(controller: _blockNameCtrl, decoration: _inputDeco('Block Name')),
            const SizedBox(height: 12),
            TextField(controller: _blockTotalRoomsCtrl, decoration: _inputDeco('Total Rooms'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(controller: _wardenIdCtrl, decoration: _inputDeco('Warden Staff ID')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                onPressed: () async {
                  if (_blockNameCtrl.text.isEmpty || _blockTotalRoomsCtrl.text.isEmpty) return;
                  final db = ref.read(databaseServiceProvider);
                  await db.createHostelBlock(HostelBlock(
                    id: const Uuid().v4(),
                    blockName: _blockNameCtrl.text,
                    totalRooms: int.tryParse(_blockTotalRoomsCtrl.text) ?? 0,
                    wardenStaffId: _wardenIdCtrl.text.isEmpty ? null : _wardenIdCtrl.text,
                  ));
                  ref.invalidate(hostelBlocksProvider);
                  _blockNameCtrl.clear(); _blockTotalRoomsCtrl.clear(); _wardenIdCtrl.clear();
                  _showSuccess('Block created');
                },
                child: const Text('Create Block'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomForm() {
    final blocksAsync = ref.watch(hostelBlocksProvider);
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.divider)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Room', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            blocksAsync.when(
              data: (blocks) => DropdownButtonFormField<String>(
                decoration: _inputDeco('Select Block'),
                value: _selectedBlockId,
                items: blocks.map((b) => DropdownMenuItem(value: b.id, child: Text(b.blockName))).toList(),
                onChanged: (v) => setState(() => _selectedBlockId = v),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error loading blocks'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _roomNumCtrl, decoration: _inputDeco('Room Number')),
            const SizedBox(height: 12),
            TextField(controller: _roomFloorCtrl, decoration: _inputDeco('Floor'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(controller: _roomCapCtrl, decoration: _inputDeco('Capacity'), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                onPressed: () async {
                  if (_selectedBlockId == null || _roomNumCtrl.text.isEmpty) return;
                  final db = ref.read(databaseServiceProvider);
                  await db.createHostelRoom(HostelRoom(
                    id: const Uuid().v4(),
                    blockId: _selectedBlockId!,
                    roomNumber: _roomNumCtrl.text,
                    floor: int.tryParse(_roomFloorCtrl.text) ?? 1,
                    capacity: int.tryParse(_roomCapCtrl.text) ?? 2,
                  ));
                  ref.invalidate(allHostelRoomsProvider);
                  _roomNumCtrl.clear(); _roomFloorCtrl.clear(); _roomCapCtrl.clear();
                  _showSuccess('Room created');
                },
                child: const Text('Create Room'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlocksList() {
    final blocksAsync = ref.watch(hostelBlocksProvider);
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.divider)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Blocks', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            blocksAsync.when(
              data: (blocks) => ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: blocks.length,
                itemBuilder: (ctx, i) => ListTile(
                  title: Text(blocks[i].blockName, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  subtitle: Text('Total Rooms: ${blocks[i].totalRooms}'),
                  trailing: blocks[i].isActive ? const Icon(Icons.check_circle, color: AppTheme.success) : const Icon(Icons.cancel, color: AppTheme.error),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text(err.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomsList() {
    final roomsAsync = ref.watch(allHostelRoomsProvider);
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.divider)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rooms', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            roomsAsync.when(
              data: (rooms) => ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rooms.length,
                itemBuilder: (ctx, i) {
                  final r = rooms[i];
                  return ListTile(
                    title: Text('Room ${r.roomNumber} (Floor ${r.floor})', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    subtitle: Text('Occupancy: ${r.currentOccupancy} / ${r.capacity}'),
                    trailing: Text('Block ID: ${r.blockId.substring(0, 4)}...', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text(err.toString()),
            ),
          ],
        ),
      ),
    );
  }

  // ====================== TAB 2: ALLOCATION ======================
  Widget _buildAllocationTab() {
    final allocationsAsync = ref.watch(hostelAllocationsProvider);
    final roomsAsync = ref.watch(allHostelRoomsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.divider)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Allocate Room', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    TextField(controller: _allocStudentIdCtrl, decoration: _inputDeco('Student ID')),
                    const SizedBox(height: 12),
                    roomsAsync.when(
                      data: (rooms) => DropdownButtonFormField<String>(
                        decoration: _inputDeco('Select Room'),
                        value: _allocRoomId,
                        items: rooms.map((r) => DropdownMenuItem(value: r.id, child: Text('Room ${r.roomNumber} (Occupancy: ${r.currentOccupancy}/${r.capacity})'))).toList(),
                        onChanged: (v) => setState(() => _allocRoomId = v),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Error'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: _inputDeco('Academic Year'),
                      value: _allocYear,
                      items: ['2025-2026', '2026-2027'].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                      onChanged: (v) => setState(() => _allocYear = v ?? '2026-2027'),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _allocFeeCtrl, decoration: _inputDeco('Monthly Fee'), keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                        onPressed: () async {
                          if (_allocStudentIdCtrl.text.isEmpty || _allocRoomId == null || _allocFeeCtrl.text.isEmpty) return;
                          try {
                            final db = ref.read(databaseServiceProvider);
                            await db.allocateStudent(
                              _allocStudentIdCtrl.text,
                              _allocRoomId!,
                              _allocYear,
                              double.parse(_allocFeeCtrl.text),
                            );
                            ref.invalidate(hostelAllocationsProvider);
                            ref.invalidate(allHostelRoomsProvider);
                            _allocStudentIdCtrl.clear();
                            _allocFeeCtrl.clear();
                            _showSuccess('Allocated successfully');
                          } catch (e) {
                            _showError(e.toString());
                          }
                        },
                        child: const Text('Allocate'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.divider)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Allocations', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    allocationsAsync.when(
                      data: (allocs) {
                        if (allocs.isEmpty) return const Text('No active allocations');
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: allocs.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (ctx, i) {
                            final a = allocs[i];
                            return ListTile(
                              title: Text('Student ID: ${a.studentId}', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                              subtitle: Text('Room ID: ${a.roomId} | Year: ${a.academicYear}'),
                              trailing: Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(a.allocatedDate))),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Text(err.toString()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================== TAB 3: ATTENDANCE ======================
  Widget _buildAttendanceTab() {
    final blocksAsync = ref.watch(hostelBlocksProvider);
    final allocsAsync = ref.watch(hostelAllocationsProvider);
    final roomsAsync = ref.watch(allHostelRoomsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.divider)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hostel Attendance', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              blocksAsync.when(
                data: (blocks) => DropdownButtonFormField<String>(
                  decoration: _inputDeco('Select Block'),
                  value: _attBlockId,
                  items: blocks.map((b) => DropdownMenuItem(value: b.id, child: Text(b.blockName))).toList(),
                  onChanged: (v) {
                    setState(() {
                      _attBlockId = v;
                      _attendanceMap.clear();
                    });
                  },
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Error'),
              ),
              const SizedBox(height: 24),
              if (_attBlockId != null) ...[
                Builder(
                  builder: (ctx) {
                    if (allocsAsync.isLoading || roomsAsync.isLoading) return const CircularProgressIndicator();
                    if (allocsAsync.hasError || roomsAsync.hasError) return const Text('Error loading data');
                    
                    final allRooms = roomsAsync.value!;
                    final roomsInBlock = allRooms.where((r) => r.blockId == _attBlockId).map((r) => r.id).toSet();
                    
                    final allAllocs = allocsAsync.value!;
                    final allocsInBlock = allAllocs.where((a) => roomsInBlock.contains(a.roomId)).toList();

                    if (allocsInBlock.isEmpty) return const Text('No students allocated in this block.');

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: allocsInBlock.length,
                          itemBuilder: (ctx, i) {
                            final a = allocsInBlock[i];
                            final status = _attendanceMap[a.studentId] ?? 'Present';
                            return ListTile(
                              title: Text('Student ID: ${a.studentId}', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                              subtitle: Text('Room: ${allRooms.firstWhere((r) => r.id == a.roomId).roomNumber}'),
                              trailing: SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(value: 'Present', label: Text('Present')),
                                  ButtonSegment(value: 'Absent', label: Text('Absent')),
                                ],
                                selected: {status},
                                onSelectionChanged: (s) {
                                  setState(() => _attendanceMap[a.studentId] = s.first);
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                          onPressed: () async {
                            final date = DateTime.now().toIso8601String().substring(0, 10);
                            final list = allocsInBlock.map((a) => HostelAttendance(
                              id: const Uuid().v4(),
                              studentId: a.studentId,
                              date: date,
                              status: _attendanceMap[a.studentId] ?? 'Present',
                              markedBy: 'admin',
                            )).toList();
                            
                            await ref.read(databaseServiceProvider).markHostelAttendance(list);
                            _showSuccess('Attendance marked successfully');
                          },
                          child: const Text('Submit Attendance'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ====================== TAB 4: OUTPASS ======================
  Widget _buildOutpassTab() {
    final outpassesAsync = ref.watch(outpassesProvider);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.divider)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Request Outpass', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    TextField(controller: _opStudentIdCtrl, decoration: _inputDeco('Student ID')),
                    const SizedBox(height: 12),
                    TextField(controller: _opReasonCtrl, decoration: _inputDeco('Reason'), maxLines: 2),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _opExpectedReturnCtrl, 
                      decoration: _inputDeco('Expected Return Date (YYYY-MM-DD)'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                        onPressed: () async {
                          if (_opStudentIdCtrl.text.isEmpty || _opReasonCtrl.text.isEmpty) return;
                          final db = ref.read(databaseServiceProvider);
                          await db.requestOutpass(Outpass(
                            id: const Uuid().v4(),
                            studentId: _opStudentIdCtrl.text,
                            reason: _opReasonCtrl.text,
                            outDate: DateTime.now().toIso8601String(),
                            expectedReturnDate: _opExpectedReturnCtrl.text,
                            status: 'Pending',
                          ));
                          ref.invalidate(outpassesProvider);
                          _opStudentIdCtrl.clear(); _opReasonCtrl.clear(); _opExpectedReturnCtrl.clear();
                          _showSuccess('Outpass requested');
                        },
                        child: const Text('Submit Request'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.divider)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Outpasses', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    outpassesAsync.when(
                      data: (ops) {
                        if (ops.isEmpty) return const Text('No outpasses found');
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: ops.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (ctx, i) {
                            final o = ops[i];
                            DateTime? expected;
                            try { expected = DateTime.parse(o.expectedReturnDate); } catch (_) {}
                            bool isOverdue = false;
                            if (o.actualReturnDate == null && expected != null) {
                              if (DateTime.now().isAfter(expected)) {
                                isOverdue = true;
                              }
                            }
                            
                            return ListTile(
                              title: Row(
                                children: [
                                  Text('Student ID: ${o.studentId}', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: o.status == 'Approved' ? AppTheme.success.withValues(alpha: 0.1) : 
                                            (o.status == 'Rejected' ? AppTheme.error.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(o.status, style: TextStyle(
                                      fontSize: 10,
                                      color: o.status == 'Approved' ? AppTheme.success : (o.status == 'Rejected' ? AppTheme.error : Colors.orange)
                                    )),
                                  ),
                                  if (isOverdue) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                      child: const Text('OVERDUE', style: TextStyle(fontSize: 10, color: AppTheme.error, fontWeight: FontWeight.bold)),
                                    ),
                                  ]
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Reason: ${o.reason}'),
                                  Text('Out: ${DateFormat('MMM dd').format(DateTime.parse(o.outDate))} | Expected: ${o.expectedReturnDate}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (o.status == 'Pending') ...[
                                    IconButton(
                                      icon: const Icon(Icons.check_circle_outline, color: AppTheme.success),
                                      onPressed: () async {
                                        await ref.read(databaseServiceProvider).updateOutpassStatus(o.id, 'Approved', approvedBy: 'admin');
                                        ref.invalidate(outpassesProvider);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.cancel_outlined, color: AppTheme.error),
                                      onPressed: () async {
                                        await ref.read(databaseServiceProvider).updateOutpassStatus(o.id, 'Rejected', approvedBy: 'admin');
                                        ref.invalidate(outpassesProvider);
                                      },
                                    ),
                                  ] else if (o.status == 'Approved' && o.actualReturnDate == null) ...[
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.success, foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                      onPressed: () async {
                                        await ref.read(databaseServiceProvider).updateOutpassStatus(o.id, 'Returned', returnDate: DateTime.now().toIso8601String());
                                        ref.invalidate(outpassesProvider);
                                      },
                                      child: const Text('Mark Returned', style: TextStyle(fontSize: 12)),
                                    ),
                                  ]
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Text(err.toString()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.divider)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.divider)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.primaryPurple)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
