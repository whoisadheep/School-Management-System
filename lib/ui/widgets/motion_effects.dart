import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Motion.dev-style animation extensions for Flutter.
/// Provides fluid springs, staggered entrances, and micro-interactions.
extension MotionExtensions on Widget {
  /// Motion.dev-style staggered spring entrance (fade + slight slide up + spring scale)
  Widget motionEntrance({
    int index = 0,
    Duration duration = const Duration(milliseconds: 350),
    Duration stagger = const Duration(milliseconds: 50),
    double slideOffsetY = 0.1,
    Curve curve = Curves.easeOutBack,
  }) {
    final delayMs = index * stagger.inMilliseconds;
    return animate(delay: Duration(milliseconds: delayMs))
        .fadeIn(duration: duration, curve: Curves.easeOutCubic)
        .slideY(begin: slideOffsetY, end: 0, duration: duration, curve: curve)
        .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1), duration: duration, curve: curve);
  }

  /// Motion.dev-style dialog or card pop-in with energetic spring
  Widget motionPop({
    Duration duration = const Duration(milliseconds: 300),
    Duration delay = Duration.zero,
  }) {
    return animate(delay: delay)
        .fadeIn(duration: duration)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), duration: duration, curve: Curves.easeOutBack);
  }

  /// Subtle shimmer sweep highlight (great for hero cards or premium tags)
  Widget motionShimmer({
    Duration delay = const Duration(milliseconds: 500),
    Duration duration = const Duration(milliseconds: 1200),
    Color? color,
  }) {
    return animate(delay: delay).shimmer(
      duration: duration,
      color: color ?? Colors.white.withValues(alpha: 0.3),
    );
  }

  /// Gentle attention pulse (e.g. for badges, pending alerts, or live dots)
  Widget motionPulse({
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    return animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.06, 1.06),
          duration: duration,
          curve: Curves.easeInOut,
        );
  }
}
