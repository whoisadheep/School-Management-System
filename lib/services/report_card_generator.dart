import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';

/// Printable PDF Report Card Generator
class ReportCardGenerator {
  /// Generate a clean A4 PDF Student Progress Report Card
  static Future<File> generateReportCard({
    required ExamResultData examResult,
    int? rankInClass,
    String schoolName = 'Eduvia',
    String schoolAddress = '123 Education Boulevard, Academic District',
    String schoolContact = 'Phone: +1 800 555-0199 | Email: exams@school.edu',
  }) async {
    final pdf = pw.Document();
    final dateFormatter = DateFormat('dd MMM yyyy');

    final primaryColor = PdfColor.fromHex('#4C3BCF');
    final darkColor = PdfColor.fromHex('#1A1A2E');
    final greyColor = PdfColor.fromHex('#616161');
    final lightGrey = PdfColor.fromHex('#F8F9FA');
    final successColor = PdfColor.fromHex('#16A34A');
    final errorColor = PdfColor.fromHex('#DC2626');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Banner
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          schoolName,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          schoolAddress,
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                        ),
                        pw.Text(
                          schoolContact,
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'PROGRESS REPORT',
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Student & Exam Details Box
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _pdfInfoRow('Student Name:', examResult.studentName, darkColor, true),
                          pw.SizedBox(height: 4),
                          _pdfInfoRow('Roll Number:', examResult.rollNumber, darkColor),
                          pw.SizedBox(height: 4),
                          _pdfInfoRow('Class & Section:', '${examResult.className} - ${examResult.section ?? "A"}', darkColor),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _pdfInfoRow('Exam Title:', examResult.examName, darkColor, true),
                          pw.SizedBox(height: 4),
                          _pdfInfoRow('Academic Year:', examResult.academicYear, darkColor),
                          pw.SizedBox(height: 4),
                          _pdfInfoRow('Date Issued:', dateFormatter.format(DateTime.now()), darkColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Subject-wise Marks Table
              pw.Text(
                'SUBJECT PERFORMANCE BREAKDOWN',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#E0E0E0'), width: 0.8),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3), // Subject
                  1: const pw.FlexColumnWidth(2), // Max Marks
                  2: const pw.FlexColumnWidth(2), // Pass Marks
                  3: const pw.FlexColumnWidth(2), // Obtained
                  4: const pw.FlexColumnWidth(1.5), // Grade
                  5: const pw.FlexColumnWidth(2), // Status
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#EEEEEE')),
                    children: [
                      _pdfTableHeader('Subject'),
                      _pdfTableHeader('Max Marks'),
                      _pdfTableHeader('Pass Marks'),
                      _pdfTableHeader('Marks Obtained'),
                      _pdfTableHeader('Grade'),
                      _pdfTableHeader('Result'),
                    ],
                  ),
                  // Table Rows
                  ...examResult.subjectResults.map((s) {
                    final isPass = s.isPassed;
                    return pw.TableRow(
                      children: [
                        _pdfTableCell(s.subject, alignLeft: true, bold: true),
                        _pdfTableCell(s.maxMarks.toStringAsFixed(0)),
                        _pdfTableCell(s.passingMarks.toStringAsFixed(0)),
                        _pdfTableCell(s.isAbsent ? 'ABSENT' : (s.marksObtained?.toStringAsFixed(1) ?? 'N/A'),
                            color: s.isAbsent ? errorColor : darkColor),
                        _pdfTableCell(s.grade, bold: true),
                        _pdfTableCell(
                          isPass ? 'PASS' : 'FAIL',
                          color: isPass ? successColor : errorColor,
                          bold: true,
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),

              // Overall Performance Summary Card
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColor.fromHex('#D0D0D0')),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _pdfSummaryMetric('TOTAL MARKS', '${examResult.totalMarksObtained.toStringAsFixed(1)} / ${examResult.totalMaxMarks.toStringAsFixed(0)}'),
                    _pdfSummaryMetric('PERCENTAGE', '${examResult.percentage.toStringAsFixed(2)}%'),
                    _pdfSummaryMetric('OVERALL GRADE', examResult.grade),
                    _pdfSummaryMetric('ATTENDANCE', examResult.attendancePercent != null ? '${examResult.attendancePercent!.toStringAsFixed(1)}%' : 'N/A'),
                    _pdfSummaryMetric('CLASS RANK', rankInClass != null ? '$rankInClass' : 'N/A'),
                    _pdfSummaryMetric(
                      'FINAL RESULT',
                      examResult.isPassed ? 'PASSED' : 'FAILED',
                      textColor: examResult.isPassed ? successColor : errorColor,
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Signatures Footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 140, height: 1, color: greyColor),
                      pw.SizedBox(height: 4),
                      pw.Text('Class Teacher Signature', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 140, height: 1, color: greyColor),
                      pw.SizedBox(height: 4),
                      pw.Text('Principal Signature & Seal', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Save to App Documents directory
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String exportDir = p.join(appDocDir.path, 'Eduvia', 'ReportCards');
    final dir = Directory(exportDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final safeStudentName = examResult.studentName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final safeExamName = examResult.examName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final String fileName = 'ReportCard_${safeStudentName}_$safeExamName.pdf';
    final String fullPath = p.join(exportDir, fileName);

    final File file = File(fullPath);
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _pdfInfoRow(String label, String value, PdfColor textColor, [bool bold = false]) {
    return pw.Row(
      children: [
        pw.Text(
          '$label ',
          style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#616161'), fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            color: textColor,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  static pw.Widget _pdfTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#333333')),
      ),
    );
  }

  static pw.Widget _pdfTableCell(String text, {bool alignLeft = false, bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColor.fromHex('#333333'),
        ),
      ),
    );
  }

  static pw.Widget _pdfSummaryMetric(String label, String value, {PdfColor? textColor}) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#616161'), fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textColor ?? PdfColor.fromHex('#1A1A2E'))),
      ],
    );
  }
}
