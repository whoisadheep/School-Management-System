import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/services_provider.dart';

/// Deterministic pseudo-random number generator using FNV-1a hash and LCG.
class _BlobRng {
  int _state;

  _BlobRng(String seed) : _state = _fnv1a(seed);

  static int _fnv1a(String text) {
    var hash = 0x811C9DC5;
    final bytes = utf8.encode(text);
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  double nextDouble() {
    _state = (1664525 * _state + 1013904223) & 0xFFFFFFFF;
    return (_state & 0x7FFFFFFF) / 0x7FFFFFFF;
  }

  int nextInt(int max) => (nextDouble() * max).floor();

  double range(double min, double max) => min + nextDouble() * (max - min);

  T pick<T>(List<T> list) => list[nextInt(list.length)];
}

/// Curated color palette pairing a vibrant pastel body with a deep matching-tone face.
class _BlobPalette {
  final String body;
  final String face;
  final String blush;
  final String? accent;

  const _BlobPalette({
    required this.body,
    required this.face,
    required this.blush,
    this.accent,
  });
}

const List<_BlobPalette> _kPalettes = [
  // Lavender Purple (Eduvia Theme)
  _BlobPalette(body: '#9D7BFF', face: '#1E0C42', blush: '#FF88A5', accent: '#FFD43B'),
  // Soft Lilac
  _BlobPalette(body: '#C38EE6', face: '#260D38', blush: '#FFA8BD', accent: '#4DABF7'),
  // Coral Pink
  _BlobPalette(body: '#FF7597', face: '#3D0717', blush: '#FFB8C6', accent: '#FFD43B'),
  // Mint Seafoam
  _BlobPalette(body: '#38D9A9', face: '#053324', blush: '#FF8787', accent: '#9D7BFF'),
  // Sky Azure
  _BlobPalette(body: '#4DABF7', face: '#07243D', blush: '#FFA94D', accent: '#FFD43B'),
  // Sunset Peach
  _BlobPalette(body: '#FFA94D', face: '#3D1C00', blush: '#FF6B6B', accent: '#4DABF7'),
  // Lemon Sunshine
  _BlobPalette(body: '#FFD43B', face: '#3D2F00', blush: '#FF8787', accent: '#9D7BFF'),
  // Emerald Green
  _BlobPalette(body: '#69DB7C', face: '#093613', blush: '#FFA94D', accent: '#FFD43B'),
  // Periwinkle Indigo
  _BlobPalette(body: '#748FFC', face: '#0E1747', blush: '#FF8787', accent: '#38D9A9'),
  // Strawberry Crimson
  _BlobPalette(body: '#FF6B6B', face: '#380909', blush: '#FFB3B3', accent: '#FFD43B'),
  // Teal Cyan
  _BlobPalette(body: '#20C997', face: '#043325', blush: '#FFA8BD', accent: '#FFA94D'),
  // Royal Grape
  _BlobPalette(body: '#B197FC', face: '#241052', blush: '#FF8787', accent: '#FFD43B'),
];

/// Offline Pure Dart Generator for Blobatar SVG Avatars.
class BlobatarGenerator {
  static final Map<String, String> _cache = {};

