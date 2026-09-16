import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:school_management_system/core/theme/app_theme.dart';
import 'package:school_management_system/providers/services_provider.dart';
import 'package:school_management_system/providers/navigation_provider.dart';
import 'package:school_management_system/providers/dashboard_provider.dart';
import 'package:school_management_system/services/import_service.dart';
import 'package:school_management_system/services/column_mapping_service.dart';
import 'package:school_management_system/ui/widgets/ai_column_mapping_dialog.dart';

class DataImportView extends ConsumerStatefulWidget {
  const DataImportView({super.key});

  @override
  ConsumerState<DataImportView> createState() => _DataImportViewState();
}

class _DataImportViewState extends ConsumerState<DataImportView> {
  bool _isImporting = false;
  bool _isAnalyzing = false;
  String _importResult = '';

  Future<void> _downloadTemplate(String type) async {
    try {
      final importService = ImportService(dbService: ref.read(databaseServiceProvider));
      String csvData = '';
      String fileName = '';

      if (type == 'students') {
        csvData = importService.generateStudentTemplateCSV();
        fileName = 'students_template.csv';
      } else if (type == 'staff') {
        csvData = importService.generateStaffTemplateCSV();
        fileName = 'staff_template.csv';
      }

      // Check if running on desktop or mobile
      String path = '';
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final dir = await getDownloadsDirectory();
        path = '${dir?.path ?? ''}/$fileName';
      } else {
        final dir = await getApplicationDocumentsDirectory();
        path = '${dir.path}/$fileName';
      }

      final file = File(path);
      await file.writeAsString(csvData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Template downloaded to: $path')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error downloading template: $e')));
      }
    }
  }

  /// Student import with AI Smart Column Mapper.
  Future<void> _importStudentsWithAI() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final dbService = ref.read(databaseServiceProvider);
      final importService = ImportService(dbService: dbService);

      // Step 1: Extract headers
      setState(() {
        _isAnalyzing = true;
        _importResult = '';
      });

      final headers = await importService.extractHeaders(file);
      final sampleRow = await importService.extractSampleRow(file);
      final rows = await importService.parseFile(file);
      final totalRows = rows.length;

      if (headers.isEmpty) {
        setState(() {
          _isAnalyzing = false;
          _importResult = 'Error: Could not read headers from the file. Is it empty?';
        });
        return;
      }

      // Step 2: Ask AI to map columns (OpenRouter -> Groq -> Gemini -> Local)
      final mappingService = ColumnMappingService(dbService);
      final mappingResponse = await mappingService.mapColumnsWithAI(headers);

      setState(() { _isAnalyzing = false; });

      if (!mounted) return;

      // Step 3: Show review dialog
      final confirmedMappings = await AIColumnMappingDialog.show(
        context: context,
        mappings: mappingResponse.mappings,
        sampleRow: sampleRow,
        totalRows: totalRows,
        providerName: mappingResponse.providerName,
        model: mappingResponse.model,
      );

      if (confirmedMappings == null) {
        // User cancelled
        return;
      }

      // Step 4: Build the eduviaKey -> sourceColumn mapping
      final Map<String, String> finalMapping = {};
      for (final m in confirmedMappings) {
        if (m.eduviaFieldKey != 'skip') {
          finalMapping[m.eduviaFieldKey] = m.sourceHeader;
        }
      }

      // Step 5: Run import
      setState(() {
        _isImporting = true;
        _importResult = 'Importing $totalRows students...';
      });

      final res = await importService.importStudentsWithMapping(
        file: file,
        mapping: finalMapping,
      );

      ref.invalidate(studentsListProvider);
      ref.invalidate(dashboardMetricsProvider);

      setState(() {
        _importResult = '✅ Import Complete! Successfully imported ${res.successCount} student${res.successCount == 1 ? '' : 's'}.\nFailed: ${res.failureCount}';
        if (res.errors.isNotEmpty) {
          _importResult += '\n\nErrors (Showing top 5):\n${res.errors.take(5).join('\n')}';
        }
      });

      if (mounted) {
        if (res.successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Students Imported Successfully!',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${res.successCount} student${res.successCount == 1 ? '' : 's'} imported through AI Mapper.${res.failureCount > 0 ? " (${res.failureCount} failed)" : ""}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 4),
            ),
          );

          _showImportSuccessDialog(
            title: 'Students Imported Successfully',
            successCount: res.successCount,
            failureCount: res.failureCount,
            entityName: 'student',
            targetTab: NavigationTab.students,
            targetTabName: 'View Student Directory',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No students imported. ${res.failureCount} record(s) failed validation.',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _importResult = 'Error during import: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Failed to import students: $e',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() {
        _isImporting = false;
        _isAnalyzing = false;
      });
    }
  }

  /// Legacy staff import (no AI mapping needed — simpler schema).
  Future<void> _importStaff() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _isImporting = true;
        _importResult = 'Importing...';
      });

      final file = result.files.first;
      final importService = ImportService(dbService: ref.read(databaseServiceProvider));
      final res = await importService.importStaff(file);
      ref.invalidate(staffListProvider);
      ref.invalidate(dashboardMetricsProvider);

      setState(() {
        _importResult = '✅ Import Complete! Successfully imported ${res.successCount} staff record${res.successCount == 1 ? '' : 's'}.\nFailed: ${res.failureCount}';
        if (res.errors.isNotEmpty) {
          _importResult += '\n\nErrors (Showing top 5):\n${res.errors.take(5).join('\n')}';
        }
      });

      if (mounted) {
        if (res.successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Staff Imported Successfully!',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${res.successCount} staff record${res.successCount == 1 ? '' : 's'} imported.${res.failureCount > 0 ? " (${res.failureCount} failed)" : ""}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 4),
            ),
          );

          _showImportSuccessDialog(
            title: 'Staff Imported Successfully',
            successCount: res.successCount,
            failureCount: res.failureCount,
            entityName: 'staff member',
            targetTab: NavigationTab.staff,
            targetTabName: 'View Staff Directory',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No staff records imported. ${res.failureCount} failed validation.',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _importResult = 'Error during import: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Failed to import staff: $e',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  void _showImportSuccessDialog({
    required String title,
    required int successCount,
    required int failureCount,
    required String entityName,
    NavigationTab? targetTab,
    String? targetTabName,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppTheme.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Successfully imported $successCount $entityName${successCount == 1 ? '' : 's'} into the database.',
              style: GoogleFonts.poppins(fontSize: 13.5, color: AppTheme.textPrimary),
            ),
            if (failureCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                '⚠️ $failureCount record${failureCount == 1 ? '' : 's'} failed to import. Check the error log below for details.',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Dismiss', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
          ),
          if (targetTab != null && targetTabName != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                ref.read(selectedTabProvider.notifier).state = targetTab;
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(targetTabName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStudentImportCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school, size: 32, color: AppTheme.primaryPurple),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Import Students', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_fix_high_rounded, size: 12, color: AppTheme.primaryPurple),
                                const SizedBox(width: 4),
                                Text(
                                  'AI Smart Mapper',
                                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Upload any CSV or Excel file — our AI will automatically detect and map your columns to Eduvia fields.\n'
              'No need to match exact column names! Review the mapping before importing.',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '🔒 Only column headers are sent to AI — zero student data leaves your device.',
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF166534), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: (_isImporting || _isAnalyzing) ? null : () => _downloadTemplate('students'),
                  icon: const Icon(Icons.download, size: 16),
                  label: Text('Download Template', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryPurple),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: (_isImporting || _isAnalyzing) ? null : _importStudentsWithAI,
                  icon: _isAnalyzing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: Text(
                    _isAnalyzing ? 'AI Analyzing...' : 'Import with AI Mapper',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
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
    );
  }

  Widget _buildStaffImportCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, size: 32, color: AppTheme.primaryPurple),
                const SizedBox(width: 16),
                Text('Import Staff', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '1. Download the template CSV.\n2. Fill in your data matching the columns.\n3. Upload the filled file (.csv or .xlsx).',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isImporting ? null : () => _downloadTemplate('staff'),
                  icon: const Icon(Icons.download, size: 16),
                  label: Text('Download Template', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryPurple),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isImporting ? null : _importStaff,
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: Text('Import Data', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data Import Center',
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Easily migrate data from other software. Upload any spreadsheet — AI will map your columns automatically.',
          style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 24),
        _buildStudentImportCard(),
        _buildStaffImportCard(),
        
        if (_isImporting || _importResult.isNotEmpty) ...[
          const SizedBox(height: 24),
          Card(
            color: _isImporting ? Colors.blue.shade50 : (_importResult.contains('Error') || (_importResult.contains('Failed: ') && !_importResult.contains('Failed: 0')) ? Colors.orange.shade50 : Colors.green.shade50),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_isImporting) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      if (_isImporting) const SizedBox(width: 8),
                      Text(
                        _isImporting ? 'Processing...' : 'Result',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_importResult, style: GoogleFonts.poppins(fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
