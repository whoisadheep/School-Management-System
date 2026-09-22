import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/admission_provider.dart';
import '../../../providers/license_provider.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../services/file_storage_service.dart';
import '../../../services/sound_service.dart';
import '../../../services/telemetry_service.dart';
import '../../widgets/blobatar.dart';
import '../students/student_directory_view.dart';

class AdmissionView extends ConsumerStatefulWidget {
  const AdmissionView({super.key});

  @override
  ConsumerState<AdmissionView> createState() => _AdmissionViewState();
}

class _AdmissionViewState extends ConsumerState<AdmissionView> {
  static const List<String> _fatherOccupations = [
    'Business / Self-Employed',
    'Private Sector / Salaried',
    'Government Service',
    'Professional (Doctor / Engineer / Lawyer / CA)',
    'Agriculture / Farmer',
    'Defence / Armed Forces / Police',
    'Teacher / Professor / Educator',
    'Daily Wage / Artisan',
    'Househusband / Homemaker',
    'Retired',
    'Other',
  ];

  static const List<String> _motherOccupations = [
    'Housewife',
    'Private Sector / Salaried',
    'Government Service',
    'Business / Self-Employed',
    'Professional (Doctor / Engineer / Lawyer / CA)',
    'Teacher / Professor / Educator',
    'Healthcare / Nurse / Medical',
    'Agriculture / Farmer',
    'Daily Wage / Artisan',
    'Retired',
    'Other',
  ];

  // Focus nodes
  final _fnFirstName = FocusNode();
  final _fnLastName = FocusNode();
  final _fnDob = FocusNode();
  final _fnGender = FocusNode();
  final _fnBloodGroup = FocusNode();
  final _fnGrade = FocusNode();
  final _fnSection = FocusNode();
  final _fnAadhaar = FocusNode();
  final _fnAdmissionNo = FocusNode();
  final _fnRollNo = FocusNode();
  final _fnAdmissionDate = FocusNode();
  final _fnCaste = FocusNode();
  final _fnReligion = FocusNode();
  final _fnFatherName = FocusNode();
  final _fnFatherOcc = FocusNode();
  final _fnFatherPhone = FocusNode();
  final _fnMotherName = FocusNode();
  final _fnMotherOcc = FocusNode();
  final _fnMotherPhone = FocusNode();
  final _fnPrimaryPhone = FocusNode();
  final _fnResAddr = FocusNode();
  final _fnPermAddr = FocusNode();
  final _fnRoute = FocusNode();
  final _fnHostel = FocusNode();

  // Controllers for smooth keyboard input
  late final TextEditingController _ctrlFirstName;
  late final TextEditingController _ctrlLastName;
  late final TextEditingController _ctrlDob;
  late final TextEditingController _ctrlAadhaar;
  late final TextEditingController _ctrlAdmissionNo;
  late final TextEditingController _ctrlRollNo;
  late final TextEditingController _ctrlAdmissionDate;
  late final TextEditingController _ctrlFatherName;
  late final TextEditingController _ctrlFatherOcc;
  late final TextEditingController _ctrlFatherPhone;
  late final TextEditingController _ctrlMotherName;
  late final TextEditingController _ctrlMotherOcc;
  late final TextEditingController _ctrlMotherPhone;
  late final TextEditingController _ctrlPrimaryPhone;
  late final TextEditingController _ctrlResAddr;
  late final TextEditingController _ctrlPermAddr;

  @override
  void initState() {
    super.initState();
    final form = ref.read(admissionFormProvider);
    _ctrlFirstName = TextEditingController(text: form.firstName);
    _ctrlLastName = TextEditingController(text: form.lastName);
    _ctrlDob = TextEditingController(
      text: form.dob != null ? DateFormat('dd/MM/yyyy').format(form.dob!) : '',
    );
    _ctrlAadhaar = TextEditingController(text: form.aadhaarNumber);
    _ctrlAdmissionNo = TextEditingController(text: form.admissionNumber);
    _ctrlRollNo = TextEditingController(text: form.rollNumber);
    _ctrlAdmissionDate = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(form.admissionDate),
    );
    _ctrlFatherName = TextEditingController(text: form.fatherName);
    _ctrlFatherOcc = TextEditingController(text: form.fatherOccupation);
    _ctrlFatherPhone = TextEditingController(text: form.fatherPhone);
    _ctrlMotherName = TextEditingController(text: form.motherName);
    _ctrlMotherOcc = TextEditingController(text: form.motherOccupation);
    _ctrlMotherPhone = TextEditingController(text: form.motherPhone);
    _ctrlPrimaryPhone = TextEditingController(text: form.primaryContactNumber);
    _ctrlResAddr = TextEditingController(text: form.residentialAddress);
    _ctrlPermAddr = TextEditingController(text: form.permanentAddress);

