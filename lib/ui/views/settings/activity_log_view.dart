import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/services_provider.dart';
import '../../layout/widgets/glass_card.dart';
import '../../../models/audit_log.dart';

final auditLogsProvider = FutureProvider.autoDispose<List<AuditLog>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  final db = await dbService.rawDb;
  final results = await db.query('audit_logs', orderBy: 'timestamp DESC', limit: 1000);
  return results.map((m) => AuditLog.fromMap(m)).toList();
});

class ActivityLogView extends ConsumerStatefulWidget {
  const ActivityLogView({super.key});

  @override
  ConsumerState<ActivityLogView> createState() => _ActivityLogViewState();
}

class _ActivityLogViewState extends ConsumerState<ActivityLogView> {
  String? _selectedAction;
  String? _selectedModule;

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Activity Log (Audit Trail)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppTheme.primaryPurple), onPressed: () => ref.invalidate(auditLogsProvider)),
          const SizedBox(width: 24),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Filters
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _selectedAction,
                    decoration: const InputDecoration(labelText: 'Filter by Action'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Actions')),
                      DropdownMenuItem(value: 'create', child: Text('Create')),
                      DropdownMenuItem(value: 'update', child: Text('Update')),
                      DropdownMenuItem(value: 'delete', child: Text('Delete')),
                      DropdownMenuItem(value: 'login', child: Text('Login')),
                      DropdownMenuItem(value: 'risky_action_blocked', child: Text('Blocked Actions')),
                    ],
                    onChanged: (val) => setState(() => _selectedAction = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _selectedModule,
                    decoration: const InputDecoration(labelText: 'Filter by Module'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Modules')),
                      DropdownMenuItem(value: 'Security', child: Text('Security')),
                      DropdownMenuItem(value: 'students', child: Text('Students')),
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                      DropdownMenuItem(value: 'fees', child: Text('Fees')),
                      DropdownMenuItem(value: 'exams', child: Text('Exams')),
                    ],
                    onChanged: (val) => setState(() => _selectedModule = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GlassCard(
                child: logsAsync.when(
                  data: (logs) {
                    final filtered = logs.where((l) {
                      if (_selectedAction != null && l.actionType != _selectedAction) return false;
                      if (_selectedModule != null && l.module != _selectedModule) return false;
                      return true;
                    }).toList();

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final log = filtered[index];
                        final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp);
                        
                        return ListTile(
                          title: Text('${log.actionType.toUpperCase()} - ${log.description}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Module: ${log.module} • By: ${log.adminUserId ?? "Unknown"} • Time: $timeStr', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                              if (log.actionType == 'update' && log.oldValue != null && log.newValue != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text('Changes:\nFrom: ${log.oldValue}\nTo: ${log.newValue}', style: GoogleFonts.sourceCodePro(fontSize: 10, color: Colors.blueGrey)),
                                ),
                            ],
                          ),
                          isThreeLine: log.actionType == 'update',
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('Error: $e'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
