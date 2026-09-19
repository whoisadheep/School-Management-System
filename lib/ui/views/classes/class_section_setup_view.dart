import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../core/auth/permission_helper.dart';
import '../../../providers/services_provider.dart';

class ClassSectionSetupView extends ConsumerStatefulWidget {
  const ClassSectionSetupView({super.key});

  @override
  ConsumerState<ClassSectionSetupView> createState() => _ClassSectionSetupViewState();
}

class _ClassSectionSetupViewState extends ConsumerState<ClassSectionSetupView> {
  String _selectedAcademicYear = 'All';

  final Map<String, bool> _expandedClasses = {};

  void _showManageSessionsDialog(BuildContext context) {
    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.updateRecord)) return;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dbService = ref.read(databaseServiceProvider);
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryPurple),
                const SizedBox(width: 10),
                Text('Academic Sessions / Years', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: FutureBuilder<List<AcademicYear>>(
                future: dbService.getAllAcademicYears(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
                  }
                  final years = snapshot.data!;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage academic sessions for student enrolments, promotions, and class rollover.',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: years.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final y = years[i];
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              leading: Icon(
                                y.isCurrent ? Icons.check_circle_rounded : Icons.calendar_today_rounded,
                                color: y.isCurrent ? AppTheme.success : AppTheme.textSecondary,
                                size: 20,
                              ),
                              title: Text(y.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: Text(
                                '${y.startDate.toIso8601String().split('T')[0]} to ${y.endDate.toIso8601String().split('T')[0]}',
                                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                              trailing: y.isCurrent
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.success.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text('Current Active', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success)),
                                    )
                                  : TextButton(
                                      onPressed: () async {
                                        await dbService.setCurrentAcademicYear(y.id);
                                        setDialogState(() {});
                                        ref.invalidate(classListProvider);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Set ${y.name} as current active session!'), backgroundColor: AppTheme.primaryPurple),
                                          );
                                        }
                                      },
                                      child: const Text('Set as Current', style: TextStyle(fontSize: 11)),
                                    ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),
                      Text('Add New Session', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _showCreateSessionDialog(context, () {
                                  setDialogState(() {});
                                  ref.invalidate(classListProvider);
                                });
                              },
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text('Create New Session', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  void _showCreateSessionDialog(BuildContext context, VoidCallback onCreated) {
    final nameCtrl = TextEditingController(text: '2026-2027');
    final startCtrl = TextEditingController(text: '2026-04-01');
    final endCtrl = TextEditingController(text: '2027-03-31');
    bool isCurrent = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setCreateState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Create Academic Session', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Session Name (e.g. 2026-2027) *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: startCtrl,
                  decoration: const InputDecoration(labelText: 'Start Date (YYYY-MM-DD) *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: endCtrl,
                  decoration: const InputDecoration(labelText: 'End Date (YYYY-MM-DD) *'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Set as Current Active Session', style: GoogleFonts.poppins(fontSize: 12)),
                  value: isCurrent,
                  onChanged: (v) => setCreateState(() => isCurrent = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final nm = nameCtrl.text.trim();
                if (nm.isEmpty) return;

                final startDate = DateTime.tryParse(startCtrl.text.trim()) ?? DateTime(2026, 4, 1);
                final endDate = DateTime.tryParse(endCtrl.text.trim()) ?? DateTime(2027, 3, 31);
                final dbService = ref.read(databaseServiceProvider);

                final ay = AcademicYear(
                  id: 'ay-$nm',
                  name: nm,
                  startDate: startDate,
                  endDate: endDate,
                  isCurrent: isCurrent,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await dbService.createAcademicYear(ay);
                if (isCurrent) {
                  await dbService.setCurrentAcademicYear(ay.id);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  onCreated();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Session $nm created successfully!'), backgroundColor: AppTheme.primaryPurple),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: const Text('Save Session'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRolloverDialog(BuildContext context) {
    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.updateRecord)) return;
    
    bool isLoading = true;
    List<AcademicYear> years = [];
    String? sourceYear;
    String? targetYear;
    bool isCustomTarget = false;
    final customTargetController = TextEditingController(text: '2026-2027');
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isLoading) {
            ref.read(databaseServiceProvider).getAllAcademicYears().then((list) {
              setDialogState(() {
                years = list;
                if (list.isNotEmpty) {
                  sourceYear = list.firstWhere((y) => y.isCurrent, orElse: () => list.first).name;
                  targetYear = list.length > 1 ? list[1].name : '__new__';
                  if (targetYear == '__new__') isCustomTarget = true;
                } else {
                  isCustomTarget = true;
                }
                isLoading = false;
              });
            });
          }
          
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.auto_awesome_motion_rounded, color: AppTheme.primaryPurple),
                const SizedBox(width: 10),
                Text('Clone Classes to New Session', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: isLoading 
              ? const SizedBox(width: 420, height: 120, child: Center(child: CircularProgressIndicator()))
              : SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This will duplicate all classes and sections from the Source year into the Target year. Students and Teachers are NOT copied over, giving you a fresh start for the new year!', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: sourceYear,
                        decoration: const InputDecoration(labelText: 'Source Academic Year'),
                        items: years.map((y) => DropdownMenuItem(value: y.name, child: Text(y.name))).toList(),
                        onChanged: (v) => setDialogState(() => sourceYear = v),
                      ),
                      const SizedBox(height: 16),
                      if (!isCustomTarget) ...[
                        DropdownButtonFormField<String>(
                          value: targetYear,
                          decoration: const InputDecoration(labelText: 'Target Academic Year'),
                          items: [
                            ...years.map((y) => DropdownMenuItem(value: y.name, child: Text(y.name))),
                            const DropdownMenuItem(value: '__new__', child: Text('➕ Create New Session...', style: TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold))),
                          ],
                          onChanged: (v) {
                            if (v == '__new__') {
                              setDialogState(() {
                                isCustomTarget = true;
                                targetYear = customTargetController.text.trim();
                              });
                            } else {
                              setDialogState(() => targetYear = v);
                            }
                          },
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: customTargetController,
                                decoration: const InputDecoration(
                                  labelText: 'New Target Academic Year (e.g. 2026-2027) *',
                                  hintText: '2026-2027',
                                ),
                                onChanged: (v) => setDialogState(() => targetYear = v.trim()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Select existing year',
                              icon: const Icon(Icons.list_rounded, color: AppTheme.primaryPurple),
                              onPressed: () => setDialogState(() {
                                isCustomTarget = false;
                                targetYear = years.isNotEmpty ? years.first.name : null;
                              }),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading || sourceYear == null || (isCustomTarget ? customTargetController.text.trim().isEmpty : targetYear == null) || sourceYear == (isCustomTarget ? customTargetController.text.trim() : targetYear)
                  ? null
                  : () async {
                      final effectiveTarget = isCustomTarget ? customTargetController.text.trim() : targetYear!;
                      try {
                        final dbService = ref.read(databaseServiceProvider);
                        
                        // Ensure academic year exists in database
                        final parts = effectiveTarget.split('-');
                        final startY = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 2026 : 2026;
                        final endY = parts.length > 1 ? int.tryParse(parts[1]) ?? 2027 : 2027;
                        final ay = AcademicYear(
                          id: 'ay-$effectiveTarget',
                          name: effectiveTarget,
                          startDate: DateTime(startY, 6, 1),
                          endDate: DateTime(endY, 4, 30),
                          isCurrent: false,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        await dbService.createAcademicYear(ay);

                        await dbService.cloneClassesToAcademicYear(sourceYear!, effectiveTarget);
                        ref.invalidate(classListProvider);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully cloned classes to $effectiveTarget!'), backgroundColor: AppTheme.primaryPurple));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
                        }
                      }
                    },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                child: const Text('Clone Now'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classListProvider);
    final staffAsync = ref.watch(staffListProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
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
                    Text('Class & Section Setup',
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Manage academic classes, sections, seat capacity, and assigned class teachers.',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showManageSessionsDialog(context),
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: Text('Manage Sessions', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryPurple,
                        side: const BorderSide(color: AppTheme.primaryPurple),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _showRolloverDialog(context),
                      icon: const Icon(Icons.auto_awesome_motion_rounded, size: 18),
                      label: Text('Clone to New Session', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryPurple,
                        side: const BorderSide(color: AppTheme.primaryPurple),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditClassDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text('Add New Class', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Academic Year Filter


          Padding(


            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),


            child: Row(


              children: [


                const Icon(Icons.filter_list_rounded, color: AppTheme.primaryPurple, size: 20),


                const SizedBox(width: 8),


                Text('Filter by Academic Year:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),


                const SizedBox(width: 16),


                Container(


                  width: 200,


                  padding: const EdgeInsets.symmetric(horizontal: 16),


                  decoration: BoxDecoration(


                    color: Colors.white,


                    borderRadius: BorderRadius.circular(8),


                    border: Border.all(color: AppTheme.divider),


                  ),


                  child: DropdownButtonHideUnderline(


                    child: classesAsync.when(


                      data: (classes) {


                        final years = classes.map((c) => c.academicYear).where((y) => y != null).map((y) => y!).toSet().toList()..sort();


                        return DropdownButton<String>(


                          value: _selectedAcademicYear,


                          isExpanded: true,


                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),


                          items: [


                            const DropdownMenuItem(value: 'All', child: Text('All Sessions')),


                            ...years.map((y) => DropdownMenuItem(value: y, child: Text(y))),


                          ],


                          onChanged: (val) {


                            if (val != null) setState(() => _selectedAcademicYear = val);


                          },


                        );


                      },


                      loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),


                      error: (_, __) => const Text('Error'),


                    ),


                  ),


                ),


              ],


            ),


          ),


          // Main Content List
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: classesAsync.when(
                data: (classes) {
                  if (classes.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(48),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.class_rounded, size: 48, color: AppTheme.textHint),
                          const SizedBox(height: 16),
                          Text('No classes configured yet.', style: GoogleFonts.poppins(fontSize: 16, color: AppTheme.textSecondary)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => _showAddEditClassDialog(context),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                            child: const Text('Add First Class'),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: classes.where((c) => _selectedAcademicYear == 'All' || c.academicYear == _selectedAcademicYear).map((classModel) {
                      final isExpanded = _expandedClasses[classModel.id] ?? true;
                      final sectionsAsync = ref.watch(sectionsForClassProvider(classModel.id));

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.divider),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            // Class Header Bar
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _expandedClasses[classModel.id] = !isExpanded;
                                });
                              },
                              borderRadius: BorderRadius.vertical(
                                top: const Radius.circular(16),
                                bottom: isExpanded ? Radius.zero : const Radius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.school_rounded, color: AppTheme.primaryPurple, size: 22),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(classModel.name,
                                              style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.textPrimary)),
                                          const SizedBox(height: 2),
                                          Consumer(
                                            builder: (context, ref, _) {
                                              final classStudentCountAsync = ref.watch(classStudentCountProvider(classModel.id));
                                              final countText = classStudentCountAsync.when(
                                                data: (cnt) => '  •  Enrolled: $cnt Students',
                                                loading: () => '',
                                                error: (_, __) => '',
                                              );
                                              return Text('Academic Year: ${classModel.academicYear ?? "Current"}$countText  •  Default Capacity: ${classModel.capacity ?? 40} Seats',
                                                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary));
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                     OutlinedButton.icon(
                                       onPressed: () => _showManageClassSubjectsDialog(context, classModel),
                                       icon: const Icon(Icons.menu_book_rounded, size: 14),
                                       label: Text('Subjects', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                                       style: OutlinedButton.styleFrom(
                                         foregroundColor: AppTheme.primaryPurple,
                                         side: const BorderSide(color: AppTheme.primaryPurple),
                                       ),
                                     ),
                                     const SizedBox(width: 8),
                                     OutlinedButton.icon(
                                       onPressed: () => _showAddEditSectionDialog(context, classModel),
                                       icon: const Icon(Icons.add_rounded, size: 14),
                                       label: Text('Add Section', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                                       style: OutlinedButton.styleFrom(
                                         foregroundColor: AppTheme.primaryPurple,
                                         side: const BorderSide(color: AppTheme.primaryPurple),
                                       ),
                                     ),
                                     const SizedBox(width: 12),
                                     IconButton(
                                       icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 20),
                                       onPressed: () => _showAddEditClassDialog(context, classModel: classModel),
                                       tooltip: 'Edit Class',
                                     ),
                                     IconButton(
                                       icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                                       onPressed: () {
                                         if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.deleteRecord)) return;
                                         _confirmDeleteClass(context, classModel);
                                       },
                                       tooltip: 'Delete Class',
                                     ),
                                     Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
                                   ],
                                 ),
                               ),
                             ),

                             // Class Content (Expandable: Subjects & Sections)
                             if (isExpanded) ...[
                               const Divider(height: 1),
                               // Class Subjects Section
                               Padding(
                                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Row(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                         Row(
                                           children: [
                                             const Icon(Icons.auto_stories_rounded, size: 18, color: AppTheme.primaryPurple),
                                             const SizedBox(width: 8),
                                             Text(
                                               'Class Subjects Curriculum',
                                               style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                             ),
                                             const SizedBox(width: 8),
                                             Consumer(
                                               builder: (context, ref, _) {
                                                 final subsAsync = ref.watch(classSubjectsProvider(classModel.id));
                                                 return subsAsync.when(
                                                   data: (subs) => Container(
                                                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                     decoration: BoxDecoration(
                                                       color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                                                       borderRadius: BorderRadius.circular(12),
                                                     ),
                                                     child: Text(
                                                       '${subs.length} subjects',
                                                       style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple),
                                                     ),
                                                   ),
                                                   loading: () => const SizedBox.shrink(),
                                                   error: (_, __) => const SizedBox.shrink(),
                                                 );
                                               },
                                             ),
                                           ],
                                         ),
                                         TextButton.icon(
                                           onPressed: () => _showManageClassSubjectsDialog(context, classModel),
                                           icon: const Icon(Icons.tune_rounded, size: 14),
                                           label: Text('Manage Subjects', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                                           style: TextButton.styleFrom(foregroundColor: AppTheme.primaryPurple),
                                         ),
                                       ],
                                     ),
                                     const SizedBox(height: 8),
                                     Consumer(
                                       builder: (context, ref, _) {
                                         final subsAsync = ref.watch(classSubjectsProvider(classModel.id));
                                         return subsAsync.when(
                                           data: (subjects) {
                                             if (subjects.isEmpty) {
                                               return Container(
                                                 width: double.infinity,
                                                 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                 decoration: BoxDecoration(
                                                   color: AppTheme.bgMain,
                                                   borderRadius: BorderRadius.circular(8),
                                                   border: Border.all(color: AppTheme.divider),
                                                 ),
                                                 child: Row(
                                                   children: [
                                                     const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.textHint),
                                                     const SizedBox(width: 8),
                                                     Expanded(
                                                       child: Text(
                                                         'No subjects configured for ${classModel.name} yet. Configure subjects to auto-populate them when creating exams.',
                                                         style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                                                       ),
                                                     ),
                                                     TextButton(
                                                       onPressed: () => _showManageClassSubjectsDialog(context, classModel),
                                                       child: const Text('Add Subjects', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                     ),
                                                   ],
                                                 ),
                                               );
                                             }
                                             return Wrap(
                                               spacing: 8,
                                               runSpacing: 8,
                                               children: subjects.map((sub) {
                                                 return Container(
                                                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                   decoration: BoxDecoration(
                                                     color: AppTheme.bgMain,
                                                     borderRadius: BorderRadius.circular(8),
                                                     border: Border.all(color: AppTheme.divider),
                                                   ),
                                                   child: Row(
                                                     mainAxisSize: MainAxisSize.min,
                                                     children: [
                                                       const Icon(Icons.menu_book_rounded, size: 14, color: AppTheme.primaryPurple),
                                                       const SizedBox(width: 6),
                                                       Text(
                                                         sub.subjectName,
                                                         style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                                       ),
                                                       const SizedBox(width: 6),
                                                       Container(
                                                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                         decoration: BoxDecoration(
                                                           color: Colors.white,
                                                           borderRadius: BorderRadius.circular(4),
                                                           border: Border.all(color: AppTheme.divider),
                                                         ),
                                                         child: Text(
                                                           'Max: ${sub.defaultMaxMarks.toStringAsFixed(0)} | Pass: ${sub.defaultPassMarks.toStringAsFixed(0)}',
                                                           style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
                                                         ),
                                                       ),
                                                       const SizedBox(width: 4),
                                                       InkWell(
                                                         onTap: () async {
                                                           final dbService = ref.read(databaseServiceProvider);
                                                           await dbService.deleteClassSubject(sub.id);
                                                           ref.invalidate(classSubjectsProvider(classModel.id));
                                                         },
                                                         borderRadius: BorderRadius.circular(10),
                                                         child: const Padding(
                                                           padding: EdgeInsets.all(2.0),
                                                           child: Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
                                                         ),
                                                       ),
                                                     ],
                                                   ),
                                                 );
                                               }).toList(),
                                             );
                                           },
                                           loading: () => const LinearProgressIndicator(),
                                           error: (e, _) => Text('Error loading subjects: $e', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.error)),
                                         );
                                       },
                                     ),
                                   ],
                                 ),
                               ),
                               const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: sectionsAsync.when(
                                  data: (sections) {
                                    if (sections.isEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                                        child: Center(
                                          child: Text('No sections created for ${classModel.name}. Click "Add Section" to create Section A.',
                                              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint, fontStyle: FontStyle.italic)),
                                        ),
                                      );
                                    }
                                    return Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      children: sections.map((sec) {
                                        final studentCountAsync = ref.watch(sectionStudentCountProvider(sec.id));
                                        final staffList = staffAsync.value ?? [];
                                        final teacher = staffList.where((s) => s.id == sec.classTeacherId).firstOrNull;

                                        return Container(
                                          width: 320,
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: AppTheme.bgSurface,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AppTheme.divider),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.primaryPurple,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text('Section ${sec.name}',
                                                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                                  ),
                                                  Row(
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textSecondary),
                                                        onPressed: () => _showAddEditSectionDialog(context, classModel, section: sec),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.error),
                                                        onPressed: () async {
                                                          if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.deleteRecord)) return;
                                                          final dbService = ref.read(databaseServiceProvider);
                                                          
                                                          final count = await dbService.getStudentCountForSection(sec.id);
                                                          if (count > 0) {
                                                            if (context.mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(content: Text('Cannot delete section with $count enrolled student(s).'), backgroundColor: AppTheme.error),
                                                              );
                                                            }
                                                            return;
                                                          }

                                                          await dbService.deleteSection(sec.id);
                                                          ref.invalidate(sectionsForClassProvider(classModel.id));
                                                          ref.invalidate(classStudentCountProvider(classModel.id));
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              studentCountAsync.when(
                                                data: (count) => Text('Enrolled Students: $count / ${sec.capacity ?? 40} Seats',
                                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                                loading: () => const SizedBox(height: 16),
                                                error: (_, __) => const SizedBox(height: 16),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  const Icon(Icons.person_rounded, size: 14, color: AppTheme.primaryPurple),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      teacher != null ? 'In-Charge: ${teacher.fullName}' : 'In-Charge: Unassigned',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 11,
                                                        fontWeight: teacher != null ? FontWeight.bold : FontWeight.normal,
                                                        color: teacher != null ? AppTheme.primaryPurple : AppTheme.textHint,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  InkWell(
                                                    onTap: () => _showAssignTeacherDialog(context, sec, staffList),
                                                    child: Text('Assign', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.primaryPurple, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                  loading: () => const CircularProgressIndicator(),
                                  error: (e, s) => Text('Error loading sections: $e'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Error loading classes: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditClassDialog(BuildContext context, {ClassModel? classModel}) {
    final nameController = TextEditingController(text: classModel?.name ?? 'Grade 11');
    final yearController = TextEditingController(text: classModel?.academicYear ?? '2026-2027');
    final capacityController = TextEditingController(text: (classModel?.capacity ?? 40).toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(classModel == null ? 'Add New Class' : 'Edit Class', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Class Name (e.g. Grade 10, Class 8) *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearController,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Academic Year (e.g. 2026-2027) *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capacityController,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Default Class Capacity (Seats) *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final nm = nameController.text.trim();
              final yr = yearController.text.trim();
              final cap = int.tryParse(capacityController.text.trim()) ?? 40;
              if (nm.isEmpty) return;

              try {
                final dbService = ref.read(databaseServiceProvider);
                
                // Ensure academic year exists in academic_years table
                if (yr.isNotEmpty) {
                  final parts = yr.split('-');
                  final startY = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 2026 : 2026;
                  final endY = parts.length > 1 ? int.tryParse(parts[1]) ?? 2027 : 2027;
                  final ay = AcademicYear(
                    id: 'ay-$yr',
                    name: yr,
                    startDate: DateTime(startY, 6, 1),
                    endDate: DateTime(endY, 4, 30),
                    isCurrent: false,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  await dbService.createAcademicYear(ay);
                }

                if (classModel == null) {
                  final classId = 'cls-${nm.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}-${const Uuid().v4().substring(0, 4)}';
                  final newClass = ClassModel(
                    id: classId,
                    name: nm,
                    academicYear: yr,
                    capacity: cap,
                    createdAt: DateTime.now(),
                  );
                  await dbService.createClass(newClass);
                  // Automatically seed Section A
                  final sec = Section(
                    id: 'sec-${classId.replaceFirst('cls-', '')}-a',
                    classId: classId,
                    name: 'A',
                    capacity: cap,
                  );
                  await dbService.createSection(sec);
                } else {
                  final updatedClass = classModel.copyWith(
                    name: nm,
                    academicYear: yr,
                    capacity: cap,
                  );
                  if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.updateRecord)) return;
                  await dbService.updateClass(updatedClass);
                }

                ref.invalidate(classListProvider);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Class $nm saved successfully!'), backgroundColor: AppTheme.primaryPurple),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save class: $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
            child: const Text('Save Class'),
          ),
        ],
      ),
    );
  }

  void _showAddEditSectionDialog(BuildContext context, ClassModel classModel, {Section? section}) {
    final nameController = TextEditingController(text: section?.name ?? 'B');
    final capacityController = TextEditingController(text: (section?.capacity ?? classModel.capacity ?? 40).toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(section == null ? 'Add Section to ${classModel.name}' : 'Edit Section', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Section Name (e.g. A, B, C, D) *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capacityController,
                style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Section Capacity (Max Students) *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final nm = nameController.text.trim().toUpperCase();
              final cap = int.tryParse(capacityController.text.trim()) ?? 40;
              if (nm.isEmpty) return;

              try {
                final dbService = ref.read(databaseServiceProvider);
                if (section == null) {
                  final secId = 'sec-${classModel.id.replaceFirst('cls-', '')}-${nm.toLowerCase()}';
                  final newSec = Section(
                    id: secId,
                    classId: classModel.id,
                    name: nm,
                    capacity: cap,
                  );
                  await dbService.createSection(newSec);
                } else {
                  final updatedSec = section.copyWith(name: nm, capacity: cap);
                  if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.updateRecord)) return;
                  await dbService.updateSection(updatedSec);
                }

                ref.invalidate(sectionsForClassProvider(classModel.id));
                ref.invalidate(classStudentCountProvider(classModel.id));
                if (section != null) ref.invalidate(sectionStudentCountProvider(section.id));

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Section $nm saved!'), backgroundColor: AppTheme.primaryPurple),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save section: $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
            child: const Text('Save Section'),
          ),
        ],
      ),
    );
  }

  void _showAssignTeacherDialog(BuildContext context, Section section, List<Staff> staffList) {
    String? selectedStaffId = section.classTeacherId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Assign Class In-Charge Teacher', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: DropdownButtonFormField<String?>(
              value: selectedStaffId,
              style: GoogleFonts.poppins(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Select Class Teacher *'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Unassigned (No Class Teacher)')),
                ...staffList.map((st) => DropdownMenuItem<String?>(
                  value: st.id,
                  child: Text('${st.fullName} (${st.designation ?? st.role})'),
                )),
              ],
              onChanged: (val) => setDialogState(() => selectedStaffId = val),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final dbService = ref.read(databaseServiceProvider);
                await dbService.assignClassTeacherToSection(section.id, selectedStaffId);
                ref.invalidate(sectionsForClassProvider(section.classId));

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Class Teacher assignment updated!'), backgroundColor: AppTheme.primaryPurple),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: const Text('Save Assignment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteClass(BuildContext context, ClassModel classModel) async {
    final dbService = ref.read(databaseServiceProvider);
    
    // Check if any sections have students
    final sections = await dbService.getSectionsForClass(classModel.id);
    int totalStudents = 0;
    for (final sec in sections) {
      totalStudents += await dbService.getStudentCountForSection(sec.id);
    }

    if (!context.mounted) return;

    if (totalStudents > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Cannot Delete Class', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text('This class currently has $totalStudents student(s) enrolled across its sections. You must reassign or remove these students before deleting the class.',
              style: GoogleFonts.poppins(fontSize: 13)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: const Text('Okay'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${classModel.name}?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this class and all associated sections? This action cannot be undone.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await dbService.deleteClass(classModel.id);
              ref.invalidate(classListProvider);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted ${classModel.name}'), backgroundColor: AppTheme.error),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Delete Class'),
          ),
        ],
      ),
    );
  }

  void _showManageClassSubjectsDialog(BuildContext context, ClassModel classModel) {
    final subjectNameCtrl = TextEditingController();
    final maxMarksCtrl = TextEditingController(text: '100');
    final passMarksCtrl = TextEditingController(text: '35');

    final suggestedSubjects = [
      'Mathematics',
      'English',
      'Hindi',
      'Science',
      'Social Studies',
      'Computer Science',
      'Physics',
      'Chemistry',
      'Biology',
      'History',
      'Geography',
      'Sanskrit',
      'Art & Craft',
      'Physical Education',
      'Economics',
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) => Consumer(
        builder: (context, ref, _) {
          final subjectsAsync = ref.watch(classSubjectsProvider(classModel.id));
          final dbService = ref.read(databaseServiceProvider);

          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: AppTheme.primaryPurple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Manage Subjects — ${classModel.name}',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Configure subjects taught in this class. They will auto-populate during exam creation.',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Add Suggestions
                      Text('Suggested Subjects (Click to add):',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      subjectsAsync.when(
                        data: (existingSubs) {
                          final existingNames = existingSubs.map((s) => s.subjectName.toLowerCase()).toSet();
                          return Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: suggestedSubjects.map((sName) {
                              final isAdded = existingNames.contains(sName.toLowerCase());
                              return ActionChip(
                                avatar: Icon(
                                  isAdded ? Icons.check_circle_rounded : Icons.add_rounded,
                                  size: 14,
                                  color: isAdded ? AppTheme.success : AppTheme.primaryPurple,
                                ),
                                label: Text(
                                  sName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: isAdded ? AppTheme.textSecondary : AppTheme.primaryPurple,
                                    fontWeight: isAdded ? FontWeight.normal : FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: isAdded ? AppTheme.bgMain : AppTheme.primaryPurple.withValues(alpha: 0.08),
                                side: BorderSide(
                                  color: isAdded ? AppTheme.divider : AppTheme.primaryPurple.withValues(alpha: 0.3),
                                ),
                                onPressed: isAdded
                                    ? null
                                    : () async {
                                        final sub = ClassSubject.create(
                                          classId: classModel.id,
                                          subjectName: sName,
                                          defaultMaxMarks: 100.0,
                                          defaultPassMarks: 35.0,
                                        );
                                        await dbService.addClassSubject(sub);
                                        ref.invalidate(classSubjectsProvider(classModel.id));
                                      },
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Add Custom Subject Form
                      Text('Add Custom Subject:',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: subjectNameCtrl,
                              style: GoogleFonts.poppins(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Subject name (e.g. Sanskrit)',
                                labelText: 'Subject Name',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: maxMarksCtrl,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.poppins(fontSize: 12),
                              decoration: InputDecoration(
                                labelText: 'Max Marks',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: passMarksCtrl,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.poppins(fontSize: 12),
                              decoration: InputDecoration(
                                labelText: 'Pass Marks',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final name = subjectNameCtrl.text.trim();
                              if (name.isEmpty) return;
                              final maxM = double.tryParse(maxMarksCtrl.text.trim()) ?? 100.0;
                              final passM = double.tryParse(passMarksCtrl.text.trim()) ?? 35.0;

                              final sub = ClassSubject.create(
                                classId: classModel.id,
                                subjectName: name,
                                defaultMaxMarks: maxM,
                                defaultPassMarks: passM,
                              );
                              await dbService.addClassSubject(sub);
                              subjectNameCtrl.clear();
                              ref.invalidate(classSubjectsProvider(classModel.id));
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: Text('Add', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Configured Subjects Table/List
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Configured Subjects for ${classModel.name}:',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          subjectsAsync.when(
                            data: (subs) => subs.isEmpty
                                ? OutlinedButton.icon(
                                    onPressed: () async {
                                      final standard = ['Mathematics', 'English', 'Hindi', 'Science', 'Social Studies'];
                                      await dbService.setSubjectsForClass(classModel.id, standard);
                                      ref.invalidate(classSubjectsProvider(classModel.id));
                                    },
                                    icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                                    label: Text('Seed Standard Subjects', style: GoogleFonts.poppins(fontSize: 11)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primaryPurple,
                                      side: const BorderSide(color: AppTheme.primaryPurple),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      subjectsAsync.when(
                        data: (subs) {
                          if (subs.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.bgMain,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(Icons.menu_book_outlined, size: 36, color: AppTheme.textHint),
                                    const SizedBox(height: 8),
                                    Text('No subjects added for this class yet.',
                                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                                    const SizedBox(height: 4),
                                    Text('Click suggested subjects above or add custom ones.',
                                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: subs.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final s = subs[idx];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.menu_book_rounded, size: 18, color: AppTheme.primaryPurple),
                                  title: Text(s.subjectName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    'Default Max: ${s.defaultMaxMarks.toStringAsFixed(0)}  •  Pass: ${s.defaultPassMarks.toStringAsFixed(0)}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                                    tooltip: 'Remove Subject',
                                    onPressed: () async {
                                      await dbService.deleteClassSubject(s.id);
                                      ref.invalidate(classSubjectsProvider(classModel.id));
                                    },
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error loading subjects: $e', style: GoogleFonts.poppins(color: AppTheme.error)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
