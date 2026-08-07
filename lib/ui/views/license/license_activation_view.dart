import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/license_provider.dart';
import '../../../services/license_generator.dart';
import '../../../core/auth/permission_helper.dart';
import '../../../services/license_service.dart';

class LicenseActivationView extends ConsumerStatefulWidget {
  const LicenseActivationView({super.key});

  @override
  ConsumerState<LicenseActivationView> createState() => _LicenseActivationViewState();
}

class _LicenseActivationViewState extends ConsumerState<LicenseActivationView> {
  final _keyController = TextEditingController();
  bool _isActivating = false;
  String? _statusMessage;
  bool _isSuccess = false;
  bool _showTamperInstructions = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  String _generateTamperIncidentId(String hwId) {
    // Generate a short alphanumeric hash for support reference
    final str = '$hwId-${DateTime.now().millisecondsSinceEpoch}';
    final bytes = utf8.encode(str);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 10).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hardwareIdAsync = ref.watch(hardwareIdProvider);
    final licenseState = ref.watch(licenseStateProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Software License Activation', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 580,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.vpn_key_rounded, color: Color(0xFF3B82F6), size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Offline RSA License Activation',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Hardware-locked license activation for single Windows PC',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Hardware ID Card ──
                hardwareIdAsync.when(
                  data: (hwId) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.laptop_windows_rounded, color: Color(0xFF94A3B8), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('YOUR PC HARDWARE ID (Send to Sai Infotek)', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(
                                    hwId,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: hwId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Hardware ID copied to clipboard!')),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 14),
                              label: const Text('Copy ID'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF334155),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                        
                        if (licenseState?.status == LicenseStatus.tampered) ...[
                           const SizedBox(height: 16),
                           const Divider(color: Color(0xFF334155)),
                           const SizedBox(height: 8),
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               const Text('System locked due to clock tampering.', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                               TextButton.icon(
                                 onPressed: () {
                                   setState(() {
                                     _showTamperInstructions = !_showTamperInstructions;
                                   });
                                 },
                                 icon: const Icon(Icons.support_agent_rounded, size: 16, color: Color(0xFFFBBF24)),
                                 label: const Text('Request Unlock', style: TextStyle(color: Color(0xFFFBBF24))),
                               ),
                             ],
                           )
                        ],
                        
                        if (_showTamperInstructions) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF451A03),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF78350F)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TAMPER RESET INSTRUCTIONS', style: TextStyle(color: Color(0xFFFCD34D), fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                const Text('If your CMOS battery died or the clock was reset accidentally, please WhatsApp Sai Infotek support with your Hardware ID and the following Incident ID:', style: TextStyle(color: Color(0xFFFDE68A), fontSize: 12)),
                                const SizedBox(height: 8),
                                SelectableText('Incident ID: ${_generateTamperIncidentId(hwId)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                const SizedBox(height: 4),
                                const Text('You will receive a Tamper Reset Token to paste below.', style: TextStyle(color: Color(0xFFFDE68A), fontSize: 12, fontStyle: FontStyle.italic)),
                              ],
                            ),
                          )
                        ]
                      ],
                    ),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (e, s) => Text('Error: $e'),
                ),

                const SizedBox(height: 20),

                // ── Paste License Key Field ──
                const Text('PASTE RSA LICENSE KEY BELOW', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _keyController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'Paste license key or override token string provided by vendor...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                if (_statusMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _isSuccess ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(_isSuccess ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: const TextStyle(color: Colors.white, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Quick Test Key Generator button for demo
                    TextButton.icon(
                      onPressed: () async {
                        if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.licenseManagement)) return;
                        final hwId = await ref.read(hardwareIdProvider.future);
                        final demoKey = LicenseGenerator.generateLicenseKey(
                          hardwareId: hwId,
                          expiryDate: DateTime.now().add(const Duration(days: 365)),
                          clientName: "Mother's Kids Play School",
                        );
                        setState(() {
                          _keyController.text = demoKey;
                        });
                      },
                      icon: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF60A5FA)),
                      label: const Text('Generate 1-Year Demo Key', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 12)),
                    ),

                    ElevatedButton.icon(
                      onPressed: _isActivating ? null : _handleActivate,
                      icon: _isActivating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.verified_rounded, size: 18),
                      label: const Text('Activate License'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleActivate() async {
    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.licenseManagement)) return;
    if (_keyController.text.trim().isEmpty) return;

    setState(() {
      _isActivating = true;
      _statusMessage = null;
    });

    final result = await ref.read(licenseStateProvider.notifier).activateKey(_keyController.text.trim());

    setState(() {
      _isActivating = false;
      _isSuccess = !result.status.isReadOnly;
      _statusMessage = result.message;
    });
  }
}
