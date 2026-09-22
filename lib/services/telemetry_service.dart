import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'hardware_id_service.dart';
import 'settings_service.dart';

/// Industry-grade telemetry and user analytics service powered by PostHog.
///
/// Tracks:
/// - Active Installations (Daily/Monthly Active Users via unique Hardware ID)
/// - App Version adoption across schools
/// - Operating System distribution
/// - Core workflow engagement (Fee Collection, Admissions, Attendance, AI)
/// - Offline event queueing with automatic network flush
class TelemetryService {
  static final TelemetryService instance = TelemetryService._internal();
  TelemetryService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 8),
  ));

  static String _unmask(List<int> bytes) =>
      String.fromCharCodes(bytes.map((b) => b ^ 42));

  // Default fallback PostHog key byte-encoded to ensure telemetry works on all client builds
  static String get defaultPosthogKey => _unmask(const [
        90, 66, 73, 117, 92, 98, 125, 75, 124, 76, 102, 31, 98, 18, 114, 100,
        88, 95, 93, 92, 95, 107, 82, 124, 115, 105, 95, 83, 90, 69, 114, 76,
        122, 75, 75, 25, 92, 71, 102, 127, 103, 25, 76, 31, 66, 104, 98, 110
      ]);

  String _apiKey = '';
  String _hostUrl = 'https://us.i.posthog.com';
  String _distinctId = '';
  String _appVersion = '1.0.28';
  String _schoolName = 'Eduvia School';
  bool _initialized = false;
  Timer? _heartbeatTimer;

  // In-memory queue for offline resilience
  final List<Map<String, dynamic>> _offlineQueue = [];
  static const int _maxQueueSize = 50;

  bool get isEnabled => _apiKey.isNotEmpty;

  /// Initializes the telemetry service on application bootstrap
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Resolve API key & Host URL
      _apiKey = (dotenv.env['POSTHOG_API_KEY'] ?? defaultPosthogKey).trim();
      _hostUrl = (dotenv.env['POSTHOG_HOST'] ?? 'https://us.i.posthog.com').trim();

      // 2. Fetch unique persistent Hardware ID
      final hwService = HardwareIdService();
      _distinctId = await hwService.getHardwareId();

      // 3. Fetch app version info
      try {
        final pkg = await PackageInfo.fromPlatform();
        _appVersion = '${pkg.version}+${pkg.buildNumber}';
      } catch (_) {}

      // 4. Fetch school identity
      try {
        final settings = SettingsService();
        final storedName = await settings.getSetting('school_name');
        if (storedName != null && storedName.trim().isNotEmpty) {
          _schoolName = storedName.trim();
        }
      } catch (_) {}

      _initialized = true;

      // 5. Fire initial App Launch event (non-blocking)
      unawaited(trackAppLaunch());

      // 6. Schedule background heartbeat every 4 hours while app remains open
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(hours: 4), (_) {
        unawaited(trackHeartbeat());
      });
    } catch (e) {
      debugPrint('TelemetryService init notice: $e');
    }
  }

  /// Track when the desktop software is opened (Active User / DAU ping)
  Future<void> trackAppLaunch() async {
    await trackEvent('app_opened', {
      'event_type': 'lifecycle',
      'launch_timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Periodic active session heartbeat
  Future<void> trackHeartbeat() async {
    await trackEvent('heartbeat', {
      'event_type': 'heartbeat',
    });
  }

  /// Track screen navigation
  Future<void> trackScreenView(String screenName) async {
    await trackEvent('screen_view', {
      'screen_name': screenName,
    });
  }

  /// Track specific feature interactions (e.g. fee_collected, attendance_marked)
  Future<void> trackFeatureUsage(String featureName, [Map<String, dynamic>? properties]) async {
    await trackEvent('feature_used', {
      'feature_name': featureName,
      if (properties != null) ...properties,
    });
  }

  /// Track fee collection event with amount bracket
  void trackFeeCollected({
    required double amount,
    required dynamic paymentMethod,
    int ledgerCount = 1,
  }) {
    final methodStr = paymentMethod is Enum
        ? paymentMethod.name
        : paymentMethod.toString().replaceAll('PaymentMethod.', '');

    String bracket;
    if (amount < 1000) {
      bracket = '< 1,000';
    } else if (amount <= 5000) {
      bracket = '1,000 - 5,000';
    } else if (amount <= 15000) {
      bracket = '5,000 - 15,000';
    } else if (amount <= 50000) {
      bracket = '15,000 - 50,000';
    } else {
      bracket = '> 50,000';
    }

    unawaited(trackFeatureUsage('fee_collected', {
      'payment_method': methodStr,
      'amount_bracket': bracket,
      'ledger_count': ledgerCount,
    }));
  }

  /// Track transport operations (e.g. student assigned, route created, vehicle added)
  void trackTransportOperation({
    required String action,
    Map<String, dynamic>? properties,
  }) {
    unawaited(trackFeatureUsage('transport_$action', {
      if (properties != null) ...properties,
    }));
  }

  /// Track student admission event
  void trackStudentAdmitted({String? gradeLevel, String? gender}) {
    unawaited(trackFeatureUsage('student_admitted', {
      if (gradeLevel != null) 'grade_level': gradeLevel,
      if (gender != null) 'gender': gender,
    }));
  }

  /// Track daily student attendance submission
  void trackAttendanceMarked({
    required String className,
    String? section,
    int studentCount = 0,
  }) {
    unawaited(trackFeatureUsage('attendance_marked', {
      'class': className,
      if (section != null) 'section': section,
      'student_count': studentCount,
    }));
  }

  /// Track AI Assistant queries
  void trackAiQuery({required String intent, String? provider}) {
    unawaited(trackFeatureUsage('ai_query_asked', {
      'intent': intent,
      if (provider != null) 'provider': provider,
    }));
  }

  /// Track PDF document exports
  void trackReportExported({required String reportType}) {
    unawaited(trackFeatureUsage('report_exported', {
      'report_type': reportType,
    }));
  }

  /// Core event capture method with PostHog REST API & offline queueing
  Future<void> trackEvent(String eventName, [Map<String, dynamic>? customProps]) async {
    if (!_initialized || _apiKey.isEmpty) return;

    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final platformStr = kIsWeb ? 'Web' : Platform.operatingSystem;
    final osVersionStr = kIsWeb ? 'Browser' : Platform.operatingSystemVersion;

    final eventPayload = {
      'api_key': _apiKey,
      'event': eventName,
      'distinct_id': _distinctId,
      'timestamp': nowUtc,
      'properties': {
        'distinct_id': _distinctId,
        'app_version': _appVersion,
        'school_name': _schoolName,
        'os': platformStr,
        'os_version': osVersionStr,
        // PostHog user person properties
        '\$set': {
          'school_name': _schoolName,
          'app_version': _appVersion,
          'os': platformStr,
          'last_active_at': nowUtc,
        },
        '\$set_once': {
          'first_seen_at': nowUtc,
          'hardware_id': _distinctId,
        },
        if (customProps != null) ...customProps,
      },
    };

    try {
      final captureUrl = '$_hostUrl/capture/';
      final response = await _dio.post(
        captureUrl,
        data: eventPayload,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // If successful, flush any previously queued offline events
        if (_offlineQueue.isNotEmpty) {
          unawaited(_flushOfflineQueue());
        }
      } else {
        _enqueueOffline(eventPayload);
      }
    } catch (_) {
      // Offline fallback: enqueue to send once connectivity is restored
      _enqueueOffline(eventPayload);
    }
  }

  void _enqueueOffline(Map<String, dynamic> event) {
    if (_offlineQueue.length >= _maxQueueSize) {
      _offlineQueue.removeAt(0); // Evict oldest event to prevent memory growth
    }
    _offlineQueue.add(event);
  }

  Future<void> _flushOfflineQueue() async {
    if (_offlineQueue.isEmpty || _apiKey.isEmpty) return;

    final eventsToSend = List<Map<String, dynamic>>.from(_offlineQueue);
    _offlineQueue.clear();

    try {
      final batchUrl = '$_hostUrl/batch/';
      await _dio.post(
        batchUrl,
        data: {
          'api_key': _apiKey,
          'batch': eventsToSend,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
    } catch (_) {
      // Re-queue failed events
      _offlineQueue.insertAll(0, eventsToSend.take(_maxQueueSize));
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
  }
}
