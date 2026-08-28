import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import 'settings_service.dart';

/// Data transfer objects for isolate communication.
/// Isolates cannot share complex objects, so we convert to simple Maps.
class _StudentCsvPayload {
  final List<Map<String, dynamic>> studentMaps;
  _StudentCsvPayload(this.studentMaps);
}

class _LedgerCsvPayload {
  final List<Map<String, dynamic>> entryMaps;
  _LedgerCsvPayload(this.entryMaps);
}

class CsvExportService {
  final SettingsService _settingsService = SettingsService();

  Future<String> _getExportDirectory() async {
    final configuredPath = await _settingsService.getSetting('receipt_export_path');
    if (configuredPath != null && configuredPath.isNotEmpty) {
      return configuredPath;
    }
    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, 'Eduvia', 'Exports');
  }

  /// Export Student Directory list to CSV file.
  /// The CSV string is built in a background isolate via [compute].
  Future<File> exportStudentsToCsv(List<Student> students) async {
    final exportDirStr = await _getExportDirectory();
    final dir = Directory(exportDirStr);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Convert Student objects to simple maps for isolate transfer
    final studentMaps = students.map((s) => {
      'admissionNumber': s.admissionNumber ?? '',
      'firstName': s.firstName ?? s.name,
      'lastName': s.lastName ?? '',
      'gradeLevel': s.gradeLevel,
      'section': s.section ?? '',
      'guardianPhone': s.guardianPhone ?? s.fatherPhone ?? '',
      'aadhaarNumber': s.aadhaarNumber ?? '',
      'currentBalance': s.currentBalance.toStringAsFixed(2),
      'isActive': s.isActive ? 'Active' : 'Inactive',
    }).toList();

    // Build CSV content in a background isolate
    final csvContent = await compute(
      _buildStudentCsvInIsolate,
      _StudentCsvPayload(studentMaps),
    );

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = p.join(exportDirStr, 'Student_Directory_$timestamp.csv');
    final file = File(filePath);
    await file.writeAsString(csvContent);
    return file;
  }

  /// Export General Ledger Entries to CSV file.
  /// The CSV string is built in a background isolate via [compute].
  Future<File> exportLedgerToCsv(List<LedgerEntry> entries) async {
    final exportDirStr = await _getExportDirectory();
    final dir = Directory(exportDirStr);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Convert LedgerEntry objects to simple maps for isolate transfer
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final entryMaps = entries.map((e) => {
      'id': e.id,
      'date': dateFormatter.format(e.date),
      'type': e.type.displayName,
      'category': e.category,
      'amount': e.amount.toStringAsFixed(2),
      'description': e.description ?? '',
    }).toList();

    // Build CSV content in a background isolate
    final csvContent = await compute(
      _buildLedgerCsvInIsolate,
      _LedgerCsvPayload(entryMaps),
    );

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = p.join(exportDirStr, 'General_Ledger_$timestamp.csv');
    final file = File(filePath);
    await file.writeAsString(csvContent);
    return file;
  }
}

/// Top-level function for isolate: builds student CSV string.
String _buildStudentCsvInIsolate(_StudentCsvPayload payload) {
  final sb = StringBuffer();
  sb.writeln('Admission No,First Name,Last Name,Grade Level,Section,Guardian Phone,Aadhaar No,Current Balance,Status');

  for (final m in payload.studentMaps) {
    final admNo = _escapeCsv(m['admissionNumber'] as String);
    final fn = _escapeCsv(m['firstName'] as String);
    final ln = _escapeCsv(m['lastName'] as String);
    final grade = _escapeCsv(m['gradeLevel'] as String);
    final sec = _escapeCsv(m['section'] as String);
    final phone = _escapeCsv(m['guardianPhone'] as String);
    final aadhaar = _escapeCsv(m['aadhaarNumber'] as String);
    final bal = m['currentBalance'] as String;
    final status = m['isActive'] as String;

    sb.writeln('$admNo,$fn,$ln,$grade,$sec,$phone,$aadhaar,$bal,$status');
  }
  return sb.toString();
}

/// Top-level function for isolate: builds ledger CSV string.
String _buildLedgerCsvInIsolate(_LedgerCsvPayload payload) {
  final sb = StringBuffer();
  sb.writeln('Entry ID,Date,Type,Category,Amount,Description');

  for (final m in payload.entryMaps) {
    final id = _escapeCsv(m['id'] as String);
    final date = m['date'] as String;
    final type = m['type'] as String;
    final cat = _escapeCsv(m['category'] as String);
    final amount = m['amount'] as String;
    final desc = _escapeCsv(m['description'] as String);

    sb.writeln('$id,$date,$type,$cat,$amount,$desc');
  }
  return sb.toString();
}

String _escapeCsv(String field) {
  if (field.contains(',') || field.contains('"') || field.contains('\n')) {
    return '"${field.replaceAll('"', '""')}"';
  }
  return field;
}
