import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../services/settings_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../models/academic_year.dart';

class OnboardingWizardView extends ConsumerStatefulWidget {
  const OnboardingWizardView({super.key});

  @override
  ConsumerState<OnboardingWizardView> createState() => _OnboardingWizardViewState();
}

class _OnboardingWizardViewState extends ConsumerState<OnboardingWizardView>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  // Step 1: School Profile Controllers
  final _schoolNameController = TextEditingController(text: 'St. Xavier\'s High School');
  final _schoolAddressController = TextEditingController(text: '123 Education Boulevard, City Campus');
  final _schoolContactController = TextEditingController(text: '+91 98765 43210 | info@school.edu');
  final _schoolMottoController = TextEditingController(text: 'Inspiring Excellence, Building Futures');

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
  bool _celebrationVisible = false;

  // Animation Controllers
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _celebrationController;
  late Animation<double> _celebrationScale;

  @override
  void initState() {
    super.initState();

    // Gentle float animation for header mascot
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Cute pulsing ring for active stepper
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Celebratory bounce on completion
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _celebrationScale = CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _celebrationController.dispose();
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
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    if (!_skipPasswordChange && _passwordController.text.isNotEmpty) {
      if (!_formKey3.currentState!.validate()) return;
    }

    setState(() {
      _isFinishing = true;
      _celebrationVisible = true;
    });

    _celebrationController.forward(from: 0.0);

    try {
      final settings = SettingsService();
      final dbService = DatabaseService();
      final authService = AuthService();

      // 1. Save School Profile
      await settings.setSetting('school_name', _schoolNameController.text.trim());
      await settings.setSetting('school_address', _schoolAddressController.text.trim());
      await settings.setSetting('school_contact', _schoolContactController.text.trim());
      await settings.setSetting('school_motto', _schoolMottoController.text.trim());
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

      // Hold celebration for 1.4s so the user enjoys the cute animation
      await Future.delayed(const Duration(milliseconds: 1400));

      if (mounted) {
        ref.read(onboardingPendingProvider.notifier).state = false;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFinishing = false;
          _celebrationVisible = false;
        });
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
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient with soft ambient circles
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryPurple,
                  Color(0xFF3B2F99),
                  Color(0xFF221668),
                ],
              ),
            ),
          ),

          // Floating Ambient Glow Circles
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          // Main Wizard Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Container(
                width: 640,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCuteHeader(),
                    _buildStepperBar(),
                    const Divider(height: 1, color: AppTheme.divider),
                    SizedBox(
                      height: 420,
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
                    const Divider(height: 1, color: AppTheme.divider),
                    _buildBottomNavigationBar(),
                  ],
                ),
              ),
            ),
          ),

          // Celebratory Success Overlay
          if (_celebrationVisible) _buildCelebrationOverlay(),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Header with Cute Bouncing Icon Mascot
  // --------------------------------------------------------------------------
  Widget _buildCuteHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF9FF),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: child,
              );
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), AppTheme.primaryPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.school_rounded, color: Colors.white, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Welcome to Eduvia!',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('✨', style: TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Let\'s set up your school profile in 2 simple minutes.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Cute Stepper Bar with Animated Pills
  // --------------------------------------------------------------------------
  Widget _buildStepperBar() {
    final steps = [
      {'title': 'Identity', 'icon': Icons.account_balance_rounded},
      {'title': 'Session', 'icon': Icons.calendar_month_rounded},
      {'title': 'Security', 'icon': Icons.shield_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      color: Colors.white,
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = _currentStep == index;
          final isCompleted = _currentStep > index;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.primaryPurple
                          : (isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle_rounded : (steps[index]['icon'] as IconData),
                          size: 16,
                          color: isActive
                              ? Colors.white
                              : (isCompleted ? const Color(0xFF16A34A) : AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            steps[index]['title'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                              color: isActive
                                  ? Colors.white
                                  : (isCompleted ? const Color(0xFF15803D) : AppTheme.textSecondary),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (index < steps.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: isCompleted ? AppTheme.primaryPurple : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Step 1: School Identity Form
  // --------------------------------------------------------------------------
  Widget _buildStep1SchoolIdentity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 1: School Identity & Details',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This name and branding will appear on all fee receipts and report cards.',
              style: GoogleFonts.poppins(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _schoolNameController,
              decoration: InputDecoration(
                labelText: 'Official School Name *',
                hintText: 'e.g. St. Xavier\'s International School',
                prefixIcon: const Icon(Icons.school_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your school name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _schoolAddressController,
              decoration: InputDecoration(
                labelText: 'Campus Address',
                hintText: 'e.g. 123 Education Boulevard, District',
                prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _schoolContactController,
                    decoration: InputDecoration(
                      labelText: 'Contact Phone & Email',
                      hintText: '+91 98765 43210 | info@school.edu',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _schoolMottoController,
              decoration: InputDecoration(
                labelText: 'School Motto / Tagline',
                hintText: 'e.g. Inspiring Excellence, Building Futures',
                prefixIcon: const Icon(Icons.lightbulb_outline, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Step 2: Academic Session & Currency
  // --------------------------------------------------------------------------
  Widget _buildStep2AcademicAndFinance() {
    final currencies = [
      {'symbol': '₹', 'label': '₹ INR (Rupees)'},
      {'symbol': '\$', 'label': '\$ USD (Dollars)'},
      {'symbol': '€', 'label': '€ EUR (Euros)'},
      {'symbol': '£', 'label': '£ GBP (Pounds)'},
      {'symbol': 'AED', 'label': 'AED (Dirhams)'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
      child: Form(
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 2: Academic Session & Currency',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configure your institutional calendar and billing currency symbol.',
              style: GoogleFonts.poppins(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _academicYearController,
              decoration: InputDecoration(
                labelText: 'Active Academic Session *',
                hintText: 'e.g. 2026-2027',
                prefixIcon: const Icon(Icons.event_note_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please specify academic year' : null,
            ),
            const SizedBox(height: 20),
            Text(
              'Currency Symbol for Fee Receipts',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: currencies.map((c) {
                final isSelected = _selectedCurrency == c['symbol'];
                return ChoiceChip(
                  label: Text(c['label']!),
                  selected: isSelected,
                  selectedColor: AppTheme.primarySoft,
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppTheme.primaryPurple : AppTheme.textPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryPurple : Colors.grey.shade300,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCurrency = c['symbol']!);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Default Fee Billing Frequency',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: ['Monthly', 'Quarterly', 'Annually'].map((cycle) {
                final isSelected = _selectedFeeCycle == cycle;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ChoiceChip(
                    label: Text(cycle),
                    selected: isSelected,
                    selectedColor: AppTheme.primarySoft,
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppTheme.primaryPurple : AppTheme.textPrimary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primaryPurple : Colors.grey.shade300,
                      ),
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedFeeCycle = cycle);
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Step 3: Admin Security Form
  // --------------------------------------------------------------------------
  Widget _buildStep3AdminSecurity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
      child: Form(
        key: _formKey3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 3: Secure Your Admin Account',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Replace the initial default password to protect school records.',
              style: GoogleFonts.poppins(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Keep current password for now (change later in Settings)',
                style: GoogleFonts.poppins(fontSize: 12.5, color: AppTheme.textPrimary),
              ),
              value: _skipPasswordChange,
              activeColor: AppTheme.primaryPurple,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (val) {
                setState(() => _skipPasswordChange = val ?? false);
              },
            ),
            if (!_skipPasswordChange) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'New Admin Password',
                        hintText: 'Enter new password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (_skipPasswordChange) return null;
                        if (v == null || v.isEmpty) return 'Please enter a password';
                        if (v.length < 4) return 'Password must be at least 4 characters';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Re-enter password',
                        prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (_skipPasswordChange) return null;
                        if (v != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _selectedSecurityQuestion,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Security Recovery Question',
                prefixIcon: const Icon(Icons.help_outline_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _securityQuestions
                  .map((q) => DropdownMenuItem(
                        value: q,
                        child: Text(q, style: GoogleFonts.poppins(fontSize: 12.5)),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedSecurityQuestion = val);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _securityAnswerController,
              decoration: InputDecoration(
                labelText: 'Recovery Answer',
                hintText: 'Your secret answer in case you forget password',
                prefixIcon: const Icon(Icons.verified_user_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Bottom Navigation Bar with Back & Next / Finish
  // --------------------------------------------------------------------------
  Widget _buildBottomNavigationBar() {
    final isLast = _currentStep == 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: AppTheme.divider),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _previousStep,
            )
          else
            const SizedBox.shrink(),
          ElevatedButton.icon(
            icon: isLast
                ? const Icon(Icons.rocket_launch_rounded, size: 18)
                : const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(
              isLast ? 'Finish & Launch Eduvia 🚀' : 'Next Step',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            onPressed: isLast ? _finishOnboarding : _nextStep,
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Cute Celebration Success Overlay
  // --------------------------------------------------------------------------
  Widget _buildCelebrationOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: ScaleTransition(
          scale: _celebrationScale,
          child: Container(
            width: 440,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.celebration_rounded,
                      color: Color(0xFF16A34A),
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '🎉 All Set!',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome to ${_schoolNameController.text.trim()}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryPurple,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your administrative portal is configured and ready to go. Launching your school dashboard...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
