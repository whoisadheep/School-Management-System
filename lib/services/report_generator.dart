import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';

/// PDF Report Generator utility to generate A4-sized fee payment receipts
/// and save them to the local Windows Documents directory.
class ReportGenerator {
  /// Generate an A4-sized PDF receipt for a payment transaction and save to Documents directory.
  ///
  /// Returns the saved [File] object pointing to the generated PDF.
  /// Build raw PDF bytes for a payment receipt (for preview).
  static Future<Uint8List> buildPaymentReceiptPdfBytes({
    Uint8List? schoolLogo,
    required Transaction transaction,
    required Invoice invoice,
    required Student student,
    String? receiptNumber,
    String? feeHeadName,
    String schoolName = 'Eduvia',
    String schoolAddress = '123 Education Boulevard, Academic District',
    String schoolContact = 'Phone: +1 800 555-0199 | Email: finance@school.edu',
  }) async {
    final pdf = pw.Document();

    final formattedReceiptNumber = receiptNumber ?? 'RCT-${transaction.timestamp.year}-${transaction.id.substring(0, 4).toUpperCase()}';
    final currencyFormatter = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 2);
    final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');

    final primaryColor = PdfColor.fromHex('#4C3BCF');
    final darkColor = PdfColor.fromHex('#1A1A2E');
    final greyColor = PdfColor.fromHex('#616161');
    final lightGrey = PdfColor.fromHex('#F8F9FA');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              // ── Top Half: Student 1 (1/4 Parent Copy & 2/4 Office Copy) ──
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildQuadrantSingleReceiptCard(
                      copyTitle: 'STUDENT / PARENT (1/4)',
                      schoolLogo: schoolLogo,
                      schoolName: schoolName,
                      schoolAddress: schoolAddress,
                      schoolContact: schoolContact,
                      transaction: transaction,
                      invoice: invoice,
                      student: student,
                      formattedReceiptNumber: formattedReceiptNumber,
                      feeHeadName: feeHeadName,
                      dateFormatter: dateFormatter,
                      currencyFormatter: currencyFormatter,
                      primaryColor: primaryColor,
                      darkColor: darkColor,
                      greyColor: greyColor,
                      lightGrey: lightGrey,
                    ),
                  ),
                  _buildVerticalPerforationDivider(height: 385),
                  pw.Expanded(
                    child: _buildQuadrantSingleReceiptCard(
                      copyTitle: 'OFFICE RECORD (2/4)',
                      schoolLogo: schoolLogo,
                      schoolName: schoolName,
                      schoolAddress: schoolAddress,
                      schoolContact: schoolContact,
                      transaction: transaction,
                      invoice: invoice,
                      student: student,
                      formattedReceiptNumber: formattedReceiptNumber,
                      feeHeadName: feeHeadName,
                      dateFormatter: dateFormatter,
                      currencyFormatter: currencyFormatter,
                      primaryColor: primaryColor,
                      darkColor: darkColor,
                      greyColor: greyColor,
                      lightGrey: lightGrey,
                    ),
                  ),
                ],
              ),
              _buildHorizontalPerforationDivider(),
              // ── Bottom Half: Clean Blank Reusable Paper (3/4 & 4/4) ──
              _buildBlankReusableHalf(height: 385),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// Vertical portrait receipt card (occupying 1/4 quadrant of an A4 page).
  static pw.Widget _buildQuadrantSingleReceiptCard({
    required String copyTitle,
    Uint8List? schoolLogo,
    required String schoolName,
    required String schoolAddress,
    required String schoolContact,
    required Transaction transaction,
    required Invoice invoice,
    required Student student,
    required String formattedReceiptNumber,
    String? feeHeadName,
    required DateFormat dateFormatter,
    required NumberFormat currencyFormatter,
    required PdfColor primaryColor,
    required PdfColor darkColor,
    required PdfColor greyColor,
    required PdfColor lightGrey,
  }) {
    final isPaidFull = (student.currentBalance - transaction.amountPaid) <= 0;

    return pw.Container(
      height: 385,
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Header Section ──
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (schoolLogo != null) ...[
                        pw.Container(
                          width: 28,
                          height: 28,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                          ),
                          padding: const pw.EdgeInsets.all(1.5),
                          child: pw.Image(
                            pw.MemoryImage(schoolLogo),
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                        pw.SizedBox(width: 6),
                      ],
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              schoolName,
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 10.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              maxLines: 1,
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              schoolAddress,
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 6.8,
                              ),
                              maxLines: 1,
                            ),
                            pw.Text(
                              schoolContact,
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 6.8,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        copyTitle,
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontSize: 7.2,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'FEE RECEIPT',
                        style: pw.TextStyle(
                          color: darkColor,
                          fontSize: 6.2,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 6),

          // ── Student & Receipt Meta Data ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left: Student Info
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: lightGrey,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'STUDENT DETAILS',
                        style: pw.TextStyle(
                          fontSize: 6.8,
                          fontWeight: pw.FontWeight.bold,
                          color: greyColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                      pw.Divider(thickness: 0.5, color: PdfColors.grey300, height: 4),
                      pw.Text(
                        student.name,
                        style: pw.TextStyle(
                          fontSize: 9.2,
                          fontWeight: pw.FontWeight.bold,
                          color: darkColor,
                        ),
                        maxLines: 1,
                      ),
                      pw.SizedBox(height: 1.5),
                      pw.Text(
                        'Grade: ${student.gradeLevel}',
                        style: pw.TextStyle(fontSize: 7.2, color: darkColor),
                        maxLines: 1,
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Student ID: ${student.id.substring(0, student.id.length > 8 ? 8 : student.id.length)}',
                        style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey700),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(width: 5),

              // Right: Receipt Meta
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: lightGrey,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RECEIPT DETAILS',
                        style: pw.TextStyle(
                          fontSize: 6.8,
                          fontWeight: pw.FontWeight.bold,
                          color: greyColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                      pw.Divider(thickness: 0.5, color: PdfColors.grey300, height: 4),
                      pw.Text(
                        formattedReceiptNumber,
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkColor),
                        maxLines: 1,
                      ),
                      pw.SizedBox(height: 1.5),
                      pw.Text(
                        dateFormatter.format(transaction.timestamp),
                        style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey800),
                        maxLines: 1,
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Mode: ${transaction.paymentMethod.displayName}',
                        style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: darkColor),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 6),

          // ── Payment Details Table ──
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.6),
              1: const pw.FlexColumnWidth(4.4),
              2: const pw.FlexColumnWidth(3.0),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: primaryColor),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                    child: pw.Text('Invoice ID', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.2)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                    child: pw.Text('Description', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.2)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                    child: pw.Text('Amount Paid', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.2), textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: pw.Text(invoice.id.substring(0, invoice.id.length > 8 ? 8 : invoice.id.length).toUpperCase(), style: const pw.TextStyle(fontSize: 7.2)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: pw.Text(feeHeadName ?? invoice.notes ?? 'School Fee Invoice', style: const pw.TextStyle(fontSize: 7.2), maxLines: 1),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: pw.Text(currencyFormatter.format(transaction.amountPaid), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 6),

          // ── Summary Row with Status Badge & Totals ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left: Payment Status Pill
              pw.Expanded(
                flex: 4,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: isPaidFull ? PdfColors.green50 : PdfColors.orange50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    border: pw.Border.all(
                      color: isPaidFull ? PdfColors.green300 : PdfColors.orange300,
                      width: 0.5,
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        isPaidFull ? 'STATUS: PAID' : 'STATUS: PARTIAL',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: isPaidFull ? PdfColors.green800 : PdfColors.orange800,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Payment received with thanks.',
                        style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 5),
              // Right: Totals Card
              pw.Expanded(
                flex: 6,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: lightGrey,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Invoice Total:', style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey700)),
                          pw.Text(currencyFormatter.format(invoice.totalAmount), style: const pw.TextStyle(fontSize: 6.8)),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Amount Paid Now:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                            currencyFormatter.format(transaction.amountPaid),
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                          ),
                        ],
                      ),
                      pw.Divider(thickness: 0.5, height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Remaining Balance:', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                            currencyFormatter.format(student.currentBalance - transaction.amountPaid),
                            style: pw.TextStyle(
                              fontSize: 6.8,
                              fontWeight: pw.FontWeight.bold,
                              color: (student.currentBalance - transaction.amountPaid) > 0 ? PdfColors.red800 : PdfColors.green800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.Spacer(),

          // ── Note ──
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: pw.BoxDecoration(
              color: lightGrey,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  'Note: Fees once paid are non-refundable. Please keep this receipt for records.',
                  style: pw.TextStyle(fontSize: 5.5, color: greyColor, fontStyle: pw.FontStyle.italic),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 8),

          // ── Footer & Signatures ──
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 85, height: 0.6, color: PdfColors.grey400),
                  pw.SizedBox(height: 2),
                  pw.Text('Parent / Guardian', style: pw.TextStyle(fontSize: 6.5, color: greyColor)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(width: 85, height: 0.6, color: PdfColors.grey400),
                  pw.SizedBox(height: 2),
                  pw.Text('Authorized Cashier / Stamp', style: pw.TextStyle(fontSize: 6.5, color: greyColor)),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'Computer-generated receipt issued by $schoolName.',
              style: pw.TextStyle(fontSize: 5.5, color: greyColor, fontStyle: pw.FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  /// Vertical dashed perforation line dividing the Parent Copy (1/4) and Office Copy (2/4).
  static pw.Widget _buildVerticalPerforationDivider({double height = 385}) {
    return pw.Container(
      height: height,
      width: 14,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.VerticalDivider(
              thickness: 0.8,
              color: PdfColors.grey400,
              borderStyle: pw.BorderStyle.dashed,
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              color: PdfColors.white,
            ),
            child: pw.Text(
              'CUT',
              style: pw.TextStyle(
                fontSize: 5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.VerticalDivider(
              thickness: 0.8,
              color: PdfColors.grey400,
              borderStyle: pw.BorderStyle.dashed,
            ),
          ),
        ],
      ),
    );
  }

  /// Horizontal cut line dividing the top half (1/4 & 2/4) from the bottom half (3/4 & 4/4).
  static pw.Widget _buildHorizontalPerforationDivider() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Divider(
              thickness: 0.8,
              color: PdfColors.grey400,
              borderStyle: pw.BorderStyle.dashed,
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              color: PdfColors.white,
            ),
            child: pw.Text(
              '- - - - - -  CUT ALONG LINE TO REUSE BOTTOM HALF (3/4 & 4/4) FOR NEXT RECEIPT  - - - - - -',
              style: pw.TextStyle(
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Divider(
              thickness: 0.8,
              color: PdfColors.grey400,
              borderStyle: pw.BorderStyle.dashed,
            ),
          ),
        ],
      ),
    );
  }

  /// Blank bottom half (Quadrants 3/4 & 4/4) so paper can be cut along the divider
  /// and fed back into the printer tray for another student.
  static pw.Widget _buildBlankReusableHalf({double height = 385}) {
    return pw.SizedBox(
      height: height,
    );
  }

  /// Build raw PDF bytes for a unified batch payment receipt (supporting multiple fees/months).
  /// Renders 2 copies on a single A4 page: Top half for Parent, Bottom half for Office.
  static Future<Uint8List> buildBatchPaymentReceiptPdfBytes({
    Uint8List? schoolLogo,
    required List<StudentFeeLedger> paidLedgers,
    required Student student,
    required double totalAmountPaid,
    required PaymentMethod paymentMethod,
    String? referenceNumber,
    String? receiptNumber,
    String? academicYear,
    String schoolName = 'Eduvia Public School',
    String schoolAddress = '123 Education Boulevard, Academic District',
    String schoolContact = 'Phone: +91 9876543210 | Email: finance@school.edu',
  }) async {
    final pdf = pw.Document();

    final formattedReceiptNumber = receiptNumber ?? 'RCT-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final currencyFormatter = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 2);
    final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');

    final primaryColor = PdfColor.fromHex('#4C3BCF');
    final darkColor = PdfColor.fromHex('#1A1A2E');
    final greyColor = PdfColor.fromHex('#616161');
    final lightGrey = PdfColor.fromHex('#F8F9FA');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              // ── Top Half: Student 1 (1/4 Parent Copy & 2/4 Office Copy) ──
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildQuadrantBatchReceiptCard(
                      copyTitle: 'STUDENT / PARENT (1/4)',
                      schoolLogo: schoolLogo,
                      schoolName: schoolName,
                      schoolAddress: schoolAddress,
                      schoolContact: schoolContact,
                      academicYear: academicYear,
                      student: student,
                      formattedReceiptNumber: formattedReceiptNumber,
                      dateFormatter: dateFormatter,
                      paymentMethod: paymentMethod,
                      referenceNumber: referenceNumber,
                      paidLedgers: paidLedgers,
                      totalAmountPaid: totalAmountPaid,
                      currencyFormatter: currencyFormatter,
                      primaryColor: primaryColor,
                      darkColor: darkColor,
                      greyColor: greyColor,
                      lightGrey: lightGrey,
                    ),
                  ),
                  _buildVerticalPerforationDivider(height: 385),
                  pw.Expanded(
                    child: _buildQuadrantBatchReceiptCard(
                      copyTitle: 'OFFICE RECORD (2/4)',
                      schoolLogo: schoolLogo,
                      schoolName: schoolName,
                      schoolAddress: schoolAddress,
                      schoolContact: schoolContact,
                      academicYear: academicYear,
                      student: student,
                      formattedReceiptNumber: formattedReceiptNumber,
                      dateFormatter: dateFormatter,
                      paymentMethod: paymentMethod,
                      referenceNumber: referenceNumber,
                      paidLedgers: paidLedgers,
                      totalAmountPaid: totalAmountPaid,
                      currencyFormatter: currencyFormatter,
                      primaryColor: primaryColor,
                      darkColor: darkColor,
                      greyColor: greyColor,
                      lightGrey: lightGrey,
                    ),
                  ),
                ],
              ),
              _buildHorizontalPerforationDivider(),
              // ── Bottom Half: Clean Blank Reusable Paper (3/4 & 4/4) ──
              _buildBlankReusableHalf(height: 385),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// Vertical portrait receipt card for batch payment (occupying 1/4 quadrant of an A4 page).
  static pw.Widget _buildQuadrantBatchReceiptCard({
    required String copyTitle,
    Uint8List? schoolLogo,
    required String schoolName,
    required String schoolAddress,
    required String schoolContact,
    String? academicYear,
    required Student student,
    required String formattedReceiptNumber,
    required DateFormat dateFormatter,
    required PaymentMethod paymentMethod,
    String? referenceNumber,
    required List<StudentFeeLedger> paidLedgers,
    required double totalAmountPaid,
    required NumberFormat currencyFormatter,
    required PdfColor primaryColor,
    required PdfColor darkColor,
    required PdfColor greyColor,
    required PdfColor lightGrey,
  }) {
    final consolidatedLedgers = ConsolidatedFeeItem.consolidate(paidLedgers);

    // Show max 4 rows in table to guarantee fitting perfectly within quadrant
    final displayLedgers = consolidatedLedgers.length <= 4
        ? consolidatedLedgers
        : consolidatedLedgers.sublist(0, 3);
    final remainingCount = consolidatedLedgers.length - displayLedgers.length;
    final remainingSum = remainingCount > 0
        ? consolidatedLedgers.sublist(3).fold<double>(0.0, (sum, l) => sum + (l.amountPaid > 0 ? l.amountPaid : l.amountDue))
        : 0.0;

    final isPaidFull = (student.currentBalance - totalAmountPaid) <= 0;

    return pw.Container(
      height: 385,
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Header Section ──
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (schoolLogo != null) ...[
                        pw.Container(
                          width: 28,
                          height: 28,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                          ),
                          padding: const pw.EdgeInsets.all(1.5),
                          child: pw.Image(
                            pw.MemoryImage(schoolLogo),
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                        pw.SizedBox(width: 6),
                      ],
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              schoolName,
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 10.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              maxLines: 1,
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              schoolAddress,
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 6.8,
                              ),
                              maxLines: 1,
                            ),
                            pw.Text(
                              schoolContact,
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 6.8,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        copyTitle,
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontSize: 7.2,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        academicYear != null ? 'RECEIPT - $academicYear' : 'FEE RECEIPT',
                        style: pw.TextStyle(
                          color: darkColor,
                          fontSize: 6.2,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 6),

          // ── Receipt & Student Meta Data Grid ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left: Student Info
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: lightGrey,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'STUDENT DETAILS',
                        style: pw.TextStyle(
                          fontSize: 6.8,
                          fontWeight: pw.FontWeight.bold,
                          color: greyColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                      pw.Divider(thickness: 0.5, color: PdfColors.grey300, height: 4),
                      pw.Text(
                        student.name,
                        style: pw.TextStyle(
                          fontSize: 9.2,
                          fontWeight: pw.FontWeight.bold,
                          color: darkColor,
                        ),
                        maxLines: 1,
                      ),
                      pw.SizedBox(height: 1.5),
                      pw.Text(
                        'Class: ${student.gradeLevel} ${student.section != null ? "- ${student.section}" : ""}',
                        style: pw.TextStyle(fontSize: 7.2, color: darkColor),
                        maxLines: 1,
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Adm No: ${student.admissionNumber ?? "N/A"}   Roll: ${student.rollNumber ?? "N/A"}',
                        style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey700),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(width: 5),

              // Right: Receipt Meta
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: lightGrey,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TRANSACTION DETAILS',
                        style: pw.TextStyle(
                          fontSize: 6.8,
                          fontWeight: pw.FontWeight.bold,
                          color: greyColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                      pw.Divider(thickness: 0.5, color: PdfColors.grey300, height: 4),
                      pw.Text(
                        formattedReceiptNumber,
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkColor),
                        maxLines: 1,
                      ),
                      pw.SizedBox(height: 1.5),
                      pw.Text(
                        dateFormatter.format(DateTime.now()),
                        style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey800),
                        maxLines: 1,
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Mode: ${paymentMethod.displayName}',
                        style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: darkColor),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 6),

          // ── Payment Details Table ──
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.7),
              1: const pw.FlexColumnWidth(3.8),
              2: const pw.FlexColumnWidth(2.9),
              3: const pw.FlexColumnWidth(2.6),
            },
            children: [
              // Table Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: primaryColor),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3.5),
                    child: pw.Text('#', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.2), textAlign: pw.TextAlign.center),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                    child: pw.Text('Fee Head', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.2)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                    child: pw.Text('Period', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.2)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                    child: pw.Text('Amount', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.2), textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              // Table Body Rows
              ...displayLedgers.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final item = entry.value;
                final headName = item.feeHeadName;
                final month = item.periodLabel;
                final isEven = idx % 2 == 0;

                return pw.TableRow(
                  decoration: isEven ? pw.BoxDecoration(color: lightGrey) : null,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                      child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 7.2), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: pw.Text(headName, style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold), maxLines: 1),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: pw.Text(month, style: const pw.TextStyle(fontSize: 7.2), maxLines: 1),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: pw.Text(
                        currencyFormatter.format(item.amountPaid > 0 ? item.amountPaid : item.amountDue),
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                );
              }),
              if (remainingCount > 0) ...[
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightGrey),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                      child: pw.Text('+', style: const pw.TextStyle(fontSize: 7.2), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: pw.Text('Other ($remainingCount fees)', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: pw.Text('Multiple schedules', style: const pw.TextStyle(fontSize: 7.2)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: pw.Text(
                        currencyFormatter.format(remainingSum),
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),

          pw.SizedBox(height: 6),

          // ── Summary Row with Status Badge & Totals ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left: Payment Status Pill & Reference
              pw.Expanded(
                flex: 4,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: isPaidFull ? PdfColors.green50 : PdfColors.orange50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    border: pw.Border.all(
                      color: isPaidFull ? PdfColors.green300 : PdfColors.orange300,
                      width: 0.5,
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        isPaidFull ? 'STATUS: PAID' : 'STATUS: PARTIAL',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: isPaidFull ? PdfColors.green800 : PdfColors.orange800,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      if (referenceNumber != null && referenceNumber.trim().isNotEmpty) ...[
                        pw.Text(
                          'Ref: $referenceNumber',
                          style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: darkColor),
                          maxLines: 1,
                        ),
                        pw.SizedBox(height: 1),
                      ],
                      pw.Text(
                        'Payment received with thanks.',
                        style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 5),
              // Right: Totals Card
              pw.Expanded(
                flex: 6,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: lightGrey,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Items: ${paidLedgers.length}', style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey700)),
                          pw.Text('Total Paid Now:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                            currencyFormatter.format(totalAmountPaid),
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                          ),
                        ],
                      ),
                      pw.Divider(thickness: 0.5, height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Remaining Balance:', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                            currencyFormatter.format(student.currentBalance - totalAmountPaid),
                            style: pw.TextStyle(
                              fontSize: 6.8,
                              fontWeight: pw.FontWeight.bold,
                              color: (student.currentBalance - totalAmountPaid) > 0 ? PdfColors.red800 : PdfColors.green800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.Spacer(),

          // ── Note ──
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: pw.BoxDecoration(
              color: lightGrey,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  'Note: Fees once paid are non-refundable. Please keep this receipt for records.',
                  style: pw.TextStyle(fontSize: 5.5, color: greyColor, fontStyle: pw.FontStyle.italic),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 8),

          // ── Footer & Signatures ──
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 85, height: 0.6, color: PdfColors.grey400),
                  pw.SizedBox(height: 2),
                  pw.Text('Parent / Guardian', style: pw.TextStyle(fontSize: 6.5, color: greyColor)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(width: 85, height: 0.6, color: PdfColors.grey400),
                  pw.SizedBox(height: 2),
                  pw.Text('Authorized Cashier / Stamp', style: pw.TextStyle(fontSize: 6.5, color: greyColor)),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'Computer-generated receipt issued by $schoolName.',
              style: pw.TextStyle(fontSize: 5.5, color: greyColor, fontStyle: pw.FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  /// Generate an A4-sized PDF receipt and save to Documents directory.
  ///
  /// Returns the saved [File] object pointing to the generated PDF.
  static Future<File> generatePaymentReceipt({
    Uint8List? schoolLogo,
    required Transaction transaction,
    required Invoice invoice,
    required Student student,
    String? receiptNumber,
    String? feeHeadName,
    String? customExportDirectory,
    String schoolName = 'Eduvia',
    String schoolAddress = '123 Education Boulevard, Academic District',
    String schoolContact = 'Phone: +1 800 555-0199 | Email: finance@school.edu',
  }) async {
    final bytes = await buildPaymentReceiptPdfBytes(
      transaction: transaction,
      invoice: invoice,
      student: student,
      receiptNumber: receiptNumber,
      feeHeadName: feeHeadName,
      schoolLogo: schoolLogo,
      schoolName: schoolName,
      schoolAddress: schoolAddress,
      schoolContact: schoolContact,
    );

    // Save PDF directly to configured receipt export path
    String receiptsFolderPath = customExportDirectory ?? '';
    if (receiptsFolderPath.isEmpty) {
      final Directory documentsDir = await getApplicationDocumentsDirectory();
      receiptsFolderPath = p.join(documentsDir.path, 'Eduvia', 'Receipts');
    }

    final receiptsDir = Directory(receiptsFolderPath);
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final String receiptFileName = 'Receipt_${transaction.id.substring(0, 8)}.pdf';
    final String fullPath = p.join(receiptsFolderPath, receiptFileName);

    final File file = File(fullPath);
    await file.writeAsBytes(bytes);

    return file;
  }

  /// Build raw PDF bytes for a Student ID Card (for preview).
  static Future<Uint8List> buildStudentIdCardPdfBytes({
    Uint8List? schoolLogo,
    required Student student,
    String schoolName = 'Eduvia',
    String schoolAddress = '123 Education Boulevard, Academic District',
    String schoolContact = 'Phone: +1 800 555-0199',
  }) async {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromHex('#1A73E8');
    final darkColor = PdfColor.fromHex('#1A1A2E');
    final greyColor = PdfColor.fromHex('#616161');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Container(
              width: 250,
              height: 380,
              decoration: pw.BoxDecoration(
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                border: pw.Border.all(color: primaryColor, width: 2),
                color: PdfColors.white,
              ),
              child: pw.Column(
                children: [
                  // Card Header
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(10),
                        topRight: pw.Radius.circular(10),
                      ),
                    ),
                    child: pw.Column(
                      children: [
                        if (schoolLogo != null) ...[
                          pw.Container(
                            width: 32,
                            height: 32,
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.white,
                              shape: pw.BoxShape.circle,
                            ),
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Image(
                              pw.MemoryImage(schoolLogo),
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                        ],
                        pw.Text(
                          schoolName,
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'STUDENT IDENTITY CARD',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // Student Photo Container
                  pw.Container(
                    width: 70,
                    height: 70,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: primaryColor, width: 2),
                      color: PdfColors.grey200,
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                        style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 10),

                  // Student Name & Grade
                  pw.Text(
                    '${student.firstName ?? student.name} ${student.lastName ?? ""}'.trim(),
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkColor),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      '${student.gradeLevel} ${student.section != null ? "- Sec ${student.section}" : ""}',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor),
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // Details Grid
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16),
                    child: pw.Column(
                      children: [
                        _buildIdRow('Admission No:', student.admissionNumber ?? 'N/A'),
                        _buildIdRow('Roll Number:', student.rollNumber ?? 'N/A'),
                        _buildIdRow('Date of Birth:', student.dob ?? 'N/A'),
                        _buildIdRow('Blood Group:', student.bloodGroup ?? 'N/A'),
                        _buildIdRow('Emergency Ph:', student.guardianPhone ?? student.fatherPhone ?? 'N/A'),
                      ],
                    ),
                  ),
                  pw.Spacer(),

                  // Card Footer / Barcode Placeholder
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.only(
                        bottomLeft: pw.Radius.circular(10),
                        bottomRight: pw.Radius.circular(10),
                      ),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          '||| || |||| | ||||| ||| ||||',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 2),
                        ),
                        pw.Text(
                          schoolContact,
                          style: pw.TextStyle(fontSize: 6, color: greyColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// Generate a printable PDF Student ID Card and save to Documents.
  static Future<File> generateStudentIdCard({
    Uint8List? schoolLogo,
    required Student student,
    String schoolName = 'Eduvia',
    String schoolAddress = '123 Education Boulevard, Academic District',
    String schoolContact = 'Phone: +1 800 555-0199',
  }) async {
    final bytes = await buildStudentIdCardPdfBytes(
      student: student,
      schoolLogo: schoolLogo,
      schoolName: schoolName,
      schoolAddress: schoolAddress,
      schoolContact: schoolContact,
    );

    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final String idCardsDirPath = p.join(documentsDir.path, 'Eduvia', 'ID_Cards');
    final idCardsDir = Directory(idCardsDirPath);
    if (!await idCardsDir.exists()) {
      await idCardsDir.create(recursive: true);
    }

    final String fileName = 'ID_Card_${student.admissionNumber ?? student.id.substring(0, 6)}.pdf';
    final File file = File(p.join(idCardsDirPath, fileName));
    await file.writeAsBytes(bytes);

    return file;
  }

  static pw.Widget _buildIdRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  /// Build raw PDF bytes for a Transfer Certificate (for preview).
  static Future<Uint8List> buildTransferCertificatePdfBytes({
    Uint8List? schoolLogo,
    required Student student,
    required String tcNumber,
    required String tcDate,
    required String reasonForLeaving,
    String schoolName = 'Eduvia',
    String schoolAddress = '123 Education Boulevard, Academic District',
    String affiliationNo = 'AFF-CBSE-2024-99881',
  }) async {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromHex('#1A73E8');
    final greyColor = PdfColor.fromHex('#616161');

    final dateFormatter = DateFormat('dd MMMM yyyy');
    final issueDateStr = dateFormatter.format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Certificate Header Border Frame
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: primaryColor, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    if (schoolLogo != null) ...[
                      pw.Container(
                        width: 48,
                        height: 48,
                        child: pw.Image(
                          pw.MemoryImage(schoolLogo),
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                    ],
                    pw.Text(
                      schoolName,
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      schoolAddress,
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text(
                      'Affiliation No: $affiliationNo',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 12),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'TRANSFER / SCHOOL LEAVING CERTIFICATE',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Meta Header Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TC No: $tcNumber', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Admission No: ${student.admissionNumber ?? "N/A"}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: $issueDateStr', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 16),

              // Details List
              _buildTcFieldRow('1. Full Name of Student:', '${student.firstName ?? student.name} ${student.lastName ?? ""}'.trim()),
              _buildTcFieldRow('2. Mother\'s Name:', student.motherName ?? '—'),
              _buildTcFieldRow('3. Father\'s / Guardian\'s Name:', student.fatherName ?? student.motherName ?? '—'),
              _buildTcFieldRow('4. Nationality & Religion:', 'Indian / ${student.religion ?? "General"}'),
              _buildTcFieldRow('5. Category / Caste:', student.caste ?? 'General'),
              _buildTcFieldRow('6. Date of Admission in School:', student.admissionDate ?? '—'),
              _buildTcFieldRow('7. Date of Birth (in Christian Era):', student.dob ?? '—'),
              _buildTcFieldRow('8. Class in which pupil last studied:', student.gradeLevel),
              _buildTcFieldRow('9. School / Board Annual Exam Last Taken:', '${student.gradeLevel} Passed'),
              _buildTcFieldRow('10. Whether qualified for promotion:', 'Yes, Qualified for Next Class'),
              _buildTcFieldRow('11. Month up to which school dues paid:', 'All Dues Paid in Full'),
              _buildTcFieldRow('12. General Conduct:', 'Good & Satisfactory'),
              _buildTcFieldRow('13. Date of Application for TC:', tcDate),
              _buildTcFieldRow('14. Reason for Leaving School:', reasonForLeaving),
              _buildTcFieldRow('15. Any Other Remarks:', 'Alumni Record Updated'),

              pw.Spacer(),

              // Signature Footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(width: 120, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('Class Teacher', style: pw.TextStyle(fontSize: 9, color: greyColor)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 70,
                        height: 70,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: primaryColor, width: 1.5),
                        ),
                        child: pw.Center(
                          child: pw.Text('SEAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('School Seal', style: pw.TextStyle(fontSize: 8, color: greyColor)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(width: 120, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('Principal Signature', style: pw.TextStyle(fontSize: 9, color: greyColor)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// Generate a formal PDF Transfer Certificate and save to Documents.
  static Future<File> generateTransferCertificate({
    Uint8List? schoolLogo,
    required Student student,
    required String tcNumber,
    required String tcDate,
    required String reasonForLeaving,
    String schoolName = 'Eduvia',
    String schoolAddress = '123 Education Boulevard, Academic District',
    String affiliationNo = 'AFF-CBSE-2024-99881',
  }) async {
    final bytes = await buildTransferCertificatePdfBytes(
      student: student,
      tcNumber: tcNumber,
      tcDate: tcDate,
      reasonForLeaving: reasonForLeaving,
      schoolLogo: schoolLogo,
      schoolName: schoolName,
      schoolAddress: schoolAddress,
      affiliationNo: affiliationNo,
    );

    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final String certificatesDirPath = p.join(documentsDir.path, 'Eduvia', 'Certificates');
    final certsDir = Directory(certificatesDirPath);
    if (!await certsDir.exists()) {
      await certsDir.create(recursive: true);
    }

    final String fileName = 'TC_${student.admissionNumber ?? student.id.substring(0, 6)}.pdf';
    final File file = File(p.join(certificatesDirPath, fileName));
    await file.writeAsBytes(bytes);

    return file;
  }

  static pw.Widget _buildTcFieldRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 230,
            child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
          ),
        ],
      ),
    );
  }
}

