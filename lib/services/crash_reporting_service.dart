import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';

class CrashReportingService {
  static final CrashReportingService instance = CrashReportingService._internal();

  CrashReportingService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  String? _webhookUrl;
  String _appVersion = '1.0.5';
  final Map<String, DateTime> _recentErrors = {};
  static const Duration _debounceWindow = Duration(minutes: 2);

  Future<void> initialize() async {
    try {
      _webhookUrl = dotenv.env['CRASH_REPORT_WEBHOOK_URL'] ??
          dotenv.env['DISCORD_WEBHOOK_URL'] ??
          dotenv.env['ERROR_WEBHOOK_URL'];
      
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (_) {}
  }

  void setWebhookUrl(String url) {
    _webhookUrl = url;
  }

  /// Automatically report an error if a webhook URL is configured
  Future<void> reportError(String message, [Object? error, StackTrace? stackTrace]) async {
    final url = _webhookUrl ?? dotenv.env['CRASH_REPORT_WEBHOOK_URL'];
    if (url == null || url.trim().isEmpty) return;

    // Debounce duplicate error messages within 2 minutes to prevent spam
    final errorKey = '${message}_${error.toString()}';
    final lastSent = _recentErrors[errorKey];
    if (lastSent != null && DateTime.now().difference(lastSent) < _debounceWindow) {
      return;
    }
    _recentErrors[errorKey] = DateTime.now();

    try {
      final platform = kIsWeb ? 'Web' : Platform.operatingSystem;
      final osVersion = kIsWeb ? '' : Platform.operatingSystemVersion;
      final timeStr = DateTime.now().toUtc().toIso8601String();

      final stackSnippet = stackTrace != null
          ? stackTrace.toString().split('\n').take(12).join('\n')
          : 'No stacktrace available';

      final description = [
        if (error != null) '**Error:** `$error`',
        '**Message:** $message',
        '**Platform:** $platform ($osVersion)',
        '**App Version:** $_appVersion',
        '**Time (UTC):** $timeStr',
      ].join('\n');

      // Formatted for Discord / Slack / Teams webhooks
      if (url.contains('discord.com')) {
        final payload = {
          'username': 'Eduvia Crash Bot',
          'avatar_url': 'https://raw.githubusercontent.com/whoisadheep/School-Management-System/main/assets/icons/app_icon.png',
          'embeds': [
            {
              'title': '🚨 Eduvia App Exception Detected',
              'color': 0xE53935, // Red
              'description': description,
              'fields': [
                {
                  'name': 'Stack Trace',
                  'value': '```dart\n${stackSnippet.length > 950 ? stackSnippet.substring(0, 950) + "..." : stackSnippet}\n```',
                }
              ],
              'footer': {
                'text': 'Eduvia Automated Telemetry',
              },
              'timestamp': timeStr,
            }
          ]
        };
        await _dio.post(url, data: payload);
      } else {
        // Generic JSON Webhook
        final genericPayload = {
          'app': 'Eduvia',
          'version': _appVersion,
          'platform': platform,
          'os': osVersion,
          'timestamp': timeStr,
          'message': message,
          'error': error?.toString(),
          'stackTrace': stackTrace?.toString(),
        };
        await _dio.post(url, data: genericPayload);
      }
    } catch (e) {
      debugPrint('Failed to send automated error report: $e');
    }
  }
}
