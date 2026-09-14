import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

/// Renders assistant messages with rich typography, numbered step badges,
/// indented bullet points, callout tip boxes, and inline bold styling.
class FormattedAssistantMessageContent extends StatelessWidget {
  final String text;
  final bool isUser;

  const FormattedAssistantMessageContent({
    super.key,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return SelectableText(
        text,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (var i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      final trimmed = rawLine.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // 1. Tip / Callout Box (lines starting with 💡 or Tip: or Note:)
      if (trimmed.startsWith('💡') ||
          trimmed.toLowerCase().startsWith('tip:') ||
          trimmed.toLowerCase().startsWith('note:') ||
          trimmed.toLowerCase().startsWith('important:')) {
        widgets.add(_buildCalloutBox(trimmed));
        continue;
      }

      // 2. Headings (### or ## or #)
      if (trimmed.startsWith('#')) {
        final headingText = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
        widgets.add(_buildHeading(headingText));
        continue;
      }

      // 3. Numbered Step (e.g. "1. ", "2. ", "10. ")
      final stepMatch = RegExp(r'^(\d+)\.\s+(.*)').firstMatch(trimmed);
      if (stepMatch != null) {
        final stepNumber = stepMatch.group(1)!;
        final stepContent = stepMatch.group(2)!;
        widgets.add(_buildStepRow(stepNumber, stepContent));
        continue;
      }

      // 4. Sub-bullet / Bullet Point (indented or starting with - or * or •)
      final isSubBullet = rawLine.startsWith('   -') || rawLine.startsWith('    -') || rawLine.startsWith('\t-');
      final bulletMatch = RegExp(r'^\s*[-*•]\s+(.*)').firstMatch(rawLine);
      if (bulletMatch != null) {
        final bulletContent = bulletMatch.group(1)!;
        widgets.add(_buildBulletRow(bulletContent, isSubBullet: isSubBullet));
        continue;
      }

      // 5. Standard Paragraph Text
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: SelectableText.rich(
          _parseInlineFormatting(trimmed),
          style: GoogleFonts.poppins(
            color: AppTheme.textPrimary,
            fontSize: 13.5,
            height: 1.55,
          ),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget _buildStepRow(String number, String content) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: SelectableText.rich(
              _parseInlineFormatting(content),
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                height: 1.55,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletRow(String content, {bool isSubBullet = false}) {
    return Padding(
      padding: EdgeInsets.only(
        left: isSubBullet ? 34.0 : 12.0,
        top: 2.0,
        bottom: 2.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isSubBullet ? 5 : 6,
            height: isSubBullet ? 5 : 6,
            margin: EdgeInsets.only(right: 10, top: isSubBullet ? 8 : 7),
            decoration: BoxDecoration(
              color: isSubBullet ? AppTheme.primaryPurple.withValues(alpha: 0.6) : AppTheme.primaryPurple,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: SelectableText.rich(
              _parseInlineFormatting(content),
              style: GoogleFonts.poppins(
                fontSize: isSubBullet ? 12.5 : 13.5,
                height: 1.5,
                color: isSubBullet ? AppTheme.textSecondary : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeading(String headingText) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SelectableText.rich(
              _parseInlineFormatting(headingText),
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalloutBox(String calloutText) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // soft mint green/emerald tint
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8, top: 2),
            child: Icon(Icons.lightbulb_rounded, size: 16, color: Color(0xFF16A34A)),
          ),
          Expanded(
            child: SelectableText.rich(
              _parseInlineFormatting(calloutText.replaceFirst(RegExp(r'^[💡\s]+'), '')),
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                height: 1.5,
                color: const Color(0xFF166534),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Parses markdown tokens like **bold text** and `code` into a styled TextSpan.
  TextSpan _parseInlineFormatting(String text) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'(\*\*.*?\*\*|`.*?`)');
    final matches = pattern.allMatches(text);

    var lastIndex = 0;
    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      final matchedStr = match.group(0)!;
      if (matchedStr.startsWith('**') && matchedStr.endsWith('**') && matchedStr.length >= 4) {
        final inner = matchedStr.substring(2, matchedStr.length - 2);
        spans.add(TextSpan(
          text: inner,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryPurple,
          ),
        ));
      } else if (matchedStr.startsWith('`') && matchedStr.endsWith('`') && matchedStr.length >= 2) {
        final inner = matchedStr.substring(1, matchedStr.length - 1);
        spans.add(TextSpan(
          text: inner,
          style: const TextStyle(
            fontFamily: 'monospace',
            backgroundColor: Color(0xFFE2E8F0),
            color: Color(0xFF334155),
            fontSize: 12,
          ),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return TextSpan(children: spans);
  }
}
