import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';

/// Controller to drive the interactive mascot reactions from text inputs & form events.
class InteractiveLoginMascotController {
  InteractiveLoginMascotState? _state;

  void attach(InteractiveLoginMascotState state) {
    _state = state;
  }

  void detach() {
    _state = null;
  }

  /// Sets whether the mascot is actively looking down at an input field.
  void setChecking(bool isChecking) => _state?.setChecking(isChecking);

  /// Sets the horizontal look position (0.0 to 100.0) corresponding to cursor/text length.
  void setLook(double look) => _state?.setLook(look);

  /// Sets whether the mascot covers its eyes with its paws (e.g. for password entry).
  void setHandsUp(bool isHandsUp) => _state?.setHandsUp(isHandsUp);

  /// Sets whether the mascot peeks through one paw (e.g. when show password is toggled).
  void setPeeking(bool isPeeking) => _state?.setPeeking(isPeeking);

  /// Sets the global mouse cursor position so the mascot tracks the mouse anywhere on the screen.
  void setGlobalMousePosition(Offset globalPosition) =>
      _state?.setGlobalMousePosition(globalPosition);

  /// Resets the gaze to center when the mouse leaves the window.
  void resetGaze() => _state?.resetGaze();

  /// Triggers a celebratory/success reaction.
  void triggerSuccess() => _state?.triggerSuccess();

  /// Triggers a disappointed/shake reaction for incorrect login.
  void triggerFail() => _state?.triggerFail();
}

/// A delightful, 100% pure Flutter native interactive Bear mascot.
/// Features real-time mouse gaze tracking, animated paws covering eyes, peeking, ear wiggles, and reactions.
class InteractiveLoginMascot extends StatefulWidget {
  final InteractiveLoginMascotController? controller;
  final double size;

  const InteractiveLoginMascot({
    super.key,
    this.controller,
    this.size = 170,
  });

  @override
  State<InteractiveLoginMascot> createState() => InteractiveLoginMascotState();
}

