import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/database_service.dart';

class ImportResult {
  final int successCount;
  final int failureCount;
  final List<String> errors;

  ImportResult({
    required this.successCount,
    required this.failureCount,
    required this.errors,
  });
}

class ImportService {
  final DatabaseService dbService;

  ImportService({required this.dbService});

  /// Reads a file and returns a list of rows, where each row is a map of Column Header -> Value
  Future<List<Map<String, dynamic>>> _parseFile(PlatformFile file) async {
    final extension = file.extension?.toLowerCase();
    List<Map<String, dynamic>> parsedData = [];

    List<int> bytes = [];
    if (kIsWeb) {
      if (file.bytes == null) throw Exception("File bytes are null on web");
      bytes = file.bytes!;
    } else {
      if (file.path == null) throw Exception("File path is null");
      bytes = await File(file.path!).readAsBytes();
    }

    if (extension == 'csv') {
      final input = utf8.decode(bytes);
      final fields = Csv().decode(input);
      if (fields.isEmpty) return [];

      final headers = fields.first.map((e) => e.toString().trim()).toList();
      for (var i = 1; i < fields.length; i++) {
        final row = fields[i];
        final map = <String, dynamic>{};
        for (var j = 0; j < headers.length; j++) {
          if (j < row.length) {
            map[headers[j]] = row[j];
          }
        }
        parsedData.add(map);
      }
    } else if (extension == 'xlsx' || extension == 'xls') {
      var excel = Excel.decodeBytes(bytes);
      for (var table in excel.tables.keys) {
        final rows = excel.tables[table]?.rows ?? [];
        if (rows.isEmpty) continue;

        final headersRow = rows.first;
        final headers = headersRow.map((e) => e?.value?.toString().trim() ?? '').toList();

        for (var i = 1; i < rows.length; i++) {
          final row = rows[i];
          final map = <String, dynamic>{};
          for (var j = 0; j < headers.length; j++) {
            if (j < row.length) {
              map[headers[j]] = row[j]?.value;
            }
          }
          parsedData.add(map);
        }
        break; // Only read the first sheet
      }
    } else {
      throw Exception("Unsupported file format: $extension");
    }

    return parsedData;
  }

  Future<ImportResult> importStudents(PlatformFile file) async {
    final rows = await _parseFile(file);
    int success = 0;
    int failure = 0;
    List<String> errors = [];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final admissionNumber = row['Admission Number']?.toString() ?? '';
        final firstName = row['First Name']?.toString() ?? '';
        final lastName = row['Last Name']?.toString() ?? '';
        final currentClass = row['Class']?.toString() ?? '';
        
        if (admissionNumber.isEmpty || firstName.isEmpty || currentClass.isEmpty) {
          errors.add("Row ${i + 2}: Missing required fields (Admission Number, First Name, Class)");
          failure++;
          continue;
        }

        final student = Student.create(
          name: '$firstName $lastName'.trim(),
          admissionNumber: admissionNumber,
          rollNumber: row['Roll Number']?.toString(),
          firstName: firstName,
          lastName: lastName,
          dob: row['Date of Birth']?.toString(),
          gender: row['Gender']?.toString().toLowerCase() ?? 'other',
          bloodGroup: row['Blood Group']?.toString(),
          religion: row['Religion']?.toString(),
          caste: row['Category']?.toString(),
          aadhaarNumber: row['Aadhar Number']?.toString(),
          gradeLevel: currentClass,
          section: row['Section']?.toString() ?? 'A',
          admissionDate: row['Admission Date']?.toString() ?? DateTime.now().toIso8601String(),
          fatherName: row['Father Name']?.toString() ?? '',
          motherName: row['Mother Name']?.toString() ?? '',
          guardianPhone: row['Contact Number 1']?.toString() ?? '',
          residentialAddress: row['Current Address']?.toString() ?? '',
          permanentAddress: row['Permanent Address']?.toString() ?? '',
        );

        await dbService.insertStudent(student);
        success++;
      } catch (e) {
        errors.add("Row ${i + 2}: $e");
        failure++;
      }
    }

    return ImportResult(successCount: success, failureCount: failure, errors: errors);
  }

  Future<ImportResult> importStaff(PlatformFile file) async {
    final rows = await _parseFile(file);
    int success = 0;
    int failure = 0;
    List<String> errors = [];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final employeeId = row['Employee ID']?.toString() ?? '';
        final firstName = row['First Name']?.toString() ?? '';
        final role = row['Role']?.toString().toLowerCase() ?? 'teacher';

        if (employeeId.isEmpty || firstName.isEmpty) {
          errors.add("Row ${i + 2}: Missing required fields (Employee ID, First Name)");
          failure++;
          continue;
        }

        final staff = Staff(
          id: const Uuid().v4(),
          firstName: firstName,
          lastName: row['Last Name']?.toString() ?? '',
          staffCode: employeeId,
          role: role,
          departmentId: row['Department ID']?.toString(),
          dob: row['Date of Birth']?.toString(),
          gender: row['Gender']?.toString().toLowerCase() ?? 'other',
          joiningDate: row['Joining Date']?.toString() ?? DateTime.now().toIso8601String(),
          qualification: row['Qualification']?.toString() ?? '',
          experienceYears: int.tryParse(row['Experience Years']?.toString() ?? '0') ?? 0,
          phone: row['Contact Number']?.toString() ?? '',
          email: row['Email']?.toString() ?? '',
          address: row['Address']?.toString() ?? '',
          basicSalary: double.tryParse(row['Basic Salary']?.toString() ?? '0') ?? 0,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await dbService.insertStaff(staff);
        success++;
      } catch (e) {
        errors.add("Row ${i + 2}: $e");
        failure++;
      }
    }

    return ImportResult(successCount: success, failureCount: failure, errors: errors);
  }
  
  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      return DateTime.parse(dateStr.trim());
    } catch (e) {
      return null;
    }
  }
  
  String generateStudentTemplateCSV() {
    return "Admission Number,Roll Number,First Name,Last Name,Date of Birth,Gender,Blood Group,Religion,Category,Aadhar Number,Class,Section,Admission Date,Father Name,Mother Name,Guardian Name,Contact Number 1,Contact Number 2,Email,Current Address,Permanent Address,Medical History\n" +
           "STD001,101,John,Doe,2010-05-15,male,O+,Christian,General,123456789012,10,A,2023-04-01,Richard Doe,Jane Doe,,9876543210,,johndoe@example.com,123 Main St,123 Main St,None";
  }

  String generateStaffTemplateCSV() {
    return "Employee ID,First Name,Last Name,Role,Department ID,Date of Birth,Gender,Joining Date,Qualification,Experience Years,Contact Number,Email,Address,Basic Salary\n" +
           "EMP001,Alice,Smith,teacher,,1985-08-22,female,2020-01-15,M.Sc. B.Ed,5,9876543210,alice@example.com,456 Elm St,50000";
  }
}
