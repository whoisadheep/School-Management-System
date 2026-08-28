import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/services_provider.dart';
import '../../../core/auth/permission_helper.dart';

class FeeStructureSetupView extends ConsumerStatefulWidget {
  const FeeStructureSetupView({super.key});

  @override
  ConsumerState<FeeStructureSetupView> createState() => _FeeStructureSetupViewState();
}

class _FeeStructureSetupViewState extends ConsumerState<FeeStructureSetupView> {
  String _selectedClass = 'Grade 10';
  String _selectedAcademicYear = '2024-2025';

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classListProvider);
    final feeHeadsAsync = ref.watch(feeHeadsProvider);
    final param = ClassYearParam(className: _selectedClass, academicYear: _selectedAcademicYear);
    final structuresAsync = ref.watch(feeStructuresForClassProvider(param));

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
                    Text('Fee Structure Configuration',
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Define fee heads, recurring schedules, and annual/monthly amounts per class.',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showManageFeeHeadsDialog(context),
                      icon: const Icon(Icons.settings_rounded, size: 16),
                      label: Text('Manage Fee Heads',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryPurple,
                        side: const BorderSide(color: AppTheme.primaryPurple),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddStructureDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text('Add Fee Head to $_selectedClass',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filter Controls (Class & Academic Year Selectors)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            color: Colors.white,
            child: Row(
              children: [
                Text('Filter Class:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(width: 12),
                classesAsync.when(
                  data: (classes) {
                    final classNames = classes.map((c) => c.name).toList();
                    if (classNames.isEmpty) classNames.add('Grade 10');
                    if (!classNames.contains(_selectedClass)) {
                      _selectedClass = classNames.first;
                    }
                    return Container(
                      width: 220,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedClass,
                          isExpanded: true,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          items: classNames.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedClass = val);
                          },
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox(width: 220, child: LinearProgressIndicator()),
                  error: (_, __) => Text(_selectedClass),
                ),
                const SizedBox(width: 24),
                Text('Academic Year:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(width: 12),
                Container(
                  width: 160,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedAcademicYear,
                      isExpanded: true,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      items: const [
                        DropdownMenuItem(value: '2024-2025', child: Text('2024-2025')),
                        DropdownMenuItem(value: '2025-2026', child: Text('2025-2026')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedAcademicYear = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Main Table Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: structuresAsync.when(
                data: (structures) {
                  final feeHeadsList = feeHeadsAsync.value ?? [];
                  final headMap = {for (var fh in feeHeadsList) fh.id: fh};

                  if (structures.isEmpty) {
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
                          const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppTheme.textHint),
                          const SizedBox(height: 16),
                          Text('No fee structure configured for $_selectedClass ($_selectedAcademicYear).',
                              style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.textSecondary)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAddStructureDialog(context),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Configure Fee Heads'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                          ),
                        ],
                      ),
                    );
                  }

                  double totalAnnualPayable = 0.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(AppTheme.bgSurface),
                            columns: [
                              DataColumn(label: Text('Fee Head Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13))),
                              DataColumn(label: Text('Frequency', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13))),
                              DataColumn(label: Text('Due Day of Month', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13))),
                              DataColumn(label: Text('Amount (₹)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13))),
                              DataColumn(label: Text('Actions', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13))),
                            ],
                            rows: structures.map((fs) {
                              final headId = fs.feeHeadId ?? fs.feeCategoryId;
                              final head = headMap[headId];
                              final headName = head?.name ?? 'Fee Head ($headId)';
                              final freq = head?.frequency ?? 'monthly';

                              double annualValue = fs.amount;
                              if (freq == 'monthly') annualValue = fs.amount * 12;
                              if (freq == 'quarterly') annualValue = fs.amount * 4;
                              totalAnnualPayable += annualValue;

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        const Icon(Icons.payments_outlined, color: AppTheme.primaryPurple, size: 18),
                                        const SizedBox(width: 10),
                                        Text(headName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(freq.toUpperCase(),
                                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                                    ),
                                  ),
                                  DataCell(Text(fs.dueDayOfMonth != null ? 'Day ${fs.dueDayOfMonth} of month' : 'End of period',
                                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary))),
                                  DataCell(Text('₹${fs.amount.toStringAsFixed(2)}',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary))),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 18),
                                          onPressed: () => _showAddStructureDialog(context, existingStructure: fs),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 18),
                                          onPressed: () async {
                                            if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.deleteRecord)) return;
                                            final dbService = ref.read(databaseServiceProvider);
                                            await dbService.deleteFeeStructureRow(fs.id);
                                            ref.invalidate(feeStructuresForClassProvider(param));
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Total Summary Box
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Estimated Gross Annual Base Payable for $_selectedClass:',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textSecondary)),
                            Text('₹${totalAnnualPayable.toStringAsFixed(2)} / student',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryPurple)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Error loading fee structure: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStructureDialog(BuildContext context, {FeeStructure? existingStructure}) {
    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.editFeeStructure)) return;
    final feeHeadsList = ref.read(feeHeadsProvider).value ?? [];
    if (feeHeadsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No fee heads configured! Please add fee heads first.'), backgroundColor: AppTheme.error),
      );
      return;
    }

    String selectedHeadId = existingStructure?.feeHeadId ?? feeHeadsList.first.id;
    final amountController = TextEditingController(text: (existingStructure?.amount ?? 1500.0).toString());
    final dueDayController = TextEditingController(text: (existingStructure?.dueDayOfMonth ?? 10).toString());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(existingStructure == null ? 'Add Fee Head to $_selectedClass' : 'Edit Fee Structure Row',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedHeadId,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Select Fee Head *'),
                  items: feeHeadsList.map((fh) => DropdownMenuItem(
                    value: fh.id,
                    child: Text('${fh.name} (${fh.frequency})'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedHeadId = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Amount (₹) *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dueDayController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Due Day of Month (e.g. 10 for 10th of every month)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                final dueDay = int.tryParse(dueDayController.text.trim());
                if (amt <= 0) return;

                final dbService = ref.read(databaseServiceProvider);
                final fs = FeeStructure(
                  id: existingStructure?.id ?? const Uuid().v4(),
                  feeHeadId: selectedHeadId,
                  feeCategoryId: selectedHeadId,
                  className: _selectedClass,
                  academicYear: _selectedAcademicYear,
                  amount: amt,
                  dueDayOfMonth: dueDay,
                  createdAt: existingStructure?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await dbService.saveFeeStructureRow(fs);
                ref.invalidate(feeStructuresForClassProvider(ClassYearParam(className: _selectedClass, academicYear: _selectedAcademicYear)));

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved fee structure for $_selectedClass!'), backgroundColor: AppTheme.primaryPurple),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: const Text('Save Structure Row'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManageFeeHeadsDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedFrequency = 'monthly';
    bool isRecurring = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Consumer(
            builder: (context, ref, child) {
              final feeHeadsList = ref.watch(feeHeadsProvider).value ?? [];

              return AlertDialog(
                backgroundColor: Colors.white,
                title: Text('Manage Fee Heads Master Data', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                content: SizedBox(
                  width: 550,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Fee Heads:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                        const SizedBox(height: 8),
                        ...feeHeadsList.map((fh) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.label_important_rounded, color: AppTheme.primaryPurple),
                          title: Text(fh.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('${fh.frequency.toUpperCase()} • ${fh.description ?? "No description"}', style: GoogleFonts.poppins(fontSize: 11)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 18),
                            onPressed: () async {
                              if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.deleteRecord)) return;
                              final dbService = ref.read(databaseServiceProvider);
                              await dbService.deleteFeeHead(fh.id);
                              ref.invalidate(feeHeadsProvider);
                            },
                          ),
                        )),
                        const Divider(height: 24),
                    Text('Add New Fee Head:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Fee Head Name (e.g. Sports Fee, Technology Fee) *'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descController,
                      style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Description (Optional)'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedFrequency,
                      style: GoogleFonts.poppins(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Frequency *'),
                      items: const [
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                        DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                        DropdownMenuItem(value: 'annual', child: Text('Annual')),
                        DropdownMenuItem(value: 'one_time', child: Text('One-Time')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedFrequency = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: Text('Is Recurring Fee?', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      value: isRecurring,
                      activeTrackColor: AppTheme.primaryPurple,
                      onChanged: (val) => setDialogState(() => isRecurring = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ElevatedButton(
                onPressed: () async {
                  final nm = nameController.text.trim();
                  if (nm.isEmpty) return;

                  final dbService = ref.read(databaseServiceProvider);
                  final head = FeeHead(
                    id: 'fh-${nm.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}-${const Uuid().v4().substring(0, 4)}',
                    name: nm,
                    description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                    isRecurring: isRecurring,
                    frequency: selectedFrequency,
                  );

                  await dbService.createFeeHead(head);
                  ref.invalidate(feeHeadsProvider);
                  nameController.clear();
                  descController.clear();
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                child: const Text('Add Fee Head'),
              ),
            ],
          );
        },
      );
        },
      ),
    );
  }
}
