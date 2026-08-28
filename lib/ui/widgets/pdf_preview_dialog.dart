import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_theme.dart';

/// A reusable full-screen dialog that shows a live PDF preview
/// with options to Print, Save to file, or Cancel.
///
/// Usage:
/// ```dart
/// final saved = await PdfPreviewDialog.show(
///   context: context,
///   title: 'Payment Receipt',
///   pdfBytes: myPdfBytes,
///   defaultFileName: 'Receipt_001.pdf',
///   defaultSubDirectory: 'Receipts',
/// );
/// ```
class PdfPreviewDialog extends StatelessWidget {
  final String title;
  final Uint8List pdfBytes;
  final String defaultFileName;
  final String defaultSubDirectory;

  const PdfPreviewDialog({
    super.key,
    required this.title,
    required this.pdfBytes,
    required this.defaultFileName,
    this.defaultSubDirectory = 'Documents',
  });

  /// Show the preview dialog. Returns the saved [File] if the user confirmed
  /// save, or null if they cancelled.
  static Future<File?> show({
    required BuildContext context,
    required String title,
    required Uint8List pdfBytes,
    required String defaultFileName,
    String defaultSubDirectory = 'Documents',
  }) {
    return showDialog<File?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PdfPreviewDialog(
        title: title,
        pdfBytes: pdfBytes,
        defaultFileName: defaultFileName,
        defaultSubDirectory: defaultSubDirectory,
      ),
    );
  }

  Future<File> _savePdf() async {
    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final String dirPath = p.join(documentsDir.path, 'Eduvia', defaultSubDirectory);
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dirPath, defaultFileName));
    await file.writeAsBytes(pdfBytes);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: AppTheme.bgMain,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close Preview',
            onPressed: () => Navigator.of(context).pop(null),
          ),
          title: Row(
            children: [
              const Icon(Icons.picture_as_pdf_rounded, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          actions: [
            // ── Print Button ──
            _ActionButton(
              icon: Icons.print_rounded,
              label: 'Print',
              color: Colors.white,
              textColor: AppTheme.primaryPurple,
              onPressed: () async {
                await Printing.layoutPdf(
                  onLayout: (_) => pdfBytes,
                  name: defaultFileName,
                );
              },
            ),
            const SizedBox(width: 8),

            // ── Save & Close Button ──
            _ActionButton(
              icon: Icons.save_alt_rounded,
              label: 'Save PDF',
              color: AppTheme.success,
              textColor: Colors.white,
              onPressed: () async {
                final file = await _savePdf();
                if (context.mounted) {
                  Navigator.of(context).pop(file);
                }
              },
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: PdfPreview(
          build: (_) => pdfBytes,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: true,
          allowPrinting: false, // We handle printing via our own button
          pdfFileName: defaultFileName,
          loadingWidget: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: AppTheme.primaryPurple,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Rendering preview…',
                  style: GoogleFonts.poppins(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
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

/// Internal styled action button for the AppBar.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
