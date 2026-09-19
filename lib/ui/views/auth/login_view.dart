import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'forgot_password_view.dart';
import '../../widgets/interactive_blob_mascot.dart';

class AdminLoginView extends ConsumerStatefulWidget {
  const AdminLoginView({super.key});

  @override
  ConsumerState<AdminLoginView> createState() => _AdminLoginViewState();
}

class _AdminLoginViewState extends ConsumerState<AdminLoginView> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  Offset _mousePosition = Offset.zero;
  BlobMascotState _mascotState = BlobMascotState.idle;

  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _usernameFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {
      if (_passwordFocus.hasFocus) {
        _mascotState = _obscurePassword ? BlobMascotState.password : BlobMascotState.peek;
      } else if (_usernameFocus.hasFocus) {
        _mascotState = BlobMascotState.typing;
      } else {
        _mascotState = BlobMascotState.idle;
      }
    });
  }

  Future<void> _submitLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _mascotState = BlobMascotState.typing; 
      });
      
      final success = await ref.read(authProvider.notifier).login(
        _usernameController.text.trim(), 
        _passwordController.text,
      );
      
      if (success) {
        if (mounted) {
          setState(() {
            _mascotState = BlobMascotState.success;
          });
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      } else if (mounted) {
        setState(() {
          _mascotState = BlobMascotState.error;
          _passwordController.clear();
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _onFocusChange(); 
        }
      }
    } else {
       setState(() {
         _mascotState = BlobMascotState.error;
       });
       Future.delayed(const Duration(seconds: 2), () {
         if (mounted) _onFocusChange();
       });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  void _updateMousePosition(PointerEvent details) {
    final size = MediaQuery.of(context).size;
    final screenCenter = Offset(size.width / 2, size.height / 2 - 150); 
    setState(() {
      _mousePosition = Offset(
        details.position.dx - screenCenter.dx,
        details.position.dy - screenCenter.dy,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: MouseRegion(
        onHover: _updateMousePosition,
        child: Stack(
          children: [
            // Animated Aurora/Mesh Gradient Background
            AnimatedBuilder(
              animation: _bgAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _AuroraBackgroundPainter(_bgAnimationController.value),
                  size: Size.infinite,
                );
              },
            ),

            // Content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Blob Mascot
                    InteractiveBlobMascot(
                      mousePosition: _mousePosition,
                      mascotState: _mascotState,
                      size: 160,
                    ),
                    const SizedBox(height: 30),

                    // Glassmorphism Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          width: 440,
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                                blurRadius: 30,
                                spreadRadius: -5,
                              )
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/icons/app_icon.png',
                                      width: 32,
                                      height: 32,
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.school_rounded, color: AppTheme.primaryPurple, size: 32),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Welcome Back 👋',
                                      style: GoogleFonts.poppins(
                                        color: AppTheme.textPrimary,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sign in to continue to Eduvia',
                                  style: GoogleFonts.poppins(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
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
                                  const SizedBox(height: 20),
                                ],

                                TextFormField(
                                  controller: _usernameController,
                                  focusNode: _usernameFocus,
                                  onChanged: (_) {
                                    if (_mascotState != BlobMascotState.typing) {
                                      setState(() => _mascotState = BlobMascotState.typing);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Username',
                                    hintText: 'Enter your admin username',
                                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryPurple),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)), // Colors.grey.shade200 equivalent
                                    ),
                                  ),
                                  validator: (value) => value == null || value.isEmpty ? 'Please enter a username' : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  focusNode: _passwordFocus,
                                  obscureText: _obscurePassword,
                                  onChanged: (_) {
                                    if (_mascotState != BlobMascotState.password && _obscurePassword) {
                                      setState(() => _mascotState = BlobMascotState.password);
                                    } else if (_mascotState != BlobMascotState.peek && !_obscurePassword) {
                                      setState(() => _mascotState = BlobMascotState.peek);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'Enter your password',
                                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryPurple),
                                    filled: true,
                                    fillColor: Colors.white,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        color: AppTheme.primaryPurple,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                          if (!_obscurePassword) {
                                            _mascotState = BlobMascotState.peek;
                                          } else {
                                            _mascotState = BlobMascotState.password;
                                          }
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                                    ),
                                  ),
                                  validator: (value) => value == null || value.isEmpty ? 'Please enter a password' : null,
                                  onFieldSubmitted: (_) => _submitLogin(),
                                ),
                                
                                const SizedBox(height: 32),
                                
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: authState.isLoading ? null : _submitLogin,
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 4,
                                      shadowColor: AppTheme.primaryPurple.withValues(alpha: 0.5),
                                    ),
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [AppTheme.primaryPurple, AppTheme.primaryDark],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: authState.isLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                              )
                                            : Text(
                                                'LOGIN',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 15, 
                                                  fontWeight: FontWeight.bold, 
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const ForgotPasswordView()),
                                    );
                                  },
                                  child: Text(
                                    'Forgot Password?',
                                    style: GoogleFonts.poppins(
                                      color: AppTheme.primaryPurple,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Footer Text
                    Text(
                      '🔒 All local data is securely stored on this computer offline.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.code_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Text(
                          'Developed by Kishan  •  Contact: 9839994285',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuroraBackgroundPainter extends CustomPainter {
  final double animationValue;

  _AuroraBackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    // Background base
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4C1D95)], 
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    _drawOrb(canvas, size, const Color(0xFF8B5CF6).withValues(alpha: 0.4), 0.3, 0.4, 0.2, 1);
    _drawOrb(canvas, size, const Color(0xFF3B82F6).withValues(alpha: 0.3), 0.7, 0.2, 0.25, -1);
    _drawOrb(canvas, size, const Color(0xFFEC4899).withValues(alpha: 0.3), 0.8, 0.8, 0.15, 1.5);
    _drawOrb(canvas, size, const Color(0xFF6366F1).withValues(alpha: 0.4), 0.2, 0.8, 0.2, -1.2);
    _drawOrb(canvas, size, const Color(0xFFD946EF).withValues(alpha: 0.25), 0.5, 0.5, 0.3, 0.8);
  }

  void _drawOrb(Canvas canvas, Size size, Color color, double relX, double relY, double radiusRatio, double speedMulti) {
    double moveX = math.sin(animationValue * 2 * math.pi * speedMulti) * size.width * 0.1;
    double moveY = math.cos(animationValue * 2 * math.pi * speedMulti) * size.height * 0.1;

    final center = Offset(size.width * relX + moveX, size.height * relY + moveY);
    final radius = size.width * radiusRatio;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0.0)],
        stops: const [0.2, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..blendMode = BlendMode.screen;
      
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
