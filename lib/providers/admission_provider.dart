import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'services_provider.dart';
import 'dashboard_provider.dart';

class AdmissionState {
  final int currentStep;
  final String firstName;
  final String lastName;
  final DateTime? dob;
  final String gender;
  final String bloodGroup;
  final String? photographPath;

  final String caste;
  final String religion;
  final String aadhaarNumber;
  final String admissionNumber;
  final String rollNumber;
  final String gradeLevel;
  final String section;
  final DateTime admissionDate;

  final String fatherName;
  final String fatherOccupation;
  final String fatherPhone;
  final String motherName;
  final String motherOccupation;
  final String motherPhone;
  final String primaryContactNumber;

  final String residentialAddress;
  final String permanentAddress;
  final bool sameAsResidential;
  final String transportRouteId;
  final String hostelId;

  final String? stepError;
  final bool isSubmitting;

  AdmissionState({
    this.currentStep = 0,
    this.firstName = '',
    this.lastName = '',
    this.dob,
    this.gender = 'Male',
    this.bloodGroup = 'O+',
    this.photographPath,
    this.caste = 'General',
    this.religion = 'Hinduism',
    this.aadhaarNumber = '',
    String? admissionNumber,
    this.rollNumber = '',
    this.gradeLevel = 'Grade 1',
    this.section = 'A',
    DateTime? admissionDate,
    this.fatherName = '',
    this.fatherOccupation = '',
    this.fatherPhone = '',
    this.motherName = '',
    this.motherOccupation = '',
    this.motherPhone = '',
    this.primaryContactNumber = '',
    this.residentialAddress = '',
    this.permanentAddress = '',
    this.sameAsResidential = true,
    this.transportRouteId = 'None',
    this.hostelId = 'Day Scholar',
    this.stepError,
    this.isSubmitting = false,
  })  : admissionNumber = admissionNumber ?? _generateDefaultAdmissionNumber(),
        admissionDate = admissionDate ?? DateTime.now();

  static String _generateDefaultAdmissionNumber() {
    final year = DateTime.now().year;
    final random = Random().nextInt(8999) + 1000;
    return 'ADM-$year-$random';
  }

  String get fullName {
    final fn = firstName.trim();
    final ln = lastName.trim();
    if (fn.isEmpty && ln.isEmpty) return 'New Student';
    if (ln.isEmpty) return fn;
    if (fn.isEmpty) return ln;
    return '$fn $ln';
  }

