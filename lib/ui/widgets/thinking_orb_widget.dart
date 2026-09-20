import 'package:flutter/material.dart';
import 'package:agent_orbs/agent_orbs.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

export 'package:agent_orbs/agent_orbs.dart' show OrbState, OrbTheme, OrbSize;

/// A branded wrapper around [ThinkingOrb] featuring Eduvia purple glow styling,
/// customizable size presets, and optional status typography.
class EduviaThinkingOrb extends StatelessWidget {
  final OrbState state;
  final double size;
  final OrbTheme theme;
  final bool showGlow;
  final Color? glowColor;
  final String? label;
  final TextStyle? labelStyle;
  final double speed;
  final bool paused;

  const EduviaThinkingOrb({
    super.key,
    this.state = OrbState.working,
    this.size = 48,
    this.theme = OrbTheme.light,
    this.showGlow = true,
    this.glowColor,
    this.label,
    this.labelStyle,
    this.speed = 1.0,
    this.paused = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGlowColor = glowColor ?? AppTheme.primaryPurple.withValues(alpha: 0.12);

    Widget orbWidget = Stack(
      alignment: Alignment.center,
      children: [
        if (showGlow)
          Container(
            width: size * 1.4,
            height: size * 1.4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  effectiveGlowColor,
                  effectiveGlowColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ThinkingOrb(
          state: state,
          size: size,
          theme: theme,
          speed: speed,
          paused: paused,
        ),
      ],
    );

    if (label == null || label!.isEmpty) {
      return orbWidget;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        orbWidget,
        const SizedBox(height: 12),
        Text(
          label!,
          textAlign: TextAlign.center,
          style: labelStyle ??
              GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
        ),
      ],
    );
  }
}

/// An inline or centered loading placeholder for Riverpod `.when(loading: ...)`
/// or asynchronous data queries.
class ThinkingLoadingCard extends StatelessWidget {
  final String message;
  final String? subMessage;
  final OrbState state;
  final double size;
  final EdgeInsetsGeometry padding;
  final bool compact;

  const ThinkingLoadingCard({
    super.key,
    this.message = 'Loading data...',
    this.subMessage,
    this.state = OrbState.working,
    this.size = 48,
    this.padding = const EdgeInsets.all(32),
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EduviaThinkingOrb(
              state: state,
              size: 24,
              showGlow: false,
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            EduviaThinkingOrb(
              state: state,
              size: size,
              showGlow: true,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            if (subMessage != null && subMessage!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A modal dialog displaying a Thinking Orb and status text for long-running operations.
class ThinkingLoadingDialog extends StatelessWidget {
  final String message;
  final String? subMessage;
  final OrbState state;

  const ThinkingLoadingDialog({
    super.key,
    required this.message,
    this.subMessage,
    this.state = OrbState.working,
  });

  /// Displays the modal dialog and returns a controller to dismiss it.
  static Future<T> runWithDialog<T>({
    required BuildContext context,
    required Future<T> Function() task,
    required String message,
    String? subMessage,
    OrbState state = OrbState.working,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => ThinkingLoadingDialog(
        message: message,
        subMessage: subMessage,
        state: state,
      ),
    );

    try {
      final result = await task();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      return result;
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EduviaThinkingOrb(
                state: state,
                size: 56,
                showGlow: true,
              ),
              const SizedBox(height: 18),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (subMessage != null && subMessage!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
