import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'settings_service.dart';

/// Service to extract a unique, hardware-locked machine identifier on Windows Desktop.
class HardwareIdService {
  final SettingsService _settingsService;

  HardwareIdService({SettingsService? settingsService})
      : _settingsService = settingsService ?? SettingsService();

  /// Retrieves or generates a unique, persistent hardware identifier for the current PC.
  Future<String> getHardwareId() async {
    // 1. Check if hardware ID was previously persisted in local SQLite settings
    final existingId = await _settingsService.getSetting('hardware_id');
    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }

    String machineId = '';

    try {
      if (Platform.isWindows) {
        final deviceInfo = DeviceInfoPlugin();
        final windowsInfo = await deviceInfo.windowsInfo;
        // Combine deviceId + computerName for a unique Windows machine signature
        machineId = 'WIN-${windowsInfo.deviceId.replaceAll('{', '').replaceAll('}', '').toUpperCase()}';
      }
    } catch (_) {
      // Fallback
    }

    if (machineId.isEmpty || machineId == 'WIN-') {
      // Fallback: Generate a persistent machine UUID if hardware API unavailable
      machineId = 'SMS-HW-${const Uuid().v4().substring(0, 18).toUpperCase()}';
    }

    // Persist hardware ID in local SQLite settings to maintain consistency across app restarts
    await _settingsService.setSetting('hardware_id', machineId);
    return machineId;
  }
}