    _fnDob.addListener(() {
      if (!_fnDob.hasFocus) _formatAndApplyDob();
    });
    _fnAdmissionDate.addListener(() {
      if (!_fnAdmissionDate.hasFocus) _formatAndApplyAdmissionDate();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fnFirstName.requestFocus();
    });
  }

  DateTime? _parseFlexibleDate(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    // 1. If it contains separators (/ or - or . or space)
    if (clean.contains('/') || clean.contains('-') || clean.contains('.') || clean.contains(' ')) {
      final parts = clean.split(RegExp(r'[/.\-\s]+'));
      if (parts.length == 3) {
        int? day = int.tryParse(parts[0]);
        int? month = int.tryParse(parts[1]);
        int? year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          if (year < 100) {
            year += (year > 50 ? 1900 : 2000);
          }
          if (day >= 1 && day <= 31 && month >= 1 && month <= 12 && year >= 1900 && year <= DateTime.now().year + 5) {
            try {
              return DateTime(year, month, day);
            } catch (_) {}
          }
        }
      }
    }

    // 2. Pure digits without separators (e.g. 1582005 -> 15/08/2005)
    final digits = clean.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 8) {
      // DDMMYYYY e.g. 15082005
      final day = int.tryParse(digits.substring(0, 2));
      final month = int.tryParse(digits.substring(2, 4));
      final year = int.tryParse(digits.substring(4, 8));
      if (day != null && month != null && year != null) {
        if (day >= 1 && day <= 31 && month >= 1 && month <= 12 && year >= 1900 && year <= DateTime.now().year + 5) {
          try {
            return DateTime(year, month, day);
          } catch (_) {}
        }
      }
    } else if (digits.length == 7) {
      // DDMYYYY e.g. 1582005 -> 15/08/2005
      final dayA = int.tryParse(digits.substring(0, 2)) ?? 0;
      final monthA = int.tryParse(digits.substring(2, 3)) ?? 0;
      final yearA = int.tryParse(digits.substring(3, 7)) ?? 0;

      // DMMYYYY e.g. 1122005 -> 01/12/2005
      final dayB = int.tryParse(digits.substring(0, 1)) ?? 0;
      final monthB = int.tryParse(digits.substring(1, 3)) ?? 0;
      final yearB = int.tryParse(digits.substring(3, 7)) ?? 0;

      if (dayA >= 1 && dayA <= 31 && monthA >= 1 && monthA <= 12 && yearA >= 1900 && yearA <= DateTime.now().year + 5) {
        try {
          return DateTime(yearA, monthA, dayA);
        } catch (_) {}
      } else if (dayB >= 1 && dayB <= 31 && monthB >= 1 && monthB <= 12 && yearB >= 1900 && yearB <= DateTime.now().year + 5) {
        try {
          return DateTime(yearB, monthB, dayB);
        } catch (_) {}
      }
    } else if (digits.length == 6) {
      // DMYYYY e.g. 582005 -> 05/08/2005
      final yearLast4 = int.tryParse(digits.substring(2, 6)) ?? 0;
      if (yearLast4 >= 1950 && yearLast4 <= DateTime.now().year + 5) {
        final day = int.tryParse(digits.substring(0, 1)) ?? 0;
        final month = int.tryParse(digits.substring(1, 2)) ?? 0;
        if (day >= 1 && day <= 9 && month >= 1 && month <= 9) {
          try {
            return DateTime(yearLast4, month, day);
          } catch (_) {}
        }
      } else {
        // DDMMYY e.g. 150805 -> 15/08/2005
        final day = int.tryParse(digits.substring(0, 2)) ?? 0;
        final month = int.tryParse(digits.substring(2, 4)) ?? 0;
        int year = int.tryParse(digits.substring(4, 6)) ?? 0;
        year += (year > 50 ? 1900 : 2000);
        if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
          try {
            return DateTime(year, month, day);
          } catch (_) {}
        }
      }
    } else if (digits.length == 5) {
      // DDMYY e.g. 15805 -> 15/08/2005
      final dayA = int.tryParse(digits.substring(0, 2)) ?? 0;
      final monthA = int.tryParse(digits.substring(2, 3)) ?? 0;
      int yearA = int.tryParse(digits.substring(3, 5)) ?? 0;
      yearA += (yearA > 50 ? 1900 : 2000);
      if (dayA >= 1 && dayA <= 31 && monthA >= 1 && monthA <= 9) {
        try {
          return DateTime(yearA, monthA, dayA);
        } catch (_) {}
      }
    }
    return null;
  }

  void _formatAndApplyDob() {
    final raw = _ctrlDob.text.trim();
    if (raw.isEmpty) return;

    final parsed = _parseFlexibleDate(raw);
    if (parsed != null) {
      final formatted = DateFormat('dd/MM/yyyy').format(parsed);
      if (_ctrlDob.text != formatted) {
        _ctrlDob.text = formatted;
      }
      ref.read(admissionFormProvider.notifier).updateDob(parsed);
    }
  }

  void _formatAndApplyAdmissionDate() {
    final raw = _ctrlAdmissionDate.text.trim();
    if (raw.isEmpty) return;

    final parsed = _parseFlexibleDate(raw);
    if (parsed != null) {
      final formatted = DateFormat('dd/MM/yyyy').format(parsed);
      if (_ctrlAdmissionDate.text != formatted) {
        _ctrlAdmissionDate.text = formatted;
      }
      ref.read(admissionFormProvider.notifier).updateAdmissionDate(parsed);
    }
  }

  void _syncControllers(AdmissionState next) {
    if (_ctrlAdmissionNo.text != next.admissionNumber) {
      _ctrlAdmissionNo.text = next.admissionNumber;
    }
    if (_ctrlRollNo.text != next.rollNumber) {
      _ctrlRollNo.text = next.rollNumber;
    }
    if (_ctrlPrimaryPhone.text != next.primaryContactNumber && next.primaryContactNumber.isNotEmpty) {
      _ctrlPrimaryPhone.text = next.primaryContactNumber;
    }
    final nextDobStr = next.dob != null ? DateFormat('dd/MM/yyyy').format(next.dob!) : '';
    if (_ctrlDob.text != nextDobStr && !_fnDob.hasFocus) {
      _ctrlDob.text = nextDobStr;
    }
    final nextAdmDateStr = DateFormat('dd/MM/yyyy').format(next.admissionDate);
    if (_ctrlAdmissionDate.text != nextAdmDateStr && !_fnAdmissionDate.hasFocus) {
      _ctrlAdmissionDate.text = nextAdmDateStr;
    }
    if (next.firstName.isEmpty && _ctrlFirstName.text.isNotEmpty) {
      _ctrlFirstName.clear();
      _ctrlLastName.clear();
      _ctrlDob.text = nextDobStr;
      _ctrlAadhaar.clear();
      _ctrlRollNo.text = next.rollNumber;
      _ctrlAdmissionDate.text = nextAdmDateStr;
      _ctrlFatherName.clear();
      _ctrlFatherOcc.text = next.fatherOccupation;
      _ctrlFatherPhone.clear();
      _ctrlMotherName.clear();
      _ctrlMotherOcc.text = next.motherOccupation;
      _ctrlMotherPhone.clear();
      _ctrlPrimaryPhone.clear();
      if (next.residentialAddress.isNotEmpty) {
        _ctrlResAddr.text = next.residentialAddress;
        _ctrlPermAddr.text = next.permanentAddress;
      } else {
        _ctrlResAddr.clear();
        _ctrlPermAddr.clear();
      }
    }
  }

  @override
  void dispose() {
    _fnFirstName.dispose();
    _fnLastName.dispose();
    _fnDob.dispose();
    _fnGender.dispose();
    _fnBloodGroup.dispose();
    _fnGrade.dispose();
    _fnSection.dispose();
    _fnAadhaar.dispose();
    _fnAdmissionNo.dispose();
    _fnRollNo.dispose();
    _fnAdmissionDate.dispose();
    _fnCaste.dispose();
    _fnReligion.dispose();
    _fnFatherName.dispose();
    _fnFatherOcc.dispose();
    _fnFatherPhone.dispose();
    _fnMotherName.dispose();
    _fnMotherOcc.dispose();
    _fnMotherPhone.dispose();
    _fnPrimaryPhone.dispose();
    _fnResAddr.dispose();
    _fnPermAddr.dispose();
    _fnRoute.dispose();
    _fnHostel.dispose();

    _ctrlFirstName.dispose();
    _ctrlLastName.dispose();
    _ctrlDob.dispose();
    _ctrlAadhaar.dispose();
    _ctrlAdmissionNo.dispose();
    _ctrlRollNo.dispose();
    _ctrlAdmissionDate.dispose();
    _ctrlFatherName.dispose();
    _ctrlFatherOcc.dispose();
    _ctrlFatherPhone.dispose();
    _ctrlMotherName.dispose();
    _ctrlMotherOcc.dispose();
    _ctrlMotherPhone.dispose();
    _ctrlPrimaryPhone.dispose();
    _ctrlResAddr.dispose();
    _ctrlPermAddr.dispose();
    super.dispose();
  }

  void _onAdmitNext(AdmissionFormNotifier formNotifier) {
    SoundService().playClick();
    formNotifier.startNextAdmission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fnFirstName.requestFocus();
    });
  }

  Future<void> _submitForm(AdmissionFormNotifier formNotifier) async {
    final isReadOnly = ref.read(licenseStateProvider).value?.status.isReadOnly ?? false;
    if (isReadOnly) {
      SoundService().playAlert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot register admission: System is in read-only mode.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final formState = ref.read(admissionFormProvider);
    final success = await formNotifier.submitAdmission();
    if (success && mounted) {
      TelemetryService.instance.trackStudentAdmitted(
        gradeLevel: formState.gradeLevel.isNotEmpty ? formState.gradeLevel : null,
        gender: formState.gender.isNotEmpty ? formState.gender : null,
      );
      SoundService().playSuccess();
      ref.invalidate(studentsListProvider);
      ref.invalidate(studentDirectoryProvider);
      ref.invalidate(studentDirectoryStatsProvider);
      ref.invalidate(dashboardMetricsProvider);
    } else if (!success && mounted) {
      SoundService().playAlert();
    }
  }

  Future<void> _sendWhatsAppWelcome(Student student) async {
    String phone = (student.guardianPhone ?? student.fatherPhone ?? student.motherPhone ?? '').trim();
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid contact phone number available for WhatsApp.'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
      return;
    }

    final formattedPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final schoolName = ref.read(schoolNameProvider).value ?? 'Eduvia Public School';
    final studentName = student.name.isNotEmpty
        ? student.name
        : '${student.firstName ?? ""} ${student.lastName ?? ""}'.trim();
    final msg = Uri.encodeComponent(
      '🎉 *Welcome to $schoolName!* 🎓\n\n'
      'We are delighted to confirm the admission of *$studentName*.\n'
      '• *Class & Section:* ${student.gradeLevel} - ${student.section ?? "A"}\n'
      '• *Admission No:* ${student.admissionNumber ?? "—"}\n'
      '• *Roll No:* ${student.rollNumber ?? "—"}\n\n'
      'We look forward to an inspiring and successful academic journey together!',
    );

    final url = Uri.parse('https://wa.me/$formattedPhone?text=$msg');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WhatsApp: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AdmissionState>(admissionFormProvider, (prev, next) {
      _syncControllers(next);
      if (prev != null && prev.currentStep != next.currentStep) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          switch (next.currentStep) {
            case 0:
              _fnFirstName.requestFocus();
              break;
            case 1:
              _fnGrade.requestFocus();
              break;
            case 2:
              _fnFatherName.requestFocus();
              break;
            case 3:
              _fnResAddr.requestFocus();
              break;
          }
        });
      }
    });

    final formState = ref.watch(admissionFormProvider);
    final formNotifier = ref.read(admissionFormProvider.notifier);
    final isReadOnly = ref.watch(licenseStateProvider).value?.status.isReadOnly ?? false;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (formState.showSuccessHud) {
            _onAdmitNext(formNotifier);
            return;
          }
          if (formState.currentStep < 3) {
            SoundService().playClick();
            formNotifier.nextStep();
          } else if (!isReadOnly && !formState.isSubmitting) {
            _submitForm(formNotifier);
          }
        },
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (formState.showSuccessHud) {
            _onAdmitNext(formNotifier);
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () {
          if (formState.currentStep < 3) {
            SoundService().playClick();
            formNotifier.nextStep();
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () {
          if (formState.currentStep > 0) {
            SoundService().playClick();
            formNotifier.previousStep();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyB, alt: true): () {
          SoundService().playClick();
          formNotifier.toggleBatchMode();
        },
        const SingleActivator(LogicalKeyboardKey.keyP, alt: true): () {
          SoundService().playClick();
          formNotifier.copyFatherPhoneToPrimary();
          _ctrlPrimaryPhone.text = ref.read(admissionFormProvider).primaryContactNumber;
        },
        const SingleActivator(LogicalKeyboardKey.keyM, alt: true): () {
          SoundService().playClick();
          formNotifier.copyMotherPhoneToPrimary();
          _ctrlPrimaryPhone.text = ref.read(admissionFormProvider).primaryContactNumber;
        },
        const SingleActivator(LogicalKeyboardKey.keyR, alt: true): () {
          SoundService().playClick();
          formNotifier.resetForm();
        },
        const SingleActivator(LogicalKeyboardKey.keyW, alt: true): () {
          if (formState.lastAdmittedStudent != null) {
            _sendWhatsAppWelcome(formState.lastAdmittedStudent!);
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyN, alt: true): () {
          _onAdmitNext(formNotifier);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppTheme.bgMain,
          body: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── View Header ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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
                      Expanded(
                        child: Column(
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
                              'Rapid Flow State • Keyboard Driven • Ctrl+Enter to advance / confirm',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Pace & Count Meter
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.speed_rounded, color: Colors.amberAccent, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  formState.avgPaceSeconds > 0
                                      ? '${formState.avgPaceSeconds.toStringAsFixed(1)}s / student'
                                      : 'Pace: —',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 10),
                                Container(width: 1, height: 12, color: Colors.white30),
                                const SizedBox(width: 10),
                                const Icon(Icons.how_to_reg_rounded, color: Colors.lightGreenAccent, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Admitted: ${formState.sessionAdmittedCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          // Batch Mode Toggle
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: formState.isBatchMode ? Colors.amber.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: formState.isBatchMode ? Colors.amberAccent : Colors.white.withValues(alpha: 0.25),
                                width: formState.isBatchMode ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  size: 18,
                                  color: formState.isBatchMode ? Colors.amberAccent : Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Batch Mode (Alt+B)',
                                  style: TextStyle(
                                    color: formState.isBatchMode ? Colors.amberAccent : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Transform.scale(
                                  scale: 0.75,
                                  child: Switch(
                                    value: formState.isBatchMode,
                                    activeThumbColor: Colors.amberAccent,
                                    activeTrackColor: Colors.amber.withValues(alpha: 0.4),
                                    onChanged: (val) {
                                      SoundService().playClick();
                                      formNotifier.setBatchMode(val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              SoundService().playClick();
                              formNotifier.resetForm();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Reset Form (Alt+R)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Flow State Success HUD ──
                if (formState.showSuccessHud && formState.lastAdmittedStudent != null)
                  _buildSuccessHud(context, formState, formNotifier),

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
                                      SoundService().playClick();
                                      formNotifier.nextStep();
                                    },
                                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                    label: const Text('Next Step (Ctrl+Enter / Tab)'),
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
                                        : () => _submitForm(formNotifier),
                                    icon: formState.isSubmitting
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : Icon(isReadOnly ? Icons.lock_rounded : Icons.check_circle_rounded, size: 18),
                                    label: Text(isReadOnly ? 'Soft-Lock Active (Read-Only)' : 'Confirm Admission (Ctrl+Enter)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isReadOnly ? Colors.grey : AppTheme.success,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                if (formState.currentStep > 0)
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      SoundService().playClick();
                                      formNotifier.previousStep();
                                    },
                                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                                    label: const Text('Previous Step (Alt+←)'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.textPrimary,
                                      side: const BorderSide(color: Color(0xFFDDDDDD)),
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
        ),
      ),
    );
  }

  // ── Flow State Success HUD ──
  Widget _buildSuccessHud(BuildContext context, AdmissionState state, AdmissionFormNotifier notifier) {
    final student = state.lastAdmittedStudent!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F9D58), Color(0xFF0B8043)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AppAvatar(
            seed: student.admissionNumber ?? student.name,
            name: student.name,
            size: 48,
            borderRadius: 24,
            fallbackColor: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '🎉 Admission Confirmed: ${student.name.isNotEmpty ? student.name : "${student.firstName ?? ''} ${student.lastName ?? ''}".trim()}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Class ${student.gradeLevel} - ${student.section}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (student.rollNumber != null && student.rollNumber!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Roll #${student.rollNumber}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Admission No: ${student.admissionNumber} • Batch Mode is ${state.isBatchMode ? "ACTIVE (Class & Section retained)" : "OFF"}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _sendWhatsAppWelcome(student),
                icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                label: const Text('WhatsApp Welcome (Alt+W)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  elevation: 0,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _onAdmitNext(notifier),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                label: const Text('Admit Next (Enter / Alt+N)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0B8043),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  elevation: 2,
                ),
              ),
              IconButton(
                onPressed: () => notifier.dismissSuccessHud(),
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                tooltip: 'Dismiss',
              ),
            ],
          ),
        ],
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
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to save image: $e')),
                              );
                            }
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
                            controller: _ctrlFirstName,
                            onChanged: notifier.updateFirstName,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _fnLastName.requestFocus(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            label: 'Last Name *',
                            focusNode: _fnLastName,
                            controller: _ctrlLastName,
                            onChanged: notifier.updateLastName,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _fnDob.requestFocus(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildDatePickerField(
                            context: context,
                            label: 'Date of Birth *',
                            controller: _ctrlDob,
                            focusNode: _fnDob,
                            selectedDate: state.dob,
                            onDateSelected: notifier.updateDob,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) {
                              _formatAndApplyDob();
                              _fnGender.requestFocus();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Gender *',
                            value: state.gender,
                            items: ['Male', 'Female', 'Other'],
                            focusNode: _fnGender,
                            onSubmitted: () => _fnBloodGroup.requestFocus(),
                            onChanged: (val) => notifier.updateGender(val!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Blood Group',
                            value: state.bloodGroup,
                            items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
                            focusNode: _fnBloodGroup,
                            onSubmitted: () => notifier.nextStep(),
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
                      focusNode: _fnGrade,
                      onSubmitted: () => _fnSection.requestFocus(),
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
                      focusNode: _fnSection,
                      onSubmitted: () => _fnAdmissionNo.requestFocus(),
                      onChanged: (val) => notifier.updateSection(val!),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: 'Admission Number *',
                  focusNode: _fnAdmissionNo,
                  controller: _ctrlAdmissionNo,
                  onChanged: notifier.updateAdmissionNumber,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _fnRollNo.requestFocus(),
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
                  controller: _ctrlRollNo,
                  onChanged: notifier.updateRollNumber,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _fnAdmissionDate.requestFocus(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDatePickerField(
                  context: context,
                  label: 'Admission Date *',
                  controller: _ctrlAdmissionDate,
                  focusNode: _fnAdmissionDate,
                  selectedDate: state.admissionDate,
                  onDateSelected: (d) => notifier.updateAdmissionDate(d ?? DateTime.now()),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) {
                    _formatAndApplyAdmissionDate();
                    _fnAadhaar.requestFocus();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: 'Aadhaar Number (12 Digits)',
                  focusNode: _fnAadhaar,
                  controller: _ctrlAadhaar,
                  onChanged: notifier.updateAadhaarNumber,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _fnCaste.requestFocus(),
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
                  focusNode: _fnCaste,
                  onSubmitted: () => _fnReligion.requestFocus(),
                  onChanged: (val) => notifier.updateCaste(val!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField(
                  label: 'Religion',
                  value: state.religion,
                  items: ['Hinduism', 'Islam', 'Christianity', 'Sikhism', 'Buddhism', 'Jainism', 'Other'],
                  focusNode: _fnReligion,
                  onSubmitted: () => notifier.nextStep(),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  label: "Father's Full Name *",
                  focusNode: _fnFatherName,
                  controller: _ctrlFatherName,
                  onChanged: notifier.updateFatherName,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _fnFatherOcc.requestFocus(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOccupationDropdownField(
                  label: "Father's Occupation",
                  value: state.fatherOccupation,
                  options: _fatherOccupations,
                  onChanged: notifier.updateFatherOccupation,
                  focusNode: _fnFatherOcc,
                  controller: _ctrlFatherOcc,
                  onSubmitted: () => _fnFatherPhone.requestFocus(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: "Father's Phone",
                  focusNode: _fnFatherPhone,
                  controller: _ctrlFatherPhone,
                  onChanged: notifier.updateFatherPhone,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) {
                    if (state.primaryContactNumber.isEmpty && _ctrlFatherPhone.text.isNotEmpty) {
                      notifier.copyFatherPhoneToPrimary();
                      _ctrlPrimaryPhone.text = _ctrlFatherPhone.text;
                    }
                    _fnMotherName.requestFocus();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  label: "Mother's Full Name",
                  focusNode: _fnMotherName,
                  controller: _ctrlMotherName,
                  onChanged: notifier.updateMotherName,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _fnMotherOcc.requestFocus(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOccupationDropdownField(
                  label: "Mother's Occupation",
                  value: state.motherOccupation,
                  options: _motherOccupations,
                  onChanged: notifier.updateMotherOccupation,
                  focusNode: _fnMotherOcc,
                  controller: _ctrlMotherOcc,
                  onSubmitted: () => _fnMotherPhone.requestFocus(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: "Mother's Phone",
                  focusNode: _fnMotherPhone,
                  controller: _ctrlMotherPhone,
                  onChanged: notifier.updateMotherPhone,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) {
                    if (state.primaryContactNumber.isEmpty && _ctrlMotherPhone.text.isNotEmpty) {
                      notifier.copyMotherPhoneToPrimary();
                      _ctrlPrimaryPhone.text = _ctrlMotherPhone.text;
                    }
                    _fnPrimaryPhone.requestFocus();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Primary Emergency Contact Number *',
                  focusNode: _fnPrimaryPhone,
                  controller: _ctrlPrimaryPhone,
                  onChanged: notifier.updatePrimaryContactNumber,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => notifier.nextStep(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quick Autofill Contact', style: TextStyle(color: Color(0xFF757575), fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            SoundService().playClick();
                            notifier.copyFatherPhoneToPrimary();
                            _ctrlPrimaryPhone.text = ref.read(admissionFormProvider).primaryContactNumber;
                          },
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text("Father's (Alt+P)", style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryPurple,
                            side: const BorderSide(color: AppTheme.primaryPurple),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            SoundService().playClick();
                            notifier.copyMotherPhoneToPrimary();
                            _ctrlPrimaryPhone.text = ref.read(admissionFormProvider).primaryContactNumber;
                          },
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text("Mother's (Alt+M)", style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryPurple,
                            side: const BorderSide(color: AppTheme.primaryPurple),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      controller: _ctrlResAddr,
                      maxLines: 2,
                      onChanged: (v) {
                        notifier.updateResidentialAddress(v);
                        if (state.sameAsResidential) {
                          _ctrlPermAddr.text = v;
                        }
                      },
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        if (state.sameAsResidential) {
                          _fnRoute.requestFocus();
                        } else {
                          _fnPermAddr.requestFocus();
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Checkbox(
                          value: state.sameAsResidential,
                          activeColor: AppTheme.primaryPurple,
                          onChanged: (val) {
                            final isSame = val ?? true;
                            notifier.toggleSameAsResidential(isSame);
                            if (isSame) {
                              _ctrlPermAddr.text = _ctrlResAddr.text;
                            }
                          },
                        ),
                        const Text('Permanent Address is same as Residential Address', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.5)),
                      ],
                    ),

                    if (!state.sameAsResidential) ...[
                      const SizedBox(height: 12),
                      _buildTextField(
                        label: 'Permanent Address *',
                        focusNode: _fnPermAddr,
                        controller: _ctrlPermAddr,
                        maxLines: 2,
                        onChanged: notifier.updatePermanentAddress,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _fnRoute.requestFocus(),
                      ),
                    ],

                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Consumer(
                            builder: (context, ref, child) {
                              final routesAsync = ref.watch(routesListProvider);
                              final Map<String, String> routeMap = {'None': 'None'};
                              
                              if (routesAsync.value != null) {
                                for (final r in routesAsync.value!) {
                                  routeMap[r.id] = r.routeName;
                                }
                              }
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildMapDropdownField(
                                    label: 'Transport Facility Route',
                                    value: state.transportRouteId,
                                    items: routeMap,
                                    focusNode: _fnRoute,
                                    onSubmitted: () => _fnHostel.requestFocus(),
                                    onChanged: (val) => notifier.updateTransportRouteId(val!),
                                  ),
                                  if (state.transportRouteId.isNotEmpty && state.transportRouteId != 'None') ...[
                                    const SizedBox(height: 14),
                                    Consumer(
                                      builder: (context, ref, child) {
                                        final stopsAsync = ref.watch(routeStopsProvider(state.transportRouteId));
                                        return stopsAsync.when(
                                          data: (stops) {
                                            final Map<String, String> stopMap = {};
                                            if (stops.isEmpty) {
                                              stopMap[''] = 'Campus Stop (Auto-created, ₹0/mo)';
                                            } else {
                                              for (final s in stops) {
                                                final feeStr = s.fee > 0 ? ' (₹${s.fee.toStringAsFixed(0)}/mo)' : ' (₹0/mo)';
                                                stopMap[s.id] = '${s.stopName}$feeStr';
                                              }
                                            }
                                            final currentValue = stopMap.containsKey(state.transportStopId)
                                                ? state.transportStopId
                                                : stopMap.keys.first;

                                            return _buildMapDropdownField(
                                              label: 'Pickup / Drop Stop & Fee',
                                              value: currentValue,
                                              items: stopMap,
                                              onChanged: (val) {
                                                if (val != null) {
                                                  notifier.updateTransportStopId(val);
                                                }
                                              },
                                            );
                                          },
                                          loading: () => const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 8),
                                            child: LinearProgressIndicator(minHeight: 2),
                                          ),
                                          error: (_, __) => const SizedBox.shrink(),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Hostel Facility Room',
                            value: state.hostelId,
                            items: ['Day Scholar', 'Hostel A - Block 1', 'Hostel B - Block 2'],
                            focusNode: _fnHostel,
                            onSubmitted: () => _submitForm(notifier),
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
                      Row(
                        children: [
                          AppAvatar(
                            seed: state.admissionNumber.isNotEmpty ? state.admissionNumber : state.fullName,
                            name: state.fullName,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.fullName.isNotEmpty ? state.fullName : 'New Student',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                ),
                                Text(
                                  'Class ${state.gradeLevel} - ${state.section} • Adm #${state.admissionNumber}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
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
                      Consumer(
                        builder: (context, ref, child) {
                          final routesAsync = ref.watch(routesListProvider);
                          final dynamic route = routesAsync.value?.cast<dynamic>().firstWhere(
                            (r) => r.id == state.transportRouteId,
                            orElse: () => null,
                          );
                          final routeName = route?.routeName ?? (state.transportRouteId == 'None' ? 'None' : state.transportRouteId);
                          
                          if (state.transportRouteId != 'None' && state.transportRouteId.isNotEmpty) {
                            final stopsAsync = ref.watch(routeStopsProvider(state.transportRouteId));
                            final stops = stopsAsync.value;
                            final stop = stops != null && stops.isNotEmpty
                                ? stops.cast<RouteStop?>().firstWhere(
                                    (s) => s?.id == state.transportStopId,
                                    orElse: () => stops.first,
                                  )
                                : null;
                            final stopInfo = stop != null ? ' (${stop.stopName}, ₹${stop.fee.toStringAsFixed(0)}/mo)' : '';
                            return _buildSummaryRow('Transport / Hostel', '$routeName$stopInfo / ${state.hostelId}');
                          }
                          return _buildSummaryRow('Transport / Hostel', '$routeName / ${state.hostelId}');
                        },
                      ),
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
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
    TextInputAction? textInputAction,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF757575), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          maxLines: maxLines,
          textInputAction: textInputAction ?? (maxLines == 1 ? TextInputAction.next : TextInputAction.newline),
          onFieldSubmitted: onFieldSubmitted,
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
    FocusNode? focusNode,
    VoidCallback? onSubmitted,
  }) {
    final effectiveItems = items.isNotEmpty ? items : ['None'];
    final selectedValue = effectiveItems.contains(value) ? value : effectiveItems.first;

    void toggleNext() {
      final currentIndex = effectiveItems.indexOf(selectedValue);
      final nextIndex = (currentIndex + 1) % effectiveItems.length;
      onChanged(effectiveItems[nextIndex]);
      SoundService().playClick();
    }

    void togglePrevious() {
      final currentIndex = effectiveItems.indexOf(selectedValue);
      final prevIndex = (currentIndex - 1 + effectiveItems.length) % effectiveItems.length;
      onChanged(effectiveItems[prevIndex]);
      SoundService().playClick();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF757575), fontSize: 11, fontWeight: FontWeight.bold)),
            Text('↓ / ↑ to toggle', style: TextStyle(color: AppTheme.primaryPurple.withValues(alpha: 0.6), fontSize: 9.5, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        Focus(
          focusNode: focusNode,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                toggleNext();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                togglePrevious();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.enter && onSubmitted != null) {
                onSubmitted();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: DropdownButtonFormField<String>(
            value: selectedValue,
            dropdownColor: Colors.white,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            onChanged: onChanged,
            icon: InkWell(
              onTap: toggleNext,
              borderRadius: BorderRadius.circular(16),
              child: const Tooltip(
                message: 'Click to cycle next (or press ↓)',
                child: Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.arrow_drop_down, color: Color(0xFF757575), size: 24),
                ),
              ),
            ),
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
            items: effectiveItems.map((item) {
              return DropdownMenuItem(value: item, child: Text(item));
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOccupationDropdownField({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    required FocusNode focusNode,
    required TextEditingController controller,
    VoidCallback? onSubmitted,
  }) {
    final bool isKnownOption = options.where((o) => o != 'Other').contains(value);
    final String dropdownValue = isKnownOption ? value : 'Other';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropdownField(
          label: label,
          value: dropdownValue,
          items: options,
          onSubmitted: onSubmitted,
          onChanged: (selected) {
            if (selected == 'Other') {
              controller.clear();
              onChanged('Other');
            } else if (selected != null) {
              controller.text = selected;
              onChanged(selected);
            }
          },
        ),
        if (!isKnownOption || dropdownValue == 'Other') ...[
          const SizedBox(height: 8),
          _buildTextField(
            label: 'Specify $label',
            focusNode: focusNode,
            controller: controller,
            onChanged: (val) {
              onChanged(val.trim().isEmpty ? 'Other' : val);
            },
            onFieldSubmitted: (_) {
              if (onSubmitted != null) onSubmitted();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildMapDropdownField({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
    FocusNode? focusNode,
    VoidCallback? onSubmitted,
  }) {
    final effectiveItems = items.isNotEmpty ? items : {'': 'None'};
    final selectedKey = effectiveItems.containsKey(value) ? value : effectiveItems.keys.first;
    final keysList = effectiveItems.keys.toList();

    void toggleNext() {
      final currentIndex = keysList.indexOf(selectedKey);
      final nextIndex = (currentIndex + 1) % keysList.length;
      onChanged(keysList[nextIndex]);
      SoundService().playClick();
    }

    void togglePrevious() {
      final currentIndex = keysList.indexOf(selectedKey);
      final prevIndex = (currentIndex - 1 + keysList.length) % keysList.length;
      onChanged(keysList[prevIndex]);
      SoundService().playClick();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF757575), fontSize: 11, fontWeight: FontWeight.bold)),
            Text('↓ / ↑ to toggle', style: TextStyle(color: AppTheme.primaryPurple.withValues(alpha: 0.6), fontSize: 9.5, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        Focus(
          focusNode: focusNode,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                toggleNext();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                togglePrevious();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.enter && onSubmitted != null) {
                onSubmitted();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: DropdownButtonFormField<String>(
            value: selectedKey,
            dropdownColor: Colors.white,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            onChanged: onChanged,
            icon: InkWell(
              onTap: toggleNext,
              borderRadius: BorderRadius.circular(16),
              child: const Tooltip(
                message: 'Click to cycle next (or press ↓)',
                child: Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.arrow_drop_down, color: Color(0xFF757575), size: 24),
                ),
              ),
            ),
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
            items: effectiveItems.entries.map((entry) {
              return DropdownMenuItem(value: entry.key, child: Text(entry.value));
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required DateTime? selectedDate,
    required ValueChanged<DateTime?> onDateSelected,
    TextInputAction? textInputAction,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF757575), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.datetime,
          textInputAction: textInputAction ?? TextInputAction.next,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          onChanged: (val) {
            final parsed = _parseFlexibleDate(val);
            if (parsed != null) {
              onDateSelected(parsed);
            }
          },
          onFieldSubmitted: (val) {
            final parsed = _parseFlexibleDate(val);
            if (parsed != null) {
              controller.text = DateFormat('dd/MM/yyyy').format(parsed);
              onDateSelected(parsed);
            }
            if (onFieldSubmitted != null) {
              onFieldSubmitted(controller.text);
            }
          },
          decoration: InputDecoration(
            hintText: 'DD/MM/YYYY (e.g. 1582005)',
            hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF757575)),
              tooltip: 'Open Calendar',
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 6)),
                  firstDate: DateTime(1990),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  controller.text = DateFormat('dd/MM/yyyy').format(picked);
                  onDateSelected(picked);
                }
              },
            ),
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
}
