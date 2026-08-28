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

  String? _selectedAllocStudentId;
  String? _selectedOpStudentId;

  String? _selectedAllocGrade;
  String? _selectedOpGrade;

  final List<String> _grades = [
    'Nursery', 'LKG', 'UKG', 'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4',
    'Grade 5', 'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'
  ];
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
                  try {
                    await db.createHostelBlock(HostelBlock(
                      id: const Uuid().v4(),
                      blockName: _blockNameCtrl.text,
                      totalRooms: int.tryParse(_blockTotalRoomsCtrl.text) ?? 0,
                      wardenStaffId: _wardenIdCtrl.text.isEmpty ? null : _wardenIdCtrl.text,
                    ));
                    ref.invalidate(hostelBlocksProvider);
                    _blockNameCtrl.clear(); _blockTotalRoomsCtrl.clear(); _wardenIdCtrl.clear();
                    _showSuccess('Block created');
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
                  }
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
                  try {
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
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
                  }
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
                    DropdownButtonFormField<String>(
                      decoration: _inputDeco('Select Grade'),
                      value: _selectedAllocGrade,
                      items: _grades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedAllocGrade = v;
                          _selectedAllocStudentId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_selectedAllocGrade != null)
                      ref.watch(studentsByGradeProvider(_selectedAllocGrade!)).when(
                        data: (students) => DropdownButtonFormField<String>(
                          decoration: _inputDeco('Select Student'),
                          value: _selectedAllocStudentId,
                          items: students.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.firstName ?? s.name} ${s.lastName ?? ""} (${s.admissionNumber ?? "N/A"})'))).toList(),
                          onChanged: (v) => setState(() => _selectedAllocStudentId = v),
                          isExpanded: true,
                        ),
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const Text('Error loading students'),
                      ),
                    if (_selectedAllocGrade != null)
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
                          if (_selectedAllocStudentId == null || _allocRoomId == null || _allocFeeCtrl.text.isEmpty) return;
                          try {
                            final db = ref.read(databaseServiceProvider);
                            await db.allocateStudent(
                              _selectedAllocStudentId!,
                              _allocRoomId!,
                              _allocYear,
                              double.parse(_allocFeeCtrl.text),
                            );
                            ref.invalidate(hostelAllocationsProvider);
                            ref.invalidate(allHostelRoomsProvider);
                            setState(() => _selectedAllocStudentId = null);
                            _allocFeeCtrl.clear();
                            _showSuccess('Allocated successfully');
                          } catch (e) {
                            if (!mounted) return;
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
                        final allStudentsAsync = ref.watch(allActiveStudentsProvider);
                        return allStudentsAsync.when(
                          data: (students) {
                            return roomsAsync.when(
                              data: (rooms) {
                                final allocsByRoom = <String, List<HostelAllocation>>{};
                                for (var a in allocs) {
                                  allocsByRoom.putIfAbsent(a.roomId, () => []).add(a);
                                }

                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: allocsByRoom.keys.length,
                                  itemBuilder: (ctx, i) {
                                    final roomId = allocsByRoom.keys.elementAt(i);
                                    final roomAllocs = allocsByRoom[roomId]!;
                                    final room = rooms.firstWhere((r) => r.id == roomId, orElse: () => HostelRoom(id: roomId, blockId: '', roomNumber: 'Unknown', capacity: 0, currentOccupancy: 0, floor: 0));
                                    
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      color: const Color(0xFFF9FAFB),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE5E7EB))),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Room ${room.roomNumber}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.primaryPurple, fontSize: 15)),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryPurple.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text('${roomAllocs.length}/${room.capacity} Occupied', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primaryPurple, fontWeight: FontWeight.w500)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            ...roomAllocs.map((a) {
                                              final student = students.firstWhere((s) => s.id == a.studentId, orElse: () => Student(id: a.studentId, name: 'Unknown Student', gradeLevel: 'N/A', createdAt: DateTime.now(), updatedAt: DateTime.now()));
                                              final name = '${student.firstName ?? student.name} ${student.lastName ?? ""}'.trim();
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 8),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.person_outline, size: 18, color: AppTheme.textSecondary),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                                                          Text('ID: ${student.admissionNumber ?? "N/A"} | Year: ${a.academicYear}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              loading: () => const CircularProgressIndicator(),
                              error: (e, _) => Text('Error loading rooms: $e'),
                            );
                          },
                          loading: () => const CircularProgressIndicator(),
                          error: (e, _) => Text('Error loading students: $e'),
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
    final allStudentsAsync = ref.watch(allActiveStudentsProvider);

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
                allStudentsAsync.when(
                  data: (students) {
                    if (allocsAsync.isLoading || roomsAsync.isLoading) return const CircularProgressIndicator();
                    if (allocsAsync.hasError || roomsAsync.hasError) return const Text('Error loading data');
                    
                    final allRooms = roomsAsync.value!;
                    final roomsInBlock = allRooms.where((r) => r.blockId == _attBlockId).map((r) => r.id).toSet();
                    
                    final allAllocs = allocsAsync.value!;
                    final allocsInBlock = allAllocs.where((a) => roomsInBlock.contains(a.roomId)).toList();

                    if (allocsInBlock.isEmpty) return const Text('No students allocated in this block.');

                    final allocsByRoom = <String, List<HostelAllocation>>{};
                    for (var a in allocsInBlock) {
                      allocsByRoom.putIfAbsent(a.roomId, () => []).add(a);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...allocsByRoom.keys.map((roomId) {
                          final roomAllocs = allocsByRoom[roomId]!;
                          final room = allRooms.firstWhere((r) => r.id == roomId);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            color: const Color(0xFFF9FAFB),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE5E7EB))),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Room ${room.roomNumber}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.primaryPurple, fontSize: 15)),
                                  const SizedBox(height: 12),
                                  ...roomAllocs.map((a) {
                                    final student = students.firstWhere((s) => s.id == a.studentId, orElse: () => Student(id: a.studentId, name: 'Unknown Student', gradeLevel: 'N/A', createdAt: DateTime.now(), updatedAt: DateTime.now()));
                                    final name = '${student.firstName ?? student.name} ${student.lastName ?? ""}'.trim();
                                    final status = _attendanceMap[a.studentId] ?? 'Present';
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                                            child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: AppTheme.primaryPurple, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                                                Text('${student.gradeLevel} | ID: ${student.admissionNumber ?? "N/A"}', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                                              ],
                                            ),
                                          ),
                                          SegmentedButton<String>(
                                            segments: const [
                                              ButtonSegment(value: 'Present', label: Text('Present', style: TextStyle(fontSize: 12))),
                                              ButtonSegment(value: 'Absent', label: Text('Absent', style: TextStyle(fontSize: 12))),
                                            ],
                                            selected: {status},
                                            onSelectionChanged: (s) {
                                              setState(() => _attendanceMap[a.studentId] = s.first);
                                            },
                                            style: ButtonStyle(
                                              visualDensity: VisualDensity.compact,
                                              backgroundColor: WidgetStateProperty.resolveWith((states) {
                                                if (states.contains(WidgetState.selected)) {
                                                  return status == 'Present' ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2);
                                                }
                                                return null;
                                              }),
                                              foregroundColor: WidgetStateProperty.resolveWith((states) {
                                                if (states.contains(WidgetState.selected)) {
                                                  return status == 'Present' ? Colors.green[800] : Colors.red[800];
                                                }
                                                return Colors.black87;
                                              }),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
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
                            if (!mounted) return;
                            _showSuccess('Attendance marked successfully');
                          },
                          child: const Text('Submit Attendance'),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error loading students: $e'),
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
                    DropdownButtonFormField<String>(
                      decoration: _inputDeco('Select Grade'),
                      value: _selectedOpGrade,
                      items: _grades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedOpGrade = v;
                          _selectedOpStudentId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_selectedOpGrade != null)
                      ref.watch(studentsByGradeProvider(_selectedOpGrade!)).when(
                        data: (students) => DropdownButtonFormField<String>(
                          decoration: _inputDeco('Select Student'),
                          value: _selectedOpStudentId,
                          items: students.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.firstName ?? s.name} ${s.lastName ?? ""} (${s.admissionNumber ?? "N/A"})'))).toList(),
                          onChanged: (v) => setState(() => _selectedOpStudentId = v),
                          isExpanded: true,
                        ),
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const Text('Error loading students'),
                      ),
                    if (_selectedOpGrade != null)
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
                          if (_selectedOpStudentId == null || _opReasonCtrl.text.isEmpty) return;
                          final db = ref.read(databaseServiceProvider);
                          try {
                            await db.requestOutpass(Outpass(
                              id: const Uuid().v4(),
                              studentId: _selectedOpStudentId!,
                              reason: _opReasonCtrl.text,
                              expectedReturnDate: _opExpectedReturnCtrl.text,
                              status: 'Pending',
                              outDate: DateTime.now().toIso8601String(),
                            ));
                            ref.invalidate(outpassesProvider);
                            setState(() => _selectedOpStudentId = null);
                            _opReasonCtrl.clear();
                            _opExpectedReturnCtrl.clear();
                            _showSuccess('Outpass requested');
                          } catch (e) {
                            if (!mounted) return;
                            _showError(e.toString());
                          }
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
