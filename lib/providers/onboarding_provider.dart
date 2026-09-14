import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';

/// Tracks whether the first-run onboarding setup wizard should be shown.
final onboardingPendingProvider = StateProvider<bool>((ref) => false);

/// Checks persistent database setting for whether onboarding has been completed.
final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final settings = SettingsService();
  final val = await settings.getSetting('is_onboarding_completed');
  return val == '1';
});
