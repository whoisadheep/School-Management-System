import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/report_generator.dart';
import '../../services/settings_service.dart';
import 'pdf_preview_dialog.dart';

class PaymentReceiptDialog extends StatefulWidget {
  final Student student;
  final List<StudentFeeLedger> paidLedgers;
  final double totalAmount;
  final PaymentMethod paymentMethod;
  final String? referenceNumber;
  final String? academicYear;
  final String receiptNumber;

  const PaymentReceiptDialog({
    super.key,
    required this.student,
    required this.paidLedgers,
    required this.totalAmount,
    required this.paymentMethod,
    this.referenceNumber,
    this.academicYear,
    required this.receiptNumber,
  });

  static Future<void> show({
    required BuildContext context,
    required Student student,
    required List<StudentFeeLedger> paidLedgers,
    required double totalAmount,
    required PaymentMethod paymentMethod,
    String? referenceNumber,
    String? academicYear,
    required String receiptNumber,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => PaymentReceiptDialog(
        student: student,
        paidLedgers: paidLedgers,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
        academicYear: academicYear,
        receiptNumber: receiptNumber,
      ),
    );
  }

  @override
  State<PaymentReceiptDialog> createState() => _PaymentReceiptDialogState();
}

class _PaymentReceiptDialogState extends State<PaymentReceiptDialog> {
  final _settingsService = SettingsService();
  String _schoolName = 'Eduvia Public School';
  String _schoolAddress = '123 Education Boulevard, Academic District';
  String _schoolContact = 'Phone: +91 9876543210';

  @override
  void initState() {
    super.initState();
    _loadSchoolSettings();
  }

  Future<void> _loadSchoolSettings() async {
    final name = await _settingsService.getSetting('school_name');
    final addr = await _settingsService.getSetting('school_address');
    final phone = await _settingsService.getSetting('school_phone') ??
        await _settingsService.getSetting('school_contact');

    if (mounted) {
      setState(() {
        if (name != null && name.isNotEmpty) _schoolName = name;
        if (addr != null && addr.isNotEmpty) _schoolAddress = addr;
        if (phone != null && phone.isNotEmpty) _schoolContact = phone;
      });
    }
  }

