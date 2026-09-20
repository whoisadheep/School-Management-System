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
      final input = utf8.decode(bytes, allowMalformed: true);
      final fields = Csv().decode(input);
      if (fields.isEmpty) return [];

      final headers = fields.first.map((e) => e.toString().trim()).toList();
      for (var i = 1; i < fields.length; i++) {
        final row = fields[i];
        if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) continue;
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

  // ============================================================================
  // EDGE CASE NORMALIZATION HELPERS
  // ============================================================================

  /// Normalizes arbitrary date formats (ISO, DD/MM/YYYY, DD-MM-YYYY, Excel serial)
  /// into standard ISO `YYYY-MM-DD`. Returns null if empty or unparseable.
  static String? normalizeDate(dynamic raw) {
    if (raw == null) return null;
    var str = raw.toString().trim();
    if (str.isEmpty) return null;

    // Check for Excel serial date (e.g. 44287 = 2021-04-01)
    final numVal = int.tryParse(str);
    if (numVal != null && numVal >= 10000 && numVal <= 70000) {
      try {
        final date = DateTime(1899, 12, 30).add(Duration(days: numVal));
        return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    // Remove time portion if present (e.g. "1990-08-15 00:00:00" or "15/08/1990 12:00:00 PM")
    if (str.contains(' ')) {
      str = str.split(' ').first;
    }

    // Try parsing ISO format directly (YYYY-MM-DD or YYYY/MM/DD)
    final isoMatch = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$').firstMatch(str);
    if (isoMatch != null) {
      final y = int.parse(isoMatch.group(1)!);
      final m = int.parse(isoMatch.group(2)!);
      final d = int.parse(isoMatch.group(3)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      }
    }

    // Try parsing DD/MM/YYYY or DD-MM-YYYY or MM/DD/YYYY
    final dmyMatch = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})$').firstMatch(str);
    if (dmyMatch != null) {
      var d = int.parse(dmyMatch.group(1)!);
      var m = int.parse(dmyMatch.group(2)!);
      var y = int.parse(dmyMatch.group(3)!);
      if (y < 100) y += (y < 50 ? 2000 : 1900); // 2-digit year support
      
      // If month > 12 and day <= 12, it might be MM/DD/YYYY
      if (m > 12 && d <= 12) {
        final temp = d;
        d = m;
        m = temp;
      }
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      }
    }

    // Fallback to standard DateTime.tryParse
    final dt = DateTime.tryParse(str);
    if (dt != null) {
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    return null;
  }

  /// Cleans and validates phone numbers.
  /// Discards non-digits (preserves leading +), rejects junk/placeholders,
  /// and ensures reasonable length (7-15 digits). Returns null if invalid.
  static String? cleanPhone(dynamic raw) {
    if (raw == null) return null;
    var str = raw.toString().trim();
    if (str.isEmpty) return null;
    final lower = str.toLowerCase();
    if (['n/a', 'na', 'none', 'nil', '-', '--', 'null', 'unknown', 'not available'].contains(lower)) {
      return null;
    }
    final cleaned = str.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (RegExp(r'[^\d+]').hasMatch(cleaned)) {
      return null; // Contains letters or invalid characters like "98765abc"
    }
    final digitsOnly = cleaned.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 7 || digitsOnly.length > 15) {
      return null;
    }
    if (RegExp(r'^0+$').hasMatch(digitsOnly)) {
      return null; // All zeros
    }
    return cleaned;
  }

  /// Cleans and validates email addresses.
  /// Trims, lowercases, checks RFC pattern, and discards placeholders.
  static String? cleanEmail(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim().toLowerCase();
    if (str.isEmpty) return null;
    if (['n/a', 'na', 'none', 'nil', '-', '--', 'null', 'unknown', 'no email', 'not available'].contains(str)) {
      return null;
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$');
    if (!emailRegex.hasMatch(str)) {
      return null;
    }
    return str;
  }

  /// Formats names with Title Casing, preserving Unicode / non-ASCII characters (e.g. Hindi/Devanagari).
  static String toTitleCase(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    // If it contains non-ASCII characters (like Hindi, Devanagari, etc.), return as is
    if (RegExp(r'[^\x00-\x7F]').hasMatch(trimmed)) {
      return trimmed;
    }
    return trimmed.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Builds a combined full address string from street, city, state, and pincode.
  static String buildFullAddress({
    String? street,
    String? city,
    String? state,
    String? pincode,
  }) {
    final parts = <String>[];
    if (street != null && street.trim().isNotEmpty) {
      parts.add(street.trim());
    }
    if (city != null && city.trim().isNotEmpty) {
      parts.add(city.trim());
    }
    if (state != null && state.trim().isNotEmpty) {
      if (pincode != null && pincode.trim().isNotEmpty) {
        parts.add('${state.trim()} - ${pincode.trim()}');
      } else {
        parts.add(state.trim());
      }
    } else if (pincode != null && pincode.trim().isNotEmpty) {
      parts.add(pincode.trim());
    }
    return parts.join(', ');
  }

  Future<ImportResult> importStudents(PlatformFile file) async {
    final rows = await parseFile(file);
    int success = 0;
    int failure = 0;
    List<String> errors = [];

    // Pre-load existing admission numbers to prevent collisions
    final Set<String> existingAdmissionNos = {};
    try {
      final db = await dbService.rawDb;
      final existingRows = await db.query('students', columns: ['admission_number']);
      for (final r in existingRows) {
        final adm = r['admission_number']?.toString().trim();
        if (adm != null && adm.isNotEmpty) {
          existingAdmissionNos.add(adm.toLowerCase());
        }
      }
    } catch (_) {}
    final Set<String> seenAdmissionNos = {};

    int admissionSeq = 0;
    try {
      final nextAdm = await dbService.getNextAdmissionNumber();
      admissionSeq = int.tryParse(nextAdm) ?? 1;
      admissionSeq--;
    } catch (_) {}

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        var admissionNumber = row['Admission Number']?.toString().trim() ?? '';
        var firstName = row['First Name']?.toString().trim() ?? '';
        var lastName = row['Last Name']?.toString().trim() ?? '';
        final currentClass = row['Class']?.toString().trim() ?? '';
        
        // Handle name fallback
        if (firstName.isEmpty && lastName.isNotEmpty) {
          firstName = lastName;
          lastName = '';
        }
        firstName = toTitleCase(firstName);
        lastName = toTitleCase(lastName);

        if (firstName.isEmpty || currentClass.isEmpty) {
          errors.add("Row ${i + 2}: Missing required fields (First Name, Class)");
          failure++;
          continue;
        }

        // Admission number deduplication/auto-generation
        if (admissionNumber.isEmpty) {
          admissionSeq++;
          admissionNumber = admissionSeq.toString().padLeft(4, '0');
          while (existingAdmissionNos.contains(admissionNumber.toLowerCase()) ||
              seenAdmissionNos.contains(admissionNumber.toLowerCase())) {
            admissionSeq++;
            admissionNumber = admissionSeq.toString().padLeft(4, '0');
          }
        } else if (existingAdmissionNos.contains(admissionNumber.toLowerCase()) ||
            seenAdmissionNos.contains(admissionNumber.toLowerCase())) {
          final oldNumber = admissionNumber;
          admissionSeq++;
          admissionNumber = admissionSeq.toString().padLeft(4, '0');
          while (existingAdmissionNos.contains(admissionNumber.toLowerCase()) ||
              seenAdmissionNos.contains(admissionNumber.toLowerCase())) {
            admissionSeq++;
            admissionNumber = admissionSeq.toString().padLeft(4, '0');
          }
          errors.add("Row ${i + 2}: Duplicate admission number '$oldNumber' auto-reassigned to $admissionNumber");
        }
        seenAdmissionNos.add(admissionNumber.toLowerCase());

        final dob = normalizeDate(row['Date of Birth']);
        final admissionDate = normalizeDate(row['Admission Date']) ??
            DateTime.now().toIso8601String().substring(0, 10);

        final rawGender = row['Gender']?.toString().toLowerCase().trim() ?? '';
        final gender = rawGender.startsWith('m')
            ? 'male'
            : (rawGender.startsWith('f') ? 'female' : 'other');

        final fatherPhone = cleanPhone(row['Contact Number 1'] ?? row['Father Phone']);
        final motherPhone = cleanPhone(row['Contact Number 2'] ?? row['Mother Phone']);
        final guardianPhone = cleanPhone(row['Guardian Phone']) ?? fatherPhone ?? motherPhone ?? '';

        final residentialAddress = buildFullAddress(
          street: row['Current Address']?.toString() ?? row['Address']?.toString(),
          city: row['City']?.toString(),
          state: row['State']?.toString(),
          pincode: row['Pincode']?.toString() ?? row['Pin Code']?.toString(),
        );

        final permanentAddress = row['Permanent Address'] != null && row['Permanent Address'].toString().trim().isNotEmpty
            ? buildFullAddress(
                street: row['Permanent Address'].toString(),
                city: row['City']?.toString(),
                state: row['State']?.toString(),
                pincode: row['Pincode']?.toString() ?? row['Pin Code']?.toString(),
              )
            : residentialAddress;

        final student = Student.create(
          name: '$firstName $lastName'.trim(),
          admissionNumber: admissionNumber,
          rollNumber: row['Roll Number']?.toString().trim().isNotEmpty == true ? row['Roll Number']?.toString().trim() : null,
          firstName: firstName,
          lastName: lastName,
          dob: dob,
          gender: gender,
          bloodGroup: row['Blood Group']?.toString().trim().isNotEmpty == true ? row['Blood Group']?.toString().trim() : null,
          religion: row['Religion']?.toString().trim().isNotEmpty == true ? row['Religion']?.toString().trim() : null,
          caste: row['Category']?.toString().trim().isNotEmpty == true ? row['Category']?.toString().trim() : null,
          aadhaarNumber: row['Aadhar Number']?.toString().trim().isNotEmpty == true ? row['Aadhar Number']?.toString().trim() : null,
          gradeLevel: currentClass,
          section: row['Section']?.toString().trim().isNotEmpty == true ? row['Section']?.toString().trim() : 'A',
          admissionDate: admissionDate,
          fatherName: toTitleCase(row['Father Name']?.toString() ?? ''),
          fatherPhone: fatherPhone,
          motherName: toTitleCase(row['Mother Name']?.toString() ?? ''),
          motherPhone: motherPhone,
          guardianPhone: guardianPhone,
          residentialAddress: residentialAddress,
          permanentAddress: permanentAddress,
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

    // Pre-load existing admission numbers
    final Set<String> existingAdmissionNos = {};
    try {
      final db = await dbService.rawDb;
      final existingRows = await db.query('students', columns: ['admission_number']);
      for (final r in existingRows) {
        final adm = r['admission_number']?.toString().trim();
        if (adm != null && adm.isNotEmpty) {
          existingAdmissionNos.add(adm.toLowerCase());
        }
      }
    } catch (_) {}
    final Set<String> seenAdmissionNos = {};

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
        if (firstName.isEmpty && lastName.isNotEmpty) {
          firstName = lastName;
          lastName = '';
        }

        firstName = toTitleCase(firstName);
        lastName = toTitleCase(lastName);

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

        // Admission number: use mapped value or auto-generate with duplicate protection
        String admissionNumber;
        if (autoAdmission) {
          admissionSeq++;
          admissionNumber = admissionSeq.toString().padLeft(4, '0');
          while (existingAdmissionNos.contains(admissionNumber.toLowerCase()) ||
              seenAdmissionNos.contains(admissionNumber.toLowerCase())) {
            admissionSeq++;
            admissionNumber = admissionSeq.toString().padLeft(4, '0');
          }
        } else {
          admissionNumber = getValue('admission_number');
          if (admissionNumber.isEmpty) {
            admissionSeq++;
            admissionNumber = admissionSeq.toString().padLeft(4, '0');
            while (existingAdmissionNos.contains(admissionNumber.toLowerCase()) ||
                seenAdmissionNos.contains(admissionNumber.toLowerCase())) {
              admissionSeq++;
              admissionNumber = admissionSeq.toString().padLeft(4, '0');
            }
          } else if (existingAdmissionNos.contains(admissionNumber.toLowerCase()) ||
              seenAdmissionNos.contains(admissionNumber.toLowerCase())) {
            final oldNumber = admissionNumber;
            admissionSeq++;
            admissionNumber = admissionSeq.toString().padLeft(4, '0');
            while (existingAdmissionNos.contains(admissionNumber.toLowerCase()) ||
                seenAdmissionNos.contains(admissionNumber.toLowerCase())) {
              admissionSeq++;
              admissionNumber = admissionSeq.toString().padLeft(4, '0');
            }
            errors.add("Row ${i + 2}: Duplicate admission number '$oldNumber' auto-reassigned to $admissionNumber");
          }
        }
        seenAdmissionNos.add(admissionNumber.toLowerCase());

        final dob = normalizeDate(getValue('dob'));
        final admissionDate = normalizeDate(getValue('admission_date')) ??
            DateTime.now().toIso8601String().substring(0, 10);

        final rawGender = getValue('gender').toLowerCase().trim();
        final gender = rawGender.startsWith('m')
            ? 'male'
            : (rawGender.startsWith('f') ? 'female' : 'other');

        final fatherPhone = cleanPhone(getValue('father_phone'));
        final motherPhone = cleanPhone(getValue('mother_phone'));
        final guardianPhone = cleanPhone(getValue('guardian_phone')) ?? fatherPhone ?? motherPhone ?? '';

        final residentialAddress = buildFullAddress(
          street: getValue('residential_address'),
          city: getValue('city'),
          state: getValue('state'),
          pincode: getValue('pincode'),
        );
        final permanentAddress = getValue('permanent_address').isNotEmpty
            ? buildFullAddress(
                street: getValue('permanent_address'),
                city: getValue('city'),
                state: getValue('state'),
                pincode: getValue('pincode'),
              )
            : residentialAddress;

        final student = Student.create(
          name: '$firstName $lastName'.trim(),
          admissionNumber: admissionNumber,
          rollNumber: getValue('roll_number').isNotEmpty ? getValue('roll_number') : null,
          firstName: firstName,
          lastName: lastName,
          dob: dob,
          gender: gender,
          bloodGroup: getValue('blood_group').isNotEmpty ? getValue('blood_group') : null,
          religion: getValue('religion').isNotEmpty ? getValue('religion') : null,
          caste: getValue('caste').isNotEmpty ? getValue('caste') : null,
          aadhaarNumber: getValue('aadhaar').isNotEmpty ? getValue('aadhaar') : null,
          gradeLevel: currentClass,
          section: getValue('section').isNotEmpty ? getValue('section') : 'A',
          admissionDate: admissionDate,
          fatherName: toTitleCase(getValue('father_name')),
          fatherPhone: fatherPhone,
          motherName: toTitleCase(getValue('mother_name')),
          motherPhone: motherPhone,
          guardianPhone: guardianPhone,
          residentialAddress: residentialAddress,
          permanentAddress: permanentAddress,
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

    // Pre-load existing staff codes, emails, phones to prevent collisions
    final Set<String> existingStaffCodes = {};
    final Set<String> existingEmails = {};
    final Set<String> existingPhones = {};
    try {
      final db = await dbService.rawDb;
      final staffRows = await db.query('staff', columns: ['staff_code', 'email', 'phone']);
      for (final r in staffRows) {
        final code = r['staff_code']?.toString().trim();
        if (code != null && code.isNotEmpty) existingStaffCodes.add(code.toLowerCase());
        final mail = r['email']?.toString().trim();
        if (mail != null && mail.isNotEmpty) existingEmails.add(mail.toLowerCase());
        final ph = r['phone']?.toString().trim();
        if (ph != null && ph.isNotEmpty) existingPhones.add(ph);
      }
    } catch (_) {}

    final Set<String> seenStaffCodes = {};
    final Set<String> seenEmails = {};
    final Set<String> seenPhones = {};
    String? currentStaffCode;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        var employeeId = row['Employee ID']?.toString().trim() ?? '';
        var firstName = row['First Name']?.toString().trim() ?? '';
        var lastName = row['Last Name']?.toString().trim() ?? '';

        if (firstName.isEmpty && lastName.isNotEmpty) {
          firstName = lastName;
          lastName = '';
        }
        firstName = toTitleCase(firstName);
        lastName = toTitleCase(lastName);

        if (firstName.isEmpty) {
          errors.add("Row ${i + 2}: Missing required field: First Name");
          failure++;
          continue;
        }

        // Staff code handling
        if (employeeId.isEmpty) {
          currentStaffCode = await dbService.generateNextStaffCode(afterCode: currentStaffCode);
          employeeId = currentStaffCode;
          while (existingStaffCodes.contains(employeeId.toLowerCase()) ||
              seenStaffCodes.contains(employeeId.toLowerCase())) {
            currentStaffCode = await dbService.generateNextStaffCode(afterCode: currentStaffCode);
            employeeId = currentStaffCode;
          }
        } else if (existingStaffCodes.contains(employeeId.toLowerCase()) ||
            seenStaffCodes.contains(employeeId.toLowerCase())) {
          final oldId = employeeId;
          currentStaffCode = await dbService.generateNextStaffCode(afterCode: currentStaffCode);
          employeeId = currentStaffCode;
          while (existingStaffCodes.contains(employeeId.toLowerCase()) ||
              seenStaffCodes.contains(employeeId.toLowerCase())) {
            currentStaffCode = await dbService.generateNextStaffCode(afterCode: currentStaffCode);
            employeeId = currentStaffCode;
          }
          errors.add("Row ${i + 2}: Duplicate employee ID '$oldId' auto-reassigned to '$employeeId'");
        }
        seenStaffCodes.add(employeeId.toLowerCase());

        // Role & designation
        var roleInput = row['Role']?.toString().toLowerCase().trim() ?? '';
        if (roleInput.isEmpty) {
          roleInput = row['Designation']?.toString().toLowerCase().trim() ?? '';
        }
        String role = 'teacher';
        if (roleInput.contains('admin') ||
            roleInput.contains('princ') ||
            roleInput.contains('head') ||
            roleInput.contains('director') ||
            roleInput.contains('account') ||
            roleInput.contains('clerk') ||
            roleInput.contains('manager') ||
            roleInput.contains('coord') ||
            roleInput.contains('dean') ||
            roleInput.contains('office')) {
          role = 'admin';
        } else if (roleInput.contains('drive') || roleInput.contains('transport')) {
          role = 'driver';
        } else if (roleInput.contains('support') ||
            roleInput.contains('peon') ||
            roleInput.contains('staff') ||
            roleInput.contains('clean') ||
            roleInput.contains('guard') ||
            roleInput.contains('security') ||
            roleInput.contains('attendant') ||
            roleInput.contains('helper') ||
            roleInput.contains('maid') ||
            roleInput.contains('worker') ||
            roleInput.contains('sweeper')) {
          role = 'support_staff';
        }

        // Email & Phone with duplicate avoidance
        String? email = cleanEmail(row['Email']);
        if (email != null) {
          if (existingEmails.contains(email) || seenEmails.contains(email)) {
            errors.add("Row ${i + 2}: Duplicate email '$email' omitted to avoid database collision");
            email = null;
          } else {
            seenEmails.add(email);
          }
        }

        String? phone = cleanPhone(row['Contact Number'] ?? row['Phone']);
        if (phone != null) {
          if (existingPhones.contains(phone) || seenPhones.contains(phone)) {
            errors.add("Row ${i + 2}: Duplicate phone '$phone' omitted to avoid database collision");
            phone = null;
          } else {
            seenPhones.add(phone);
          }
        }

        final dob = normalizeDate(row['Date of Birth']);
        final joiningDate = normalizeDate(row['Joining Date']) ??
            DateTime.now().toIso8601String().substring(0, 10);

        final rawGender = row['Gender']?.toString().toLowerCase().trim() ?? '';
        final gender = rawGender.startsWith('m')
            ? 'male'
            : (rawGender.startsWith('f') ? 'female' : 'other');

        final address = buildFullAddress(
          street: row['Address']?.toString(),
          city: row['City']?.toString(),
          state: row['State']?.toString(),
          pincode: row['Pincode']?.toString(),
        );

        double? basicSalary;
        final rawSalary = row['Basic Salary']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '';
        if (rawSalary.isNotEmpty) {
          basicSalary = double.tryParse(rawSalary);
        }

        final staff = Staff(
          id: const Uuid().v4(),
          firstName: firstName,
          lastName: lastName,
          staffCode: employeeId,
          role: role,
          departmentId: row['Department ID']?.toString(),
          designation: row['Designation']?.toString(),
          dob: dob,
          gender: gender,
          joiningDate: joiningDate,
          qualification: row['Qualification']?.toString() ?? '',
          experienceYears: int.tryParse(row['Experience Years']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0,
          phone: phone,
          email: email,
          address: address.isNotEmpty ? address : null,
          basicSalary: basicSalary ?? 0,
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

    // Pre-load existing staff codes, emails, phones to prevent collisions
    final Set<String> existingStaffCodes = {};
    final Set<String> existingEmails = {};
    final Set<String> existingPhones = {};
    try {
      final db = await dbService.rawDb;
      final staffRows = await db.query('staff', columns: ['staff_code', 'email', 'phone']);
      for (final r in staffRows) {
        final code = r['staff_code']?.toString().trim();
        if (code != null && code.isNotEmpty) existingStaffCodes.add(code.toLowerCase());
        final mail = r['email']?.toString().trim();
        if (mail != null && mail.isNotEmpty) existingEmails.add(mail.toLowerCase());
        final ph = r['phone']?.toString().trim();
        if (ph != null && ph.isNotEmpty) existingPhones.add(ph);
      }
    } catch (_) {}

    final Set<String> seenStaffCodes = {};
    final Set<String> seenEmails = {};
    final Set<String> seenPhones = {};

    // Pre-load all departments to resolve names to IDs and satisfy foreign key constraints
    final Map<String, String> deptMap = {}; // lowercase name or id -> department id
    try {
      final existingDepartments = await dbService.getAllDepartments();
      for (final d in existingDepartments) {
        deptMap[d.id.toLowerCase()] = d.id;
        deptMap[d.name.toLowerCase()] = d.id;
      }
    } catch (_) {}

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
        if (firstName.isEmpty && lastName.isNotEmpty) {
          firstName = lastName;
          lastName = '';
        }

        if (firstName.isEmpty) {
          errors.add("Row ${i + 2}: Missing required field: First Name (or Full Name)");
          failure++;
          continue;
        }

        firstName = toTitleCase(firstName);
        lastName = toTitleCase(lastName);

        // Staff Code / Employee ID
        String staffCode;
        if (autoStaffCode) {
          currentStaffCode = await dbService.generateNextStaffCode(afterCode: currentStaffCode);
          staffCode = currentStaffCode;
          while (existingStaffCodes.contains(staffCode.toLowerCase()) ||
              seenStaffCodes.contains(staffCode.toLowerCase())) {
            currentStaffCode = await dbService.generateNextStaffCode(afterCode: currentStaffCode);
            staffCode = currentStaffCode;
          }
        } else {
          staffCode = getValue('staff_code');
          if (staffCode.isEmpty) {
            currentStaffCode = await dbService.generateNextStaffCode(afterCode: currentStaffCode);
            staffCode = currentStaffCode;
            while (existingStaffCodes.contains(staffCode.toLowerCase()) ||
                seenStaffCodes.contains(staffCode.toLowerCase())) {
              currentStaffCode = await dbService.generateNextStaffCode(afterCode: currentStaffCode);
              staffCode = currentStaffCode;
            }
          } else if (existingStaffCodes.contains(staffCode.toLowerCase()) ||
              seenStaffCodes.contains(staffCode.toLowerCase())) {
            final oldCode = staffCode;
            currentStaffCode = await dbService.generateNextStaffCode(afterCode: currentStaffCode);
            staffCode = currentStaffCode;
            while (existingStaffCodes.contains(staffCode.toLowerCase()) ||
                seenStaffCodes.contains(staffCode.toLowerCase())) {
              currentStaffCode = await dbService.generateNextStaffCode(afterCode: currentStaffCode);
              staffCode = currentStaffCode;
            }
            errors.add("Row ${i + 2}: Duplicate employee ID '$oldCode' auto-reassigned to '$staffCode'");
          }
        }
        seenStaffCodes.add(staffCode.toLowerCase());

        // Role normalization (must be one of: 'teacher', 'admin', 'support_staff', 'driver')
        String roleInput = getValue('role').toLowerCase().trim();
        if (roleInput.isEmpty) {
          roleInput = getValue('designation').toLowerCase().trim();
        }
        String role = 'teacher';
        if (roleInput.contains('admin') ||
            roleInput.contains('princ') ||
            roleInput.contains('head') ||
            roleInput.contains('director') ||
            roleInput.contains('account') ||
            roleInput.contains('clerk') ||
            roleInput.contains('manager') ||
            roleInput.contains('coord') ||
            roleInput.contains('dean') ||
            roleInput.contains('office')) {
          role = 'admin';
        } else if (roleInput.contains('drive') || roleInput.contains('transport')) {
          role = 'driver';
        } else if (roleInput.contains('support') ||
            roleInput.contains('peon') ||
            roleInput.contains('staff') ||
            roleInput.contains('clean') ||
            roleInput.contains('guard') ||
            roleInput.contains('security') ||
            roleInput.contains('attendant') ||
            roleInput.contains('helper') ||
            roleInput.contains('maid') ||
            roleInput.contains('worker') ||
            roleInput.contains('sweeper')) {
          role = 'support_staff';
        } else {
          role = 'teacher';
        }

        // Designation: if not explicitly mapped, or if role had special title (e.g. Principal), keep it
        String? designation = getValue('designation').isNotEmpty ? getValue('designation') : null;
        if (designation == null) {
          final originalRole = getValue('role').trim();
          if (originalRole.isNotEmpty && originalRole.toLowerCase() != role) {
            designation = originalRole;
          }
        }

        // Department ID: resolve name to UUID in departments table (or create if not existing)
        String? departmentId;
        final deptValue = getValue('department_id').trim();
        if (deptValue.isNotEmpty) {
          final lowerDept = deptValue.toLowerCase();
          if (deptMap.containsKey(lowerDept)) {
            departmentId = deptMap[lowerDept];
          } else {
            try {
              final newDept = Department(
                id: const Uuid().v4(),
                name: deptValue,
                createdAt: DateTime.now(),
              );
              await dbService.insertDepartment(newDept);
              deptMap[lowerDept] = newDept.id;
              deptMap[newDept.id.toLowerCase()] = newDept.id;
              departmentId = newDept.id;
            } catch (_) {
              // If insert fails (e.g. duplicate name in DB), re-fetch and try matching
              try {
                final reloaded = await dbService.getAllDepartments();
                for (final d in reloaded) {
                  deptMap[d.id.toLowerCase()] = d.id;
                  deptMap[d.name.toLowerCase()] = d.id;
                }
                departmentId = deptMap[lowerDept];
              } catch (_) {
                departmentId = null;
              }
            }
          }
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
        final rawGender = getValue('gender').toLowerCase().trim();
        if (rawGender.startsWith('m')) {
          gender = 'male';
        } else if (rawGender.startsWith('f')) {
          gender = 'female';
        } else if (rawGender.isNotEmpty) {
          gender = 'other';
        }

        // Dates
        final dob = normalizeDate(getValue('dob'));
        final joiningDate = normalizeDate(getValue('joining_date')) ??
            DateTime.now().toIso8601String().substring(0, 10);

        // Email & Phone with duplicate avoidance
        String? email = cleanEmail(getValue('email'));
        if (email != null) {
          if (existingEmails.contains(email) || seenEmails.contains(email)) {
            errors.add("Row ${i + 2}: Duplicate email '$email' omitted to avoid database constraint error");
            email = null;
          } else {
            seenEmails.add(email);
          }
        }

        String? phone = cleanPhone(getValue('phone'));
        if (phone != null) {
          if (existingPhones.contains(phone) || seenPhones.contains(phone)) {
            errors.add("Row ${i + 2}: Duplicate phone '$phone' omitted to avoid database constraint error");
            phone = null;
          } else {
            seenPhones.add(phone);
          }
        }

        // Address construction
        final address = buildFullAddress(
          street: getValue('address'),
          city: getValue('city'),
          state: getValue('state'),
          pincode: getValue('pincode'),
        );

        final staff = Staff(
          id: const Uuid().v4(),
          staffCode: staffCode,
          firstName: firstName,
          lastName: lastName,
          dob: dob,
          gender: gender,
          bloodGroup: getValue('blood_group').isNotEmpty ? getValue('blood_group') : null,
          role: role,
          departmentId: departmentId,
          designation: designation,
          joiningDate: joiningDate,
          qualification: getValue('qualification').isNotEmpty ? getValue('qualification') : null,
          experienceYears: experienceYears ?? 0,
          phone: phone,
          email: email,
          address: address.isNotEmpty ? address : null,
          emergencyContact: cleanPhone(getValue('emergency_contact')),
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
        final errorMsg = e.toString();
        if (errorMsg.contains('UNIQUE constraint failed: staff.email')) {
          errors.add("Row ${i + 2}: Duplicate email already exists");
        } else if (errorMsg.contains('UNIQUE constraint failed: staff.phone')) {
          errors.add("Row ${i + 2}: Duplicate phone number already exists");
        } else if (errorMsg.contains('UNIQUE constraint failed: staff.staff_code')) {
          errors.add("Row ${i + 2}: Duplicate employee ID already exists");
        } else if (errorMsg.contains('FOREIGN KEY constraint failed')) {
          errors.add("Row ${i + 2}: Department foreign key failed");
        } else {
          errors.add("Row ${i + 2}: $e");
        }
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
