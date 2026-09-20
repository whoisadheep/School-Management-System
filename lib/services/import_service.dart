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

  /// Reads a file and returns a list of rows, where each row is a map of Column Header -> Value.
  /// Public so the AI mapping flow can call it.
  Future<List<Map<String, dynamic>>> parseFile(PlatformFile file) async {
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

  /// Extract just the column headers from a file.
  Future<List<String>> extractHeaders(PlatformFile file) async {
    final rows = await parseFile(file);
    if (rows.isEmpty) return [];
    return rows.first.keys.toList();
  }

  /// Extract the first data row as sample values (for the mapping UI).
  Future<List<String>> extractSampleRow(PlatformFile file) async {
    final rows = await parseFile(file);
    if (rows.isEmpty) return [];
    return rows.first.values.map((v) => v?.toString() ?? '').toList();
  }

  Future<ImportResult> importStudents(PlatformFile file) async {
    final rows = await parseFile(file);
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

  /// Import students using AI-confirmed column mappings.
  /// [mapping] is a map of eduviaFieldKey -> sourceColumnHeader.
  /// If admission_number key is absent, sequential IDs are auto-generated.
  Future<ImportResult> importStudentsWithMapping({
    required PlatformFile file,
    required Map<String, String> mapping,
  }) async {
    final rows = await parseFile(file);
    int success = 0;
    int failure = 0;
    List<String> errors = [];

    // Get current student count for auto-generating admission numbers
    int admissionSeq = 0;
    try {
      final nextAdm = await dbService.getNextAdmissionNumber();
      admissionSeq = int.tryParse(nextAdm) ?? 1;
      admissionSeq--; // Will be incremented before first use
    } catch (_) {}

    final bool autoAdmission = !mapping.containsKey('admission_number');

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        String getValue(String eduviaKey) {
          final sourceCol = mapping[eduviaKey];
          if (sourceCol == null) return '';
          return row[sourceCol]?.toString().trim() ?? '';
        }

        // Handle full_name -> first + last split
        String firstName = getValue('first_name');
        String lastName = getValue('last_name');
        if (firstName.isEmpty && mapping.containsKey('full_name')) {
          final fullName = getValue('full_name');
          final parts = fullName.split(RegExp(r'\s+'));
          if (parts.isNotEmpty) firstName = parts.first;
          if (parts.length > 1) lastName = parts.sublist(1).join(' ');
        }

        final currentClass = getValue('class');

        if (firstName.isEmpty) {
          errors.add("Row ${i + 2}: Missing required field: First Name");
          failure++;
          continue;
        }
        if (currentClass.isEmpty) {
          errors.add("Row ${i + 2}: Missing required field: Class / Grade");
          failure++;
          continue;
        }

        // Admission number: use mapped value or auto-generate
        String admissionNumber;
        if (autoAdmission) {
          admissionSeq++;
          admissionNumber = admissionSeq.toString().padLeft(4, '0');
        } else {
          admissionNumber = getValue('admission_number');
          if (admissionNumber.isEmpty) {
            admissionSeq++;
            admissionNumber = admissionSeq.toString().padLeft(4, '0');
          }
        }

        final student = Student.create(
          name: '$firstName $lastName'.trim(),
          admissionNumber: admissionNumber,
          rollNumber: getValue('roll_number').isNotEmpty ? getValue('roll_number') : null,
          firstName: firstName,
          lastName: lastName,
          dob: getValue('dob').isNotEmpty ? getValue('dob') : null,
          gender: getValue('gender').isNotEmpty ? getValue('gender').toLowerCase() : 'other',
          bloodGroup: getValue('blood_group').isNotEmpty ? getValue('blood_group') : null,
          religion: getValue('religion').isNotEmpty ? getValue('religion') : null,
          caste: getValue('caste').isNotEmpty ? getValue('caste') : null,
          aadhaarNumber: getValue('aadhaar').isNotEmpty ? getValue('aadhaar') : null,
          gradeLevel: currentClass,
          section: getValue('section').isNotEmpty ? getValue('section') : 'A',
          admissionDate: getValue('admission_date').isNotEmpty
              ? getValue('admission_date')
              : DateTime.now().toIso8601String().substring(0, 10),
          fatherName: getValue('father_name'),
          fatherPhone: getValue('father_phone'),
          motherName: getValue('mother_name'),
          motherPhone: getValue('mother_phone'),
          guardianPhone: getValue('guardian_phone').isNotEmpty ? getValue('guardian_phone') : getValue('father_phone'),
          residentialAddress: getValue('residential_address'),
          permanentAddress: getValue('permanent_address').isNotEmpty
              ? getValue('permanent_address')
              : getValue('residential_address'),
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
    final rows = await parseFile(file);
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

  /// Import staff using AI-confirmed column mappings.
  /// [mapping] is a map of eduviaFieldKey -> sourceColumnHeader.
  /// If staff_code key is absent or empty, employee codes are auto-generated.
  Future<ImportResult> importStaffWithMapping({
    required PlatformFile file,
    required Map<String, String> mapping,
  }) async {
    final rows = await parseFile(file);
    int success = 0;
    int failure = 0;
    List<String> errors = [];

    // Track sequential staff code generation
    String? currentStaffCode;
    final bool autoStaffCode = !mapping.containsKey('staff_code');

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        String getValue(String eduviaKey) {
          final sourceCol = mapping[eduviaKey];
          if (sourceCol == null) return '';
          return row[sourceCol]?.toString().trim() ?? '';
        }

        // Handle full_name -> first + last split
        String firstName = getValue('first_name');
        String lastName = getValue('last_name');
        if (firstName.isEmpty && mapping.containsKey('full_name')) {
          final fullName = getValue('full_name');
          final parts = fullName.split(RegExp(r'\s+'));
          if (parts.isNotEmpty) firstName = parts.first;
          if (parts.length > 1) lastName = parts.sublist(1).join(' ');
        }

        if (firstName.isEmpty) {
          errors.add("Row ${i + 2}: Missing required field: First Name (or Full Name)");
          failure++;
          continue;
        }

        // Staff Code / Employee ID
        String staffCode;
        if (autoStaffCode) {
          currentStaffCode = await dbService.generateNextStaffCode(afterCode: currentStaffCode);
          staffCode = currentStaffCode;
        } else {
          staffCode = getValue('staff_code');
          if (staffCode.isEmpty) {
            currentStaffCode = await dbService.generateNextStaffCode(afterCode: currentStaffCode);
            staffCode = currentStaffCode;
          }
        }

        // Role normalization
        String roleInput = getValue('role').toLowerCase();
        String role = 'teacher';
        if (roleInput.contains('teach') ||
            roleInput.contains('faculty') ||
            roleInput.contains('educator') ||
            roleInput.contains('lecturer') ||
            roleInput.contains('instructor')) {
          role = 'teacher';
        } else if (roleInput.contains('princ') ||
            roleInput.contains('head') ||
            roleInput.contains('director') ||
            roleInput.contains('admin')) {
          role = 'principal';
        } else if (roleInput.contains('drive')) {
          role = 'driver';
        } else if (roleInput.contains('support') ||
            roleInput.contains('peon') ||
            roleInput.contains('staff') ||
            roleInput.contains('clean') ||
            roleInput.contains('guard') ||
            roleInput.contains('security') ||
            roleInput.contains('clerk') ||
            roleInput.contains('attendant')) {
          role = 'support_staff';
        } else if (roleInput.isNotEmpty) {
          role = roleInput;
        }

        // Salary parsing
        double? basicSalary;
        final rawSalary = getValue('basic_salary').replaceAll(RegExp(r'[^0-9.]'), '');
        if (rawSalary.isNotEmpty) {
          basicSalary = double.tryParse(rawSalary);
        }

        // Experience parsing
        int? experienceYears;
        final rawExp = getValue('experience_years').replaceAll(RegExp(r'[^0-9]'), '');
        if (rawExp.isNotEmpty) {
          experienceYears = int.tryParse(rawExp);
        }

        // Gender normalization
        String? gender;
        final rawGender = getValue('gender').toLowerCase();
        if (rawGender.startsWith('m')) {
          gender = 'male';
        } else if (rawGender.startsWith('f')) {
          gender = 'female';
        } else if (rawGender.isNotEmpty) {
          gender = 'other';
        }

        // Joining Date
        String joiningDate = getValue('joining_date');
        if (joiningDate.isEmpty) {
          joiningDate = DateTime.now().toIso8601String().substring(0, 10);
        }

        final staff = Staff(
          id: const Uuid().v4(),
          staffCode: staffCode,
          firstName: firstName,
          lastName: lastName,
          dob: getValue('dob').isNotEmpty ? getValue('dob') : null,
          gender: gender,
          bloodGroup: getValue('blood_group').isNotEmpty ? getValue('blood_group') : null,
          role: role,
          departmentId: getValue('department_id').isNotEmpty ? getValue('department_id') : null,
          designation: getValue('designation').isNotEmpty ? getValue('designation') : null,
          joiningDate: joiningDate,
          qualification: getValue('qualification').isNotEmpty ? getValue('qualification') : null,
          experienceYears: experienceYears ?? 0,
          phone: getValue('phone').isNotEmpty ? getValue('phone') : null,
          email: getValue('email').isNotEmpty ? getValue('email') : null,
          address: getValue('address').isNotEmpty ? getValue('address') : null,
          emergencyContact: getValue('emergency_contact').isNotEmpty ? getValue('emergency_contact') : null,
          basicSalary: basicSalary,
          bankAccountNumber: getValue('bank_account_number').isNotEmpty ? getValue('bank_account_number') : null,
          bankIfsc: getValue('bank_ifsc').isNotEmpty ? getValue('bank_ifsc') : null,
          panNumber: getValue('pan_number').isNotEmpty ? getValue('pan_number') : null,
          aadhaarNumber: getValue('aadhaar_number').isNotEmpty ? getValue('aadhaar_number') : null,
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
  
  String generateStudentTemplateCSV() {
    return "Admission Number,Roll Number,First Name,Last Name,Date of Birth,Gender,Blood Group,Religion,Category,Aadhar Number,Class,Section,Admission Date,Father Name,Mother Name,Guardian Name,Contact Number 1,Contact Number 2,Email,Current Address,Permanent Address,Medical History\n"
           "STD001,101,John,Doe,2010-05-15,male,O+,Christian,General,123456789012,10,A,2023-04-01,Richard Doe,Jane Doe,,9876543210,,johndoe@example.com,123 Main St,123 Main St,None";
  }

  String generateStaffTemplateCSV() {
    return "Employee ID,First Name,Last Name,Role,Department ID,Date of Birth,Gender,Joining Date,Qualification,Experience Years,Contact Number,Email,Address,Basic Salary\n"
           "EMP001,Alice,Smith,teacher,,1985-08-22,female,2020-01-15,M.Sc. B.Ed,5,9876543210,alice@example.com,456 Elm St,50000";
  }
}
