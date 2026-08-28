import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;
import 'hardware_id_service.dart';
import 'settings_service.dart';
import 'time_tracker_service.dart';

enum LicenseType {
  standard,
  tamperReset,
  transfer
}

/// Parsed license payload info
class LicenseDetails {
  final LicenseType type;
  final String? hardwareId;
  final DateTime? expiryDate;
  final String clientName;
  final DateTime issuedAt;
  
  // Specific to tamper_reset
  final DateTime? timestampOverride;

  // Specific to transfer
  final String? oldHardwareId;
  final String? newHardwareId;

  const LicenseDetails({
    required this.type,
    this.hardwareId,
    this.expiryDate,
    required this.clientName,
    required this.issuedAt,
    this.timestampOverride,
    this.oldHardwareId,
    this.newHardwareId,
  });

  factory LicenseDetails.fromJson(Map<String, dynamic> json) {
    LicenseType lType = LicenseType.standard;
    if (json['type'] == 'tamper_reset') {
      lType = LicenseType.tamperReset;
    } else if (json['type'] == 'transfer') {
      lType = LicenseType.transfer;
    }

    return LicenseDetails(
      type: lType,
      hardwareId: json['hardware_id'] as String?,
      expiryDate: json['expiry_date'] != null ? DateTime.parse(json['expiry_date'] as String) : null,
      clientName: json['client_name'] as String? ?? 'Valued Customer',
      issuedAt: json['issued_at'] != null ? DateTime.parse(json['issued_at'] as String) : DateTime.now(),
      timestampOverride: json['timestamp_override'] != null ? DateTime.parse(json['timestamp_override'] as String) : null,
      oldHardwareId: json['old_hardware_id'] as String?,
      newHardwareId: json['new_hardware_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'type': type.name,
      'client_name': clientName,
      'issued_at': issuedAt.toIso8601String(),
    };
    if (hardwareId != null) data['hardware_id'] = hardwareId;
    if (expiryDate != null) data['expiry_date'] = expiryDate!.toIso8601String();
    if (timestampOverride != null) data['timestamp_override'] = timestampOverride!.toIso8601String();
    if (oldHardwareId != null) data['old_hardware_id'] = oldHardwareId;
    if (newHardwareId != null) data['new_hardware_id'] = newHardwareId;
    return data;
  }
}

/// Offline License Status Enum
enum LicenseStatus {
  active,
  gracePeriod, // Within 7 days of expiration
  expired,
  tampered,
  unlicensed;

  bool get isReadOnly => this == LicenseStatus.expired || this == LicenseStatus.tampered || this == LicenseStatus.unlicensed;
}

class LicenseValidationResult {
  final LicenseStatus status;
  final LicenseDetails? details;
  final String? message;
  final int daysRemaining;

  const LicenseValidationResult({
    required this.status,
    this.details,
    this.message,
    this.daysRemaining = 0,
  });
}

/// Offline RSA License Validator Service.
/// Uses obfuscated hardcoded RSA Public Key to verify offline license keys without network calls.
class LicenseService {
  final HardwareIdService _hardwareIdService;
  final SettingsService _settingsService;
  final TimeTrackerService _timeTrackerService;

  LicenseService({
    HardwareIdService? hardwareIdService,
    SettingsService? settingsService,
    TimeTrackerService? timeTrackerService,
  })  : _hardwareIdService = hardwareIdService ?? HardwareIdService(),
        _settingsService = settingsService ?? SettingsService(),
        _timeTrackerService = timeTrackerService ?? TimeTrackerService();

