import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/auth/permission_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/license_provider.dart';
import '../../../services/license_service.dart';
import '../../../services/telemetry_service.dart';
import '../../widgets/blobatar.dart';

class LicenseActivationView extends ConsumerStatefulWidget {
  const LicenseActivationView({super.key});

  @override
  ConsumerState<LicenseActivationView> createState() => _LicenseActivationViewState();
}

class _LicenseActivationViewState extends ConsumerState<LicenseActivationView> {
  final _keyController = TextEditingController();
  bool _isActivating = false;
  String? _statusMessage;
  bool _isSuccess = false;
  LicenseValidationResult? _successResult;
  bool _showTamperInstructions = false;
  bool _hasCopied = false;
  Timer? _copyTimer;
  int _shakeCounter = 0;

  @override
  void dispose() {
    _keyController.dispose();
    _copyTimer?.cancel();
    super.dispose();
  }

  String _generateTamperIncidentId(String hwId) {
    final str = '$hwId-${DateTime.now().millisecondsSinceEpoch}';
    final bytes = utf8.encode(str);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 10).toUpperCase();
  }

  void _onCopyHardwareId(String hwId) {
    Clipboard.setData(ClipboardData(text: hwId));
    setState(() => _hasCopied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _hasCopied = false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hardware ID copied to clipboard!', style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppTheme.primaryPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hardwareIdAsync = ref.watch(hardwareIdProvider);
    final licenseState = ref.watch(licenseStateProvider).value;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // ── Left Branding Panel (hidden on narrow screens) ──
          if (isWide)
            Expanded(
              flex: 5,
              child: Container(
                color: AppTheme.primaryPurple,
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Logo
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/icons/app_icon.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.school_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Eduvia',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                        .slideY(begin: -0.15, end: 0),

                    const Spacer(),

                    // Animated Blobatar Mascot Trio with subtle breathing loop
                    Center(
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Blobatar(seed: 'license-shield', size: 72, borderRadius: 36),
                          SizedBox(width: 16),
                          Blobatar(seed: 'license-key', size: 96, borderRadius: 48),
                          SizedBox(width: 16),
                          Blobatar(seed: 'license-lock', size: 72, borderRadius: 36),
                        ],
                      )
                          .animate()
                          .fadeIn(delay: 150.ms, duration: 500.ms, curve: Curves.easeOut)
                          .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), curve: Curves.easeOutBack)
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .moveY(begin: 0, end: -6, duration: 2500.ms, curve: Curves.easeInOut),
                    ),

                    const SizedBox(height: 40),

                    // Tagline
                    Text(
                      'Activate\nYour License',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 250.ms, duration: 450.ms)
                        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

                    const SizedBox(height: 20),

                    Text(
                      'Enter your vendor-issued license key to unlock\npermanent access to the Eduvia platform.',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 15,
                        height: 1.6,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 350.ms, duration: 450.ms),

                    const Spacer(),

                    // Security Badges
                    Row(
                      children: [
                        Icon(Icons.shield_rounded, color: Colors.white.withValues(alpha: 0.6), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Hardware-locked  •  Offline activation  •  RSA-2048',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(delay: 450.ms, duration: 400.ms),
                  ],
                ),
              ),
            ),

          // ── Right Form / Success Panel ──
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Top bar with back button (only shown if navigated and not in success state)
                  if (Navigator.of(context).canPop() && !_isSuccess)
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12, top: 12),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textSecondary),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Go back',
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 48),

                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _isSuccess
                                ? _buildSuccessCelebrationView()
                                : _buildActivationForm(hardwareIdAsync, licenseState, isWide),
                          ),
                        ),
                      ),
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

  /// Builds the standard license input form with entrance animations
  Widget _buildActivationForm(
    AsyncValue<String> hardwareIdAsync,
    dynamic licenseState,
    bool isWide,
  ) {
    return Column(
      key: const ValueKey('activation_form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mobile-only app icon
        if (!isWide) ...[
          Center(
            child: Image.asset(
              'assets/icons/app_icon.png',
              width: 56,
              height: 56,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.school_rounded,
                color: AppTheme.primaryPurple,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Header
        Text(
          'License Activation',
          style: GoogleFonts.poppins(
            color: AppTheme.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms, curve: Curves.easeOut)
            .slideY(begin: 0.1, end: 0),

        const SizedBox(height: 6),

        Text(
          'Activate your offline installation',
          style: GoogleFonts.poppins(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        )
            .animate()
            .fadeIn(delay: 80.ms, duration: 400.ms),

        const SizedBox(height: 28),

        // ── 30-Day Free Trial Banner ──
        if (licenseState?.status == LicenseStatus.trial) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: AppTheme.primaryPurple, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '30-Day Free Trial Active',
                        style: GoogleFonts.poppins(
                          color: AppTheme.primaryDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${licenseState?.daysRemaining} day(s) remaining. Enter a permanent license key to activate forever.',
                        style: GoogleFonts.poppins(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: 120.ms, duration: 400.ms)
              .slideY(begin: 0.08, end: 0),
          const SizedBox(height: 20),
        ],

        // ── Hardware ID Card ──
        Text(
          'Your Hardware ID',
          style: GoogleFonts.poppins(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Share this ID with Kishan — 9839994285 to get your key',
          style: GoogleFonts.poppins(
            color: AppTheme.textHint,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 8),

        hardwareIdAsync.when(
          data: (hwId) => _buildHardwareIdCard(hwId, licenseState),
          loading: () => Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPurple),
              ),
            ),
          ),
          error: (e, _) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.errorLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Could not detect hardware ID: $e',
                    style: GoogleFonts.poppins(color: AppTheme.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 160.ms, duration: 400.ms)
            .slideY(begin: 0.08, end: 0),

        const SizedBox(height: 22),

        // ── License Key Input Field ──
        Text(
          'RSA License Key',
          style: GoogleFonts.poppins(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        Animate(
          key: ValueKey(_shakeCounter),
          effects: _shakeCounter > 0
              ? [ShakeEffect(duration: 400.ms, hz: 4, curve: Curves.easeInOutCubic, offset: const Offset(6, 0))]
              : const [],
          child: TextField(
            controller: _keyController,
            maxLines: 4,
            style: GoogleFonts.poppins(fontSize: 12.5, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Paste license key provided by vendor...',
              hintStyle: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 13),
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
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .slideY(begin: 0.08, end: 0),

        const SizedBox(height: 16),

        // ── Error / Status Message ──
        if (_statusMessage != null && !_isSuccess) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.errorLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.error,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusMessage!,
                    style: GoogleFonts.poppins(
                      color: AppTheme.error,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 250.ms)
              .shake(hz: 3, duration: 350.ms),
          const SizedBox(height: 16),
        ],

        // ── Activate Button ──
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isActivating ? null : _handleActivate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: _isActivating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Activate License',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        )
            .animate()
            .fadeIn(delay: 240.ms, duration: 400.ms)
            .slideY(begin: 0.08, end: 0),

        const SizedBox(height: 36),

        // Footer
        Center(
          child: Text(
            'Developed by Kishan  •  Contact: 9839994285',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppTheme.textHint,
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 300.ms, duration: 400.ms),
      ],
    );
  }

  /// Builds the hardware ID card with interactive copy feedback and tamper section
  Widget _buildHardwareIdCard(String hwId, dynamic licenseState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              const Icon(Icons.laptop_windows_rounded, color: AppTheme.textSecondary, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: SelectableText(
                  hwId,
                  style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: TextButton.icon(
                  onPressed: () => _onCopyHardwareId(hwId),
                  icon: Icon(
                    _hasCopied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 14,
                    color: _hasCopied ? AppTheme.success : AppTheme.primaryPurple,
                  ),
                  label: Text(
                    _hasCopied ? 'Copied' : 'Copy',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _hasCopied ? AppTheme.success : AppTheme.primaryPurple,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Tamper Recovery ──
        if (licenseState?.status == LicenseStatus.tampered) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.errorLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'System locked due to clock tampering.',
                    style: GoogleFonts.poppins(color: AppTheme.error, fontSize: 12.5),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _showTamperInstructions = !_showTamperInstructions),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryPurple,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text(
                    _showTamperInstructions ? 'Hide' : 'Request Unlock',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_showTamperInstructions) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warningLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tamper Reset Instructions',
                  style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'If your CMOS battery died or clock was altered, WhatsApp support with your Hardware ID and this Incident ID:',
                  style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tag_rounded, color: AppTheme.textSecondary, size: 16),
                      const SizedBox(width: 8),
                      SelectableText(
                        _generateTamperIncidentId(hwId),
                        style: GoogleFonts.poppins(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You will receive a Tamper Reset Token to paste above.',
                  style: GoogleFonts.poppins(
                    color: AppTheme.textHint,
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 250.ms)
              .slideY(begin: -0.05, end: 0),
        ],
      ],
    );
  }

  /// Builds the celebration / success view shown upon valid license key activation
  Widget _buildSuccessCelebrationView() {
    final clientName = _successResult?.details?.clientName ?? 'Authorized User';

    return Column(
      key: const ValueKey('activation_success'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),

        // Glowing Animated Checkmark with Ripple
        Stack(
          alignment: Alignment.center,
          children: [
            // Expanding soft pulse ring
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.35), width: 2),
              ),
            )
                .animate(onPlay: (c) => c.forward())
                .scale(begin: const Offset(0.7, 0.7), end: const Offset(1.3, 1.3), duration: 800.ms, curve: Curves.easeOut)
                .fadeOut(duration: 800.ms),

            // Inner circle with checkmark
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.successLight,
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.5), width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.success.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.check_rounded, color: AppTheme.success, size: 46),
              ),
            )
                .animate()
                .scale(begin: const Offset(0.3, 0.3), end: const Offset(1.0, 1.0), duration: 650.ms, curve: Curves.elasticOut)
                .fadeIn(duration: 300.ms),
          ],
        ),

        const SizedBox(height: 28),

        // Title
        Text(
          'License Activated!',
          style: GoogleFonts.poppins(
            color: AppTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        )
            .animate()
            .fadeIn(delay: 250.ms, duration: 400.ms)
            .slideY(begin: 0.15, end: 0),

        const SizedBox(height: 12),

        // Client Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primarySoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user_rounded, color: AppTheme.primaryPurple, size: 16),
              const SizedBox(width: 8),
              Text(
                'Licensed to: $clientName',
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 350.ms, duration: 400.ms)
            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),

        const SizedBox(height: 16),

        Text(
          'Hardware verification complete.\nAll Eduvia modules are now fully unlocked.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppTheme.textSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
        )
            .animate()
            .fadeIn(delay: 450.ms, duration: 400.ms),

        const SizedBox(height: 32),

        // Launch Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: const SizedBox(
            width: 220,
            height: 6,
            child: LinearProgressIndicator(
              backgroundColor: Color(0xFFF3F4F6),
              color: AppTheme.primaryPurple,
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 550.ms, duration: 300.ms),

        const SizedBox(height: 12),

        Text(
          'Entering workspace...',
          style: GoogleFonts.poppins(
            color: AppTheme.textHint,
            fontSize: 12,
          ),
        )
            .animate()
            .fadeIn(delay: 600.ms, duration: 300.ms),

        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _handleActivate() async {
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.licenseManagement)) return;
    }

    final keyText = _keyController.text.trim();
    if (keyText.isEmpty) {
      setState(() {
        _shakeCounter++;
        _statusMessage = 'Please paste a valid license key.';
      });
      return;
    }

    setState(() {
      _isActivating = true;
      _statusMessage = null;
    });

    final result = await ref.read(licenseStateProvider.notifier).activateKey(keyText);

    if (result.status.isReadOnly) {
      // Failed activation or read-only status
      setState(() {
        _isActivating = false;
        _isSuccess = false;
        _statusMessage = result.message;
        _shakeCounter++;
      });
    } else {
      // Successful valid license activation
      setState(() {
        _isActivating = false;
        _isSuccess = true;
        _successResult = result;
      });

      TelemetryService.instance.trackFeatureUsage('license_activated', {
        'client_name': result.details?.clientName ?? 'Unknown',
      });

      // Allow user to admire the celebration animation before transitioning
      await Future.delayed(const Duration(milliseconds: 2100));

      if (mounted) {
        // Update Riverpod provider to active state
        ref.read(licenseStateProvider.notifier).updateState(result);

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    }
  }
}
