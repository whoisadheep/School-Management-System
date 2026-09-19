import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../services/settings_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../models/academic_year.dart';
import '../../../providers/services_provider.dart';

class OnboardingWizardView extends ConsumerStatefulWidget {
  const OnboardingWizardView({super.key});

  @override
  ConsumerState<OnboardingWizardView> createState() => _OnboardingWizardViewState();
}

class _OnboardingWizardViewState extends ConsumerState<OnboardingWizardView> {
  final PageController _pageController = PageController();
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  // Step 1: School Profile Controllers
  final _schoolNameController = TextEditingController(text: 'St. Xavier\'s High School');
  final _schoolAddressController = TextEditingController(text: '123 Education Boulevard, City Campus');
  final _schoolContactController = TextEditingController(text: '+91 98765 43210 | info@school.edu');
  final _schoolMottoController = TextEditingController(text: 'Inspiring Excellence, Building Futures');
  String? _logoPath;
  Uint8List? _logoBytes;

  // Step 2: Academic & Finance
  final _academicYearController = TextEditingController(text: '2026-2027');
  String _selectedCurrency = '₹';
  String _selectedFeeCycle = 'Monthly';

  // Step 3: Security
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _skipPasswordChange = false;

  String _selectedSecurityQuestion = 'What is the name of your first school?';
  final _securityAnswerController = TextEditingController();

  final List<String> _securityQuestions = [
    'What is the name of your first school?',
    'What was your childhood nickname?',
    'What is your mother\'s maiden name?',
    'What is the name of your favorite teacher?',
    'In what city were you born?',
  ];

