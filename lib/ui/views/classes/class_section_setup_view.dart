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
  final Map<String, bool> _expandedClasses = {};

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
                ElevatedButton.icon(
                  onPressed: () => _showAddEditClassDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('Add New Class',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    children: classes.map((classModel) {
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
                                          Text('Academic Year: ${classModel.academicYear ?? "Current"}  •  Default Capacity: ${classModel.capacity ?? 40} Seats',
                                              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                                        ],
                                      ),
                                    ),
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

                            // Sections Grid (Expandable)
                            if (isExpanded) ...[
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
    final yearController = TextEditingController(text: classModel?.academicYear ?? '2024-2025');
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
                decoration: const InputDecoration(labelText: 'Academic Year (e.g. 2024-2025) *'),
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

              final dbService = ref.read(databaseServiceProvider);
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
                await dbService.updateClass(updatedClass);
              }

              ref.invalidate(classListProvider);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Class $nm saved successfully!'), backgroundColor: AppTheme.primaryPurple),
                );
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
                await dbService.updateSection(updatedSec);
              }

              ref.invalidate(sectionsForClassProvider(classModel.id));

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Section $nm saved!'), backgroundColor: AppTheme.primaryPurple),
                );
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
}
