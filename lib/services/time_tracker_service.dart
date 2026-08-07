import 'settings_service.dart';

/// Anti-Time-Travel High-Water Mark Time Tracker Utility.
/// Prevents users from rolling back their Windows system clock to bypass license expiration.
class TimeTrackerService {
  final SettingsService _settingsService;

  TimeTrackerService({SettingsService? settingsService})
      : _settingsService = settingsService ?? SettingsService();

  /// Check current DateTime against high-water mark timestamp stored in SQLite.
  ///
  /// Returns `true` if valid, or `false` if clock rollback / tampering is detected.
  Future<bool> verifyAndRecordTimestamp() async {
    final tamperFlag = await _settingsService.getSetting('tamper_flag');
    if (tamperFlag == 'true') {
      return false; // Already flagged for tampering
    }

    final lastKnownStr = await _settingsService.getSetting('last_known_timestamp');
    final now = DateTime.now();

    if (lastKnownStr != null && lastKnownStr.isNotEmpty) {
      final lastKnown = DateTime.tryParse(lastKnownStr);
      if (lastKnown != null) {
        // Allow up to 5 minutes tolerance for minor system clock drift
        final minAllowedTime = lastKnown.subtract(const Duration(minutes: 5));

        if (now.isBefore(minAllowedTime)) {
          // CLOCK ROLLBACK DETECTED!
          await _settingsService.setSetting('tamper_flag', 'true');
          await _settingsService.setSetting(
            'tamper_reason',
            'Clock rollback detected: Current time ($now) is older than recorded timestamp ($lastKnown)',
          );
          return false;
        }
      }
    }

    // Update high-water mark timestamp to current DateTime.now()
    await _settingsService.setSetting('last_known_timestamp', now.toIso8601String());
    return true;
  }

  /// Check if system has been flagged for time tampering
  Future<bool> isTampered() async {
    final tamperFlag = await _settingsService.getSetting('tamper_flag');
    return tamperFlag == 'true';
  }

  /// Reset tamper flag (Admin recovery action after valid license re-activation)
  Future<void> resetTamperFlag() async {
    await _settingsService.setSetting('tamper_flag', 'false');
    await _settingsService.setSetting('last_known_timestamp', DateTime.now().toIso8601String());
  }
}
