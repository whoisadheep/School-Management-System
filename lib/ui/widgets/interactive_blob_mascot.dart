import 'dart:math' as math;
import 'package:flutter/material.dart';

enum BlobMascotState { idle, typing, password, peek, success, error }

class InteractiveBlobMascot extends StatefulWidget {
  final Offset mousePosition;
  final BlobMascotState mascotState;
  final double size;

  const InteractiveBlobMascot({
    super.key,
    required this.mousePosition,
    this.mascotState = BlobMascotState.idle,
    this.size = 200.0,
  });

  @override
  State<InteractiveBlobMascot> createState() => _InteractiveBlobMascotState();
}

class _InteractiveBlobMascotState extends State<InteractiveBlobMascot>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathingAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.mascotState == BlobMascotState.success ? 1.0 : _breathingAnimation.value,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _BlobPainter(
              mousePosition: widget.mousePosition,
              state: widget.mascotState,
              breathingValue: _breathingAnimation.value,
            ),
          ),
        );
      },
    );
  }
}

class _BlobPainter extends CustomPainter {
  final Offset mousePosition;
  final BlobMascotState state;
  final double breathingValue;

  _BlobPainter({
    required this.mousePosition,
    required this.state,
    required this.breathingValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final blobRadius = size.width / 2.2;

    // Draw Drop Shadow
    final shadowPath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(center.dx, center.dy + blobRadius * 0.9),
        width: blobRadius * 1.5,
        height: blobRadius * 0.3,
      ));
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Draw Blob Body (Organic Shape)
    final blobPath = _createBlobPath(size, center, blobRadius);
    final blobPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9D7BFF), Color(0xFF7B68EE)], // Eduvia purple palette
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(blobPath, blobPaint);

    // Draw Cheeks/Blush
    final blushPaint = Paint()
      ..color = const Color(0xFFFFB6C1).withValues(alpha: 0.5) // Soft pink
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    canvas.drawCircle(Offset(center.dx - size.width * 0.25, center.dy + size.height * 0.05), size.width * 0.08, blushPaint);
    canvas.drawCircle(Offset(center.dx + size.width * 0.25, center.dy + size.height * 0.05), size.width * 0.08, blushPaint);

    // Draw Eyes & Mouth
    _drawFace(canvas, size, center);
  }

  Path _createBlobPath(Size size, Offset center, double radius) {
    // Simple organic path using curves
    final path = Path();
    final topOffset = (breathingValue - 1.0) * 50; // Breathing effect on top

    path.moveTo(center.dx, center.dy - radius - topOffset);
    path.cubicTo(
      center.dx + radius * 1.2, center.dy - radius - topOffset,
      center.dx + radius * 1.2, center.dy + radius,
      center.dx, center.dy + radius,
    );
    path.cubicTo(
      center.dx - radius * 1.2, center.dy + radius,
      center.dx - radius * 1.2, center.dy - radius - topOffset,
      center.dx, center.dy - radius - topOffset,
    );
    return path;
  }

  void _drawFace(Canvas canvas, Size size, Offset center) {
    final eyeSpacing = size.width * 0.18;
    final leftEyeCenter = Offset(center.dx - eyeSpacing, center.dy - size.height * 0.05);
    final rightEyeCenter = Offset(center.dx + eyeSpacing, center.dy - size.height * 0.05);
    final eyeRadius = size.width * 0.12;

    // Mouth parameters
    Offset mouthCenter = Offset(center.dx, center.dy + size.height * 0.15);
    double mouthWidth = size.width * 0.15;

    final outlinePaint = Paint()
      ..color = const Color(0xFF1E1E2D) // Dark for eyes and mouth
      ..style = PaintingStyle.fill;
    final outlineStroke = Paint()
      ..color = const Color(0xFF1E1E2D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    if (state == BlobMascotState.password) {
      // Eyes closed completely (Happy Arches)
      _drawClosedEye(canvas, leftEyeCenter, eyeRadius, outlineStroke);
      _drawClosedEye(canvas, rightEyeCenter, eyeRadius, outlineStroke);
      // Small simple mouth
      _drawSmile(canvas, mouthCenter, mouthWidth * 0.6, outlineStroke, isSmall: true);
    } else if (state == BlobMascotState.peek) {
      // One closed, one looking
      _drawClosedEye(canvas, leftEyeCenter, eyeRadius, outlineStroke);
      _drawOpenEye(canvas, rightEyeCenter, eyeRadius, outlinePaint);
      _drawSmile(canvas, mouthCenter, mouthWidth * 0.8, outlineStroke, isSmall: true);
    } else if (state == BlobMascotState.success) {
      // Happy arches and big smile
      _drawClosedEye(canvas, leftEyeCenter, eyeRadius, outlineStroke);
      _drawClosedEye(canvas, rightEyeCenter, eyeRadius, outlineStroke);
      _drawSmile(canvas, mouthCenter, mouthWidth, outlineStroke, isSmall: false);
    } else if (state == BlobMascotState.error) {
      // Sad eyes and frown
      _drawSadEye(canvas, leftEyeCenter, eyeRadius, outlineStroke);
      _drawSadEye(canvas, rightEyeCenter, eyeRadius, outlineStroke);
      _drawFrown(canvas, mouthCenter, mouthWidth, outlineStroke);
    } else {
      // Idle or Typing - Open eyes that track mouse
      _drawOpenEye(canvas, leftEyeCenter, eyeRadius, outlinePaint, isTyping: state == BlobMascotState.typing);
      _drawOpenEye(canvas, rightEyeCenter, eyeRadius, outlinePaint, isTyping: state == BlobMascotState.typing);
      _drawSmile(canvas, mouthCenter, mouthWidth * 0.8, outlineStroke, isSmall: true);
    }
  }

  void _drawOpenEye(Canvas canvas, Offset eyeCenter, double radius, Paint paint, {bool isTyping = false}) {
    // Sclera (White part)
    final scleraPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(eyeCenter, radius, scleraPaint);

    // Pupil position calculation (tracking mouse)
    double pupilOffsetMax = radius * 0.45;
    Offset pupilCenter = eyeCenter;
    
    if (isTyping) {
      // Look down
      pupilCenter = Offset(eyeCenter.dx, eyeCenter.dy + pupilOffsetMax * 0.8);
    } else {
      double dx = mousePosition.dx;
      double dy = mousePosition.dy;
      
      double distance = math.sqrt(dx * dx + dy * dy);
      if (distance > 0) {
        double angle = math.atan2(dy, dx);
        double distanceRatio = math.min(1.0, distance / 500); // Normalize
        double offsetX = math.cos(angle) * pupilOffsetMax * distanceRatio;
        double offsetY = math.sin(angle) * pupilOffsetMax * distanceRatio;
        
        pupilCenter = Offset(eyeCenter.dx + offsetX, eyeCenter.dy + offsetY);
      }
    }

    // Iris / Pupil
    canvas.drawCircle(pupilCenter, radius * 0.55, paint);

    // Catchlight (White sparkle)
    final catchlightPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pupilCenter.dx - radius * 0.15, pupilCenter.dy - radius * 0.15), radius * 0.15, catchlightPaint);
    canvas.drawCircle(Offset(pupilCenter.dx + radius * 0.1, pupilCenter.dy - radius * 0.05), radius * 0.06, catchlightPaint);
  }

  void _drawClosedEye(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    path.moveTo(center.dx - radius * 0.8, center.dy);
    path.quadraticBezierTo(center.dx, center.dy - radius * 0.8, center.dx + radius * 0.8, center.dy);
    canvas.drawPath(path, paint);
  }

  void _drawSadEye(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    path.moveTo(center.dx - radius * 0.8, center.dy - radius * 0.4);
    path.quadraticBezierTo(center.dx, center.dy - radius * 0.8, center.dx + radius * 0.8, center.dy);
    canvas.drawPath(path, paint);
  }

  void _drawSmile(Canvas canvas, Offset center, double width, Paint paint, {bool isSmall = true}) {
    final path = Path();
    path.moveTo(center.dx - width / 2, center.dy);
    if (isSmall) {
      path.quadraticBezierTo(center.dx, center.dy + width / 2, center.dx + width / 2, center.dy);
    } else {
      // Big smile
      path.quadraticBezierTo(center.dx, center.dy + width, center.dx + width / 2, center.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawFrown(Canvas canvas, Offset center, double width, Paint paint) {
    final path = Path();
    path.moveTo(center.dx - width / 2, center.dy + width / 4);
    path.quadraticBezierTo(center.dx, center.dy - width / 4, center.dx + width / 2, center.dy + width / 4);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) {
    return oldDelegate.mousePosition != mousePosition ||
           oldDelegate.state != state ||
           oldDelegate.breathingValue != breathingValue;
  }
}
