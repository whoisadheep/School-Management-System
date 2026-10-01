import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// Available cute animal characters for empty states.
enum EmptyStateCharacter {
  /// A curious golden puppy wearing a detective cap, sniffing and searching with a magnifying glass.
  detectivePuppy,

  /// A cozy curled-up kitten sleeping on a soft cushion with floating 'Zzz' particles.
  sleepingCat,

  /// A cute wise owl with round spectacles perched on an open book with fluttering wings.
  scholarOwl,
}

/// A delightful, responsive, pure Flutter vector animated empty state widget.
/// Features 60fps hardware-accelerated vector animations, interactive mouse hover,
/// playful reactions, and theme-matched typography.
class CuteAnimalEmptyState extends StatefulWidget {
  final EmptyStateCharacter character;
  final String title;
  final String? subtitle;
  final Widget? action;
  final double size;
  final EdgeInsetsGeometry padding;

  const CuteAnimalEmptyState({
    super.key,
    this.character = EmptyStateCharacter.detectivePuppy,
    required this.title,
    this.subtitle,
    this.action,
    this.size = 140,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
  });

  @override
  State<CuteAnimalEmptyState> createState() => _CuteAnimalEmptyStateState();
}

class _CuteAnimalEmptyStateState extends State<CuteAnimalEmptyState>
    with TickerProviderStateMixin {
  late AnimationController _loopController;
  late AnimationController _blinkController;
  late AnimationController _interactController;

  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    // Primary continuous looping animation (tail wag, breathing, zzz float, head tilt)
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // Natural blinking cycle (triggers blink every ~3.5 seconds)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    // Interactive tap/boop reaction
    _interactController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _loopController.dispose();
    _blinkController.dispose();
    _interactController.dispose();
    super.dispose();
  }

  void _onTap() {
    if (!_interactController.isAnimating) {
      _interactController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: widget.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Interactive Animal Illustration
            MouseRegion(
              hitTestBehavior: HitTestBehavior.opaque,
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onTap,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _loopController,
                    _blinkController,
                    _interactController,
                  ]),
                  builder: (context, _) {
                    final bounce = math.sin(_interactController.value * math.pi) * 8.0;

                    return Transform.translate(
                      offset: Offset(0, -bounce),
                      child: SizedBox(
                        width: widget.size,
                        height: widget.size,
                        child: CustomPaint(
                          painter: _getPainter(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),

            // Subtitle (optional)
            if (widget.subtitle != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],

            // Action Button (optional)
            if (widget.action != null) ...[
              const SizedBox(height: 16),
              widget.action!,
            ],
          ],
        ),
      ),
    );
  }

  CustomPainter _getPainter() {
    final loop = _loopController.value;
    final blinkRaw = (_blinkController.value * 3.6); // 0.0 to 3.6
    final isBlinking = blinkRaw > 3.4; // blink for last 200ms
    final interact = _interactController.value;

    switch (widget.character) {
      case EmptyStateCharacter.detectivePuppy:
        return _DetectivePuppyPainter(
          loopProgress: loop,
          isBlinking: isBlinking,
          interactProgress: interact,
          isHovered: _isHovered,
        );
      case EmptyStateCharacter.sleepingCat:
        return _SleepingCatPainter(
          loopProgress: loop,
          interactProgress: interact,
          isHovered: _isHovered,
        );
      case EmptyStateCharacter.scholarOwl:
        return _ScholarOwlPainter(
          loopProgress: loop,
          isBlinking: isBlinking,
          interactProgress: interact,
          isHovered: _isHovered,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. DETECTIVE PUPPY PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _DetectivePuppyPainter extends CustomPainter {
  final double loopProgress;
  final bool isBlinking;
  final double interactProgress;
  final bool isHovered;

  _DetectivePuppyPainter({
    required this.loopProgress,
    required this.isBlinking,
    required this.interactProgress,
    required this.isHovered,
  });

  @override
  bool hitTest(Offset position) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 140.0;
    final center = Offset(size.width / 2, size.height / 2 + 6 * scale);

    // Palette
    const furGolden = Color(0xFFF7B754);
    const furDark = Color(0xFFE29734);
    const muzzleColor = Color(0xFFFFF6E5);
    const noseColor = Color(0xFF2D1E16);
    const hatColor = Color(0xFF5B45E0); // Eduvia Purple Cap
    const hatBrim = Color(0xFF4532B8);

    // Dynamic animation speeds: wag faster on hover!
    final wagSpeed = isHovered ? 6.0 : 3.0;
    final tailAngle = math.sin(loopProgress * math.pi * 2 * wagSpeed) * 0.45;
    final breathe = math.sin(loopProgress * math.pi * 2) * 2.5 * scale;
    final searchAngle = math.sin(loopProgress * math.pi * 2) * 0.2;

    // ── Soft Ambient Shadow ──
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height - 8 * scale),
        width: 90 * scale,
        height: 14 * scale,
      ),
      shadowPaint,
    );

    // ── Wagging Tail (Behind Body) ──
    final tailStart = Offset(center.dx + 30 * scale, center.dy + 15 * scale);
    canvas.save();
    canvas.translate(tailStart.dx, tailStart.dy);
    canvas.rotate(tailAngle);
    final tailPaint = Paint()
      ..color = furDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * scale
      ..strokeCap = StrokeCap.round;
    final tailPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(16 * scale, -10 * scale, 24 * scale, -24 * scale);
    canvas.drawPath(tailPath, tailPaint);
    canvas.restore();

    // ── Puppy Body ──
    final bodyRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + 14 * scale + breathe * 0.5),
      width: 76 * scale,
      height: 60 * scale,
    );
    final bodyPaint = Paint()..color = furGolden;
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(28 * scale)), bodyPaint);

    // ── Left & Right Floppy Ears ──
    final earY = center.dy - 20 * scale + breathe;
    final earWiggle = math.sin(loopProgress * math.pi * 4) * (isHovered ? 4.0 : 1.5) * scale;

    void drawEar({required double x, required bool isLeft}) {
      final earPaint = Paint()..color = furDark;
      final earPath = Path()
        ..moveTo(x, earY)
        ..quadraticBezierTo(
          isLeft ? x - 22 * scale - earWiggle : x + 22 * scale + earWiggle,
          earY + 12 * scale,
          isLeft ? x - 18 * scale : x + 18 * scale,
          earY + 36 * scale,
        )
        ..quadraticBezierTo(
          isLeft ? x - 8 * scale : x + 8 * scale,
          earY + 38 * scale,
          x,
          earY + 16 * scale,
        )
        ..close();
      canvas.drawPath(earPath, earPaint);
    }

    drawEar(x: center.dx - 32 * scale, isLeft: true);
    drawEar(x: center.dx + 32 * scale, isLeft: false);

    // ── Puppy Head ──
    final headCenter = Offset(center.dx, center.dy - 12 * scale + breathe);
    final headPaint = Paint()..color = furGolden;
    canvas.drawCircle(headCenter, 36 * scale, headPaint);

    // ── Detective Deerstalker Cap ──
    final hatY = headCenter.dy - 30 * scale;
    final hatPaint = Paint()..color = hatColor;
    final hatBrimPaint = Paint()..color = hatBrim;

    // Cap dome
    final hatRect = Rect.fromCenter(
      center: Offset(headCenter.dx, hatY + 6 * scale),
      width: 54 * scale,
      height: 32 * scale,
    );
    canvas.drawArc(hatRect, math.pi, math.pi, true, hatPaint);

    // Front Visor
    final visorPath = Path()
      ..moveTo(headCenter.dx - 26 * scale, hatY + 8 * scale)
      ..quadraticBezierTo(headCenter.dx, hatY + 16 * scale, headCenter.dx + 26 * scale, hatY + 8 * scale)
      ..lineTo(headCenter.dx + 22 * scale, hatY + 4 * scale)
      ..quadraticBezierTo(headCenter.dx, hatY + 10 * scale, headCenter.dx - 22 * scale, hatY + 4 * scale)
      ..close();
    canvas.drawPath(visorPath, hatBrimPaint);

    // Cap Bow / Button on top
    canvas.drawCircle(Offset(headCenter.dx, hatY - 8 * scale), 4.5 * scale, hatBrimPaint);

    // ── Cheeks & Blush ──
    final blushPaint = Paint()..color = const Color(0x33FF69B4);
    canvas.drawCircle(Offset(headCenter.dx - 24 * scale, headCenter.dy + 8 * scale), 7 * scale, blushPaint);
    canvas.drawCircle(Offset(headCenter.dx + 24 * scale, headCenter.dy + 8 * scale), 7 * scale, blushPaint);

    // ── Snout / Muzzle ──
    final muzzleCenter = Offset(headCenter.dx, headCenter.dy + 10 * scale);
    final muzzlePaint = Paint()..color = muzzleColor;
    canvas.drawOval(
      Rect.fromCenter(center: muzzleCenter, width: 38 * scale, height: 26 * scale),
      muzzlePaint,
    );

    // ── Nose ──
    final noseCenter = Offset(headCenter.dx, muzzleCenter.dy - 4 * scale);
    final nosePaint = Paint()..color = noseColor;
    final nosePath = Path()
      ..moveTo(noseCenter.dx - 6 * scale, noseCenter.dy - 2 * scale)
      ..quadraticBezierTo(noseCenter.dx, noseCenter.dy - 4 * scale, noseCenter.dx + 6 * scale, noseCenter.dy - 2 * scale)
      ..quadraticBezierTo(noseCenter.dx, noseCenter.dy + 6 * scale, noseCenter.dx - 6 * scale, noseCenter.dy - 2 * scale);
    canvas.drawPath(nosePath, nosePaint);

    // Nose highlight
    final noseHighlight = Paint()..color = Colors.white.withValues(alpha: 0.6);
    canvas.drawCircle(Offset(noseCenter.dx - 2 * scale, noseCenter.dy - 1 * scale), 1.2 * scale, noseHighlight);

    // ── Mouth & Cute Tongue ──
    final mouthPaint = Paint()
      ..color = noseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path()
      ..moveTo(headCenter.dx - 5 * scale, muzzleCenter.dy + 5 * scale)
      ..quadraticBezierTo(headCenter.dx, muzzleCenter.dy + 9 * scale, headCenter.dx + 5 * scale, muzzleCenter.dy + 5 * scale);
    canvas.drawPath(mouthPath, mouthPaint);

    if (isHovered) {
      // Cute pink tongue peeking out!
      final tonguePaint = Paint()..color = const Color(0xFFFF7675);
      final tonguePath = Path()
        ..moveTo(headCenter.dx - 3 * scale, muzzleCenter.dy + 7 * scale)
        ..quadraticBezierTo(headCenter.dx, muzzleCenter.dy + 13 * scale, headCenter.dx + 3 * scale, muzzleCenter.dy + 7 * scale)
        ..close();
      canvas.drawPath(tonguePath, tonguePaint);
    }

    // ── Eyes ──
    final eyeY = headCenter.dy - 4 * scale;
    final eyeDistance = 14 * scale;

    void drawEye(double x) {
      if (isBlinking) {
        canvas.drawLine(
          Offset(x - 5 * scale, eyeY),
          Offset(x + 5 * scale, eyeY),
          mouthPaint,
        );
        return;
      }

      // Eye White & Dark Pupil
      final pupilPaint = Paint()..color = noseColor;
      canvas.drawCircle(Offset(x, eyeY), 5.5 * scale, pupilPaint);

      // Cute white catchlights
      final sparkle = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(x - 1.8 * scale, eyeY - 1.8 * scale), 2 * scale, sparkle);
      canvas.drawCircle(Offset(x + 1.5 * scale, eyeY + 1.5 * scale), 0.9 * scale, sparkle);
    }

    drawEye(headCenter.dx - eyeDistance);
    drawEye(headCenter.dx + eyeDistance);

    // ── Searching Magnifying Glass in Paw ──
    canvas.save();
    final glassPivot = Offset(headCenter.dx + 28 * scale, headCenter.dy + 22 * scale);
    canvas.translate(glassPivot.dx, glassPivot.dy);
    canvas.rotate(searchAngle);

    // Handle
    final handlePaint = Paint()
      ..color = const Color(0xFF8D6E63)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, 0), Offset(14 * scale, 16 * scale), handlePaint);

    // Glass Rim
    final rimCenter = Offset(-8 * scale, -8 * scale);
    final rimPaint = Paint()
      ..color = const Color(0xFFFFD700) // Shiny Brass Rim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * scale;
    canvas.drawCircle(rimCenter, 14 * scale, rimPaint);

    // Glass Lens with soft blue-purple gleam
    final lensPaint = Paint()
      ..color = const Color(0x337B68EE)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(rimCenter, 13 * scale, lensPaint);

    // Lens reflection streak
    final gleamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: rimCenter, radius: 9 * scale),
      -math.pi * 0.8,
      math.pi * 0.5,
      false,
      gleamPaint,
    );

    // Puppy Paw holding the handle
    final pawPaint = Paint()..color = furGolden;
    canvas.drawCircle(Offset(4 * scale, 4 * scale), 6.5 * scale, pawPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DetectivePuppyPainter oldDelegate) {
    return oldDelegate.loopProgress != loopProgress ||
        oldDelegate.isBlinking != isBlinking ||
        oldDelegate.interactProgress != interactProgress ||
        oldDelegate.isHovered != isHovered;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. SLEEPING CAT PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _SleepingCatPainter extends CustomPainter {
  final double loopProgress;
  final double interactProgress;
  final bool isHovered;

  _SleepingCatPainter({
    required this.loopProgress,
    required this.interactProgress,
    required this.isHovered,
  });

  @override
  bool hitTest(Offset position) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 140.0;
    final center = Offset(size.width / 2, size.height / 2 + 10 * scale);

    // Breathing pulse
    final breathe = math.sin(loopProgress * math.pi * 2) * 2.8 * scale;
    final tailTwitch = math.sin(loopProgress * math.pi * 4) * 0.15;

    // Palette
    const cushionColor = Color(0xFFEDE9FE);
    const cushionBorder = Color(0xFFDDD6FE);
    const catFur = Color(0xFFFFB070); // Warm cozy ginger
    const catFurDark = Color(0xFFEA8A3B);
    const innerEar = Color(0xFFFFB6C1);

    // ── 1. Soft Ambient Shadow ──
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 26 * scale), width: 115 * scale, height: 20 * scale),
      shadowPaint,
    );

    // ── 2. Cozy Cushion ──
    final cushionPaint = Paint()..color = cushionColor;
    final cushionBorderPaint = Paint()
      ..color = cushionBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scale;

    final cushionRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + 14 * scale),
      width: 104 * scale,
      height: 44 * scale,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(cushionRect, Radius.circular(22 * scale)), cushionPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(cushionRect, Radius.circular(22 * scale)), cushionBorderPaint);

    // ── 3. Sleeping Cat Body (Curled up circle) ──
    final bodyCenter = Offset(center.dx, center.dy + 4 * scale + breathe * 0.4);
    final bodyPaint = Paint()..color = catFur;

    // Main sleeping curled body
    canvas.drawOval(
      Rect.fromCenter(
        center: bodyCenter,
        width: 78 * scale,
        height: (58 * scale) + breathe,
      ),
      bodyPaint,
    );

    // Cat Back Stripes
    final stripePaint = Paint()
      ..color = catFurDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scale
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCenter(center: Offset(bodyCenter.dx + 4 * scale, bodyCenter.dy - 6 * scale), width: 34 * scale, height: 26 * scale),
      -0.4,
      0.8,
      false,
      stripePaint,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(bodyCenter.dx + 16 * scale, bodyCenter.dy - 4 * scale), width: 28 * scale, height: 22 * scale),
      -0.4,
      0.8,
      false,
      stripePaint,
    );

    // ── 4. Tail Wrapped Around ──
    canvas.save();
    canvas.translate(bodyCenter.dx + 30 * scale, bodyCenter.dy + 8 * scale);
    canvas.rotate(tailTwitch);
    final tailPaint = Paint()
      ..color = catFurDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * scale
      ..strokeCap = StrokeCap.round;
    final tailPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(14 * scale, -10 * scale, 6 * scale, -22 * scale);
    canvas.drawPath(tailPath, tailPaint);
    canvas.restore();

    // ── 5. Cat Head ──
    final headCenter = Offset(bodyCenter.dx - 22 * scale, bodyCenter.dy + 2 * scale);
    final headPaint = Paint()..color = catFur;
    canvas.drawCircle(headCenter, 22 * scale, headPaint);

    // Pointy Ears
    void drawEar({required double x, required bool isLeft}) {
      final earPaint = Paint()..color = catFur;
      final earPath = Path()
        ..moveTo(x - 6 * scale, headCenter.dy - 16 * scale)
        ..lineTo(x, headCenter.dy - 28 * scale)
        ..lineTo(x + 6 * scale, headCenter.dy - 14 * scale)
        ..close();
      canvas.drawPath(earPath, earPaint);

      final innerPaint = Paint()..color = innerEar;
      final innerPath = Path()
        ..moveTo(x - 3 * scale, headCenter.dy - 16 * scale)
        ..lineTo(x, headCenter.dy - 24 * scale)
        ..lineTo(x + 3 * scale, headCenter.dy - 15 * scale)
        ..close();
      canvas.drawPath(innerPath, innerPaint);
    }

    drawEar(x: headCenter.dx - 8 * scale, isLeft: true);
    drawEar(x: headCenter.dx + 8 * scale, isLeft: false);

    // ── 6. Sleeping Happy Eyes (^ ^) ──
    final eyePaint = Paint()
      ..color = const Color(0xFF4A3428)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round;

    if (isHovered) {
      // One eye peeks open!
      final peekEye = Path()
        ..moveTo(headCenter.dx - 12 * scale, headCenter.dy - 1 * scale)
        ..quadraticBezierTo(headCenter.dx - 8 * scale, headCenter.dy - 6 * scale, headCenter.dx - 4 * scale, headCenter.dy - 1 * scale);
      canvas.drawPath(peekEye, eyePaint);
      canvas.drawCircle(Offset(headCenter.dx - 8 * scale, headCenter.dy - 2 * scale), 2.0 * scale, Paint()..color = const Color(0xFF4A3428));

      // Right eye still shut
      final sleepEye = Path()
        ..moveTo(headCenter.dx + 4 * scale, headCenter.dy - 2 * scale)
        ..quadraticBezierTo(headCenter.dx + 8 * scale, headCenter.dy + 3 * scale, headCenter.dx + 12 * scale, headCenter.dy - 2 * scale);
      canvas.drawPath(sleepEye, eyePaint);
    } else {
      // Both eyes sweetly shut
      final leftEye = Path()
        ..moveTo(headCenter.dx - 12 * scale, headCenter.dy - 2 * scale)
        ..quadraticBezierTo(headCenter.dx - 8 * scale, headCenter.dy + 3 * scale, headCenter.dx - 4 * scale, headCenter.dy - 2 * scale);
      final rightEye = Path()
        ..moveTo(headCenter.dx + 4 * scale, headCenter.dy - 2 * scale)
        ..quadraticBezierTo(headCenter.dx + 8 * scale, headCenter.dy + 3 * scale, headCenter.dx + 12 * scale, headCenter.dy - 2 * scale);
      canvas.drawPath(leftEye, eyePaint);
      canvas.drawPath(rightEye, eyePaint);
    }

    // Tiny Pink Nose & Blush
    final nosePaint = Paint()..color = const Color(0xFFFF9AA2);
    canvas.drawCircle(Offset(headCenter.dx, headCenter.dy + 4 * scale), 2.2 * scale, nosePaint);

    final blushPaint = Paint()..color = const Color(0x33FF69B4);
    canvas.drawCircle(Offset(headCenter.dx - 14 * scale, headCenter.dy + 4 * scale), 4.5 * scale, blushPaint);
    canvas.drawCircle(Offset(headCenter.dx + 14 * scale, headCenter.dy + 4 * scale), 4.5 * scale, blushPaint);

    // Whiskers
    final whiskerPaint = Paint()
      ..color = const Color(0x664A3428)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * scale
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(headCenter.dx - 8 * scale, headCenter.dy + 6 * scale), Offset(headCenter.dx - 22 * scale, headCenter.dy + 5 * scale), whiskerPaint);
    canvas.drawLine(Offset(headCenter.dx - 8 * scale, headCenter.dy + 8 * scale), Offset(headCenter.dx - 20 * scale, headCenter.dy + 10 * scale), whiskerPaint);
    canvas.drawLine(Offset(headCenter.dx + 8 * scale, headCenter.dy + 6 * scale), Offset(headCenter.dx + 22 * scale, headCenter.dy + 5 * scale), whiskerPaint);
    canvas.drawLine(Offset(headCenter.dx + 8 * scale, headCenter.dy + 8 * scale), Offset(headCenter.dx + 20 * scale, headCenter.dy + 10 * scale), whiskerPaint);

    // ── 7. Floating Animated "Z z z" Particles ──
    void drawZ({required double t, required double startX, required double startY, required double fontSize}) {
      final progress = (loopProgress + t) % 1.0;
      final y = startY - (progress * 38.0 * scale);
      final x = startX + (math.sin(progress * math.pi * 2) * 8.0 * scale);
      final alpha = (math.sin(progress * math.pi) * 0.85).clamp(0.0, 1.0);

      final textSpan = TextSpan(
        text: 'z',
        style: GoogleFonts.poppins(
          fontSize: fontSize * scale,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryPurple.withValues(alpha: alpha),
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x, y));
    }

    drawZ(t: 0.0, startX: headCenter.dx + 16 * scale, startY: headCenter.dy - 10 * scale, fontSize: 13);
    drawZ(t: 0.35, startX: headCenter.dx + 24 * scale, startY: headCenter.dy - 14 * scale, fontSize: 16);
    drawZ(t: 0.70, startX: headCenter.dx + 32 * scale, startY: headCenter.dy - 18 * scale, fontSize: 19);
  }

  @override
  bool shouldRepaint(covariant _SleepingCatPainter oldDelegate) {
    return oldDelegate.loopProgress != loopProgress ||
        oldDelegate.interactProgress != interactProgress ||
        oldDelegate.isHovered != isHovered;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. SCHOLAR OWL PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _ScholarOwlPainter extends CustomPainter {
  final double loopProgress;
  final bool isBlinking;
  final double interactProgress;
  final bool isHovered;

  _ScholarOwlPainter({
    required this.loopProgress,
    required this.isBlinking,
    required this.interactProgress,
    required this.isHovered,
  });

  @override
  bool hitTest(Offset position) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 140.0;
    final center = Offset(size.width / 2, size.height / 2 + 8 * scale);

    final breathe = math.sin(loopProgress * math.pi * 2) * 2.0 * scale;
    final headTilt = math.sin(loopProgress * math.pi * 2) * 0.08;
    final wingFlap = isHovered ? math.sin(loopProgress * math.pi * 8) * 0.25 : 0.0;

    // Palette
    const owlPurple = Color(0xFF6C57F5);
    const owlDark = Color(0xFF4C3BCF);
    const bellyColor = Color(0xFFEDE9FE);
    const beakGold = Color(0xFFFFB800);
    const glassesColor = Color(0xFF2A2A38);

    // ── 1. Open Book / Branch Perch ──
    final bookCenter = Offset(center.dx, center.dy + 34 * scale);
    final bookPaint = Paint()..color = const Color(0xFFE2E8F0);
    final bookSpinePaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scale;

    final leftPage = Path()
      ..moveTo(bookCenter.dx, bookCenter.dy)
      ..quadraticBezierTo(bookCenter.dx - 22 * scale, bookCenter.dy - 4 * scale, bookCenter.dx - 42 * scale, bookCenter.dy + 4 * scale)
      ..lineTo(bookCenter.dx - 42 * scale, bookCenter.dy + 12 * scale)
      ..quadraticBezierTo(bookCenter.dx - 22 * scale, bookCenter.dy + 4 * scale, bookCenter.dx, bookCenter.dy + 8 * scale)
      ..close();

    final rightPage = Path()
      ..moveTo(bookCenter.dx, bookCenter.dy)
      ..quadraticBezierTo(bookCenter.dx + 22 * scale, bookCenter.dy - 4 * scale, bookCenter.dx + 42 * scale, bookCenter.dy + 4 * scale)
      ..lineTo(bookCenter.dx + 42 * scale, bookCenter.dy + 12 * scale)
      ..quadraticBezierTo(bookCenter.dx + 22 * scale, bookCenter.dy + 4 * scale, bookCenter.dx, bookCenter.dy + 8 * scale)
      ..close();

    canvas.drawPath(leftPage, bookPaint);
    canvas.drawPath(leftPage, bookSpinePaint);
    canvas.drawPath(rightPage, bookPaint);
    canvas.drawPath(rightPage, bookSpinePaint);

    // Book cover base
    final coverPaint = Paint()..color = AppTheme.primaryPurple;
    final coverPath = Path()
      ..moveTo(bookCenter.dx - 44 * scale, bookCenter.dy + 13 * scale)
      ..quadraticBezierTo(bookCenter.dx, bookCenter.dy + 19 * scale, bookCenter.dx + 44 * scale, bookCenter.dy + 13 * scale)
      ..lineTo(bookCenter.dx + 44 * scale, bookCenter.dy + 16 * scale)
      ..quadraticBezierTo(bookCenter.dx, bookCenter.dy + 22 * scale, bookCenter.dx - 44 * scale, bookCenter.dy + 16 * scale)
      ..close();
    canvas.drawPath(coverPath, coverPaint);

    // ── 2. Owl Body ──
    final bodyCenter = Offset(center.dx, center.dy + 8 * scale + breathe * 0.5);
    final bodyPaint = Paint()..color = owlPurple;

    canvas.drawOval(
      Rect.fromCenter(center: bodyCenter, width: 68 * scale, height: 62 * scale),
      bodyPaint,
    );

    // Belly (Soft Lavender)
    final bellyPaint = Paint()..color = bellyColor;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyCenter.dx, bodyCenter.dy + 8 * scale), width: 44 * scale, height: 38 * scale),
      bellyPaint,
    );

    // Belly Feather Flecks
    final fleckPaint = Paint()
      ..color = owlPurple.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale
      ..strokeCap = StrokeCap.round;

    void drawFleck(double x, double y) {
      final fleck = Path()
        ..moveTo(x - 3 * scale, y)
        ..quadraticBezierTo(x, y + 2.5 * scale, x + 3 * scale, y);
      canvas.drawPath(fleck, fleckPaint);
    }

    drawFleck(bodyCenter.dx - 8 * scale, bodyCenter.dy + 2 * scale);
    drawFleck(bodyCenter.dx + 8 * scale, bodyCenter.dy + 2 * scale);
    drawFleck(bodyCenter.dx, bodyCenter.dy + 9 * scale);
    drawFleck(bodyCenter.dx - 10 * scale, bodyCenter.dy + 15 * scale);
    drawFleck(bodyCenter.dx + 10 * scale, bodyCenter.dy + 15 * scale);

    // ── 3. Wings (with hover flap) ──
    void drawWing({required double x, required bool isLeft}) {
      canvas.save();
      canvas.translate(x, bodyCenter.dy - 6 * scale);
      canvas.rotate(isLeft ? -wingFlap : wingFlap);
      final wingPaint = Paint()..color = owlDark;
      final wingPath = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(isLeft ? -16 * scale : 16 * scale, 12 * scale, isLeft ? -10 * scale : 10 * scale, 30 * scale)
        ..quadraticBezierTo(0, 32 * scale, 0, 0)
        ..close();
      canvas.drawPath(wingPath, wingPaint);
      canvas.restore();
    }

    drawWing(x: bodyCenter.dx - 30 * scale, isLeft: true);
    drawWing(x: bodyCenter.dx + 30 * scale, isLeft: false);

    // ── 4. Owl Head (with gentle tilt) ──
    final headCenter = Offset(center.dx, center.dy - 16 * scale + breathe);
    canvas.save();
    canvas.translate(headCenter.dx, headCenter.dy);
    canvas.rotate(headTilt);

    // Head base
    final headPaint = Paint()..color = owlPurple;
    canvas.drawCircle(Offset.zero, 30 * scale, headPaint);

    // Ear Tufts
    final tuftPaint = Paint()..color = owlDark;
    final leftTuft = Path()
      ..moveTo(-16 * scale, -22 * scale)
      ..lineTo(-24 * scale, -38 * scale)
      ..lineTo(-8 * scale, -28 * scale)
      ..close();
    final rightTuft = Path()
      ..moveTo(16 * scale, -22 * scale)
      ..lineTo(24 * scale, -38 * scale)
      ..lineTo(8 * scale, -28 * scale)
      ..close();
    canvas.drawPath(leftTuft, tuftPaint);
    canvas.drawPath(rightTuft, tuftPaint);

    // ── 5. Big Round Spectacles & Eyes ──
    final eyeY = -4 * scale;
    final eyeSpacing = 13 * scale;

    void drawScholarEye(double x) {
      // Golden Eye Background
      final eyeBg = Paint()..color = const Color(0xFFFFE082);
      canvas.drawCircle(Offset(x, eyeY), 12 * scale, eyeBg);

      if (isBlinking) {
        final blinkPaint = Paint()
          ..color = glassesColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * scale
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x - 7 * scale, eyeY), Offset(x + 7 * scale, eyeY), blinkPaint);
      } else {
        // Pupil
        final pupilPaint = Paint()..color = glassesColor;
        canvas.drawCircle(Offset(x, eyeY), 6.5 * scale, pupilPaint);

        // Sparkle
        final sparkle = Paint()..color = Colors.white;
        canvas.drawCircle(Offset(x - 2 * scale, eyeY - 2 * scale), 2.2 * scale, sparkle);
      }

      // Round Spectacle Frame
      final framePaint = Paint()
        ..color = glassesColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * scale;
      canvas.drawCircle(Offset(x, eyeY), 13 * scale, framePaint);
    }

    drawScholarEye(-eyeSpacing);
    drawScholarEye(eyeSpacing);

    // Spectacles Bridge
    final bridgePaint = Paint()
      ..color = glassesColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * scale;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(0, eyeY - 2 * scale), width: 8 * scale, height: 6 * scale),
      math.pi,
      math.pi,
      false,
      bridgePaint,
    );

    // ── 6. Beak ──
    final beakPaint = Paint()..color = beakGold;
    final beakPath = Path()
      ..moveTo(-5 * scale, eyeY + 4 * scale)
      ..lineTo(5 * scale, eyeY + 4 * scale)
      ..lineTo(0, eyeY + 14 * scale)
      ..close();
    canvas.drawPath(beakPath, beakPaint);

    // Soft Cheeks
    final blushPaint = Paint()..color = const Color(0x33FF69B4);
    canvas.drawCircle(Offset(-22 * scale, eyeY + 10 * scale), 5 * scale, blushPaint);
    canvas.drawCircle(Offset(22 * scale, eyeY + 10 * scale), 5 * scale, blushPaint);

    canvas.restore();

    // ── 7. Claws on Book ──
    final clawPaint = Paint()..color = beakGold;
    void drawClaws(double x) {
      canvas.drawCircle(Offset(x - 3 * scale, bookCenter.dy - 1 * scale), 2.5 * scale, clawPaint);
      canvas.drawCircle(Offset(x, bookCenter.dy - 1 * scale), 2.5 * scale, clawPaint);
      canvas.drawCircle(Offset(x + 3 * scale, bookCenter.dy - 1 * scale), 2.5 * scale, clawPaint);
    }

    drawClaws(center.dx - 12 * scale);
    drawClaws(center.dx + 12 * scale);

    // ── 8. Floating Wisdom Sparkles ──
    final sparklePaint = Paint()..color = const Color(0xFFFFD700);
    void drawSparkle(double x, double y, double sz, double phase) {
      final pulse = (math.sin(loopProgress * math.pi * 2 + phase) * 0.5 + 0.5) * sz;
      if (pulse > 0.5) {
        canvas.drawCircle(Offset(x, y), pulse * scale, sparklePaint);
      }
    }

    drawSparkle(center.dx - 38 * scale, center.dy - 34 * scale, 2.2, 0.0);
    drawSparkle(center.dx + 36 * scale, center.dy - 36 * scale, 2.8, 1.8);
    drawSparkle(center.dx + 44 * scale, center.dy - 14 * scale, 1.8, 3.2);
  }

  @override
  bool shouldRepaint(covariant _ScholarOwlPainter oldDelegate) {
    return oldDelegate.loopProgress != loopProgress ||
        oldDelegate.isBlinking != isBlinking ||
        oldDelegate.interactProgress != interactProgress ||
        oldDelegate.isHovered != isHovered;
  }
}