  /// Generates a complete SVG string for a given [seed].
  static String generateSvg(String seed) {
    final cleanSeed = seed.trim();
    if (_cache.containsKey(cleanSeed)) {
      return _cache[cleanSeed]!;
    }

    final rng = _BlobRng(cleanSeed);
    final palette = rng.pick(_kPalettes);
    final bodyShape = _generateBody(rng, palette);
    final faceElements = _generateFace(rng, palette);
    final accessory = _generateAccessory(rng, palette);

    final svg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  $bodyShape
  $accessory
  $faceElements
</svg>''';

    // Keep cache bounded to 500 items
    if (_cache.length > 500) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cleanSeed] = svg;
    return svg;
  }

  /// Generates the organic blob or capsule shape.
  static String _generateBody(_BlobRng rng, _BlobPalette palette) {
    final shapeType = rng.nextInt(4);

    if (shapeType == 0) {
      // Pill / Capsule Blob
      final rx = rng.range(22, 28);
      final x = rng.range(14, 20);
      final y = rng.range(14, 20);
      final w = 100 - x * 2;
      final h = 100 - y * 2;
      return '<rect x="${x.toStringAsFixed(1)}" y="${y.toStringAsFixed(1)}" width="${w.toStringAsFixed(1)}" height="${h.toStringAsFixed(1)}" rx="${rx.toStringAsFixed(1)}" fill="${palette.body}"/>';
    }

    // Organic Bezier Spline Blob (6 control points with Catmull-Rom interpolation)
    const numPoints = 6;
    final points = <_Point>[];
    final baseRadius = rng.range(33, 38);

    for (int i = 0; i < numPoints; i++) {
      final angle = (i * 2 * math.pi) / numPoints;
      final variance = rng.range(-6.5, 6.5);
      final r = baseRadius + variance;
      final px = 50.0 + r * math.cos(angle);
      final py = 50.0 + r * math.sin(angle);
      points.add(_Point(px, py));
    }

    // Build Catmull-Rom to Cubic Bezier closed path
    final buffer = StringBuffer();
    buffer.write('M ${points[0].x.toStringAsFixed(2)} ${points[0].y.toStringAsFixed(2)} ');

    for (int i = 0; i < numPoints; i++) {
      final p0 = points[(i - 1 + numPoints) % numPoints];
      final p1 = points[i];
      final p2 = points[(i + 1) % numPoints];
      final p3 = points[(i + 2) % numPoints];

      final cp1x = p1.x + (p2.x - p0.x) / 6.0;
      final cp1y = p1.y + (p2.y - p0.y) / 6.0;
      final cp2x = p2.x - (p3.x - p1.x) / 6.0;
      final cp2y = p2.y - (p3.y - p1.y) / 6.0;

      buffer.write(
        'C ${cp1x.toStringAsFixed(2)} ${cp1y.toStringAsFixed(2)}, '
        '${cp2x.toStringAsFixed(2)} ${cp2y.toStringAsFixed(2)}, '
        '${p2.x.toStringAsFixed(2)} ${p2.y.toStringAsFixed(2)} ',
      );
    }
    buffer.write('Z');

    return '<path d="${buffer.toString()}" fill="${palette.body}"/>';
  }

  /// Generates eyes, mouth, and blushing cheeks.
  static String _generateFace(_BlobRng rng, _BlobPalette palette) {
    final buffer = StringBuffer();
    final eyeStyle = rng.nextInt(7);
    final mouthStyle = rng.nextInt(6);
    final hasBlush = rng.nextDouble() > 0.3;

    final eyeY = rng.range(46, 50);
    final eyeSpread = rng.range(8, 12);
    final leftEyeX = 50.0 - eyeSpread;
    final rightEyeX = 50.0 + eyeSpread;

    // 1. Blushing cheeks
    if (hasBlush) {
      final blushY = eyeY + 9;
      final blushR = rng.range(4, 5.5);
      buffer.write(
        '<circle cx="${(leftEyeX - 3).toStringAsFixed(1)}" cy="${blushY.toStringAsFixed(1)}" r="${blushR.toStringAsFixed(1)}" fill="${palette.blush}" opacity="0.5"/>'
        '<circle cx="${(rightEyeX + 3).toStringAsFixed(1)}" cy="${blushY.toStringAsFixed(1)}" r="${blushR.toStringAsFixed(1)}" fill="${palette.blush}" opacity="0.5"/>',
      );
    }

    // 2. Eyes
    buffer.write('<g fill="${palette.face}">');
    switch (eyeStyle) {
      case 0:
        // Classic Cute Dots with Catchlights
        buffer.write(
          '<circle cx="${leftEyeX.toStringAsFixed(1)}" cy="${eyeY.toStringAsFixed(1)}" r="4.2"/>'
          '<circle cx="${rightEyeX.toStringAsFixed(1)}" cy="${eyeY.toStringAsFixed(1)}" r="4.2"/>'
          '<circle cx="${(leftEyeX + 1.2).toStringAsFixed(1)}" cy="${(eyeY - 1.2).toStringAsFixed(1)}" r="1.4" fill="#FFFFFF"/>'
          '<circle cx="${(rightEyeX + 1.2).toStringAsFixed(1)}" cy="${(eyeY - 1.2).toStringAsFixed(1)}" r="1.4" fill="#FFFFFF"/>',
        );
        break;

      case 1:
        // Happy Arches (Closed Joyful Eyes)
        buffer.write(
          '<path d="M ${(leftEyeX - 4).toStringAsFixed(1)} ${(eyeY + 2).toStringAsFixed(1)} Q ${leftEyeX.toStringAsFixed(1)} ${(eyeY - 4).toStringAsFixed(1)} ${(leftEyeX + 4).toStringAsFixed(1)} ${(eyeY + 2).toStringAsFixed(1)}" stroke="${palette.face}" stroke-width="2.8" stroke-linecap="round" fill="none"/>'
          '<path d="M ${(rightEyeX - 4).toStringAsFixed(1)} ${(eyeY + 2).toStringAsFixed(1)} Q ${rightEyeX.toStringAsFixed(1)} ${(eyeY - 4).toStringAsFixed(1)} ${(rightEyeX + 4).toStringAsFixed(1)} ${(eyeY + 2).toStringAsFixed(1)}" stroke="${palette.face}" stroke-width="2.8" stroke-linecap="round" fill="none"/>',
        );
        break;

      case 2:
        // Wink (One dot, one arch)
        buffer.write(
          '<circle cx="${leftEyeX.toStringAsFixed(1)}" cy="${eyeY.toStringAsFixed(1)}" r="4.2"/>'
          '<circle cx="${(leftEyeX + 1.2).toStringAsFixed(1)}" cy="${(eyeY - 1.2).toStringAsFixed(1)}" r="1.4" fill="#FFFFFF"/>'
          '<path d="M ${(rightEyeX - 4).toStringAsFixed(1)} ${(eyeY + 2).toStringAsFixed(1)} Q ${rightEyeX.toStringAsFixed(1)} ${(eyeY - 4).toStringAsFixed(1)} ${(rightEyeX + 4).toStringAsFixed(1)} ${(eyeY + 2).toStringAsFixed(1)}" stroke="${palette.face}" stroke-width="2.8" stroke-linecap="round" fill="none"/>',
        );
        break;

      case 3:
        // Round Glasses / Spectacles
        const glassesR = 7.0;
        buffer.write(
          '<circle cx="${leftEyeX.toStringAsFixed(1)}" cy="${eyeY.toStringAsFixed(1)}" r="${glassesR.toStringAsFixed(1)}" stroke="${palette.face}" stroke-width="2.2" fill="none"/>'
          '<circle cx="${rightEyeX.toStringAsFixed(1)}" cy="${eyeY.toStringAsFixed(1)}" r="${glassesR.toStringAsFixed(1)}" stroke="${palette.face}" stroke-width="2.2" fill="none"/>'
          '<path d="M ${(leftEyeX + glassesR).toStringAsFixed(1)} ${eyeY.toStringAsFixed(1)} L ${(rightEyeX - glassesR).toStringAsFixed(1)} ${eyeY.toStringAsFixed(1)}" stroke="${palette.face}" stroke-width="2.2"/>'
          '<circle cx="${leftEyeX.toStringAsFixed(1)}" cy="${eyeY.toStringAsFixed(1)}" r="2.8"/>'
          '<circle cx="${rightEyeX.toStringAsFixed(1)}" cy="${eyeY.toStringAsFixed(1)}" r="2.8"/>',
        );
        break;

      case 4:
        // Cool Sunglasses / Shades
        buffer.write(
          '<path d="M ${(leftEyeX - 7).toStringAsFixed(1)} ${(eyeY - 3).toStringAsFixed(1)} Q ${leftEyeX.toStringAsFixed(1)} ${(eyeY + 6).toStringAsFixed(1)} ${(leftEyeX + 7).toStringAsFixed(1)} ${(eyeY - 3).toStringAsFixed(1)} Z" fill="${palette.face}"/>'
          '<path d="M ${(rightEyeX - 7).toStringAsFixed(1)} ${(eyeY - 3).toStringAsFixed(1)} Q ${rightEyeX.toStringAsFixed(1)} ${(eyeY + 6).toStringAsFixed(1)} ${(rightEyeX + 7).toStringAsFixed(1)} ${(eyeY - 3).toStringAsFixed(1)} Z" fill="${palette.face}"/>'
          '<path d="M ${(leftEyeX + 6).toStringAsFixed(1)} ${(eyeY - 2).toStringAsFixed(1)} L ${(rightEyeX - 6).toStringAsFixed(1)} ${(eyeY - 2).toStringAsFixed(1)}" stroke="${palette.face}" stroke-width="2.5"/>',
        );
        break;

      case 5:
        // Wide Anime Eyes with Sparkle
        buffer.write(
          '<ellipse cx="${leftEyeX.toStringAsFixed(1)}" cy="${eyeY.toStringAsFixed(1)}" rx="4.8" ry="5.8"/>'
          '<ellipse cx="${rightEyeX.toStringAsFixed(1)}" cy="${eyeY.toStringAsFixed(1)}" rx="4.8" ry="5.8"/>'
          '<circle cx="${(leftEyeX + 1.5).toStringAsFixed(1)}" cy="${(eyeY - 2).toStringAsFixed(1)}" r="1.8" fill="#FFFFFF"/>'
          '<circle cx="${(leftEyeX - 1.5).toStringAsFixed(1)}" cy="${(eyeY + 2).toStringAsFixed(1)}" r="1.0" fill="#FFFFFF"/>'
          '<circle cx="${(rightEyeX + 1.5).toStringAsFixed(1)}" cy="${(eyeY - 2).toStringAsFixed(1)}" r="1.8" fill="#FFFFFF"/>'
          '<circle cx="${(rightEyeX - 1.5).toStringAsFixed(1)}" cy="${(eyeY + 2).toStringAsFixed(1)}" r="1.0" fill="#FFFFFF"/>',
        );
        break;

      default:
        // Sleepy / Relaxed Slits
        buffer.write(
          '<path d="M ${(leftEyeX - 4).toStringAsFixed(1)} ${eyeY.toStringAsFixed(1)} L ${(leftEyeX + 4).toStringAsFixed(1)} ${eyeY.toStringAsFixed(1)}" stroke="${palette.face}" stroke-width="2.8" stroke-linecap="round"/>'
          '<path d="M ${(rightEyeX - 4).toStringAsFixed(1)} ${eyeY.toStringAsFixed(1)} L ${(rightEyeX + 4).toStringAsFixed(1)} ${eyeY.toStringAsFixed(1)}" stroke="${palette.face}" stroke-width="2.8" stroke-linecap="round"/>',
        );
    }
    buffer.write('</g>');

    // 3. Mouth
    final mouthY = eyeY + 11.5;
    buffer.write('<g fill="${palette.face}">');
    switch (mouthStyle) {
      case 0:
        // Soft Curved Smile
        buffer.write(
          '<path d="M 44.5 ${(mouthY - 1).toStringAsFixed(1)} Q 50 ${(mouthY + 5).toStringAsFixed(1)} 55.5 ${(mouthY - 1).toStringAsFixed(1)}" stroke="${palette.face}" stroke-width="2.4" stroke-linecap="round" fill="none"/>',
        );
        break;

      case 1:
        // Open Joyful Grin with Tongue
        buffer.write(
          '<path d="M 43.5 ${mouthY.toStringAsFixed(1)} Q 50 ${(mouthY + 8).toStringAsFixed(1)} 56.5 ${mouthY.toStringAsFixed(1)} Z" fill="${palette.face}"/>'
          '<path d="M 46.5 ${(mouthY + 3.5).toStringAsFixed(1)} Q 50 ${(mouthY + 8).toStringAsFixed(1)} 53.5 ${(mouthY + 3.5).toStringAsFixed(1)} Z" fill="${palette.blush}"/>',
        );
        break;

      case 2:
        // Cat Mouth / ':3'
        buffer.write(
          '<path d="M 44 ${(mouthY).toStringAsFixed(1)} Q 47 ${(mouthY + 3.5).toStringAsFixed(1)} 50 ${mouthY.toStringAsFixed(1)} Q 53 ${(mouthY + 3.5).toStringAsFixed(1)} 56 ${mouthY.toStringAsFixed(1)}" stroke="${palette.face}" stroke-width="2.2" stroke-linecap="round" fill="none"/>',
        );
        break;

      case 3:
        // Surprised Cute 'o'
        buffer.write(
          '<ellipse cx="50" cy="${mouthY.toStringAsFixed(1)}" rx="3.0" ry="3.8"/>',
        );
        break;

      case 4:
        // Playful Smirk
        buffer.write(
          '<path d="M 45.5 ${(mouthY + 1).toStringAsFixed(1)} Q 51 ${(mouthY + 4).toStringAsFixed(1)} 55.5 ${(mouthY - 2).toStringAsFixed(1)}" stroke="${palette.face}" stroke-width="2.4" stroke-linecap="round" fill="none"/>',
        );
        break;

      default:
        // Neutral Tiny Smile
        buffer.write(
          '<path d="M 46.5 ${mouthY.toStringAsFixed(1)} Q 50 ${(mouthY + 3).toStringAsFixed(1)} 53.5 ${mouthY.toStringAsFixed(1)}" stroke="${palette.face}" stroke-width="2.2" stroke-linecap="round" fill="none"/>',
        );
    }
    buffer.write('</g>');

    return buffer.toString();
  }

  /// Generates optional head accessories (graduation cap, sprout, antenna, sparkles).
  static String _generateAccessory(_BlobRng rng, _BlobPalette palette) {
    final accType = rng.nextInt(6);
    final accentColor = palette.accent ?? '#FFD43B';

    switch (accType) {
      case 0:
        // Student Graduation / Academic Mortarboard Cap
        return '<g>'
            '<polygon points="50,14 74,21 50,28 26,21" fill="${palette.face}"/>'
            '<rect x="42" y="24" width="16" height="6" rx="2" fill="${palette.face}"/>'
            '<circle cx="50" cy="21" r="2.2" fill="$accentColor"/>'
            '<path d="M 68 22 Q 72 27 70 33" stroke="$accentColor" stroke-width="1.8" fill="none"/>'
            '<circle cx="70" cy="34" r="1.8" fill="$accentColor"/>'
            '</g>';

      case 1:
        // Plant Sprout / Leaf
        return '<g fill="#38D9A9">'
            '<path d="M 50 24 Q 40 15 50 11 Q 60 15 50 24 Z"/>'
            '<path d="M 50 24 Q 42 22 41 18 Q 48 18 50 24 Z" fill="#69DB7C"/>'
            '</g>';

      case 2:
        // Antenna with glowing star / orb
        return '<g>'
            '<path d="M 50 25 L 50 16" stroke="${palette.face}" stroke-width="2.5" stroke-linecap="round"/>'
            '<circle cx="50" cy="13" r="4.0" fill="$accentColor"/>'
            '</g>';

      case 3:
        // Sparkle / Star on the cheek or temple
        return '<g fill="$accentColor">'
            '<polygon points="26,30 28,34 32,36 28,38 26,42 24,38 20,36 24,34"/>'
            '</g>';

      default:
        // No accessory — clean, pure blob
        return '';
    }
  }
}

class _Point {
  final double x;
  final double y;
  const _Point(this.x, this.y);
}

/// Standalone Blobatar Widget for rendering cute organic avatars.
class Blobatar extends StatelessWidget {
  final String seed;
  final double size;
  final double? borderRadius;

  const Blobatar({
    super.key,
    required this.seed,
    this.size = 40,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final svgString = BlobatarGenerator.generateSvg(seed);
    final radius = borderRadius ?? (size / 2);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFF1EEFF),
        child: SvgPicture.string(
          svgString,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Smart Avatar Widget that respects the global `avatarStyleProvider` toggle.
/// Renders either Blobatar or Classic Initials CircleAvatar.
class AppAvatar extends ConsumerWidget {
  final String seed;
  final String name;
  final double size;
  final String? imageUrl;
  final Color? fallbackColor;
  final double? borderRadius;

  const AppAvatar({
    super.key,
    required this.seed,
    required this.name,
    this.size = 40,
    this.imageUrl,
    this.fallbackColor,
    this.borderRadius,
  });

  String _getInitials(String input) {
    final parts = input.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarStyle = ref.watch(avatarStyleProvider);
    final radius = borderRadius ?? (size / 2);

    // If an image URL is present, show network image
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(avatarStyle, radius),
        ),
      );
    }

    return _buildFallback(avatarStyle, radius);
  }

  Widget _buildFallback(String avatarStyle, double radius) {
    if (avatarStyle == 'blobatar') {
      return Blobatar(
        seed: seed.isNotEmpty ? seed : name,
        size: size,
        borderRadius: radius,
      );
    }

    // Classic Initials CircleAvatar
    final bgColor = fallbackColor ?? AppTheme.primaryPurple;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        _getInitials(name),
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}