  AdmissionState copyWith({
    int? currentStep,
    String? firstName,
    String? lastName,
    DateTime? dob,
    String? gender,
    String? bloodGroup,
    String? photographPath,
    String? caste,
    String? religion,
    String? aadhaarNumber,
    String? admissionNumber,
    String? rollNumber,
    String? gradeLevel,
    String? section,
    DateTime? admissionDate,
    String? fatherName,
    String? fatherOccupation,
    String? fatherPhone,
    String? motherName,
    String? motherOccupation,
    String? motherPhone,
    String? primaryContactNumber,
    String? residentialAddress,
    String? permanentAddress,
    bool? sameAsResidential,
    String? transportRouteId,
    String? hostelId,
    String? stepError,
    bool? isSubmitting,
  }) {
    return AdmissionState(
      currentStep: currentStep ?? this.currentStep,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      photographPath: photographPath ?? this.photographPath,
      caste: caste ?? this.caste,
      religion: religion ?? this.religion,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      rollNumber: rollNumber ?? this.rollNumber,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      section: section ?? this.section,
      admissionDate: admissionDate ?? this.admissionDate,
      fatherName: fatherName ?? this.fatherName,
      fatherOccupation: fatherOccupation ?? this.fatherOccupation,
      fatherPhone: fatherPhone ?? this.fatherPhone,
      motherName: motherName ?? this.motherName,
      motherOccupation: motherOccupation ?? this.motherOccupation,
      motherPhone: motherPhone ?? this.motherPhone,
      primaryContactNumber: primaryContactNumber ?? this.primaryContactNumber,
      residentialAddress: residentialAddress ?? this.residentialAddress,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      sameAsResidential: sameAsResidential ?? this.sameAsResidential,
      transportRouteId: transportRouteId ?? this.transportRouteId,
      hostelId: hostelId ?? this.hostelId,
      stepError: stepError,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class AdmissionFormNotifier extends StateNotifier<AdmissionState> {
  final DatabaseService _dbService;
  final Ref ref;

  AdmissionFormNotifier({DatabaseService? dbService, required this.ref})
      : _dbService = dbService ?? DatabaseService(),
        super(AdmissionState());

  void setStep(int step) {
    state = state.copyWith(currentStep: step, stepError: null);
  }

  void updateFirstName(String val) => state = state.copyWith(firstName: val, stepError: null);
  void updateLastName(String val) => state = state.copyWith(lastName: val, stepError: null);
  void updateDob(DateTime? val) => state = state.copyWith(dob: val, stepError: null);
  void updateGender(String val) => state = state.copyWith(gender: val, stepError: null);
  void updateBloodGroup(String val) => state = state.copyWith(bloodGroup: val, stepError: null);
  void updatePhotographPath(String? val) => state = state.copyWith(photographPath: val, stepError: null);

  void updateCaste(String val) => state = state.copyWith(caste: val, stepError: null);
  void updateReligion(String val) => state = state.copyWith(religion: val, stepError: null);
  void updateAadhaarNumber(String val) => state = state.copyWith(aadhaarNumber: val, stepError: null);
  void updateAdmissionNumber(String val) => state = state.copyWith(admissionNumber: val, stepError: null);
  void updateRollNumber(String val) => state = state.copyWith(rollNumber: val, stepError: null);
  void updateGradeLevel(String val) => state = state.copyWith(gradeLevel: val, stepError: null);
  void updateSection(String val) => state = state.copyWith(section: val, stepError: null);
  void updateAdmissionDate(DateTime val) => state = state.copyWith(admissionDate: val, stepError: null);

  void updateFatherName(String val) => state = state.copyWith(fatherName: val, stepError: null);
  void updateFatherOccupation(String val) => state = state.copyWith(fatherOccupation: val, stepError: null);
  void updateFatherPhone(String val) => state = state.copyWith(fatherPhone: val, stepError: null);
  void updateMotherName(String val) => state = state.copyWith(motherName: val, stepError: null);
  void updateMotherOccupation(String val) => state = state.copyWith(motherOccupation: val, stepError: null);
  void updateMotherPhone(String val) => state = state.copyWith(motherPhone: val, stepError: null);
  void updatePrimaryContactNumber(String val) => state = state.copyWith(primaryContactNumber: val, stepError: null);

  void updateResidentialAddress(String val) {
    if (state.sameAsResidential) {
      state = state.copyWith(residentialAddress: val, permanentAddress: val, stepError: null);
    } else {
      state = state.copyWith(residentialAddress: val, stepError: null);
    }
  }

  void updatePermanentAddress(String val) => state = state.copyWith(permanentAddress: val, stepError: null);

  void toggleSameAsResidential(bool val) {
    if (val) {
      state = state.copyWith(
        sameAsResidential: true,
        permanentAddress: state.residentialAddress,
        stepError: null,
      );
    } else {
      state = state.copyWith(sameAsResidential: false, stepError: null);
    }
  }

  void updateTransportRouteId(String val) => state = state.copyWith(transportRouteId: val, stepError: null);
  void updateHostelId(String val) => state = state.copyWith(hostelId: val, stepError: null);

  void regenerateAdmissionNumber() {
    state = state.copyWith(
      admissionNumber: AdmissionState._generateDefaultAdmissionNumber(),
      stepError: null,
    );
  }

  /// Step Validation Logic before advancing
  bool validateCurrentStep() {
    switch (state.currentStep) {
      case 0: // Step 1: Student Identity
        if (state.firstName.trim().isEmpty) {
          state = state.copyWith(stepError: 'First Name is required');
          return false;
        }
        if (state.lastName.trim().isEmpty) {
          state = state.copyWith(stepError: 'Last Name is required');
          return false;
        }
        if (state.dob == null) {
          state = state.copyWith(stepError: 'Date of Birth is required');
          return false;
        }
        return true;

      case 1: // Step 2: Demographics & Academic
        if (state.gradeLevel.trim().isEmpty) {
          state = state.copyWith(stepError: 'Grade Level selection is required');
          return false;
        }
        if (state.admissionNumber.trim().isEmpty) {
          state = state.copyWith(stepError: 'Admission Number is required');
          return false;
        }
        return true;

      case 2: // Step 3: Guardianship
        if (state.fatherName.trim().isEmpty && state.motherName.trim().isEmpty) {
          state = state.copyWith(stepError: 'Either Father Name or Mother Name is required');
          return false;
        }
        if (state.primaryContactNumber.trim().isEmpty && state.fatherPhone.trim().isEmpty && state.motherPhone.trim().isEmpty) {
          state = state.copyWith(stepError: 'Primary Guardian Contact Number is required');
          return false;
        }
        return true;

      case 3: // Step 4: Location & Facilities
        if (state.residentialAddress.trim().isEmpty) {
          state = state.copyWith(stepError: 'Residential Address is required');
          return false;
        }
        return true;

      default:
        return true;
    }
  }

  bool nextStep() {
    if (validateCurrentStep()) {
      if (state.currentStep < 3) {
        state = state.copyWith(currentStep: state.currentStep + 1, stepError: null);
        return true;
      }
    }
    return false;
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1, stepError: null);
    }
  }

  /// Confirm Admission & Submit to SQLite
  Future<bool> submitAdmission() async {
    if (!validateCurrentStep()) return false;

    state = state.copyWith(isSubmitting: true, stepError: null);

    try {
      final guardianPhone = state.primaryContactNumber.trim().isNotEmpty
          ? state.primaryContactNumber.trim()
          : (state.fatherPhone.trim().isNotEmpty ? state.fatherPhone.trim() : state.motherPhone.trim());

      final student = Student.create(
        name: state.fullName,
        gradeLevel: state.gradeLevel,
        firstName: state.firstName.trim(),
        lastName: state.lastName.trim(),
        dob: state.dob?.toIso8601String().split('T')[0],
        gender: state.gender,
        bloodGroup: state.bloodGroup,
        photographPath: state.photographPath,
        caste: state.caste,
        religion: state.religion,
        aadhaarNumber: state.aadhaarNumber.trim(),
        admissionNumber: state.admissionNumber.trim(),
        rollNumber: state.rollNumber.trim(),
        section: state.section,
        admissionDate: state.admissionDate.toIso8601String().split('T')[0],
        fatherName: state.fatherName.trim(),
        fatherOccupation: state.fatherOccupation.trim(),
        fatherPhone: state.fatherPhone.trim(),
        motherName: state.motherName.trim(),
        motherOccupation: state.motherOccupation.trim(),
        motherPhone: state.motherPhone.trim(),
        guardianPhone: guardianPhone,
        residentialAddress: state.residentialAddress.trim(),
        permanentAddress: state.permanentAddress.trim(),
        transportRouteId: state.transportRouteId,
        hostelId: state.hostelId,
      );

      await _dbService.insertStudent(student);

      ref.invalidate(studentsListProvider);
      ref.invalidate(dashboardMetricsProvider);

      // Reset draft state after successful admission
      resetForm();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, stepError: 'Admission Failed: ${e.toString()}');
      return false;
    }
  }

  void resetForm() {
    state = AdmissionState();
  }
}

final admissionFormProvider = StateNotifierProvider<AdmissionFormNotifier, AdmissionState>((ref) {
  return AdmissionFormNotifier(ref: ref);
});
