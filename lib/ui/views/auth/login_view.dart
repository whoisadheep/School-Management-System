import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/blobatar.dart';
import 'forgot_password_view.dart';

class AdminLoginView extends ConsumerStatefulWidget {
  const AdminLoginView({super.key});

  @override
  ConsumerState<AdminLoginView> createState() => _AdminLoginViewState();
}

class _AdminLoginViewState extends ConsumerState<AdminLoginView> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;

  Future<void> _submitLogin() async {
    if (_formKey.currentState!.validate()) {
      final success = await ref.read(authProvider.notifier).login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (!success && mounted) {
        _passwordController.clear();
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Scaffold(
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
                    // Logo
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
                    ),
                    const Spacer(),

                    // Cute Blob Cartoon Trio
                    const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Blobatar(seed: 'eduvia-student', size: 72, borderRadius: 36),
                          SizedBox(width: 16),
                          Blobatar(seed: 'eduvia-teacher', size: 96, borderRadius: 48),
                          SizedBox(width: 16),
                          Blobatar(seed: 'eduvia-admin', size: 72, borderRadius: 36),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Tagline
                    Text(
                      'School\nManagement,\nSimplified.',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Everything your institution needs — admissions,\nfees, attendance, exams — all in one place.',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const Spacer(),
                    // Footer
                    Text(
                      '🔒  All data stored locally & securely on this machine.',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Right Form Panel ──
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mobile-only logo
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

                          Text(
                            'Welcome back',
                            style: GoogleFonts.poppins(
                              color: AppTheme.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to your account',
                            style: GoogleFonts.poppins(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 36),

                          // Error message
                          if (authState.errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                      authState.errorMessage!,
                                      style: GoogleFonts.poppins(color: AppTheme.error, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Username
                          Text(
                            'Username',
                            style: GoogleFonts.poppins(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _usernameController,
                            style: GoogleFonts.poppins(fontSize: 14),
                            decoration: _inputDecoration(
                              hint: 'Enter your username',
                              icon: Icons.person_outline_rounded,
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                          ),

                          const SizedBox(height: 20),

                          // Password
                          Text(
                            'Password',
                            style: GoogleFonts.poppins(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: GoogleFonts.poppins(fontSize: 14),
                            decoration: _inputDecoration(
                              hint: 'Enter your password',
                              icon: Icons.lock_outline_rounded,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 20,
                                  color: AppTheme.textSecondary,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            onFieldSubmitted: (_) => _submitLogin(),
                          ),

                          const SizedBox(height: 12),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const ForgotPasswordView()),
                                );
                              },
                              child: Text(
                                'Forgot password?',
                                style: GoogleFonts.poppins(
                                  color: AppTheme.primaryPurple,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: authState.isLoading ? null : _submitLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryPurple,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              child: authState.isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      'Sign in',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Footer
                          Center(
                            child: Text(
                              'Developed by Kishan  •  Contact: 9839994285',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
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
