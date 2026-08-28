import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'settings_service.dart';

/// Service to extract a unique, hardware-locked machine identifier.
class HardwareIdService {
  final SettingsService _settingsService;

  HardwareIdService({SettingsService? settingsService})
      : _settingsService = settingsService ?? SettingsService();

  /// Retrieves or generates a unique, persistent hardware identifier.
  Future<String> getHardwareId() async {
    if (kIsWeb) {
      return 'WEB-LOCAL-DEV-MACHINE-001';
    }

    try {
      final existingId = await _settingsService.getSetting('hardware_id');
      if (existingId != null && existingId.isNotEmpty) {
        return existingId;
      }
    } catch (_) {}

    String machineId = '';

    try {
      if (Platform.isWindows) {
        final deviceInfo = DeviceInfoPlugin();
        final windowsInfo = await deviceInfo.windowsInfo;
        machineId = 'WIN-${windowsInfo.deviceId.replaceAll('{', '').replaceAll('}', '').toUpperCase()}';
      }
    } catch (_) {}

    if (machineId.isEmpty || machineId == 'WIN-') {
      machineId = 'SMS-HW-${const Uuid().v4().substring(0, 18).toUpperCase()}';
    }

    try {
      await _settingsService.setSetting('hardware_id', machineId);
    } catch (_) {}
    return machineId;
  }
}
