import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hardware_id_service.dart';
import '../services/license_service.dart';

/// Provider for current Hardware ID of this PC
final hardwareIdProvider = FutureProvider<String>((ref) async {
  final service = HardwareIdService();
  return await service.getHardwareId();
});

class LicenseNotifier extends StateNotifier<AsyncValue<LicenseValidationResult>> {
  final LicenseService _service;

  LicenseNotifier({LicenseService? service})
      : _service = service ?? LicenseService(),
        super(const AsyncValue.loading()) {
    validateLicense();
  }

  Future<void> validateLicense() async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.validateCurrentLicense();
      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<LicenseValidationResult> activateKey(String key) async {
    state = const AsyncValue.loading();
    final result = await _service.verifyAndApplyLicenseKey(key);
    state = AsyncValue.data(result);
    return result;
  }
}

final licenseStateProvider = StateNotifierProvider<LicenseNotifier, AsyncValue<LicenseValidationResult>>((ref) {
  return LicenseNotifier();
});