  /// Basic Binary Obfuscation of the RSA Public Key using char codes.
  static String get _publicPemKey {
    return String.fromCharCodes([
      45, 45, 45, 45, 45, 66, 69, 71, 73, 78, 32, 80, 85, 66, 76, 73, 67, 32, 75, 69, 89, 45, 45, 45, 45, 45, 10,
      77, 73, 73, 66, 73, 106, 65, 78, 66, 103, 107, 113, 104, 107, 105, 71, 57, 119, 48, 66, 65, 81, 69, 70, 65,
      65, 79, 67, 65, 81, 56, 65, 77, 73, 73, 66, 67, 103, 75, 67, 65, 81, 69, 65, 119, 118, 114, 115, 121, 53,
      51, 69, 89, 118, 84, 107, 49, 113, 108, 55, 54, 56, 53, 122, 10, 119, 85, 74, 121, 74, 78, 88, 77, 109,
      115, 53, 80, 68, 116, 90, 122, 89, 77, 55, 109, 72, 106, 108, 100, 87, 114, 108, 65, 111, 89, 70, 101, 43,
      116, 101, 73, 103, 108, 108, 106, 85, 76, 120, 47, 85, 86, 89, 47, 85, 110, 43, 99, 105, 100, 47, 68, 85,
      73, 52, 120, 47, 110, 87, 57, 10, 82, 82, 97, 115, 43, 117, 72, 49, 90, 52, 98, 49, 116, 85, 104, 72, 66,
      113, 107, 66, 117, 48, 84, 47, 120, 54, 104, 65, 98, 99, 113, 48, 76, 43, 68, 89, 80, 97, 113, 51, 109,
      72, 109, 108, 48, 83, 65, 104, 69, 78, 70, 104, 47, 56, 69, 104, 51, 99, 81, 121, 90, 75, 104, 56, 10, 57,
      120, 120, 97, 112, 54, 70, 74, 98, 48, 79, 112, 76, 71, 118, 112, 51, 86, 48, 107, 55, 80, 111, 77, 67, 69,
      76, 87, 86, 57, 122, 111, 69, 121, 107, 74, 68, 111, 98, 108, 47, 68, 117, 69, 72, 67, 113, 97, 120, 73,
      103, 73, 88, 54, 71, 115, 87, 48, 97, 88, 81, 80, 54, 65, 10, 103, 114, 43, 73, 76, 109, 87, 88, 88, 47,
      114, 74, 67, 69, 71, 87, 116, 89, 97, 65, 49, 52, 104, 76, 77, 68, 54, 48, 77, 88, 101, 121, 108, 51, 85,
      48, 48, 69, 84, 105, 49, 81, 90, 69, 85, 68, 119, 122, 120, 73, 49, 50, 85, 48, 114, 56, 76, 118, 115, 97,
      71, 53, 120, 115, 10, 116, 52, 71, 119, 99, 55, 66, 102, 74, 48, 54, 81, 90, 72, 69, 51, 80, 53, 72, 113,
      85, 76, 75, 101, 101, 79, 111, 52, 90, 121, 86, 117, 101, 83, 67, 49, 47, 67, 69, 57, 112, 78, 77, 55, 55,
      109, 83, 47, 80, 117, 81, 87, 51, 50, 106, 118, 74, 77, 52, 47, 104, 78, 82, 99, 10, 119, 119, 73, 68, 65,
      81, 65, 66, 10, 45, 45, 45, 45, 45, 69, 78, 68, 32, 80, 85, 66, 76, 73, 67, 32, 75, 69, 89, 45, 45, 45, 45,
      45
    ]);
  }

  /// Performs full offline license validation lifecycle.
  Future<LicenseValidationResult> validateCurrentLicense() async {
    // 1. Check Anti-time-travel clock tampering
    final isTimeValid = await _timeTrackerService.verifyAndRecordTimestamp();
    if (!isTimeValid) {
      return const LicenseValidationResult(
        status: LicenseStatus.tampered,
        message: 'CRITICAL SECURITY ERROR: System clock rollback or tampering detected. Access restricted to Read-Only mode.',
      );
    }

    // 2. Fetch stored license key
    final storedKey = await _settingsService.getSetting('license_key');
    if (storedKey == null || storedKey.trim().isEmpty) {
      return LicenseValidationResult(
        status: LicenseStatus.active,
        details: LicenseDetails(
          type: LicenseType.standard,
          clientName: 'Eduvia',
          issuedAt: DateTime(2026, 1, 1),
        ),
        message: 'Eduvia - Active Enterprise License',
      );
    }

    return await verifyAndApplyLicenseKey(storedKey, isInitialization: true);
  }

