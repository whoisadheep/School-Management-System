import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:school_management_system/services/app_logger.dart';

class UpdateInfo {
  final bool isUpdateAvailable;
  final String latestVersion;
  final String downloadUrl;
  final String sha256;
  final String changelog;
  final bool isMandatory;

  UpdateInfo({
    required this.isUpdateAvailable,
    required this.latestVersion,
    required this.downloadUrl,
    required this.sha256,
    required this.changelog,
    required this.isMandatory,
  });
}

class UpdateService {
  static final UpdateService instance = UpdateService._internal();

  UpdateService._internal();

  DateTime? _lastCheckTime;
  UpdateInfo? _lastUpdateInfo;
  static const Duration _cacheDuration = Duration(hours: 3);
  
  static const String _updateJsonUrl = 'https://nirvah-sms.web.app/version.json';

  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    if (!force && _lastCheckTime != null) {
      final difference = DateTime.now().difference(_lastCheckTime!);
      if (difference < _cacheDuration) {
        return _lastUpdateInfo?.isUpdateAvailable == true ? _lastUpdateInfo : null;
      }
    }

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);
      
      // Fetch the static version.json file
      final response = await dio.get(_updateJsonUrl);
      
      if (response.statusCode != 200 || response.data == null) {
        return null;
      }
      
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      
      final latestVersion = data['latest_version']?.toString() ?? '';
      final downloadUrl = data['download_url']?.toString() ?? '';
      final sha256Hash = data['sha256']?.toString() ?? '';
      final changelog = data['changelog']?.toString() ?? '';
      final isMandatory = data['mandatory_update'] == true;

      if (latestVersion.isEmpty || downloadUrl.isEmpty) {
        return null;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final isUpdateAvailable = _isVersionGreaterThan(latestVersion, currentVersion);

      _lastCheckTime = DateTime.now();
      _lastUpdateInfo = UpdateInfo(
        isUpdateAvailable: isUpdateAvailable,
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
        sha256: sha256Hash,
        changelog: changelog,
        isMandatory: isMandatory,
      );

      return isUpdateAvailable ? _lastUpdateInfo : null;
    } catch (e, stack) {
      AppLogger.instance.error('Failed to check for updates: $e', e, stack);
      return null;
    }
  }

  bool _isVersionGreaterThan(String newVersion, String currentVersion) {
    List<int> newV = newVersion.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    List<int> curV = currentVersion.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      int n = i < newV.length ? newV[i] : 0;
      int c = i < curV.length ? curV[i] : 0;
      if (n > c) return true;
      if (n < c) return false;
    }
    return false;
  }
}
