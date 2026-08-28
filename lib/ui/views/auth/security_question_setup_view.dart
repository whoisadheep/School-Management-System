import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class SecurityQuestionSetupView extends ConsumerStatefulWidget {
  const SecurityQuestionSetupView({super.key});

  @override
  ConsumerState<SecurityQuestionSetupView> createState() => _SecurityQuestionSetupViewState();
}

class _SecurityQuestionSetupViewState extends ConsumerState<SecurityQuestionSetupView> {
  final _answerController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String _selectedQuestion = _securityQuestions.first;

  static const List<String> _securityQuestions = [
    'What is the name of your first school?',
    'What is your mother\'s maiden name?',
    'What was the name of your first pet?',
    'In what city were you born?',
    'What is your favorite book?',
    'What was your childhood nickname?',
    'What is the name of your favorite teacher?',
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await ref.read(authProvider.notifier).setSecurityQuestion(
          _selectedQuestion,
          _answerController.text,
        );

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Security question saved successfully!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      // Mark setup as done so the app navigates to dashboard
      ref.read(securityQuestionPendingProvider.notifier).state = false;
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save security question. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _skipSetup() {
    ref.read(securityQuestionPendingProvider.notifier).state = false;
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Container(
              width: 440,
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
                    const Icon(Icons.shield_rounded, color: AppTheme.primaryPurple, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Set Up Security Question',
                      style: GoogleFonts.poppins(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set up a security question so you can reset your password if you ever forget it.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 28),

                    // Security Question Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedQuestion,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Security Question',
                        prefixIcon: const Icon(Icons.help_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _securityQuestions.map((q) {
                        return DropdownMenuItem(
                          value: q,
                          child: Text(
                            q,
                            style: GoogleFonts.poppins(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedQuestion = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Answer Field
                    TextFormField(
                      controller: _answerController,
                      decoration: InputDecoration(
                        labelText: 'Your Answer',
                        hintText: 'Enter your answer',
                        prefixIcon: const Icon(Icons.question_answer_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter an answer.';
                        }
                        if (val.trim().length < 2) {
                          return 'Answer must be at least 2 characters.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Your answer is case-insensitive and will be securely hashed.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Save Security Question',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _skipSetup,
                      child: Text(
                        'Skip for now',
                        style: GoogleFonts.poppins(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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
    );
  }
}

/// Provider to track whether security question setup is pending
final securityQuestionPendingProvider = StateProvider<bool>((ref) => false);