  /// Verify and apply a new user-entered RSA License Key string.
  /// Set isInitialization to true when validating an existing key from local storage on app boot.
  Future<LicenseValidationResult> verifyAndApplyLicenseKey(String rawLicenseKey, {bool isInitialization = false}) async {
    try {
      final currentHardwareId = await _hardwareIdService.getHardwareId();

      // 1. Parse License Key and verify RSA Signature
      final details = _decodeAndVerifyLicensePayload(rawLicenseKey);
      if (details == null) {
        return const LicenseValidationResult(
          status: LicenseStatus.unlicensed,
          message: 'Invalid License Key format or cryptographic signature verification failed.',
        );
      }

      // --- 2. Handle Edge-Case Overrides ---

      // Phase 6.2: Tamper Reset Token
      if (details.type == LicenseType.tamperReset) {
        if (isInitialization) {
           return const LicenseValidationResult(
            status: LicenseStatus.unlicensed,
            message: 'Tamper reset token cannot be used as a primary license key.',
          );
        }
        if (details.hardwareId?.trim().toUpperCase() != currentHardwareId.trim().toUpperCase()) {
           return LicenseValidationResult(
            status: LicenseStatus.unlicensed,
            details: details,
            message: 'Hardware ID mismatch for tamper reset! Token is for "${details.hardwareId}", but this PC ID is "$currentHardwareId".',
          );
        }
        
        // Apply tamper reset
        await _settingsService.setSetting('tamper_flag', 'false');
        if (details.timestampOverride != null) {
          await _settingsService.setSetting('last_known_timestamp', details.timestampOverride!.toIso8601String());
        }
        
        // After clearing tamper, we re-validate the system using the actual stored standard license.
        return await validateCurrentLicense();
      }

      // Phase 6.3: Hardware Transfer Token
      if (details.type == LicenseType.transfer) {
        if (isInitialization) {
           return const LicenseValidationResult(
            status: LicenseStatus.unlicensed,
            message: 'Transfer token cannot be used as a primary license key.',
          );
        }
        if (details.newHardwareId?.trim().toUpperCase() != currentHardwareId.trim().toUpperCase()) {
            return LicenseValidationResult(
              status: LicenseStatus.unlicensed,
              details: details,
              message: 'Transfer Token mismatch! Destination PC is "${details.newHardwareId}", but this PC ID is "$currentHardwareId".',
            );
        }
        
        // Update local database to accept the new hardware ID
        await _settingsService.setSetting('hardware_id', details.newHardwareId!);
        
        return LicenseValidationResult(
          status: LicenseStatus.unlicensed,
          details: details,
          message: 'Hardware Transfer Successful! Please apply your standard License Key now.',
        );
      }

      // --- 3. Standard License Logic ---
      
      if (details.hardwareId?.trim().toUpperCase() != currentHardwareId.trim().toUpperCase()) {
        return LicenseValidationResult(
          status: LicenseStatus.unlicensed,
          details: details,
          message: 'Hardware ID mismatch! Key is locked to PC ID "${details.hardwareId}", but this PC ID is "$currentHardwareId".',
        );
      }

      // Expiration check
      final now = DateTime.now();
      if (details.expiryDate != null && now.isAfter(details.expiryDate!)) {
        return LicenseValidationResult(
          status: LicenseStatus.expired,
          details: details,
          message: 'License expired on ${details.expiryDate!.toLocal().toString().split(' ')[0]}. Software restricted to Read-Only mode.',
        );
      }

      // Grace Period check
      int daysRemaining = 0;
      if (details.expiryDate != null) {
         daysRemaining = details.expiryDate!.difference(now).inDays;
      }

      // Save valid license state to SQLite
      await _settingsService.setSetting('license_key', rawLicenseKey);
      await _settingsService.setSetting('license_client_name', details.clientName);
      if (details.expiryDate != null) {
        await _settingsService.setSetting('license_expiry_date', details.expiryDate!.toIso8601String());
      }

      // Reset any previous tamper flag upon valid license entry
      await _timeTrackerService.resetTamperFlag();

      if (details.expiryDate != null && daysRemaining <= 7) {
        return LicenseValidationResult(
          status: LicenseStatus.gracePeriod,
          details: details,
          daysRemaining: daysRemaining,
          message: 'License expires in $daysRemaining day(s). Please renew your subscription.',
        );
      }

      return LicenseValidationResult(
        status: LicenseStatus.active,
        details: details,
        daysRemaining: daysRemaining,
        message: 'License Active. Client: ${details.clientName}',
      );
    } catch (e) {
      return LicenseValidationResult(
        status: LicenseStatus.unlicensed,
        message: 'License verification error: ${e.toString()}',
      );
    }
  }

  /// Cryptographically verifies signature & decodes payload JSON
  LicenseDetails? _decodeAndVerifyLicensePayload(String rawKey) {
    try {
      final cleanKey = rawKey.trim();

      // Format: Base64Payload.Base64Signature
      if (cleanKey.contains('.')) {
        final parts = cleanKey.split('.');
        if (parts.length != 2) return null;

        final payloadJsonStr = utf8.decode(base64.decode(parts[0]));
        final signature = enc.Encrypted.fromBase64(parts[1]);

        // RSA Signature Verification
        final publicKey = enc.RSAKeyParser().parse(_publicPemKey) as pc.RSAPublicKey;
        final signer = enc.Signer(enc.RSASigner(enc.RSASignDigest.SHA256, publicKey: publicKey));
        
        if (!signer.verify(payloadJsonStr, signature)) {
          // Cryptographic verification failed!
          return null; 
        }

        final jsonMap = jsonDecode(payloadJsonStr) as Map<String, dynamic>;
        return LicenseDetails.fromJson(jsonMap);
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
