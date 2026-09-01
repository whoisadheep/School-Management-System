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
    final shortDateFormatter = DateFormat('dd MMM yyyy');

    final primaryColor = PdfColor.fromHex('#4C3BCF');
    final darkColor = PdfColor.fromHex('#1A1A2E');
    final greyColor = PdfColor.fromHex('#616161');
    final lightGrey = PdfColor.fromHex('#F8F9FA');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header Section ──
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          schoolName,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          schoolAddress,
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 7.5,
                          ),
                        ),
                        pw.Text(
                          schoolContact,
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 7.5,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'OFFICIAL RECEIPT',
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // ── Receipt & Student Meta Data Grid ──
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Student Info
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(7),
                      decoration: pw.BoxDecoration(
                        color: lightGrey,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'STUDENT DETAILS',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: greyColor,
                            ),
                          ),
                          pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            student.name,
                            style: pw.TextStyle(
                              fontSize: 10.5,
                              fontWeight: pw.FontWeight.bold,
                              color: darkColor,
                            ),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text('Grade: ${student.gradeLevel}', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('Student ID: ${student.id}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                          if (student.guardianPhone != null)
                            pw.Text('Guardian Contact: ${student.guardianPhone}', style: const pw.TextStyle(fontSize: 7.5)),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 8),

                  // Right: Receipt Meta
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(7),
                      decoration: pw.BoxDecoration(
                        color: lightGrey,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'RECEIPT INFORMATION',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: greyColor,
                            ),
                          ),
                          pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Receipt #: $formattedReceiptNumber',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkColor),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text('Date: ${dateFormatter.format(transaction.timestamp)}', style: const pw.TextStyle(fontSize: 7.5)),
                          pw.Text('Payment Method: ${transaction.paymentMethod.displayName}', style: const pw.TextStyle(fontSize: 7.5)),
                          if (transaction.referenceNumber != null && transaction.referenceNumber!.isNotEmpty)
                            pw.Text('Ref / Txn No: ${transaction.referenceNumber}', style: const pw.TextStyle(fontSize: 7.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              // ── Payment Details Table ──
              pw.Text(
                'PAYMENT BREAKDOWN',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 4),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: primaryColor),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                        child: pw.Text('Invoice ID', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                        child: pw.Text('Description', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                        child: pw.Text('Due Date', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                        child: pw.Text('Amount Paid', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  // Table Body Row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                        child: pw.Text(invoice.id.substring(0, 8).toUpperCase(), style: const pw.TextStyle(fontSize: 7.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                        child: pw.Text(invoice.notes ?? 'School Fee Invoice', style: const pw.TextStyle(fontSize: 7.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                        child: pw.Text(shortDateFormatter.format(invoice.dueDate), style: const pw.TextStyle(fontSize: 7.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                        child: pw.Text(currencyFormatter.format(transaction.amountPaid), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 6),

              // ── Summary Table ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 190,
                    padding: const pw.EdgeInsets.all(7),
                    decoration: pw.BoxDecoration(
                      color: lightGrey,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Invoice Total:', style: const pw.TextStyle(fontSize: 7.5)),
                            pw.Text(currencyFormatter.format(invoice.totalAmount), style: const pw.TextStyle(fontSize: 7.5)),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Amount Paid Now:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                            pw.Text(currencyFormatter.format(transaction.amountPaid), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          ],
                        ),
                        pw.Divider(thickness: 0.5),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Remaining Balance:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                            pw.Text(
                              currencyFormatter.format(student.currentBalance - transaction.amountPaid),
                              style: pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold,
                                color: (student.currentBalance - transaction.amountPaid) > 0 ? PdfColors.red800 : PdfColors.green800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // ── Footer & Signatures ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 100,
                        height: 0.5,
                        color: PdfColors.grey500,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Payer Signature', style: pw.TextStyle(fontSize: 7, color: greyColor)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        width: 100,
                        height: 0.5,
                        color: PdfColors.grey500,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Authorized Cashier / Stamp', style: pw.TextStyle(fontSize: 7, color: greyColor)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Thank you for your prompt payment! This is a computer-generated receipt.',
                  style: pw.TextStyle(fontSize: 6.5, color: greyColor, fontStyle: pw.FontStyle.italic),
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// Build raw PDF bytes for a unified batch payment receipt (supporting multiple fees/months).
  static Future<Uint8List> buildBatchPaymentReceiptPdfBytes({
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
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header Section ──
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          schoolName,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          schoolAddress,
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 7.5,
                          ),
                        ),
                        pw.Text(
                          schoolContact,
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 7.5,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'FEE RECEIPT',
                            style: pw.TextStyle(
                              color: primaryColor,
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (academicYear != null) ...[
                            pw.SizedBox(height: 1),
                            pw.Text(
                              'Session: $academicYear',
                              style: pw.TextStyle(
                                color: darkColor,
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // ── Receipt & Student Meta Data Grid ──
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Student Info
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(7),
                      decoration: pw.BoxDecoration(
                        color: lightGrey,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'STUDENT DETAILS',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: greyColor,
                            ),
                          ),
                          pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            student.name,
                            style: pw.TextStyle(
                              fontSize: 10.5,
                              fontWeight: pw.FontWeight.bold,
                              color: darkColor,
                            ),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text('Class: ${student.gradeLevel} ${student.section != null ? "- Section ${student.section}" : ""}', style: const pw.TextStyle(fontSize: 8)),
                          if (student.rollNumber != null && student.rollNumber!.isNotEmpty)
                            pw.Text('Roll No: ${student.rollNumber}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                          if (student.admissionNumber != null && student.admissionNumber!.isNotEmpty)
                            pw.Text('Admission No: ${student.admissionNumber}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                          if (student.guardianPhone != null && student.guardianPhone!.isNotEmpty)
                            pw.Text('Guardian Phone: ${student.guardianPhone}', style: const pw.TextStyle(fontSize: 7.5)),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 8),

                  // Right: Receipt Meta
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(7),
                      decoration: pw.BoxDecoration(
                        color: lightGrey,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TRANSACTION DETAILS',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: greyColor,
                            ),
                          ),
                          pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Receipt #: $formattedReceiptNumber',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkColor),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text('Date & Time: ${dateFormatter.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 7.5)),
                          pw.Text('Payment Mode: ${paymentMethod.displayName}', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                          if (referenceNumber != null && referenceNumber.isNotEmpty)
                            pw.Text('Ref / Txn No: $referenceNumber', style: const pw.TextStyle(fontSize: 7.5)),
                          pw.Text('Status: FULLY SETTLED', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              // ── Payment Details Table ──
              pw.Text(
                'ITEMIZED FEE BREAKDOWN',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 4),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.8),
                  1: const pw.FlexColumnWidth(3.8),
                  2: const pw.FlexColumnWidth(2.8),
                  3: const pw.FlexColumnWidth(2.2),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: primaryColor),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                        child: pw.Text('#', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                        child: pw.Text('Fee Category / Head', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                        child: pw.Text('Month / Schedule', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                        child: pw.Text('Amount Paid', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  // Table Body Rows
                  ...paidLedgers.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final l = entry.value;
                    final headName = l.feeHeadName ?? l.feeHeadId;
                    final month = l.monthLabel ?? 'One-Time Fee';
                    final isEven = idx % 2 == 0;

                    return pw.TableRow(
                      decoration: isEven ? pw.BoxDecoration(color: lightGrey) : null,
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                          child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                          child: pw.Text(headName, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                          child: pw.Text(month, style: const pw.TextStyle(fontSize: 7.5)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                          child: pw.Text(currencyFormatter.format(l.amountDue > 0 ? l.amountDue : l.amountPaid), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 6),

              // ── Summary Table ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 190,
                    padding: const pw.EdgeInsets.all(7),
                    decoration: pw.BoxDecoration(
                      color: lightGrey,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total Items Paid:', style: const pw.TextStyle(fontSize: 7.5)),
                            pw.Text('${paidLedgers.length}', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Grand Total Paid:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            pw.Text(currencyFormatter.format(totalAmountPaid), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          ],
                        ),
                        pw.Divider(thickness: 0.5),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Remaining Balance:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                            pw.Text(
                              currencyFormatter.format(student.currentBalance - totalAmountPaid),
                              style: pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold,
                                color: (student.currentBalance - totalAmountPaid) > 0 ? PdfColors.red800 : PdfColors.green800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // ── Footer & Signatures ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 100,
                        height: 0.5,
                        color: PdfColors.grey500,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Parent / Guardian Signature', style: pw.TextStyle(fontSize: 7, color: greyColor)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        width: 100,
                        height: 0.5,
                        color: PdfColors.grey500,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Authorized Seal / Cashier', style: pw.TextStyle(fontSize: 7, color: greyColor)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Thank you for your payment! This is a valid computer-generated receipt issued by $schoolName.',
                  style: pw.TextStyle(fontSize: 6.5, color: greyColor, fontStyle: pw.FontStyle.italic),
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// Generate an A4-sized PDF receipt and save to Documents directory.
  ///
  /// Returns the saved [File] object pointing to the generated PDF.
  static Future<File> generatePaymentReceipt({
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
    required Student student,
    String schoolName = 'Eduvia',
    String schoolAddress = '123 Education Boulevard, Academic District',
    String schoolContact = 'Phone: +1 800 555-0199',
  }) async {
    final bytes = await buildStudentIdCardPdfBytes(
      student: student,
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