class InteractiveLoginMascotState extends State<InteractiveLoginMascot>
    with TickerProviderStateMixin {
  // Idle breathing controller
  late AnimationController _breatheController;
  late Animation<double> _breatheAnim;

  // Hands up / cover eyes controller
  late AnimationController _handsController;
  late Animation<double> _handsAnim;

  // Reaction controller (success bounce / fail shake)
  late AnimationController _reactionController;
  late Animation<double> _reactionAnim;

  // Ear wiggle on hover or click
  late AnimationController _wiggleController;
  late Animation<double> _wiggleAnim;

  bool _isChecking = false;
  double _lookProgress = 0.5; // 0.0 (left) to 1.0 (right), 0.5 center
  bool _isHandsUp = false;
  bool _isPeeking = false;
  bool _isSuccess = false;
  bool _isFail = false;
  bool _isHovered = false;

  // Mouse gaze direction vector relative to mascot center
  Offset _mouseGaze = Offset.zero;

  // Natural blink timer
  Timer? _blinkTimer;
  Timer? _boopTimer;
  Timer? _reactionTimer;
  bool _isBlinking = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(this);

    // Idle breathing (gentle 2.4s loop)
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _breatheAnim = CurvedAnimation(
      parent: _breatheController,
      curve: Curves.easeInOutSine,
    );

    // Hands movement (smooth slide up/down)
    _handsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _handsAnim = CurvedAnimation(
      parent: _handsController,
      curve: Curves.easeOutBack,
    );

    // Reactions (bounce or shake)
    _reactionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _reactionAnim = CurvedAnimation(
      parent: _reactionController,
      curve: Curves.easeInOutCubic,
    );

    // Ear wiggle on hover
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _wiggleAnim = CurvedAnimation(
      parent: _wiggleController,
      curve: Curves.easeOutCubic,
    );

    _startBlinkTimer();
  }

  void _startBlinkTimer() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 3800), (_) {
      if (!mounted || _isHandsUp) return;
      setState(() => _isBlinking = true);
      _boopTimer?.cancel();
      _boopTimer = Timer(const Duration(milliseconds: 140), () {
        if (mounted) {
          setState(() => _isBlinking = false);
        }
      });
    });
  }

  @override
  void didUpdateWidget(InteractiveLoginMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _blinkTimer?.cancel();
    _boopTimer?.cancel();
    _reactionTimer?.cancel();
    _breatheController.dispose();
    _handsController.dispose();
    _reactionController.dispose();
    _wiggleController.dispose();
    super.dispose();
  }

  void setChecking(bool isChecking) {
    if (_isChecking != isChecking && mounted) {
      setState(() {
        _isChecking = isChecking;
      });
    }
  }

  void setLook(double look) {
    if (mounted) {
      setState(() {
        _lookProgress = (look / 100.0).clamp(0.0, 1.0);
      });
    }
  }

  void setHandsUp(bool isHandsUp) {
    _isHandsUp = isHandsUp;
    if (isHandsUp) {
      _isPeeking = false;
      _handsController.forward();
    } else {
      _handsController.reverse();
    }
    if (mounted) setState(() {});
  }

  void setPeeking(bool isPeeking) {
    if (_isPeeking != isPeeking && mounted) {
      setState(() {
        _isPeeking = isPeeking;
      });
    }
  }

  void setGlobalMousePosition(Offset globalPosition) {
    if (!mounted || (_isHandsUp && !_isPeeking)) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final localPos = renderBox.globalToLocal(globalPosition);
      final center = Offset(renderBox.size.width / 2, renderBox.size.height / 2);
      final delta = localPos - center;
      final distance = delta.distance;

      if (distance > 0.5) {
        final angle = math.atan2(delta.dy, delta.dx);
        const maxShift = 5.5;
        final shiftDistance = math.min(maxShift, math.max(1.5, distance * 0.035));
        final targetGaze = Offset(
          math.cos(angle) * shiftDistance,
          math.sin(angle) * shiftDistance,
        );
        setState(() {
          _mouseGaze = targetGaze;
        });
      }
    }
  }

  void resetGaze() {
    if (mounted) {
      setState(() {
        _mouseGaze = Offset.zero;
        _isHovered = false;
      });
    }
  }

  void triggerSuccess() {
    if (!mounted) return;
    setState(() {
      _isSuccess = true;
      _isFail = false;
    });
    _reactionController.forward(from: 0).then((_) {
      if (mounted) {
        _reactionTimer?.cancel();
        _reactionTimer = Timer(const Duration(seconds: 1), () {
          if (mounted) setState(() => _isSuccess = false);
        });
      }
    });
  }

  void triggerFail() {
    if (!mounted) return;
    setState(() {
      _isFail = true;
      _isSuccess = false;
    });
    _reactionController.forward(from: 0).then((_) {
      if (mounted) {
        _reactionTimer?.cancel();
        _reactionTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _isFail = false);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.opaque,
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
        _wiggleController.forward(from: 0);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
      },
      onHover: (event) {
        final center = Offset(widget.size / 2, widget.size / 2);
        final delta = event.localPosition - center;
        final distance = delta.distance;
        if (distance > 0.5) {
          final angle = math.atan2(delta.dy, delta.dx);
          final shift = math.min(5.5, math.max(1.5, distance * 0.05));
          setState(() {
            _mouseGaze = Offset(math.cos(angle) * shift, math.sin(angle) * shift);
          });
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Boop reaction on click!
          _wiggleController.forward(from: 0);
          setState(() => _isBlinking = true);
          _boopTimer?.cancel();
          _boopTimer = Timer(const Duration(milliseconds: 180), () {
            if (mounted) setState(() => _isBlinking = false);
          });
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_breatheAnim, _handsAnim, _reactionAnim, _wiggleAnim]),
          builder: (context, _) {
            double bounceOffset = 0.0;
            double shakeOffset = 0.0;

            if (_isSuccess) {
              bounceOffset = -math.sin(_reactionAnim.value * math.pi * 2) * 14.0;
            } else if (_isFail) {
              shakeOffset =
                  math.sin(_reactionAnim.value * math.pi * 6) * (1.0 - _reactionAnim.value) * 12.0;
            }

            return Transform.translate(
              offset: Offset(shakeOffset, bounceOffset),
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _BearMascotPainter(
                    breatheProgress: _breatheAnim.value,
                    handsProgress: _handsAnim.value,
                    wiggleProgress: _wiggleAnim.value,
                    mouseGaze: _mouseGaze,
                    lookProgress: _lookProgress,
                    isChecking: _isChecking,
                    isHandsUp: _isHandsUp,
                    isPeeking: _isPeeking,
                    isBlinking: _isBlinking,
                    isSuccess: _isSuccess,
                    isFail: _isFail,
                    isHovered: _isHovered,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Custom painter that renders the cute bear mascot with vector precision.
class _BearMascotPainter extends CustomPainter {
  final double breatheProgress;
  final double handsProgress;
  final double wiggleProgress;
  final Offset mouseGaze;
  final double lookProgress; // 0.0 (left) to 1.0 (right)
  final bool isChecking;
  final bool isHandsUp;
  final bool isPeeking;
  final bool isBlinking;
  final bool isSuccess;
  final bool isFail;
  final bool isHovered;

  _BearMascotPainter({
    required this.breatheProgress,
    required this.handsProgress,
    required this.wiggleProgress,
    required this.mouseGaze,
    required this.lookProgress,
    required this.isChecking,
    required this.isHandsUp,
    required this.isPeeking,
    required this.isBlinking,
    required this.isSuccess,
    required this.isFail,
    required this.isHovered,
  });

  @override
  bool hitTest(Offset position) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final scale = size.width / 180.0;

    // Palette
    const furColor = Color(0xFF5B45E0); // Eduvia Purple Bear Fur
    const furDark = Color(0xFF4532B8);
    const muzzleColor = Color(0xFFEBE6FF);
    const innerEarColor = Color(0xFFFFB6C1); // Soft pastel pink
    const noseColor = Color(0xFF231955);
    final blushColor = isHovered ? const Color(0x66FF69B4) : const Color(0x33FF69B4);

    final breatheY = (breatheProgress - 0.5) * 4.0 * scale;

    // ── 1. Soft Ambient Shadow Underneath ──
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height - 10 * scale),
        width: 110 * scale,
        height: 18 * scale,
      ),
      shadowPaint,
    );

    // Dynamic head tilt towards mouse cursor
    final tiltAngle = isHovered
        ? (mouseGaze.dx * 0.025).clamp(-0.08, 0.08)
        : (mouseGaze.dx * 0.012).clamp(-0.04, 0.04);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tiltAngle);
    canvas.translate(-center.dx, -center.dy);

    // ── 2. Ears (with playful wiggle) ──
    final earY = (center.dy - 56 * scale) + breatheY;
    final earWiggle = math.sin(wiggleProgress * math.pi * 4) * 4.0 * scale;

    void drawEar({required double x, required bool isLeft}) {
      final currentX = isLeft ? x - earWiggle : x + earWiggle;
      final earCenter = Offset(currentX, earY);
      final earPaint = Paint()..color = furDark;
      canvas.drawCircle(earCenter, 22 * scale, earPaint);

      // Inner Ear
      final innerEarPaint = Paint()..color = innerEarColor;
      canvas.drawCircle(earCenter, 13 * scale, innerEarPaint);
    }

    drawEar(x: center.dx - 54 * scale, isLeft: true);
    drawEar(x: center.dx + 54 * scale, isLeft: false);

    // ── 3. Head & Body ──
    final headRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - 8 * scale + breatheY),
      width: 128 * scale,
      height: 112 * scale,
    );

    final headPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF6C57F5), furColor, furDark],
      ).createShader(headRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect, Radius.circular(56 * scale)),
      headPaint,
    );

    // ── 4. Cheeks (Blush) ──
    final blushPaint = Paint()..color = blushColor;
    canvas.drawCircle(Offset(center.dx - 42 * scale, center.dy + 8 * scale + breatheY), 11 * scale, blushPaint);
    canvas.drawCircle(Offset(center.dx + 42 * scale, center.dy + 8 * scale + breatheY), 11 * scale, blushPaint);

    // ── 5. Muzzle & Nose ──
    final muzzleCenter = Offset(center.dx, center.dy + 12 * scale + breatheY);
    final muzzlePaint = Paint()..color = muzzleColor;
    canvas.drawOval(
      Rect.fromCenter(center: muzzleCenter, width: 58 * scale, height: 44 * scale),
      muzzlePaint,
    );

    // Nose
    final noseCenter = Offset(center.dx, muzzleCenter.dy - 6 * scale);
    final nosePaint = Paint()..color = noseColor;
    final nosePath = Path()
      ..moveTo(noseCenter.dx - 8 * scale, noseCenter.dy - 3 * scale)
      ..quadraticBezierTo(noseCenter.dx, noseCenter.dy - 5 * scale, noseCenter.dx + 8 * scale, noseCenter.dy - 3 * scale)
      ..quadraticBezierTo(noseCenter.dx + 4 * scale, noseCenter.dy + 6 * scale, noseCenter.dx, noseCenter.dy + 7 * scale)
      ..quadraticBezierTo(noseCenter.dx - 4 * scale, noseCenter.dy + 6 * scale, noseCenter.dx - 8 * scale, noseCenter.dy - 3 * scale)
      ..close();
    canvas.drawPath(nosePath, nosePaint);

    // Mouth
    final mouthPaint = Paint()
      ..color = noseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scale
      ..strokeCap = StrokeCap.round;

    if (isSuccess || isHovered) {
      // Big open cheerful smile
      final openMouthPath = Path()
        ..moveTo(center.dx - 10 * scale, muzzleCenter.dy + 6 * scale)
        ..quadraticBezierTo(center.dx, muzzleCenter.dy + (isSuccess ? 18 : 15) * scale, center.dx + 10 * scale, muzzleCenter.dy + 6 * scale);
      if (isSuccess) {
        final fillPaint = Paint()..color = const Color(0xFFD63031);
        canvas.drawPath(openMouthPath, fillPaint);
      }
      canvas.drawPath(openMouthPath, mouthPaint);
    } else if (isFail) {
      // Small sad curve
      final sadPath = Path()
        ..moveTo(center.dx - 8 * scale, muzzleCenter.dy + 12 * scale)
        ..quadraticBezierTo(center.dx, muzzleCenter.dy + 6 * scale, center.dx + 8 * scale, muzzleCenter.dy + 12 * scale);
      canvas.drawPath(sadPath, mouthPaint);
    } else {
      // Classic cute cat/bear mouth :3
      final leftMouth = Path()
        ..moveTo(center.dx, muzzleCenter.dy + 4 * scale)
        ..lineTo(center.dx, muzzleCenter.dy + 8 * scale)
        ..quadraticBezierTo(center.dx - 6 * scale, muzzleCenter.dy + 14 * scale, center.dx - 10 * scale, muzzleCenter.dy + 9 * scale);
      final rightMouth = Path()
        ..moveTo(center.dx, muzzleCenter.dy + 8 * scale)
        ..quadraticBezierTo(center.dx + 6 * scale, muzzleCenter.dy + 14 * scale, center.dx + 10 * scale, muzzleCenter.dy + 9 * scale);
      canvas.drawPath(leftMouth, mouthPaint);
      canvas.drawPath(rightMouth, mouthPaint);
    }

    // ── 6. Eyes with Real-time Mouse Gaze Tracking ──
    final eyeY = (center.dy - 12 * scale) + breatheY;
    final leftEyeX = center.dx - 26 * scale;
    final rightEyeX = center.dx + 26 * scale;

    // Pupil shift calculations:
    // When directly hovered -> follow mouse cursor with top priority
    // When typing in input -> look down at text (unless mouse is hovering)
    // Otherwise -> smoothly follow the mouse cursor anywhere on screen
    double pupilShiftX;
    double pupilShiftY;

    if (isHovered) {
      pupilShiftX = mouseGaze.dx * scale;
      pupilShiftY = mouseGaze.dy * scale;
    } else if (isChecking) {
      pupilShiftX = (lookProgress - 0.5) * 8.0 * scale;
      pupilShiftY = 3.5 * scale;
    } else {
      pupilShiftX = mouseGaze.dx * scale;
      pupilShiftY = mouseGaze.dy * scale;
    }

    void drawEye({required double x, required bool peekOpen}) {
      if (isBlinking && !peekOpen) {
        final blinkPaint = Paint()
          ..color = noseColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * scale
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x - 9 * scale, eyeY), Offset(x + 9 * scale, eyeY), blinkPaint);
        return;
      }

      if (isSuccess) {
        // Happy arch eyes: ^
        final happyPaint = Paint()
          ..color = noseColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8 * scale
          ..strokeCap = StrokeCap.round;
        final arch = Path()
          ..moveTo(x - 9 * scale, eyeY + 2 * scale)
          ..quadraticBezierTo(x, eyeY - 8 * scale, x + 9 * scale, eyeY + 2 * scale);
        canvas.drawPath(arch, happyPaint);
        return;
      }

      // White Sclera
      final scleraPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(x, eyeY), 12 * scale, scleraPaint);

      // Pupil (dark navy)
      final pupilCenter = Offset(x + pupilShiftX, eyeY + pupilShiftY);
      final pupilPaint = Paint()..color = noseColor;
      canvas.drawCircle(pupilCenter, 7.5 * scale, pupilPaint);

      // Primary Catchlight (big sparkle)
      final sparklePaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(pupilCenter.dx - 2.8 * scale, pupilCenter.dy - 2.8 * scale), 2.5 * scale, sparklePaint);

      // Secondary Catchlight (small sparkle)
      canvas.drawCircle(Offset(pupilCenter.dx + 2.2 * scale, pupilCenter.dy + 2.2 * scale), 1.2 * scale, sparklePaint);
    }

    drawEye(x: leftEyeX, peekOpen: isPeeking);
    drawEye(x: rightEyeX, peekOpen: false);

    // ── 7. Paws Covering Eyes (Hands Up Animation) ──
    if (handsProgress > 0.01) {
      final pawStartY = center.dy + 65 * scale;
      final pawEndY = eyeY + 6 * scale;
      final currentPawY = pawStartY + (pawEndY - pawStartY) * handsProgress;

      void drawPaw({required double x, required bool dropForPeek}) {
        double y = currentPawY;
        if (dropForPeek && isPeeking) {
          y = currentPawY + 22 * scale; // paw drops lower to peek
        }

        final pawCenter = Offset(x, y);

        // Paw base
        final pawPaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6C57F5), furColor],
          ).createShader(Rect.fromCircle(center: pawCenter, radius: 18 * scale));
        canvas.drawCircle(pawCenter, 18 * scale, pawPaint);

        // Paw outline / shadow
        final pawBorder = Paint()
          ..color = furDark.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * scale;
        canvas.drawCircle(pawCenter, 18 * scale, pawBorder);

        // Soft pink center pad
        final padPaint = Paint()..color = innerEarColor;
        canvas.drawCircle(Offset(pawCenter.dx, pawCenter.dy + 1 * scale), 7.5 * scale, padPaint);

        // 3 Cute little toe beans
        canvas.drawCircle(Offset(pawCenter.dx - 7 * scale, pawCenter.dy - 8 * scale), 3.0 * scale, padPaint);
        canvas.drawCircle(Offset(pawCenter.dx, pawCenter.dy - 10 * scale), 3.2 * scale, padPaint);
        canvas.drawCircle(Offset(pawCenter.dx + 7 * scale, pawCenter.dy - 8 * scale), 3.0 * scale, padPaint);
      }

      drawPaw(x: center.dx - 28 * scale, dropForPeek: true);
      drawPaw(x: center.dx + 28 * scale, dropForPeek: false);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BearMascotPainter oldDelegate) {
    return oldDelegate.breatheProgress != breatheProgress ||
        oldDelegate.handsProgress != handsProgress ||
        oldDelegate.wiggleProgress != wiggleProgress ||
        oldDelegate.mouseGaze != mouseGaze ||
        oldDelegate.lookProgress != lookProgress ||
        oldDelegate.isChecking != isChecking ||
        oldDelegate.isHandsUp != isHandsUp ||
        oldDelegate.isPeeking != isPeeking ||
        oldDelegate.isBlinking != isBlinking ||
        oldDelegate.isSuccess != isSuccess ||
        oldDelegate.isFail != isFail ||
        oldDelegate.isHovered != isHovered;
  }
}
