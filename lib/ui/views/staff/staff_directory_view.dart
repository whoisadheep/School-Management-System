import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../services/file_storage_service.dart';
import '../../../core/auth/permission_helper.dart';
import '../../../services/app_logger.dart';
import 'staff_detail_view.dart';
import '../../widgets/blobatar.dart';
import '../../widgets/thinking_orb_widget.dart';

class StaffFilter {
  final String? role;
  final String? departmentId;
  final bool? isActive;

  const StaffFilter({this.role, this.departmentId, this.isActive});

  StaffFilter copyWith({
    String? role,
    bool clearRole = false,
    String? departmentId,
    bool clearDepartmentId = false,
    bool? isActive,
    bool clearIsActive = false,
  }) {
    return StaffFilter(
      role: clearRole ? null : (role ?? this.role),
      departmentId:
          clearDepartmentId ? null : (departmentId ?? this.departmentId),
      isActive: clearIsActive ? null : (isActive ?? this.isActive),
    );
  }
}

final staffSearchQueryProvider = StateProvider<String>((ref) => '');
final staffFilterProvider =
    StateProvider<StaffFilter>((ref) => const StaffFilter(isActive: true));
final staffPageProvider = StateProvider<int>((ref) => 0);
const int itemsPerPage = 12;

final filteredStaffProvider = Provider<AsyncValue<List<Staff>>>((ref) {
  final query = ref.watch(staffSearchQueryProvider).toLowerCase().trim();
  final filter = ref.watch(staffFilterProvider);
  final staffAsync = ref.watch(staffListProvider);
  final departments = ref.watch(departmentListProvider).valueOrNull ?? [];

  return staffAsync.whenData((staffList) {
    return staffList.where((staff) {
      if (filter.isActive != null && staff.isActive != filter.isActive) {
        return false;
      }
      if (filter.role != null &&
          filter.role!.isNotEmpty &&
          staff.role != filter.role) {
        return false;
      }
      if (filter.departmentId != null && filter.departmentId!.isNotEmpty) {
        final target = filter.departmentId!.toLowerCase();
        final matchedDept = departments.where((d) => d.id.toLowerCase() == target || d.name.toLowerCase() == target).firstOrNull;
        final staffDept = staff.departmentId?.toLowerCase() ?? '';
        final matches = staffDept == target ||
            (matchedDept != null && (staffDept == matchedDept.id.toLowerCase() || staffDept == matchedDept.name.toLowerCase()));
        if (!matches) {
          return false;
        }
      }

      if (query.isEmpty) return true;
      final name = staff.fullName.toLowerCase();
      final phone = staff.phone?.toLowerCase() ?? '';
      final role = staff.role.toLowerCase();
      final designation = staff.designation?.toLowerCase() ?? '';
      final email = staff.email?.toLowerCase() ?? '';
      final code = staff.staffCode?.toLowerCase() ?? '';

      return name.contains(query) ||
          phone.contains(query) ||
          role.contains(query) ||
          designation.contains(query) ||
          email.contains(query) ||
          code.contains(query);
    }).toList();
  });
});

final paginatedStaffProvider = Provider<AsyncValue<List<Staff>>>((ref) {
  final filteredAsync = ref.watch(filteredStaffProvider);
  final page = ref.watch(staffPageProvider);

  return filteredAsync.whenData((list) {
    final startIndex = page * itemsPerPage;
    if (startIndex >= list.length) return [];
    return list.skip(startIndex).take(itemsPerPage).toList();
  });
});

class StaffDirectoryView extends ConsumerStatefulWidget {
  const StaffDirectoryView({super.key});

  @override
  ConsumerState<StaffDirectoryView> createState() => _StaffDirectoryViewState();
}