  String _formatWhatsAppMessage() {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    final buffer = StringBuffer();
    buffer.writeln('🧾 *FEE PAYMENT RECEIPT*');
    buffer.writeln('*$_schoolName*');
    if (_schoolContact.isNotEmpty) buffer.writeln(_schoolContact);
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('👤 *Student:* ${widget.student.name}');
    buffer.writeln('🏫 *Class:* ${widget.student.gradeLevel}${widget.student.section != null ? " (${widget.student.section})" : ""}');
    if (widget.student.rollNumber != null && widget.student.rollNumber!.isNotEmpty) {
      buffer.writeln('🔢 *Roll No:* ${widget.student.rollNumber}');
    }
    if (widget.student.admissionNumber != null && widget.student.admissionNumber!.isNotEmpty) {
      buffer.writeln('🆔 *Adm No:* ${widget.student.admissionNumber}');
    }
    buffer.writeln('📄 *Receipt No:* ${widget.receiptNumber}');
    buffer.writeln('📅 *Date:* $dateStr');
    buffer.writeln('💳 *Mode:* ${widget.paymentMethod.displayName}${widget.referenceNumber != null && widget.referenceNumber!.isNotEmpty ? " (Ref: ${widget.referenceNumber})" : ""}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📋 *FEES BREAKDOWN:*');

    for (var l in widget.paidLedgers) {
      final name = l.feeHeadName ?? l.feeHeadId;
      final label = l.monthLabel ?? 'One-Time';
      final amt = currency.format(l.amountDue > 0 ? l.amountDue : l.amountPaid);
      buffer.writeln('• $name ($label): $amt');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💰 *TOTAL PAID: ${currency.format(widget.totalAmount)}*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Thank you for the prompt payment!');
    buffer.writeln('*$_schoolName*');

    return buffer.toString();
  }

  Future<void> _shareOnWhatsApp(BuildContext context) async {
    String phone = widget.student.guardianPhone ??
        widget.student.fatherPhone ??
        widget.student.motherPhone ??
        '';

    final text = _formatWhatsAppMessage();

    // If phone is missing, prompt user
    if (phone.isEmpty) {
      final phoneCtrl = TextEditingController();
      final enteredPhone = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Enter WhatsApp Phone Number', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'e.g. 9876543210 or +919876543210',
              prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF25D366)),
              filled: true,
              fillColor: AppTheme.bgSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, phoneCtrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
              child: const Text('Send Message'),
            ),
          ],
        ),
      );

      if (enteredPhone == null || enteredPhone.isEmpty) return;
      phone = enteredPhone;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final finalPhone = cleanPhone.startsWith('+') ? cleanPhone : '+91$cleanPhone';

    final url = Uri.parse('https://wa.me/$finalPhone?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch WhatsApp.', style: GoogleFonts.poppins()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _openPdfPreview(BuildContext context) async {
    final pdfBytes = await ReportGenerator.buildBatchPaymentReceiptPdfBytes(
      paidLedgers: widget.paidLedgers,
      student: widget.student,
      totalAmountPaid: widget.totalAmount,
      paymentMethod: widget.paymentMethod,
      referenceNumber: widget.referenceNumber,
      receiptNumber: widget.receiptNumber,
      academicYear: widget.academicYear,
      schoolName: _schoolName,
      schoolAddress: _schoolAddress,
      schoolContact: _schoolContact,
    );

    if (context.mounted) {
      await PdfPreviewDialog.show(
        context: context,
        title: 'Payment Receipt — ${widget.receiptNumber}',
        pdfBytes: pdfBytes,
        defaultFileName: 'Receipt_${widget.receiptNumber}.pdf',
        defaultSubDirectory: 'Receipts',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Header with Success Icon ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Succeeded!',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Receipt #${widget.receiptNumber}',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: AppTheme.divider),
            const SizedBox(height: 16),

            // ── Visual Receipt Preview Card ──
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // School Banner
                      Center(
                        child: Column(
                          children: [
                            Text(
                              _schoolName.toUpperCase(),
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple, letterSpacing: 0.5),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _schoolAddress,
                              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              _schoolContact,
                              style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'OFFICIAL FEE RECEIPT',
                                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppTheme.divider),
                      const SizedBox(height: 12),

                      // Student Details & Transaction Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('STUDENT DETAILS', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                                const SizedBox(height: 4),
                                Text(widget.student.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                Text('Class: ${widget.student.gradeLevel}${widget.student.section != null ? " - Sec ${widget.student.section}" : ""}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textPrimary)),
                                if (widget.student.rollNumber != null && widget.student.rollNumber!.isNotEmpty)
                                  Text('Roll No: ${widget.student.rollNumber}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('TRANSACTION INFO', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                                const SizedBox(height: 4),
                                Text(dateFormatter.format(DateTime.now()), style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textPrimary)),
                                Text('Mode: ${widget.paymentMethod.displayName}', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                if (widget.referenceNumber != null && widget.referenceNumber!.isNotEmpty)
                                  Text('Ref: ${widget.referenceNumber}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Itemized Breakdown Table
                      Text('FEES COLLECTED', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                      const SizedBox(height: 6),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Column(
                          children: widget.paidLedgers.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final l = entry.value;
                            final name = l.feeHeadName ?? l.feeHeadId;
                            final month = l.monthLabel ?? 'One-Time';
                            final amt = currencyFormatter.format(l.amountDue > 0 ? l.amountDue : l.amountPaid);

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: idx % 2 == 1 ? AppTheme.bgSurface.withValues(alpha: 0.5) : Colors.white,
                                border: idx < widget.paidLedgers.length - 1
                                    ? const Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5))
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.success),
                                      const SizedBox(width: 8),
                                      Text(name, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                      const SizedBox(width: 6),
                                      Text('($month)', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                  Text(amt, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Grand Total Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL PAID:',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            Text(
                              currencyFormatter.format(widget.totalAmount),
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Bottom Action Buttons ──
            Row(
              children: [
                // WhatsApp Button
                Expanded(
                  flex: 5,
                  child: ElevatedButton.icon(
                    onPressed: () => _shareOnWhatsApp(context),
                    icon: const Icon(Icons.chat_rounded, size: 16),
                    label: Text(
                      'Send via WhatsApp',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Print / PDF Button
                Expanded(
                  flex: 4,
                  child: OutlinedButton.icon(
                    onPressed: () => _openPdfPreview(context),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: Text(
                      'Print / PDF',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryPurple,
                      side: const BorderSide(color: AppTheme.primaryPurple, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Done Button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: Text('Done', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
