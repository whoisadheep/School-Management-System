import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/models.dart';
import '../../../../providers/student_attendance_provider.dart';
import '../../../../providers/services_provider.dart';
import '../../../../core/theme/app_theme.dart';

class StudentAttendanceView extends ConsumerStatefulWidget {
  const StudentAttendanceView({super.key});

  @override
  ConsumerState<StudentAttendanceView> createState() => _StudentAttendanceViewState();
}

class _StudentAttendanceViewState extends ConsumerState<StudentAttendanceView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Daily Attendance State
  String _selectedClass = 'Grade 1';
  String _selectedSection = 'A';
  DateTime _selectedDate = DateTime.now();
  Map<String, StudentAttendance> _editedAttendance = {};

  // Report State
  String _reportClass = 'Grade 1';
  String _reportSection = 'A';
  String _reportYear = '2026-2027';
  bool _generateReport = false;

  final List<String> _classes = ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10'];
  final List<String> _sections = ['A', 'B', 'C'];
  final List<String> _years = ['2023-2024', '2024-2025', '2025-2026', '2026-2027'];

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

  void _onSaveAttendance(List<StudentAttendance> originalList) async {
    final db = ref.read(databaseServiceProvider);
    
    // Merge edited with original
    final finalList = originalList.map((att) {
      if (_editedAttendance.containsKey(att.id)) {
        return _editedAttendance[att.id]!;
      }
      return att;
    }).toList();

    final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    await db.bulkUpdateAttendance(dateStr, _selectedClass, _selectedSection, finalList);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance saved successfully'), backgroundColor: AppTheme.success),
    );
    
    _editedAttendance.clear();
    
    ref.invalidate(classAttendanceProvider("$_selectedClass|$_selectedSection|$dateStr"));
  }

  void _initializeSheet() async {
    final db = ref.read(databaseServiceProvider);
    final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    
    try {
      await db.initializeAttendanceSheet(_selectedClass, _selectedSection, dateStr, 'admin');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance sheet initialized'), backgroundColor: AppTheme.success),
        );
      }
      
      ref.invalidate(classAttendanceProvider("$_selectedClass|$_selectedSection|$dateStr"));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      appBar: AppBar(
        title: const Text('Student Attendance', style: TextStyle(color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.bgSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryPurple,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryPurple,
          tabs: const [
            Tab(text: 'Daily Attendance'),
            Tab(text: 'Low Attendance Report'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDailyAttendanceTab(),
          _buildReportTab(),
        ],
      ),
    );
  }

  Widget _buildDailyAttendanceTab() {
    final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    final params = "$_selectedClass|$_selectedSection|$dateStr";
    final attendanceAsync = ref.watch(classAttendanceProvider(params));

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: AppTheme.cardDecoration(),
            child: Wrap(
              spacing: AppTheme.spacingMd,
              runSpacing: AppTheme.spacingMd,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildDropdown('Class', _selectedClass, _classes, (val) {
                  setState(() {
                    _selectedClass = val!;
                    _editedAttendance.clear();
                  });
                }),
                _buildDropdown('Section', _selectedSection, _sections, (val) {
                  setState(() {
                    _selectedSection = val!;
                    _editedAttendance.clear();
                  });
                }),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                        _editedAttendance.clear();
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryPurple),
                        const SizedBox(width: 8),
                        Text(dateStr, style: const TextStyle(color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _initializeSheet,
                  icon: const Icon(Icons.add_task),
                  label: const Text('Initialize Sheet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primarySoft,
                    foregroundColor: AppTheme.primaryPurple,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Expanded(
            child: Container(
              decoration: AppTheme.cardDecoration(),
              clipBehavior: Clip.antiAlias,
              child: attendanceAsync.when(
                data: (attendanceList) {
                  if (attendanceList.isEmpty) {
                    return const Center(child: Text('No attendance sheet found for this date.'));
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          itemCount: attendanceList.length,
                          separatorBuilder: (context, index) => const Divider(color: AppTheme.divider, height: 1),
                          itemBuilder: (context, index) {
                            final record = attendanceList[index];
                            final currentRecord = _editedAttendance[record.id] ?? record;

                            return FutureBuilder(
                              future: ref.read(databaseServiceProvider).getStudentById(record.studentId),
                              builder: (context, snapshot) {
                                final studentName = snapshot.data?.name ?? 'Loading...';
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('ID: ${record.studentId}'),
                                  trailing: SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment(value: 'present', label: Text('P')),
                                      ButtonSegment(value: 'absent', label: Text('A')),
                                      ButtonSegment(value: 'half_day', label: Text('H')),
                                      ButtonSegment(value: 'late', label: Text('L')),
                                      ButtonSegment(value: 'excused', label: Text('E')),
                                    ],
                                    selected: {currentRecord.status},
                                    onSelectionChanged: (Set<String> newSelection) {
                                      setState(() {
                                        _editedAttendance[record.id] = currentRecord.copyWith(status: newSelection.first);
                                      });
                                    },
                                    style: ButtonStyle(
                                      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                        if (states.contains(WidgetState.selected)) {
                                          return _getStatusColor(currentRecord.status).withOpacity(0.2);
                                        }
                                        return null;
                                      }),
                                      foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                        if (states.contains(WidgetState.selected)) {
                                          return _getStatusColor(currentRecord.status);
                                        }
                                        return AppTheme.textSecondary;
                                      }),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _onSaveAttendance(attendanceList),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: AppTheme.buttonRadius),
                            ),
                            child: const Text('Save Attendance'),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.error))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTab() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: AppTheme.cardDecoration(),
            child: Wrap(
              spacing: AppTheme.spacingMd,
              runSpacing: AppTheme.spacingMd,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildDropdown('Class', _reportClass, _classes, (val) {
                  setState(() {
                    _reportClass = val!;
                    _generateReport = false;
                  });
                }),
                _buildDropdown('Section', _reportSection, _sections, (val) {
                  setState(() {
                    _reportSection = val!;
                    _generateReport = false;
                  });
                }),
                _buildDropdown('Academic Year', _reportYear, _years, (val) {
                  setState(() {
                    _reportYear = val!;
                    _generateReport = false;
                  });
                }),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _generateReport = true;
                    });
                  },
                  icon: const Icon(Icons.analytics),
                  label: const Text('Generate Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          if (_generateReport)
            Expanded(
              child: Container(
                decoration: AppTheme.cardDecoration(),
                clipBehavior: Clip.antiAlias,
                child: Consumer(
                  builder: (context, ref, _) {
                    final params = "$_reportClass|$_reportSection|$_reportYear";
                    final reportAsync = ref.watch(lowAttendanceReportProvider(params));

                    return reportAsync.when(
                      data: (list) {
                        if (list.isEmpty) {
                          return const Center(child: Text('No students with low attendance found.'));
                        }
                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (context, index) => const Divider(color: AppTheme.divider, height: 1),
                          itemBuilder: (context, index) {
                            final item = list[index];
                            final student = item['student'] as Student;
                            final percent = item['percent'] as double;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.errorLight,
                                child: const Icon(Icons.warning_amber, color: AppTheme.error),
                              ),
                              title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('ID: ${student.id} | Class: ${student.gradeLevel} ${student.section ?? ''}'),
                              trailing: Text(
                                '${percent.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: AppTheme.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.error))),
                    );
                  },
                ),
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Text('Select parameters and click Generate Report', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.divider),
        borderRadius: BorderRadius.circular(8),
        color: AppTheme.bgSurface,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(label),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return AppTheme.success;
      case 'absent':
        return AppTheme.error;
      case 'half_day':
        return AppTheme.warning;
      case 'late':
        return AppTheme.info;
      case 'excused':
        return AppTheme.textSecondary;
      default:
        return AppTheme.primaryPurple;
    }
  }
}
