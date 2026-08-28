import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/auth_provider.dart';

class StudentAttendanceHistoryDialog extends ConsumerStatefulWidget {
  final Student student;

  const StudentAttendanceHistoryDialog({super.key, required this.student});

  @override
  ConsumerState<StudentAttendanceHistoryDialog> createState() => _StudentAttendanceHistoryDialogState();
}

class _StudentAttendanceHistoryDialogState extends ConsumerState<StudentAttendanceHistoryDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryPurple,
              onPrimary: Colors.white,
              surface: AppTheme.bgSurface,
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
        _endDate = range.end;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present': return AppTheme.success;
      case 'absent': return AppTheme.error;
      case 'half_day': return Colors.orange;
      case 'late': return Colors.amber;
      default: return AppTheme.textSecondary;
    }
  }

  void _editRecord(StudentAttendance record) {
    final user = ref.read(authProvider).currentUser;
    if (user == null) return;
    
    // RBAC: Admins can always edit. Teachers can edit (assuming assigned class, but for now we just check if they are teacher or admin).
    if (user.role != UserRole.admin && user.role != UserRole.teacher) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You do not have permission to edit attendance.')));
      return;
    }

    String _selectedStatus = record.status;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.bgSurface,
              title: Text('Edit Attendance - ${record.date.substring(0, 10)}', style: GoogleFonts.poppins(color: AppTheme.textPrimary)),
              content: DropdownButtonFormField<String>(
                value: _selectedStatus,
                dropdownColor: AppTheme.bgSurface,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Status',
                  labelStyle: GoogleFonts.poppins(color: AppTheme.textHint),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.divider)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryPurple)),
                ),
                items: const [
                  DropdownMenuItem(value: 'present', child: Text('Present')),
                  DropdownMenuItem(value: 'absent', child: Text('Absent')),
                  DropdownMenuItem(value: 'half_day', child: Text('Half Day')),
                  DropdownMenuItem(value: 'late', child: Text('Late')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => _selectedStatus = val);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
                  onPressed: () async {
                    final updatedRecord = record.copyWith(
                      status: _selectedStatus,
                      correctedBy: user.id,
                      correctedAt: DateTime.now().toIso8601String(),
                    );
                    await ref.read(databaseServiceProvider).updateStudentAttendanceRecord(updatedRecord);
                    if (context.mounted) {
                      Navigator.pop(context);
                      setState(() {}); // trigger rebuild
                    }
                  },
                  child: Text('Save', style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attendance History - ${widget.student.firstName ?? widget.student.name}',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryPurple,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primaryPurple,
              tabs: const [
                Tab(text: 'Month View'),
                Tab(text: 'Date Range List'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMonthView(),
                  _buildDateRangeList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthView() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppTheme.textPrimary),
              onPressed: () {
                setState(() {
                  if (_selectedMonth == 1) {
                    _selectedMonth = 12;
                    _selectedYear--;
                  } else {
                    _selectedMonth--;
                  }
                });
              },
            ),
            Text(
              '${DateFormat('MMMM').format(DateTime(_selectedYear, _selectedMonth))} $_selectedYear',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppTheme.textPrimary),
              onPressed: () {
                setState(() {
                  if (_selectedMonth == 12) {
                    _selectedMonth = 1;
                    _selectedYear++;
                  } else {
                    _selectedMonth++;
                  }
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<StudentAttendance>>(
          future: ref.read(databaseServiceProvider).getAttendanceForStudent(
            widget.student.id,
            startDate: DateTime(_selectedYear, _selectedMonth, 1).toIso8601String().substring(0, 10),
            endDate: DateTime(_selectedYear, _selectedMonth + 1, 0).toIso8601String().substring(0, 10),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Expanded(child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return Expanded(child: Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.error))));
            }

            final records = snapshot.data ?? [];
            final recordMap = {for (var r in records) r.date.substring(0, 10): r};
            
            int presentCount = records.where((r) => r.status == 'present').length;
            int totalCount = records.length;
            double percent = totalCount == 0 ? 0 : (presentCount / totalCount) * 100;

            final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
            final firstWeekday = DateTime(_selectedYear, _selectedMonth, 1).weekday; // 1 = Monday, 7 = Sunday
            
            return Expanded(
              child: Column(
                children: [
                  Text('$presentCount/$totalCount days present (${percent.toStringAsFixed(1)}%)', 
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map((day) => Text(day, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: daysInMonth + firstWeekday - 1,
                      itemBuilder: (context, index) {
                        if (index < firstWeekday - 1) return const SizedBox.shrink();
                        int day = index - firstWeekday + 2;
                        final dateStr = DateFormat('yyyy-MM-dd').format(DateTime(_selectedYear, _selectedMonth, day));
                        final record = recordMap[dateStr];
                        
                        return Container(
                          decoration: BoxDecoration(
                            color: record != null ? _getStatusColor(record.status).withValues(alpha: 0.2) : AppTheme.divider.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: record != null ? _getStatusColor(record.status) : AppTheme.divider,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              day.toString(),
                              style: GoogleFonts.poppins(
                                color: record != null ? _getStatusColor(record.status) : AppTheme.textPrimary,
                                fontWeight: record != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDateRangeList() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _startDate != null && _endDate != null
                  ? '${DateFormat('MMM d, yyyy').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}'
                  : 'Select Date Range',
              style: GoogleFonts.poppins(color: AppTheme.textPrimary),
            ),
            ElevatedButton(
              onPressed: _selectDateRange,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
              child: const Text('Pick Range', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_startDate == null || _endDate == null)
          const Expanded(child: Center(child: Text('Please select a date range.', style: TextStyle(color: AppTheme.textSecondary))))
        else
          FutureBuilder<List<StudentAttendance>>(
            future: ref.read(databaseServiceProvider).getAttendanceForStudent(
              widget.student.id,
              startDate: _startDate!.toIso8601String().substring(0, 10),
              endDate: _endDate!.toIso8601String().substring(0, 10),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Expanded(child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return Expanded(child: Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.error))));
              }
              
              final records = snapshot.data ?? [];
              if (records.isEmpty) {
                return const Expanded(child: Center(child: Text('No attendance records found for this range.', style: TextStyle(color: AppTheme.textSecondary))));
              }

              return Expanded(
                child: ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return Card(
                      color: AppTheme.bgSurface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: AppTheme.divider),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        title: Text(record.date.substring(0, 10), style: GoogleFonts.poppins(color: AppTheme.textPrimary)),
                        subtitle: record.correctedBy != null ? Text('Corrected', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.warning)) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              record.status.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(record.status),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: AppTheme.primaryPurple),
                              onPressed: () => _editRecord(record),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}