  int _currentStep = 0;
  bool _isFinishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    _schoolNameController.dispose();
    _schoolAddressController.dispose();
    _schoolContactController.dispose();
    _schoolMottoController.dispose();
    _academicYearController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _securityAnswerController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKey1.currentState!.validate()) return;
    } else if (_currentStep == 1) {
      if (!_formKey2.currentState!.validate()) return;
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    if (!_skipPasswordChange && _passwordController.text.isNotEmpty) {
      if (!_formKey3.currentState!.validate()) return;
    }

    setState(() => _isFinishing = true);

    try {
      final settings = SettingsService();
      final dbService = DatabaseService();
      final authService = AuthService();

      // 1. Save School Profile
      await settings.setSetting('school_name', _schoolNameController.text.trim());
      await settings.setSetting('school_address', _schoolAddressController.text.trim());
      await settings.setSetting('school_contact', _schoolContactController.text.trim());
      await settings.setSetting('school_motto', _schoolMottoController.text.trim());
      if (_logoPath != null) await settings.saveSchoolLogo(_logoPath!);
      await settings.setSetting('currency_symbol', _selectedCurrency);
      await settings.setSetting('fee_billing_cycle', _selectedFeeCycle);

      // 2. Setup Academic Year
      final ayName = _academicYearController.text.trim();
      if (ayName.isNotEmpty) {
        final existingYears = await dbService.getAllAcademicYears();
        final found = existingYears.where((y) => y.name == ayName);
        if (found.isEmpty) {
          final now = DateTime.now();
          await dbService.createAcademicYear(AcademicYear.create(
            name: ayName,
            startDate: DateTime(now.year, 4, 1),
            endDate: DateTime(now.year + 1, 3, 31),
            isCurrent: true,
          ));
        }
      }

      // 3. Update Admin Credentials if changed
      final authState = ref.read(authProvider);
      final adminId = authState.currentAdmin?.id ?? 'admin-default';

      if (!_skipPasswordChange && _passwordController.text.trim().isNotEmpty) {
        await authService.changePassword(adminId, _passwordController.text.trim());
      }

      if (_securityAnswerController.text.trim().isNotEmpty) {
        await authService.setSecurityQuestion(
          adminId,
          _selectedSecurityQuestion,
          _securityAnswerController.text.trim(),
        );
      }

      // 4. Mark Onboarding as Completed
      await settings.setSetting('is_onboarding_completed', '1');
      ref.invalidate(schoolNameProvider);
      ref.invalidate(schoolLogoProvider);

      if (mounted) {
        ref.read(onboardingPendingProvider.notifier).state = false;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFinishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving setup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Scaffold(
      body: Row(
        children: [
          // ── Left Branding Panel ──
          if (isWide)
            Expanded(
              flex: 4,
              child: Container(
                color: AppTheme.primaryPurple,
                padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/icons/app_icon.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Eduvia',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Let\'s get\nyour school\nset up.',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Just a few details and you\'re ready.\nThis takes about 2 minutes.',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Step indicators
                    _buildSideStepIndicator(0, 'School Identity', Icons.account_balance_outlined),
                    const SizedBox(height: 16),
                    _buildSideStepIndicator(1, 'Academic Session', Icons.calendar_month_outlined),
                    const SizedBox(height: 16),
                    _buildSideStepIndicator(2, 'Admin Security', Icons.shield_outlined),
                    const Spacer(),
                    Text(
                      '🔒  All data stays on this machine.',
                      style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // ── Right Form Panel ──
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Top bar (mobile only - shows step info)
                  if (!isWide)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      color: AppTheme.primaryPurple,
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/icons/app_icon.png',
                              width: 28,
                              height: 28,
                              errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Eduvia Setup',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Text(
                              'Step ${_currentStep + 1} of 3',
                              style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Horizontal stepper (mobile only)
                  if (!isWide) _buildMobileStepperBar(),

                  // Form content
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStep1SchoolIdentity(),
                        _buildStep2AcademicAndFinance(),
                        _buildStep3AdminSecurity(),
                      ],
                    ),
                  ),

                  // Bottom bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentStep > 0)
                          TextButton.icon(
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            label: Text('Back', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                            style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                            onPressed: _previousStep,
                          )
                        else
                          const SizedBox.shrink(),
                        ElevatedButton(
                          onPressed: _isFinishing
                              ? null
                              : (_currentStep == 2 ? _finishOnboarding : _nextStep),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.6),
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: _isFinishing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  _currentStep == 2 ? 'Finish Setup' : 'Continue',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Side step indicator for wide layout ──
  Widget _buildSideStepIndicator(int step, String label, IconData icon) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.white
                : (isActive ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded, size: 18, color: AppTheme.primaryPurple)
                : Icon(icon, size: 18, color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: isActive || isCompleted ? Colors.white : Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ── Horizontal stepper for mobile/narrow ──
  Widget _buildMobileStepperBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = _currentStep == i;
          final isCompleted = _currentStep > i;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isCompleted || isActive
                    ? AppTheme.primaryPurple
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Step 1: School Identity ──
  Widget _buildStep1SchoolIdentity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'School Identity',
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'This info appears on receipts, report cards, and documents.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 28),
            _label('School Name'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _schoolNameController,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: _inputDeco(hint: 'e.g. St. Xavier\'s International School', icon: Icons.school_outlined),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 18),
            _label('Campus Address'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _schoolAddressController,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: _inputDeco(hint: '123 Education Boulevard, District', icon: Icons.location_on_outlined),
            ),
            const SizedBox(height: 18),
            _label('Contact Phone & Email'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _schoolContactController,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: _inputDeco(hint: '+91 98765 43210 | info@school.edu', icon: Icons.phone_outlined),
            ),
            const SizedBox(height: 18),
            _label('School Motto'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _schoolMottoController,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: _inputDeco(hint: 'Inspiring Excellence, Building Futures', icon: Icons.lightbulb_outline),
            ),
            const SizedBox(height: 24),
            _label('School Logo'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(type: FileType.image, allowedExtensions: ['png', 'jpg', 'jpeg']);
                if (result != null && result.files.single.path != null) {
                  final path = result.files.single.path!;
                  final bytes = await result.files.single.xFile.readAsBytes();
                  setState(() {
                    _logoPath = path;
                    _logoBytes = bytes;
                  });
                }
              },
              child: _logoBytes != null
                  ? Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(image: MemoryImage(_logoBytes!), fit: BoxFit.cover),
                            border: Border.all(color: AppTheme.primaryPurple, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () => setState(() { _logoBytes = null; _logoPath = null; }),
                          child: Text('Remove', style: GoogleFonts.poppins(color: AppTheme.error, fontSize: 13)),
                        ),
                      ],
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, color: AppTheme.textSecondary, size: 22),
                          SizedBox(height: 2),
                          Text('Upload', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Academic Session & Currency ──
  Widget _buildStep2AcademicAndFinance() {
    final currencies = [
      {'symbol': '₹', 'label': '₹ INR'},
      {'symbol': '\$', 'label': '\$ USD'},
      {'symbol': '€', 'label': '€ EUR'},
      {'symbol': '£', 'label': '£ GBP'},
      {'symbol': 'AED', 'label': 'AED'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Form(
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Academic Session',
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Set your academic calendar and billing currency.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 28),
            _label('Active Academic Year'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _academicYearController,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: _inputDeco(hint: 'e.g. 2026-2027', icon: Icons.event_note_outlined),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            _label('Currency'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: currencies.map((c) {
                final isSelected = _selectedCurrency == c['symbol'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedCurrency = c['symbol']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primarySoft : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryPurple : const Color(0xFFE5E7EB),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      c['label']!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? AppTheme.primaryPurple : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _label('Fee Billing Frequency'),
            const SizedBox(height: 8),
            Row(
              children: ['Monthly', 'Quarterly', 'Annually'].map((cycle) {
                final isSelected = _selectedFeeCycle == cycle;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFeeCycle = cycle),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primarySoft : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryPurple : const Color(0xFFE5E7EB),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        cycle,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? AppTheme.primaryPurple : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 3: Admin Security ──
  Widget _buildStep3AdminSecurity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Form(
        key: _formKey3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Security',
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Secure your admin account with a strong password.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _skipPasswordChange,
                    activeColor: AppTheme.primaryPurple,
                    onChanged: (val) => setState(() => _skipPasswordChange = val ?? false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Keep current password (change later in Settings)',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            if (!_skipPasswordChange) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('New Password'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: _inputDeco(
                            hint: 'Enter new password',
                            icon: Icons.lock_outline_rounded,
                            suffix: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppTheme.textSecondary),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (_skipPasswordChange) return null;
                            if (v == null || v.isEmpty) return 'Required';
                            if (v.length < 4) return 'At least 4 characters';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Confirm Password'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: _inputDeco(
                            hint: 'Re-enter password',
                            icon: Icons.lock_reset_rounded,
                            suffix: IconButton(
                              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppTheme.textSecondary),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                          ),
                          validator: (v) {
                            if (_skipPasswordChange) return null;
                            if (v != _passwordController.text) return 'Passwords don\'t match';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            _label('Security Question'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedSecurityQuestion,
              isExpanded: true,
              style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary),
              decoration: _inputDeco(hint: '', icon: Icons.help_outline_rounded),
              items: _securityQuestions
                  .map((q) => DropdownMenuItem(value: q, child: Text(q, style: GoogleFonts.poppins(fontSize: 13))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedSecurityQuestion = val);
              },
            ),
            const SizedBox(height: 16),
            _label('Recovery Answer'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _securityAnswerController,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: _inputDeco(hint: 'Your secret answer', icon: Icons.verified_user_outlined),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ──

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
    );
  }

  InputDecoration _inputDeco({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
    );
  }
}
