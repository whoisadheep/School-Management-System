import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../services/sound_service.dart';

/// A tactile, deeply satisfying 3D push button.
///
/// Features:
/// - Real 3D keycap push-down animation (bottom shadow collapses, surface translates down)
/// - Spring-back physics on release (`Curves.easeOutBack`)
/// - Integrated micro-click audio feedback via [SoundService]
/// - Hover glow & subtle scale
class SatisfyingButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String? text;
  final IconData? icon;
  final Widget? child;
  final Color? color;
  final Color? textColor;
  final double? width;
  final double height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool enableSound;
  final bool isSecondary;

  const SatisfyingButton({
    super.key,
    required this.onPressed,
    this.text,
    this.icon,
    this.child,
    this.color,
    this.textColor,
    this.width,
    this.height = 40,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.borderRadius = 10,
    this.enableSound = true,
    this.isSecondary = false,
  });

  @override
  State<SatisfyingButton> createState() => _SatisfyingButtonState();
}

class _SatisfyingButtonState extends State<SatisfyingButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
    if (widget.enableSound) {
      SoundService().playClick();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? (widget.isSecondary ? Colors.white : AppTheme.primaryPurple);
    final isDark = !widget.isSecondary;
    final fgColor = widget.textColor ?? (isDark ? Colors.white : AppTheme.primaryPurple);

    // Compute 3D lip / shadow color (darker shade of the base color)
    final shadowColor = widget.isSecondary
        ? const Color(0xFFCBD5E1)
        : HSLColor.fromColor(baseColor)
            .withLightness((HSLColor.fromColor(baseColor).lightness - 0.18).clamp(0.0, 1.0))
            .toColor();

    return MouseRegion(
      cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: widget.height,
          transform: Matrix4.translationValues(0, _isPressed ? 3.0 : 0.0, 0),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _isHovered && widget.isSecondary ? const Color(0xFFF8FAFC) : baseColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.isSecondary
                ? Border.all(color: const Color(0xFFCBD5E1), width: 1.5)
                : null,
            boxShadow: [
              // Sharp physical 3D keycap edge
              BoxShadow(
                color: shadowColor,
                offset: Offset(0, _isPressed ? 0.5 : 3.5),
                blurRadius: 0,
              ),
              if (_isHovered && !_isPressed)
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Center(
            child: widget.child ??
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 16, color: fgColor),
                      const SizedBox(width: 6),
                    ],
                    if (widget.text != null)
                      Text(
                        widget.text!,
                        style: GoogleFonts.poppins(
                          color: fgColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

/// A large, ultra-satisfying tactile card button for the Quick Action Launcher.
class SatisfyingActionCard extends StatefulWidget {
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color? backgroundColor;

  const SatisfyingActionCard({
    super.key,
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.backgroundColor,
  });

  @override
  State<SatisfyingActionCard> createState() => _SatisfyingActionCardState();
}

class _SatisfyingActionCardState extends State<SatisfyingActionCard> {
  bool _isPressed = false;
  bool _isHovered = false;

  void _handleTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    SoundService().playClick();
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          curve: Curves.easeOutCubic,
          height: 76,
          transform: Matrix4.translationValues(0, _isPressed ? 3.0 : 0.0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFFBFBFE) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered ? widget.iconColor.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: [
              // 3D physical card bottom edge
              BoxShadow(
                color: const Color(0xFFCBD5E1),
                offset: Offset(0, _isPressed ? 0.5 : 3.5),
                blurRadius: 0,
              ),
              if (_isHovered && !_isPressed)
                BoxShadow(
                  color: widget.iconColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: _isHovered ? widget.iconColor : AppTheme.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
