import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:school_management_system/services/import_service.dart';
import 'package:school_management_system/services/column_mapping_service.dart';
import 'package:school_management_system/services/database_service.dart';
import 'package:school_management_system/core/database/database_helper.dart';

void main() {
  group('ImportService Normalization Helpers Unit Tests', () {
    test('normalizeDate parses various date formats accurately', () {
      // ISO format
      expect(ImportService.normalizeDate('1985-05-05'), equals('1985-05-05'));
      expect(ImportService.normalizeDate('2020-04-01'), equals('2020-04-01'));

      // DD/MM/YYYY
      expect(ImportService.normalizeDate('15/08/1990'), equals('1990-08-15'));
      expect(ImportService.normalizeDate('05/05/1985'), equals('1985-05-05'));

      // DD-MM-YYYY
      expect(ImportService.normalizeDate('01-04-2021'), equals('2021-04-01'));

      // Trailing time
      expect(ImportService.normalizeDate('1990-08-15 14:30:00'), equals('1990-08-15'));

      // Excel serial date (44287 = 2021-04-01)
      expect(ImportService.normalizeDate('44287'), equals('2021-04-01'));

      // Invalid / empty
      expect(ImportService.normalizeDate(''), isNull);
      expect(ImportService.normalizeDate('   '), isNull);
      expect(ImportService.normalizeDate('invalid-date'), isNull);
      expect(ImportService.normalizeDate(null), isNull);
    });

    test('cleanPhone validates and cleans phone numbers', () {
      expect(ImportService.cleanPhone('9876543210'), equals('9876543210'));
      expect(ImportService.cleanPhone(' 9876543218 '), equals('9876543218'));
      expect(ImportService.cleanPhone('+91-98765-43210'), equals('+919876543210'));

      // Rejects letters / junk
      expect(ImportService.cleanPhone('98765abc'), isNull);
      expect(ImportService.cleanPhone('123'), isNull); // Too short
      expect(ImportService.cleanPhone('0000000000'), isNull); // All zeros

      // Rejects placeholders
      expect(ImportService.cleanPhone('n/a'), isNull);
      expect(ImportService.cleanPhone('none'), isNull);
      expect(ImportService.cleanPhone('-'), isNull);
      expect(ImportService.cleanPhone(null), isNull);
    });

    test('cleanEmail validates and normalizes email addresses', () {
      expect(ImportService.cleanEmail('test.valid@example.com'), equals('test.valid@example.com'));
      expect(ImportService.cleanEmail('  Ritu.Sharma@Example.COM '), equals('ritu.sharma@example.com'));

      // Rejects invalid formats
      expect(ImportService.cleanEmail('not-an-email'), isNull);
      expect(ImportService.cleanEmail('missing@tld'), isNull);
      expect(ImportService.cleanEmail('n/a'), isNull);
      expect(ImportService.cleanEmail('-'), isNull);
      expect(ImportService.cleanEmail(null), isNull);
    });

    test('toTitleCase capitalizes words and preserves Unicode / Devanagari', () {
      expect(ImportService.toTitleCase('ritu'), equals('Ritu'));
      expect(ImportService.toTitleCase('SHARMA'), equals('Sharma'));
      expect(ImportService.toTitleCase('john doe'), equals('John Doe'));

      // Preserves Hindi / Devanagari script
      expect(ImportService.toTitleCase('राजेश'), equals('राजेश'));
      expect(ImportService.toTitleCase('कुमार'), equals('कुमार'));
    });

    test('buildFullAddress combines address components cleanly', () {
      expect(
        ImportService.buildFullAddress(
          street: '1 Test Road',
          city: 'Gorakhpur',
          state: 'Uttar Pradesh',
          pincode: '273001',
        ),
        equals('1 Test Road, Gorakhpur, Uttar Pradesh - 273001'),
      );

      expect(
        ImportService.buildFullAddress(street: '1 Test Road'),
        equals('1 Test Road'),
      );
    });

    test('parses staff_import_edge_cases.csv and verifies column mapping', () async {
      const csvPath = '/home/whoisadheep/Downloads/staff_import_edge_cases.csv';
      final file = File(csvPath);
      expect(await file.exists(), isTrue);

      final platformFile = PlatformFile(
        path: csvPath,
        name: 'staff_import_edge_cases.csv',
        size: await file.length(),
        bytes: await file.readAsBytes(),
      );

      final importService = ImportService(dbService: DatabaseService(dbHelper: DatabaseHelper()));
      final rows = await importService.parseFile(platformFile);

      // Exactly 12 data rows parsed (excluding header, handling multiline address)
      expect(rows.length, equals(12));

      // Verify row 10 (Hindi text and multiline address)
      final row10 = rows[8]; // index 8 = row 10 in CSV
      expect(row10['first_name'], equals('राजेश'));
      expect(row10['last_name'], equals('कुमार'));
      expect(row10['address'], contains('Flat 4, "Shanti Apartments"'));
      expect(row10['address'], contains('Near Bus Stand'));

      // Test Column Mapping Service rule-based mapper
      final mappingService = ColumnMappingService(DatabaseService(dbHelper: DatabaseHelper()));
      final headers = await importService.extractHeaders(platformFile);
      final mappingResponse = await mappingService.mapColumnsWithAI(
        headers,
        entityType: ImportEntityType.staff,
      );

      final map = {for (var m in mappingResponse.mappings) m.sourceHeader: m.eduviaFieldKey};

      expect(map['employee_id'], equals('staff_code'));
      expect(map['first_name'], equals('first_name'));
      expect(map['last_name'], equals('last_name'));
      expect(map['gender'], equals('gender'));
      expect(map['date_of_birth'], equals('dob'));
      expect(map['phone'], equals('phone'));
      expect(map['email'], equals('email'));
      expect(map['designation'], equals('designation'));
      expect(map['department'], equals('department_id'));
      expect(map['qualification'], equals('qualification'));
      expect(map['date_of_joining'], equals('joining_date'));
      expect(map['employment_type'], equals('employment_type'));
      expect(map['monthly_salary'], equals('basic_salary'));
      expect(map['address'], equals('address'));
      expect(map['city'], equals('city'));
      expect(map['state'], equals('state'));
      expect(map['pincode'], equals('pincode'));
    });
  });
}