class _StaffDirectoryViewState extends ConsumerState<StaffDirectoryView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isEditing = false;
  bool _isViewingDetail = false;
  Staff? _selectedStaff;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final _staffCodeController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _departmentController = TextEditingController();
  final _designationController = TextEditingController();
  final _basicSalaryController = TextEditingController();
  final _dobController = TextEditingController();
  final _joiningDateController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _experienceYearsController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _panNumberController = TextEditingController();
  final _aadhaarNumberController = TextEditingController();
  final _photoPathController = TextEditingController();

  String _selectedRole = 'teacher';
  String _selectedGender = 'Male';
  String _selectedBloodGroup = 'A+';

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _staffCodeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
    _designationController.dispose();
    _basicSalaryController.dispose();
    _dobController.dispose();
    _joiningDateController.dispose();
    _qualificationController.dispose();
    _experienceYearsController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _bankAccountNumberController.dispose();
    _bankIfscController.dispose();
    _panNumberController.dispose();
    _aadhaarNumberController.dispose();
    _photoPathController.dispose();
    super.dispose();
  }

  void _openStaffDetail(Staff staff) {
    setState(() {
      _isEditing = false;
      _isViewingDetail = true;
      _selectedStaff = staff;
    });
  }

  Future<void> _openStaffForm({Staff? staff}) async {
    setState(() {
      _isViewingDetail = false;
      _isEditing = true;
      _selectedStaff = staff;
      if (staff != null) {
        _staffCodeController.text = staff.staffCode ?? '';
        _firstNameController.text = staff.firstName;
        _lastNameController.text = staff.lastName;
        _phoneController.text = staff.phone ?? '';
        _emailController.text = staff.email ?? '';
        _departmentController.text = staff.departmentId ?? '';
        _designationController.text = staff.designation ?? '';
        _basicSalaryController.text = staff.basicSalary?.toString() ?? '';
        _dobController.text = staff.dob ?? '';
        _joiningDateController.text = staff.joiningDate ?? '';
        _qualificationController.text = staff.qualification ?? '';
        _experienceYearsController.text =
            staff.experienceYears?.toString() ?? '';
        _addressController.text = staff.address ?? '';
        _emergencyContactController.text = staff.emergencyContact ?? '';
        _bankAccountNumberController.text = staff.bankAccountNumber ?? '';
        _bankIfscController.text = staff.bankIfsc ?? '';
        _panNumberController.text = staff.panNumber ?? '';
        _aadhaarNumberController.text = staff.aadhaarNumber ?? '';
        _photoPathController.text = staff.photographPath ?? '';
        _selectedRole = staff.role;
        _selectedGender = staff.gender ?? 'Male';
        _selectedBloodGroup = staff.bloodGroup ?? 'A+';
      } else {
        _staffCodeController.clear();
        _firstNameController.clear();
        _lastNameController.clear();
        _phoneController.clear();
        _emailController.clear();
        _departmentController.clear();
        _designationController.clear();
        _basicSalaryController.clear();
        _dobController.clear();
        _joiningDateController.clear();
        _qualificationController.clear();
        _experienceYearsController.clear();
        _addressController.clear();
        _emergencyContactController.clear();
        _bankAccountNumberController.clear();
        _bankIfscController.clear();
        _panNumberController.clear();
        _aadhaarNumberController.clear();
        _photoPathController.clear();
        _selectedRole = 'teacher';
        _selectedGender = 'Male';
        _selectedBloodGroup = 'A+';
      }
    });

    if (staff == null) {
      final dbService = ref.read(databaseServiceProvider);
      final autoCode = await dbService.generateNextStaffCode();
      if (mounted &&
          _isEditing &&
          _selectedStaff == null &&
          _staffCodeController.text.isEmpty) {
        setState(() {
          _staffCodeController.text = autoCode;
        });
      }
    }
  }

  void _closeAll() {
    setState(() {
      _isEditing = false;
      _isViewingDetail = false;
      _selectedStaff = null;
    });
  }

  Future<void> _regenerateStaffCode() async {
    final dbService = ref.read(databaseServiceProvider);
    final code = await dbService.generateNextStaffCode(
      afterCode: _staffCodeController.text.trim(),
    );
    if (mounted) {
      setState(() => _staffCodeController.text = code);
    }
  }

  Future<void> _saveStaff() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final dbService = ref.read(databaseServiceProvider);

    final staff = Staff(
      id: _selectedStaff?.id ??
          'staff-${DateTime.now().millisecondsSinceEpoch}',
      staffCode: _staffCodeController.text.trim().isNotEmpty
          ? _staffCodeController.text.trim()
          : null,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      dob: _dobController.text.trim().isNotEmpty
          ? _dobController.text.trim()
          : null,
      gender: _selectedGender,
      bloodGroup: _selectedBloodGroup,
      photographPath: _photoPathController.text.trim().isNotEmpty
          ? _photoPathController.text.trim()
          : null,
      role: _selectedRole,
      departmentId: _departmentController.text.trim().isNotEmpty
          ? _departmentController.text.trim()
          : null,
      designation: _designationController.text.trim().isNotEmpty
          ? _designationController.text.trim()
          : null,
      joiningDate: _joiningDateController.text.trim().isNotEmpty
          ? _joiningDateController.text.trim()
          : null,
      qualification: _qualificationController.text.trim().isNotEmpty
          ? _qualificationController.text.trim()
          : null,
      experienceYears: int.tryParse(_experienceYearsController.text.trim()),
      email: _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
      phone: _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null,
      address: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      emergencyContact: _emergencyContactController.text.trim().isNotEmpty
          ? _emergencyContactController.text.trim()
          : null,
      basicSalary: double.tryParse(_basicSalaryController.text.trim()),
      bankAccountNumber: _bankAccountNumberController.text.trim().isNotEmpty
          ? _bankAccountNumberController.text.trim()
          : null,
      bankIfsc: _bankIfscController.text.trim().isNotEmpty
          ? _bankIfscController.text.trim()
          : null,
      panNumber: _panNumberController.text.trim().isNotEmpty
          ? _panNumberController.text.trim()
          : null,
      aadhaarNumber: _aadhaarNumberController.text.trim().isNotEmpty
          ? _aadhaarNumberController.text.trim()
          : null,
      isActive: _selectedStaff?.isActive ?? true,
      createdAt: _selectedStaff?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (_selectedStaff == null) {
        await dbService.insertStaff(staff);
      } else {
        if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.updateRecord)) return;
        await dbService.updateStaff(staff);
      }
      ref.invalidate(staffListProvider);
      ref.invalidate(driversListProvider);
      ref.invalidate(dashboardMetricsProvider);
      if (_selectedStaff != null) {
        _openStaffDetail(staff);
      } else {
        _closeAll();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Staff saved successfully'),
            backgroundColor: AppTheme.success));
      }
    } catch (e, stackTrace) {
      AppLogger.instance.error('Failed to save staff record', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving staff: $e'),
            backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _bulkImportCsv() async {
    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.bulkImport)) return;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        List<String> lines = await file.readAsLines();
        if (lines.isEmpty) return;

        final dbService = ref.read(databaseServiceProvider);
        int successCount = 0;
        List<String> errors = [];

        for (int i = 1; i < lines.length; i++) {
          final parts = lines[i].split(',');
          if (parts.length < 2) continue;

          try {
            final staff = Staff(
              id: 'staff-${DateTime.now().microsecondsSinceEpoch}-$i',
              firstName: parts[0].trim(),
              lastName: parts.length > 1 ? parts[1].trim() : '',
              role: parts.length > 2 && parts[2].isNotEmpty
                  ? parts[2].trim().toLowerCase()
                  : 'teacher',
              departmentId: parts.length > 3 ? parts[3].trim() : null,
              designation: parts.length > 4 ? parts[4].trim() : null,
              phone: parts.length > 5 ? parts[5].trim() : null,
              email: parts.length > 6 ? parts[6].trim() : null,
              basicSalary:
                  parts.length > 7 ? double.tryParse(parts[7].trim()) : null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await dbService.insertStaff(staff);
            successCount++;
          } catch (e) {
            errors.add('Row $i: $e');
          }
        }

        if (successCount > 0) {
          ref.invalidate(staffListProvider);
          ref.invalidate(driversListProvider);
          ref.invalidate(dashboardMetricsProvider);
        }
        if (mounted) {
          if (errors.isNotEmpty) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Import Completed with Errors',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                    child: Text(
                        'Successfully imported $successCount records.\n\nErrors:\n${errors.join('\n')}')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK')),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text('Successfully imported $successCount staff records'),
                backgroundColor: AppTheme.success));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to read file: $e'),
            backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Staff?>(pendingStaffProfileProvider, (previous, staff) {
      if (staff == null) return;
      ref.read(pendingStaffProfileProvider.notifier).state = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openStaffDetail(staff);
        }
      });
    });
    final paginatedAsync = ref.watch(paginatedStaffProvider);
    final filteredAsync = ref.watch(filteredStaffProvider);
    final searchQuery = ref.watch(staffSearchQueryProvider);
    final filter = ref.watch(staffFilterProvider);
    final currentPage = ref.watch(staffPageProvider);
    final departments = ref.watch(departmentListProvider).valueOrNull ?? [];

    if (_isViewingDetail && _selectedStaff != null) {
      return StaffDetailView(
        staff: _selectedStaff!,
        onEdit: () => _openStaffForm(staff: _selectedStaff),
        onBack: _closeAll,
      );
    }

    if (_isEditing) {
      return _buildStaffForm();
    }

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      body: _buildDirectoryView(
        context,
        paginatedAsync,
        filteredAsync,
        searchQuery,
        filter,
        currentPage,
        departments,
      ),
    );
  }

  Widget _buildStaffForm() {
    final roles = ['teacher', 'admin', 'support_staff', 'driver'];
    final genders = ['Male', 'Female', 'Other'];
    final bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
      child: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedStaff == null
                      ? 'Register New Staff Member'
                      : 'Edit Staff Profile Record',
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary),
                ),
                OutlinedButton.icon(
                  onPressed: _regenerateStaffCode,
                  icon: const Icon(Icons.autorenew_rounded, size: 16),
                  label: Text('REGENERATE EMP ID',
                      style: GoogleFonts.poppins(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryPurple,
                      side: const BorderSide(color: AppTheme.primaryPurple)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Section 1: Identity & Employee ID ──
            _buildSectionHeader('1. IDENTITY & EMPLOYEE ID'),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _buildTextField('Employee ID / Staff Code *',
                              _staffCodeController, isRequired: true)),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 22.0),
                        child: ElevatedButton(
                          onPressed: _regenerateStaffCode,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 16)),
                          child: Text('AUTO',
                              style: GoogleFonts.poppins(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            AppTheme.primaryPurple.withValues(alpha: 0.1),
                        backgroundImage: (_photoPathController
                                    .text.isNotEmpty &&
                                File(_photoPathController.text).existsSync())
                            ? FileImage(File(_photoPathController.text))
                            : null,
                        child: (_photoPathController.text.isEmpty ||
                                !File(_photoPathController.text).existsSync())
                            ? const Icon(Icons.person,
                                color: AppTheme.primaryPurple)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildTextField(
                              'Photograph Path', _photoPathController)),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 22.0),
                        child: OutlinedButton(
                          onPressed: () async {
                            final res = await FilePicker.platform
                                .pickFiles(type: FileType.image);
                            if (res != null && res.files.single.path != null) {
                              try {
                                final newPath = await FileStorageService.copyFileToAppDirectory(res.files.single.path!);
                                setState(() => _photoPathController.text = newPath);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to save image: $e')),
                                );
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryPurple,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 16)),
                          child: Text('BROWSE',
                              style: GoogleFonts.poppins(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child:
                        _buildTextField('First Name *', _firstNameController, isRequired: true)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildTextField('Last Name *', _lastNameController, isRequired: true)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: roles.contains(_selectedRole)
                        ? _selectedRole
                        : roles.first,
                    decoration: _buildInputDecoration('Role / Category *'),
                    items: roles
                        .map((r) => DropdownMenuItem(
                            value: r, child: Text(r.toUpperCase())))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRole = val);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildTextField('Designation (e.g. Sr Teacher)',
                        _designationController)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildTextField('Department (e.g. Science, Arts)',
                        _departmentController)),
              ],
            ),
            const SizedBox(height: 32),

            // ── Section 2: Demographics & Contact ──
            _buildSectionHeader('2. DEMOGRAPHICS & CONTACT INFORMATION'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildTextField('Phone Number', _phoneController)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildTextField('Email Address', _emailController)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildTextField('Emergency Contact Phone',
                        _emergencyContactController)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildTextField(
                        'Date of Birth (YYYY-MM-DD)', _dobController)),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: genders.contains(_selectedGender)
                        ? _selectedGender
                        : genders.first,
                    decoration: _buildInputDecoration('Gender'),
                    items: genders
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedGender = val);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: bloodGroups.contains(_selectedBloodGroup)
                        ? _selectedBloodGroup
                        : bloodGroups.first,
                    decoration: _buildInputDecoration('Blood Group'),
                    items: bloodGroups
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null)
                        setState(() => _selectedBloodGroup = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField('Residential Address', _addressController),
            const SizedBox(height: 32),

            // ── Section 3: Professional & Qualification ──
            _buildSectionHeader('3. PROFESSIONAL & QUALIFICATION BACKGROUND'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildTextField(
                        'Highest Qualification (e.g. M.Sc, B.Ed)',
                        _qualificationController)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildTextField('Experience in Years (e.g. 5)',
                        _experienceYearsController)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildTextField('Date of Joining (YYYY-MM-DD)',
                        _joiningDateController)),
              ],
            ),
            const SizedBox(height: 32),

            // ── Section 4: Payroll & Government IDs ──
            _buildSectionHeader('4. PAYROLL & FINANCIAL IDENTIFIERS'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildTextField(
                        'Basic Monthly Salary (₹)', _basicSalaryController)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildTextField('Aadhaar Number (12 Digits)',
                        _aadhaarNumberController)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildTextField(
                        'PAN Number (10 Chars)', _panNumberController)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildTextField(
                        'Bank Account Number', _bankAccountNumberController)),
                const SizedBox(width: 16),
                Expanded(
                    child:
                        _buildTextField('Bank IFSC Code', _bankIfscController)),
              ],
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _selectedStaff != null
                      ? () => _openStaffDetail(_selectedStaff!)
                      : _closeAll,
                  child: Text('Cancel',
                      style:
                          GoogleFonts.poppins(color: AppTheme.textSecondary)),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _saveStaff,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text('Save Staff Profile Record',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgMain,
        borderRadius: BorderRadius.circular(6),
        border:
            Border(left: BorderSide(color: AppTheme.primaryPurple, width: 4)),
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryPurple,
            letterSpacing: 1.0),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 13),
      filled: true,
      fillColor: AppTheme.bgMain,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isRequired = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontSize: 14),
      decoration: _buildInputDecoration(label),
      validator: validator ?? (isRequired ? (value) {
        if (value == null || value.trim().isEmpty) {
          return 'This field is required';
        }
        return null;
      } : null),
    );
  }

  Widget _buildDirectoryView(
    BuildContext context,
    AsyncValue<List<Staff>> paginatedAsync,
    AsyncValue<List<Staff>> filteredAsync,
    String searchQuery,
    StaffFilter filter,
    int currentPage,
    List<Department> departments,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showRightPanel = constraints.maxWidth >= 900;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Directory',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Who are you looking for today?',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _openStaffForm(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text('Add New Staff',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _bulkImportCsv,
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                        label: Text('Bulk Import',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.divider),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showLeaveApprovalsQueueDialog(context),
                        icon: const Icon(Icons.event_available_rounded,
                            size: 18, color: AppTheme.primaryPurple),
                        label: Text('Leave Approvals',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryPurple,
                          backgroundColor:
                              AppTheme.primaryPurple.withValues(alpha: 0.05),
                          side: BorderSide(
                              color: AppTheme.primaryPurple
                                  .withValues(alpha: 0.25)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Search Bar ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppTheme.divider.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.poppins(
                      color: AppTheme.textPrimary, fontSize: 14),
                  onChanged: (val) {
                    if (_debounceTimer?.isActive ?? false) {
                      _debounceTimer!.cancel();
                    }
                    _debounceTimer =
                        Timer(const Duration(milliseconds: 300), () {
                      ref.read(staffSearchQueryProvider.notifier).state = val;
                      ref.read(staffPageProvider.notifier).state = 0;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name, role, or designation...',
                    hintStyle: GoogleFonts.poppins(
                        color: AppTheme.textHint, fontSize: 13.5),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppTheme.textSecondary, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: AppTheme.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(staffSearchQueryProvider.notifier)
                                  .state = '';
                              ref.read(staffPageProvider.notifier).state = 0;
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Filter Bar ──
              Row(
                children: [
                  Text(
                    'Staff',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filteredAsync.valueOrNull?.length ?? 0} Members',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildPillDropdown<String?>(
                    label: 'Department',
                    value: filter.departmentId,
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Department: All')),
                      ...departments.map((d) => DropdownMenuItem(
                            value: d.name,
                            child: Text('Dept: ${d.name}'),
                          )),
                    ],
                    onChanged: (val) {
                      ref.read(staffFilterProvider.notifier).state =
                          filter.copyWith(
                              departmentId: val, clearDepartmentId: val == null);
                      ref.read(staffPageProvider.notifier).state = 0;
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildPillDropdown<String?>(
                    label: 'Role',
                    value: filter.role,
                    items: const [
                      DropdownMenuItem(
                          value: null, child: Text('Role: All')),
                      DropdownMenuItem(
                          value: 'teacher', child: Text('Teacher')),
                      DropdownMenuItem(
                          value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(
                          value: 'support_staff', child: Text('Support Staff')),
                      DropdownMenuItem(
                          value: 'driver', child: Text('Driver')),
                    ],
                    onChanged: (val) {
                      ref.read(staffFilterProvider.notifier).state =
                          filter.copyWith(role: val, clearRole: val == null);
                      ref.read(staffPageProvider.notifier).state = 0;
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildPillDropdown<bool?>(
                    label: 'Status',
                    value: filter.isActive,
                    items: const [
                      DropdownMenuItem(
                          value: null, child: Text('Status: All')),
                      DropdownMenuItem(
                          value: true, child: Text('Active')),
                      DropdownMenuItem(
                          value: false, child: Text('Inactive')),
                    ],
                    onChanged: (val) {
                      ref.read(staffFilterProvider.notifier).state =
                          filter.copyWith(
                              isActive: val, clearIsActive: val == null);
                      ref.read(staffPageProvider.notifier).state = 0;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Main Content Area (Cards Grid + Right Detail Panel) ──
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cards Grid & Pagination
                    Expanded(
                      flex: 3,
                      child: paginatedAsync.when(
                        data: (staffList) {
                          if (staffList.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.people_outline_rounded,
                                      size: 56, color: AppTheme.textHint),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No staff found matching criteria',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final activeStaff =
                              _selectedStaff ?? staffList.first;

                          return Column(
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, gridConstraints) {
                                    final crossAxisCount =
                                        gridConstraints.maxWidth > 580 ? 2 : 1;
                                    return GridView.builder(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        mainAxisExtent: 180,
                                      ),
                                      itemCount: staffList.length,
                                      itemBuilder: (context, index) {
                                        final staff = staffList[index];
                                        final isSelected =
                                            activeStaff.id == staff.id;
                                        return _buildStaffCard(
                                            staff, isSelected, departments);
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildPagination(filteredAsync, currentPage),
                            ],
                          );
                        },
                        loading: () => const Center(
                          child: EduviaThinkingOrb(size: 64),
                        ),
                        error: (err, stack) => Center(
                          child: Text('Error: $err',
                              style: GoogleFonts.poppins(
                                  color: AppTheme.error)),
                        ),
                      ),
                    ),

                    if (showRightPanel) ...[
                      const SizedBox(width: 24),
                      SizedBox(
                        width: constraints.maxWidth > 1200 ? 380 : 350,
                        child: paginatedAsync.when(
                          data: (staffList) {
                            final activeStaff = _selectedStaff ??
                                (staffList.isNotEmpty
                                    ? staffList.first
                                    : null);
                            if (activeStaff == null) {
                              return Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppTheme.divider
                                          .withValues(alpha: 0.6)),
                                ),
                                child: Center(
                                  child: Text(
                                    'Select a staff member to view details',
                                    style: GoogleFonts.poppins(
                                        color: AppTheme.textSecondary),
                                  ),
                                ),
                              );
                            }
                            return _buildRightDetailPanel(
                                activeStaff, departments);
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStaffCard(
      Staff staff, bool isSelected, List<Department> departments) {
    final deptName =
        _getDepartmentName(staff.departmentId, departments, staff.role);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppTheme.primaryPurple
              : AppTheme.divider.withValues(alpha: 0.6),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppTheme.primaryPurple.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: isSelected ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStaff = staff;
          });
        },
        onDoubleTap: () => _openStaffDetail(staff),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: _getAvatarBg(staff.role),
                      child: (staff.photographPath != null &&
                              staff.photographPath!.isNotEmpty &&
                              File(staff.photographPath!).existsSync())
                          ? Image.file(File(staff.photographPath!),
                              fit: BoxFit.cover)
                          : Center(
                              child: AppAvatar(
                                seed: (staff.staffCode != null &&
                                        staff.staffCode!.isNotEmpty)
                                    ? staff.staffCode!
                                    : staff.fullName,
                                name: staff.fullName,
                                size: 48,
                                borderRadius: 12,
                                fallbackColor: _getAvatarBg(staff.role),
                              ),
                            ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: staff.isActive
                          ? const Color(0xFFE8F7EE)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: staff.isActive
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          staff.isActive ? 'Active' : 'Inactive',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: staff.isActive
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                staff.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                staff.designation ?? _formatRole(staff.role),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        deptName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _formatRole(staff.role),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightDetailPanel(Staff staff, List<Department> departments) {
    final deptName =
        _getDepartmentName(staff.departmentId, departments, staff.role);
    final hasPhoto = staff.photographPath != null &&
        staff.photographPath!.isNotEmpty &&
        File(staff.photographPath!).existsSync();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Hero Photo Card with Floating Name & Designation Card ──
          Container(
            height: 270,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: _getAvatarBg(staff.role),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Photo / Studio Background
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: hasPhoto
                        ? Image.file(File(staff.photographPath!),
                            fit: BoxFit.cover)
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF6366F1),
                                  AppTheme.primaryPurple,
                                  AppTheme.primaryDark,
                                ],
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                AppAvatar(
                                  seed: (staff.staffCode != null &&
                                          staff.staffCode!.isNotEmpty)
                                      ? staff.staffCode!
                                      : staff.fullName,
                                  name: staff.fullName,
                                  size: 92,
                                  borderRadius: 24,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),

                // Floating White Card overlapping bottom of photo
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                staff.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                staff.designation ?? _formatRole(staff.role),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (staff.staffCode != null &&
                            staff.staffCode!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              staff.staffCode!,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── 2. Contact Details Section (Clean rows matching reference design) ──
          Text(
            'Contact Details',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),

          // Work Email Row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mail_rounded,
                    color: Colors.white, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Work Email',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 1),
                    SelectableText(
                      staff.email?.isNotEmpty == true
                          ? staff.email!
                          : 'No email on file',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Phone Row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_rounded,
                    color: Colors.white, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phone',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 1),
                    SelectableText(
                      staff.phone?.isNotEmpty == true
                          ? staff.phone!
                          : 'No phone on file',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // ── 3. Info Cards Row (DEPARTMENT & JOINED) ──
          Row(
            children: [
              // Department Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.divider.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DEPARTMENT',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9CA3AF),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        deptName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Joined Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.divider.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JOINED',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9CA3AF),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(staff.joiningDate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // ── 4. Profile Highlights (matching "Current Projects" style) ──
          Text(
            'Profile Highlights',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Card 1: Academic & Experience or Role
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppTheme.divider.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.qualification?.isNotEmpty == true
                      ? staff.qualification!
                      : '${_formatRole(staff.role)} Faculty',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  staff.experienceYears != null
                      ? '${staff.experienceYears} Years Experience • ${_formatRole(staff.role)}'
                      : '$deptName Department • Eduvia School Management',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Card 2: Emergency & Medical (if present) or Status & Role
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppTheme.divider.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.emergencyContact?.isNotEmpty == true
                      ? 'Emergency: ${staff.emergencyContact!}'
                      : 'Status: ${staff.isActive ? "Active in Service" : "Inactive / On Leave"}',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  staff.bloodGroup?.isNotEmpty == true
                      ? 'Blood Group: ${staff.bloodGroup!} • Verified Record'
                      : 'School Staff Record • Offline Storage',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          if (staff.address?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.divider.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Residential Address',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    staff.address!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── 5. Action Buttons: Edit Profile & Full Record ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openStaffForm(staff: staff),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text('Edit Profile',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryPurple,
                    side: const BorderSide(color: AppTheme.primaryPurple),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openStaffDetail(staff),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text('Full Record',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPagination(
      AsyncValue<List<Staff>> filteredAsync, int currentPage) {
    return filteredAsync.whenData((fullList) {
          final totalPages = (fullList.length / itemsPerPage).ceil();
          if (totalPages <= 1) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.divider.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${currentPage * itemsPerPage + 1} - ${((currentPage + 1) * itemsPerPage).clamp(0, fullList.length)} of ${fullList.length} staff',
                  style: GoogleFonts.poppins(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Page ${currentPage + 1} of $totalPages',
                      style: GoogleFonts.poppins(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      onPressed: currentPage > 0
                          ? () => ref
                              .read(staffPageProvider.notifier)
                              .state--
                          : null,
                      tooltip: 'Previous page',
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      onPressed: currentPage < totalPages - 1
                          ? () => ref
                              .read(staffPageProvider.notifier)
                              .state++
                          : null,
                      tooltip: 'Next page',
                    ),
                  ],
                ),
              ],
            ),
          );
        }).valueOrNull ??
        const SizedBox.shrink();
  }

  String _getDepartmentName(
      String? departmentId, List<Department> departments, String role) {
    if (departmentId == null || departmentId.trim().isEmpty) {
      return _formatRole(role);
    }
    final match = departments
        .where((d) =>
            d.id.toLowerCase() == departmentId.toLowerCase() ||
            d.name.toLowerCase() == departmentId.toLowerCase())
        .firstOrNull;
    if (match != null) return match.name;

    if (departmentId.startsWith('dept-') ||
        RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(departmentId)) {
      return _formatRole(role);
    }

    return departmentId[0].toUpperCase() + departmentId.substring(1);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return 'Not specified';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat.yMMMMd().format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'teacher':
        return 'Teacher';
      case 'admin':
        return 'Admin';
      case 'support_staff':
        return 'Support Staff';
      case 'driver':
        return 'Driver';
      default:
        if (role.isEmpty) return 'Staff';
        return role[0].toUpperCase() +
            role.substring(1).replaceAll('_', ' ');
    }
  }

  Color _getAvatarBg(String role) {
    switch (role.toLowerCase()) {
      case 'teacher':
        return const Color(0xFFEDE9FE);
      case 'admin':
        return const Color(0xFFE0E7FF);
      case 'driver':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  void _showLeaveApprovalsQueueDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final pendingAsync = ref.watch(pendingLeaveApplicationsProvider);

          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text('Leave Application Approvals', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: 550,
              height: 400,
              child: pendingAsync.when(
                data: (apps) {
                  if (apps.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 48),
                          const SizedBox(height: 12),
                          Text('No pending leave applications!', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Staff ID: ${app.staffId}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                                Text('${app.startDate} to ${app.endDate}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Reason: ${app.reason}', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    final dbService = ref.read(databaseServiceProvider);
                                    await dbService.updateLeaveStatus(app.id, 'rejected', 'Admin');
                                    ref.invalidate(pendingLeaveApplicationsProvider);
                                    ref.invalidate(staffLeaveApplicationsProvider(app.staffId));
                                  },
                                  child: Text('Reject', style: GoogleFonts.poppins(color: AppTheme.error, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () async {
                                    final dbService = ref.read(databaseServiceProvider);
                                    final conflicts = await dbService.checkExamDutyConflictsForLeave(app.staffId, app.startDate, app.endDate);

                                    bool proceed = true;
                                    if (conflicts.isNotEmpty && context.mounted) {
                                      final conflictNames = conflicts.map((c) => '${c.examName} on ${c.date}').join(', ');
                                      proceed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Row(
                                                children: [
                                                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                                                  const SizedBox(width: 8),
                                                  Text('Exam Duty Conflict Warning', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
                                                ],
                                              ),
                                              content: Text(
                                                'Warning: Staff member has assigned Exam Duty ($conflictNames) during the requested leave period. Do you still want to approve this leave?',
                                                style: GoogleFonts.poppins(fontSize: 13),
                                              ),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                                  child: const Text('Approve Anyway'),
                                                ),
                                              ],
                                            ),
                                          ) ??
                                          false;
                                    }

                                    if (!proceed) return;

                                    await dbService.updateLeaveStatus(app.id, 'approved', 'Admin');
                                    ref.invalidate(pendingLeaveApplicationsProvider);
                                    ref.invalidate(staffLeaveApplicationsProvider(app.staffId));

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      _showSubstituteAssignmentDialog(context, app);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                                  child: const Text('Approve & Assign Subs'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Error: $e'),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  void _showSubstituteAssignmentDialog(BuildContext context, LeaveApplication app) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              const Icon(Icons.find_replace_rounded, color: AppTheme.primaryPurple, size: 22),
              const SizedBox(width: 8),
              Text('Substitute Teacher Assignment', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 550,
            height: 450,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: ref.read(databaseServiceProvider).getSuggestedSubstitutesForStaffLeave(app.staffId, app.startDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error loading suggestions: ${snapshot.error}');
                }

                final suggestions = snapshot.data ?? [];
                if (suggestions.isEmpty) {
                  return Center(
                    child: Text('No class periods found for teacher on ${app.startDate} or no free periods to substitute.',
                        style: GoogleFonts.poppins(color: AppTheme.textHint, fontStyle: FontStyle.italic)),
                  );
                }

                return ListView.builder(
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final item = suggestions[index];
                    final periodEntry = item['periodEntry'] as TimetableEntry;
                    final freeTeachers = item['freeTeachers'] as List<Staff>;

                    String? selectedSubstituteId = freeTeachers.isNotEmpty ? freeTeachers.first.id : null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Period ${periodEntry.periodNumber}: ${periodEntry.subject}',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryPurple)),
                              Text('${periodEntry.classAssigned}-${periodEntry.section}',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (freeTeachers.isEmpty)
                            Text('No free teachers available for this period.', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error, fontStyle: FontStyle.italic))
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: selectedSubstituteId,
                                    decoration: const InputDecoration(labelText: 'Suggested Free Teacher'),
                                    items: freeTeachers
                                        .map((t) => DropdownMenuItem(
                                              value: t.id,
                                              child: Text('${t.fullName} (${t.designation ?? _formatRole(t.role)})'),
                                            ))
                                        .toList(),
                                    onChanged: (val) => setDialogState(() => selectedSubstituteId = val),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: selectedSubstituteId == null
                                      ? null
                                      : () async {
                                          final sub = Substitution(
                                            id: const Uuid().v4(),
                                            date: app.startDate,
                                            periodNumber: periodEntry.periodNumber,
                                            classAssigned: '${periodEntry.classAssigned}-${periodEntry.section}',
                                            subject: periodEntry.subject,
                                            originalStaffId: app.staffId,
                                            substituteStaffId: selectedSubstituteId!,
                                            createdAt: DateTime.now().toIso8601String(),
                                          );

                                          final dbService = ref.read(databaseServiceProvider);
                                          await dbService.assignSubstitution(sub);

                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Assigned substitute for Period ${periodEntry.periodNumber}!'), backgroundColor: AppTheme.success),
                                            );
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
                                  child: const Text('Assign'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
