import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/admission_provider.dart';
import '../../../providers/license_provider.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../services/file_storage_service.dart';

class AdmissionView extends ConsumerStatefulWidget {
  const AdmissionView({super.key});

  @override
  ConsumerState<AdmissionView> createState() => _AdmissionViewState();
}

class _AdmissionViewState extends ConsumerState<AdmissionView> {
  // Focus nodes for Step 1
  final _fnFirstName = FocusNode();
  final _fnLastName = FocusNode();

  // Focus nodes for Step 2
  final _fnAadhaar = FocusNode();
  final _fnAdmissionNo = FocusNode();
  final _fnRollNo = FocusNode();

  // Focus nodes for Step 3
  final _fnFatherName = FocusNode();
  final _fnFatherOcc = FocusNode();
  final _fnFatherPhone = FocusNode();
  final _fnMotherName = FocusNode();
  final _fnMotherOcc = FocusNode();
  final _fnMotherPhone = FocusNode();
  final _fnPrimaryPhone = FocusNode();

  // Focus nodes for Step 4
  final _fnResAddr = FocusNode();
  final _fnPermAddr = FocusNode();

  @override
  void dispose() {
    _fnFirstName.dispose();
    _fnLastName.dispose();
    _fnAadhaar.dispose();
    _fnAdmissionNo.dispose();
    _fnRollNo.dispose();
    _fnFatherName.dispose();
    _fnFatherOcc.dispose();
    _fnFatherPhone.dispose();
    _fnMotherName.dispose();
    _fnMotherOcc.dispose();
    _fnMotherPhone.dispose();
    _fnPrimaryPhone.dispose();
    _fnResAddr.dispose();
    _fnPermAddr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(admissionFormProvider);
    final formNotifier = ref.read(admissionFormProvider.notifier);
    final isReadOnly = ref.watch(licenseStateProvider).value?.status.isReadOnly ?? false;

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── View Header ──
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B4BC4), Color(0xFF7B68EE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New Student Admission',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Multi-step desktop admission wizard with rapid Tab keyboard entry',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => formNotifier.resetForm(),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset Form'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Error Banner ──
            if (formState.stepError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.errorLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        formState.stepError!,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Main Stepper Container ──
            Expanded(
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Theme(
                  data: ThemeData.light().copyWith(
                    canvasColor: Colors.white,
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF4C3BCF),
                      secondary: Color(0xFF4C3BCF),
                    ),
                  ),
                  child: Stepper(
                    type: StepperType.horizontal,
                    currentStep: formState.currentStep,
                    onStepTapped: (step) {
                      formNotifier.setStep(step);
                    },
                    controlsBuilder: (context, details) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Row(
                          children: [
                            if (formState.currentStep < 3)
                              ElevatedButton.icon(
                                onPressed: () {
                                  formNotifier.nextStep();
                                },
                                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                label: const Text('Next Step (Tab)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryPurple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            if (formState.currentStep == 3)
                              ElevatedButton.icon(
                                onPressed: isReadOnly || formState.isSubmitting
                                    ? null
                                    : () async {
                                        final success = await formNotifier.submitAdmission();
                                        if (success && context.mounted) {
                                          ref.invalidate(studentsListProvider);
                                          ref.invalidate(dashboardMetricsProvider);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Student Admission Successfully Registered!'),
                                              backgroundColor: AppTheme.success,
                                            ),
                                          );
                                        }
                                      },
                                icon: formState.isSubmitting
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Icon(isReadOnly ? Icons.lock_rounded : Icons.check_circle_rounded, size: 18),
                                label: Text(isReadOnly ? 'Soft-Lock Active (Read-Only)' : 'Confirm Admission'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isReadOnly ? Colors.grey : AppTheme.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                ),
                              ),
                            const SizedBox(width: 12),
                            if (formState.currentStep > 0)
                              OutlinedButton.icon(
                                onPressed: () => formNotifier.previousStep(),
                                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                                label: const Text('Previous Step'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFFEEEEEE)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                    steps: [
                      // ── Step 1: Student Identity ──
                      Step(
                        title: const Text('Identity'),
                        subtitle: Text(formState.fullName.isEmpty ? 'Basic Info' : formState.fullName, style: const TextStyle(fontSize: 11)),
                        isActive: formState.currentStep >= 0,
                        state: formState.currentStep > 0 ? StepState.complete : StepState.editing,
                        content: _buildStep1Identity(context, formState, formNotifier),
                      ),

                      // ── Step 2: Demographics & Academic ──
                      Step(
                        title: const Text('Academic'),
                        subtitle: Text('${formState.gradeLevel} (${formState.section})', style: const TextStyle(fontSize: 11)),
                        isActive: formState.currentStep >= 1,
                        state: formState.currentStep > 1 ? StepState.complete : (formState.currentStep == 1 ? StepState.editing : StepState.indexed),
                        content: _buildStep2Academic(context, formState, formNotifier),
                      ),

                      // ── Step 3: Guardianship ──
                      Step(
                        title: const Text('Guardianship'),
                        subtitle: Text(formState.fatherName.isNotEmpty ? formState.fatherName : 'Parents Info', style: const TextStyle(fontSize: 11)),
                        isActive: formState.currentStep >= 2,
                        state: formState.currentStep > 2 ? StepState.complete : (formState.currentStep == 2 ? StepState.editing : StepState.indexed),
                        content: _buildStep3Guardianship(context, formState, formNotifier),
                      ),

                      // ── Step 4: Location & Review ──
                      Step(
                        title: const Text('Location & Confirm'),
                        subtitle: const Text('Facilities & Review', style: TextStyle(fontSize: 11)),
                        isActive: formState.currentStep >= 3,
                        state: formState.currentStep == 3 ? StepState.editing : StepState.indexed,
                        content: _buildStep4LocationAndReview(context, formState, formNotifier),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1 UI: Student Identity ──
  Widget _buildStep1Identity(BuildContext context, AdmissionState state, AdmissionFormNotifier notifier) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Placeholder & Picker
              Container(
                width: 140,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      state.photographPath == null ? Icons.add_a_photo_rounded : Icons.check_circle_rounded,
                      color: state.photographPath == null ? AppTheme.textSecondary : AppTheme.primaryPurple,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.photographPath == null ? 'Upload Photo' : 'Photo Selected',
                      style: const TextStyle(color: Color(0xFF757575), fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          allowMultiple: false,
                        );
                        if (result != null && result.files.single.path != null) {
                          try {
                            final newPath = await FileStorageService.copyFileToAppDirectory(result.files.single.path!);
                            notifier.updatePhotographPath(newPath);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to save image: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Browse Explorer', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // Form fields grid
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'First Name *',
                            focusNode: _fnFirstName,
                            initialValue: state.firstName,
                            onChanged: notifier.updateFirstName,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            label: 'Last Name *',
                            focusNode: _fnLastName,
                            initialValue: state.lastName,
                            onChanged: notifier.updateLastName,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildDatePickerField(
                            context: context,
                            label: 'Date of Birth *',
                            selectedDate: state.dob,
                            onDateSelected: notifier.updateDob,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Gender *',
                            value: state.gender,
                            items: ['Male', 'Female', 'Other'],
                            onChanged: (val) => notifier.updateGender(val!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Blood Group',
                            value: state.bloodGroup,
                            items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
                            onChanged: (val) => notifier.updateBloodGroup(val!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 2 UI: Demographics & Academic ──
  Widget _buildStep2Academic(BuildContext context, AdmissionState state, AdmissionFormNotifier notifier) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final classesAsync = ref.watch(classListProvider);
                    final classItems = classesAsync.value?.map((c) => c.name).toList() ?? [
                      'Nursery', 'LKG', 'UKG',
                      'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5',
                      'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10',
                      'Grade 11', 'Grade 12'
                    ];
                    if (!classItems.contains(state.gradeLevel)) {
                      classItems.add(state.gradeLevel);
                    }
                    return _buildDropdownField(
                      label: 'Grade Level / Class *',
                      value: state.gradeLevel,
                      items: classItems,
                      onChanged: (val) => notifier.updateGradeLevel(val!),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final classesAsync = ref.watch(classListProvider);
                    final selClass = classesAsync.value?.where((c) => c.name.toLowerCase() == state.gradeLevel.toLowerCase()).firstOrNull;
                    final sectionsAsync = selClass != null ? ref.watch(sectionsForClassProvider(selClass.id)) : null;
                    final secItems = sectionsAsync?.value?.map((s) => s.name).toList() ?? ['A', 'B', 'C', 'D'];
                    if (!secItems.contains(state.section)) {
                      secItems.add(state.section);
                    }
                    return _buildDropdownField(
                      label: 'Section',
                      value: state.section,
                      items: secItems,
                      onChanged: (val) => notifier.updateSection(val!),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'Admission Number *',
                        focusNode: _fnAdmissionNo,
                        initialValue: state.admissionNumber,
                        onChanged: notifier.updateAdmissionNumber,
                      ),
                    ),
                    IconButton(
                      onPressed: notifier.regenerateAdmissionNumber,
                      icon: const Icon(Icons.autorenew_rounded, color: Color(0xFF60A5FA)),
                      tooltip: 'Auto-generate Admission No.',
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Roll Number',
                  focusNode: _fnRollNo,
                  initialValue: state.rollNumber,
                  onChanged: notifier.updateRollNumber,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDatePickerField(
                  context: context,
                  label: 'Admission Date *',
                  selectedDate: state.admissionDate,
                  onDateSelected: (d) => notifier.updateAdmissionDate(d ?? DateTime.now()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: 'Aadhaar Number (12 Digits)',
                  focusNode: _fnAadhaar,
                  initialValue: state.aadhaarNumber,
                  onChanged: notifier.updateAadhaarNumber,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Category / Caste',
                  value: state.caste,
                  items: ['General', 'OBC', 'SC', 'ST', 'Other'],
                  onChanged: (val) => notifier.updateCaste(val!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField(
                  label: 'Religion',
                  value: state.religion,
                  items: ['Hinduism', 'Islam', 'Christianity', 'Sikhism', 'Buddhism', 'Jainism', 'Other'],
                  onChanged: (val) => notifier.updateReligion(val!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 3 UI: Guardianship ──
  Widget _buildStep3Guardianship(BuildContext context, AdmissionState state, AdmissionFormNotifier notifier) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: "Father's Full Name *",
                  focusNode: _fnFatherName,
                  initialValue: state.fatherName,
                  onChanged: notifier.updateFatherName,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: "Father's Occupation",
                  focusNode: _fnFatherOcc,
                  initialValue: state.fatherOccupation,
                  onChanged: notifier.updateFatherOccupation,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: "Father's Phone",
                  focusNode: _fnFatherPhone,
                  initialValue: state.fatherPhone,
                  onChanged: notifier.updateFatherPhone,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: "Mother's Full Name",
                  focusNode: _fnMotherName,
                  initialValue: state.motherName,
                  onChanged: notifier.updateMotherName,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: "Mother's Occupation",
                  focusNode: _fnMotherOcc,
                  initialValue: state.motherOccupation,
                  onChanged: notifier.updateMotherOccupation,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: "Mother's Phone",
                  focusNode: _fnMotherPhone,
                  initialValue: state.motherPhone,
                  onChanged: notifier.updateMotherPhone,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Primary Emergency Contact Number *',
                  focusNode: _fnPrimaryPhone,
                  initialValue: state.primaryContactNumber,
                  onChanged: notifier.updatePrimaryContactNumber,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 4 UI: Location & Review Summary ──
  Widget _buildStep4LocationAndReview(BuildContext context, AdmissionState state, AdmissionFormNotifier notifier) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Form Inputs
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      label: 'Residential Address *',
                      focusNode: _fnResAddr,
                      initialValue: state.residentialAddress,
                      maxLines: 2,
                      onChanged: notifier.updateResidentialAddress,
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Checkbox(
                          value: state.sameAsResidential,
                          activeColor: AppTheme.primaryPurple,
                          onChanged: (val) => notifier.toggleSameAsResidential(val ?? true),
                        ),
                        const Text('Permanent Address is same as Residential Address', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.5)),
                      ],
                    ),

                    if (!state.sameAsResidential) ...[
                      const SizedBox(height: 12),
                      _buildTextField(
                        label: 'Permanent Address *',
                        focusNode: _fnPermAddr,
                        initialValue: state.permanentAddress,
                        maxLines: 2,
                        onChanged: notifier.updatePermanentAddress,
                      ),
                    ],

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Transport Facility Route',
                            value: state.transportRouteId,
                            items: ['None', 'Route 1 - North City', 'Route 2 - South Express', 'Route 3 - Central Loop'],
                            onChanged: (val) => notifier.updateTransportRouteId(val!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Hostel Facility Room',
                            value: state.hostelId,
                            items: ['Day Scholar', 'Hostel A - Block 1', 'Hostel B - Block 2'],
                            onChanged: (val) => notifier.updateHostelId(val!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // Right: Summary Card Preview
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF4C3BCF), size: 20),
                          SizedBox(width: 10),
                          Text('Admission Review Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        ],
                      ),
                      const Divider(color: Color(0xFFEEEEEE), height: 20),
                      _buildSummaryRow('Student Name', state.fullName),
                      _buildSummaryRow('Admission No.', state.admissionNumber),
                      _buildSummaryRow('Grade & Section', '${state.gradeLevel} - ${state.section}'),
                      _buildSummaryRow('DOB & Gender', '${state.dob != null ? DateFormat('dd MMM yyyy').format(state.dob!) : "N/A"} (${state.gender})'),
                      _buildSummaryRow('Primary Parent', state.fatherName.isNotEmpty ? state.fatherName : state.motherName),
                      _buildSummaryRow('Contact Phone', state.primaryContactNumber.isNotEmpty ? state.primaryContactNumber : state.fatherPhone),
                      _buildSummaryRow('Residential Address', state.residentialAddress.isNotEmpty ? state.residentialAddress : "Not provided"),
                      _buildSummaryRow('Transport / Hostel', '${state.transportRouteId} / ${state.hostelId}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Color(0xFF757575), fontSize: 11.5)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '—' : value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required FocusNode focusNode,
    required String initialValue,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF757575), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          focusNode: focusNode,
          initialValue: initialValue,
          maxLines: maxLines,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4C3BCF), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF757575), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : items.first,
          dropdownColor: Colors.white,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required BuildContext context,
    required String label,
    required DateTime? selectedDate,
    required ValueChanged<DateTime?> onDateSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF757575), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 6)),
              firstDate: DateTime(1990),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              onDateSelected(picked);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate != null ? DateFormat('dd MMM yyyy').format(selectedDate) : 'Select Date',
                  style: TextStyle(color: selectedDate != null ? AppTheme.textPrimary : AppTheme.textSecondary, fontSize: 13),
                ),
                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF757575)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
