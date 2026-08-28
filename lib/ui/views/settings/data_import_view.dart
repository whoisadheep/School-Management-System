import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:school_management_system/core/theme/app_theme.dart';
import 'package:school_management_system/providers/services_provider.dart';
import 'package:school_management_system/services/import_service.dart';

class DataImportView extends ConsumerStatefulWidget {
  const DataImportView({super.key});

  @override
  ConsumerState<DataImportView> createState() => _DataImportViewState();
}

class _DataImportViewState extends ConsumerState<DataImportView> {
  bool _isImporting = false;
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

  Future<void> _importData(String type) async {
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
      
      ImportResult res;
      if (type == 'students') {
        res = await importService.importStudents(file);
        ref.invalidate(studentsListProvider);
      } else {
        res = await importService.importStaff(file);
        ref.invalidate(staffListProvider);
      }

      setState(() {
        _importResult = 'Import Complete!\nSuccess: ${res.successCount}\nFailed: ${res.failureCount}';
        if (res.errors.isNotEmpty) {
          _importResult += '\n\nErrors (Showing top 5):\n' + res.errors.take(5).join('\n');
        }
      });
      
    } catch (e) {
      setState(() {
        _importResult = 'Error during import: $e';
      });
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  Widget _buildImportCard(String title, String type, IconData icon) {
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
                Icon(icon, size: 32, color: AppTheme.primaryPurple),
                const SizedBox(width: 16),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '1. Download the template CSV.\n2. Fill in your data matching the columns.\n3. Upload the filled file (.csv or .xlsx).',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isImporting ? null : () => _downloadTemplate(type),
                  icon: const Icon(Icons.download),
                  label: const Text('Download Template'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryPurple),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isImporting ? null : () => _importData(type),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import Data'),
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
        const Text(
          'Data Import Center',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Easily migrate data from other software by downloading templates and uploading the filled spreadsheets.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
        const SizedBox(height: 24),
        _buildImportCard('Import Students', 'students', Icons.school),
        _buildImportCard('Import Staff', 'staff', Icons.people),
        
        if (_isImporting || _importResult.isNotEmpty) ...[
          const SizedBox(height: 24),
          Card(
            color: _isImporting ? Colors.blue.shade50 : (_importResult.contains('Error') || _importResult.contains('Failed: ') && !_importResult.contains('Failed: 0') ? Colors.orange.shade50 : Colors.green.shade50),
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_importResult, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
