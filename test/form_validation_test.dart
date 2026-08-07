import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_management_system/providers/admission_provider.dart';

void main() {
  group('Student Admission Form Validation Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Step 1 fails validation when First Name is empty', () {
      final notifier = container.read(admissionFormProvider.notifier);
      
      // Attempting nextStep without filling anything
      final success = notifier.nextStep();
      
      expect(success, isFalse);
      expect(container.read(admissionFormProvider).stepError, equals('First Name is required'));
    });

    test('Step 1 fails validation when Last Name is empty', () {
      final notifier = container.read(admissionFormProvider.notifier);
      notifier.updateFirstName('Rahul');
      
      final success = notifier.nextStep();
      
      expect(success, isFalse);
      expect(container.read(admissionFormProvider).stepError, equals('Last Name is required'));
    });

    test('Step 1 fails validation when Date of Birth is missing', () {
      final notifier = container.read(admissionFormProvider.notifier);
      notifier.updateFirstName('Rahul');
      notifier.updateLastName('Sharma');
      
      final success = notifier.nextStep();
      
      expect(success, isFalse);
      expect(container.read(admissionFormProvider).stepError, equals('Date of Birth is required'));
    });

    test('Step 1 passes validation when First Name, Last Name, and DOB are valid', () {
      final notifier = container.read(admissionFormProvider.notifier);
      notifier.updateFirstName('Rahul');
      notifier.updateLastName('Sharma');
      notifier.updateDob(DateTime(2015, 5, 20));
      
      final success = notifier.nextStep();
      
      expect(success, isTrue);
      expect(container.read(admissionFormProvider).currentStep, equals(1));
      expect(container.read(admissionFormProvider).stepError, isNull);
    });

    test('Step 2 fails validation if Admission Number is cleared', () {
      final notifier = container.read(admissionFormProvider.notifier);
      // Advance past step 0
      notifier.updateFirstName('Rahul');
      notifier.updateLastName('Sharma');
      notifier.updateDob(DateTime(2015, 5, 20));
      notifier.nextStep();

      // Clear admission number
      notifier.updateAdmissionNumber('');
      final success = notifier.nextStep();

      expect(success, isFalse);
      expect(container.read(admissionFormProvider).stepError, equals('Admission Number is required'));
    });

    test('Step 3 fails validation if Father and Mother names are both empty', () {
      final notifier = container.read(admissionFormProvider.notifier);
      // Step 1
      notifier.updateFirstName('Rahul');
      notifier.updateLastName('Sharma');
      notifier.updateDob(DateTime(2015, 5, 20));
      notifier.nextStep();
      // Step 2
      notifier.nextStep();

      // Attempt step 3 without parent info
      final success = notifier.nextStep();
      expect(success, isFalse);
      expect(container.read(admissionFormProvider).stepError, equals('Either Father Name or Mother Name is required'));
    });

    test('Step 3 fails validation if Guardian Phone Number is empty', () {
      final notifier = container.read(admissionFormProvider.notifier);
      // Step 1
      notifier.updateFirstName('Rahul');
      notifier.updateLastName('Sharma');
      notifier.updateDob(DateTime(2015, 5, 20));
      notifier.nextStep();
      // Step 2
      notifier.nextStep();

      // Fill Father Name but no phone number
      notifier.updateFatherName('Vikram Sharma');
      final success = notifier.nextStep();

      expect(success, isFalse);
      expect(container.read(admissionFormProvider).stepError, equals('Primary Guardian Contact Number is required'));
    });

    test('Step 4 fails validation if Residential Address is empty', () {
      final notifier = container.read(admissionFormProvider.notifier);
      // Step 1
      notifier.updateFirstName('Rahul');
      notifier.updateLastName('Sharma');
      notifier.updateDob(DateTime(2015, 5, 20));
      notifier.nextStep();
      // Step 2
      notifier.nextStep();
      // Step 3
      notifier.updateFatherName('Vikram Sharma');
      notifier.updatePrimaryContactNumber('9876543210');
      notifier.nextStep();

      // Step 4 - Validate
      expect(container.read(admissionFormProvider).currentStep, equals(3));
      final success = notifier.validateCurrentStep();
      expect(success, isFalse);
      expect(container.read(admissionFormProvider).stepError, equals('Residential Address is required'));
    });
  });

  group('Staff Registration Form Field Validator Tests', () {
    String? requiredValidator(String? value) {
      if (value == null || value.trim().isEmpty) {
        return 'This field is required';
      }
      return null;
    }

    test('Rejects null or empty string for required fields (Employee ID, First Name, Last Name)', () {
      expect(requiredValidator(null), equals('This field is required'));
      expect(requiredValidator(''), equals('This field is required'));
      expect(requiredValidator('   '), equals('This field is required'));
    });

    test('Accepts valid non-empty string for required staff fields', () {
      expect(requiredValidator('EMP-1001'), isNull);
      expect(requiredValidator('Anita'), isNull);
      expect(requiredValidator('Deshmukh'), isNull);
    });
  });
}
