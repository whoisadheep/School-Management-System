import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/ui/widgets/blobatar.dart';

void main() {
  group('BlobatarGenerator Tests', () {
    test('Determinism: same seed produces identical SVG', () {
      final svg1 = BlobatarGenerator.generateSvg('ADM-2024-001');
      final svg2 = BlobatarGenerator.generateSvg('ADM-2024-001');
      expect(svg1, equals(svg2));
    });

    test('Different seeds produce different SVGs', () {
      final svgA = BlobatarGenerator.generateSvg('Alice');
      final svgB = BlobatarGenerator.generateSvg('Bob');
      expect(svgA, isNot(equals(svgB)));
    });

    test('Generates valid SVG wrapper and viewBox', () {
      final svg = BlobatarGenerator.generateSvg('student_test_123');
      expect(svg, startsWith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'));
      expect(svg, endsWith('</svg>'));
      expect(svg.contains('fill='), isTrue);
    });

    test('Handles edge cases without throwing', () {
      expect(() => BlobatarGenerator.generateSvg(''), returnsNormally);
      expect(() => BlobatarGenerator.generateSvg('   '), returnsNormally);
      expect(() => BlobatarGenerator.generateSvg('1234567890'), returnsNormally);
      expect(() => BlobatarGenerator.generateSvg('!@#\$%^&*()_+'), returnsNormally);
      expect(() => BlobatarGenerator.generateSvg('日本語・العربية・हिंदी'), returnsNormally);
    });

    test('Generates non-empty output for multiple unique seeds', () {
      for (int i = 0; i < 50; i++) {
        final svg = BlobatarGenerator.generateSvg('student_$i');
        expect(svg.length, greaterThan(100));
        expect(svg.contains('<svg'), isTrue);
      }
    });
  });
}
