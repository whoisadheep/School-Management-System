import 'package:flutter/material.dart';

class HoverScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration duration;

  const HoverScale({
    super.key,
    required this.child,
    this.scale = 1.05,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<HoverScale> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
