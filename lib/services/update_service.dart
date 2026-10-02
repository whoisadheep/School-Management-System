import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
  
  static const String _updateJsonUrl = 'https://raw.githubusercontent.com/whoisadheep/School-Management-System/main/version.json';

  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    if (!force && _lastCheckTime != null) {
      final difference = DateTime.now().difference(_lastCheckTime!);
      if (difference < _cacheDuration) {
        return _lastUpdateInfo?.isUpdateAvailable == true ? _lastUpdateInfo : null;
      }
    }

    try {
      final dio = Dio();
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) => true;
          return client;
        },
      );
      dio.options.connectTimeout = const Duration(seconds: 15);
      dio.options.receiveTimeout = const Duration(seconds: 15);
      dio.options.headers = {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
      };
      
      // Fetch the static version.json file with cache buster
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await dio.get('$_updateJsonUrl?_t=$timestamp');
      
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

  /// Downloads the update installer in the background with progress reporting.
  Future<File> downloadInstaller(
    UpdateInfo updateInfo, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final installerPath = p.join(tempDir.path, 'sms_updater_${updateInfo.latestVersion}.exe');
    final downloadedFile = File(installerPath);

    // If file already exists and matches hash or valid size, reuse it
    if (await downloadedFile.exists()) {
      try {
        if (updateInfo.sha256.isNotEmpty) {
          final bytes = await downloadedFile.readAsBytes();
          final hash = sha256.convert(bytes).toString();
          if (hash.toLowerCase() == updateInfo.sha256.toLowerCase()) {
            final len = await downloadedFile.length();
            onProgress(len, len);
            return downloadedFile;
          }
        } else {
          final len = await downloadedFile.length();
          if (len > 5 * 1024 * 1024) {
            onProgress(len, len);
            return downloadedFile;
          }
        }
      } catch (_) {}
    }

    final dio = Dio();
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );
    dio.options.connectTimeout = const Duration(seconds: 30);
    dio.options.receiveTimeout = const Duration(minutes: 15);

    int expectedSize = -1;
    try {
      final headResponse = await dio.head(updateInfo.downloadUrl);
      expectedSize = int.tryParse(headResponse.headers.value(HttpHeaders.contentLengthHeader) ?? '') ?? -1;
    } catch (_) {}

    await dio.download(
      updateInfo.downloadUrl,
      installerPath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        onProgress(received, total != -1 ? total : expectedSize);
      },
    );

    if (!await downloadedFile.exists()) {
      throw Exception('Downloaded installer not found at $installerPath');
    }

    if (expectedSize != -1) {
      final actualSize = await downloadedFile.length();
      if (actualSize != expectedSize) {
        throw Exception('Download incomplete. Expected $expectedSize bytes, received $actualSize bytes.');
      }
    }

    if (updateInfo.sha256.isNotEmpty) {
      final bytes = await downloadedFile.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      if (hash.toLowerCase() != updateInfo.sha256.toLowerCase()) {
        throw Exception('Security error: File hash mismatch (expected ${updateInfo.sha256}, got $hash).');
      }
    }

    return downloadedFile;
  }

  /// Launches the installer detached and exits the current app process.
  Future<void> launchInstallerAndExit(String installerPath) async {
    final file = File(installerPath);
    if (!await file.exists()) {
      throw Exception('Installer file not found at $installerPath');
    }

    await Process.start(
      installerPath,
      [],
      mode: ProcessStartMode.detached,
      runInShell: true,
    );
    exit(0);
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
