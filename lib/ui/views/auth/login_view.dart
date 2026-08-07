import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

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

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryPurple, Color(0xFF312581)],
          ),
        ),
        child: Center(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  SvgPicture.asset(
                    'assets/icons/app_icon.svg',
                    width: 64,
                    height: 64,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'SCHOOL MANAGEMENT SYSTEM',
                    style: GoogleFonts.poppins(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'System Administrator Login',
                    style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                  ),

                  const SizedBox(height: 32),

                  if (authState.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              authState.errorMessage!,
                              style: GoogleFonts.poppins(color: AppTheme.error, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'Enter your admin username',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter a username' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter a password' : null,
                    onFieldSubmitted: (_) => _submitLogin(),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _submitLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'LOGIN',
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    'Note: This application runs on a single computer and does not sync data across multiple PCs. All users must log in using this installed copy.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
