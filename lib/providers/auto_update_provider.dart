import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_logger.dart';
import '../services/update_service.dart';

enum AutoUpdateStatus {
  idle,
  checking,
  downloading,
  readyToInstall,
  error,
}

class AutoUpdateState {
  final AutoUpdateStatus status;
  final UpdateInfo? updateInfo;
  final double progress; // 0.0 to 1.0
  final int receivedBytes;
  final int totalBytes;
  final String? installerPath;
  final String? errorMessage;
  final bool isDismissed;
  final bool isCollapsed;

  const AutoUpdateState({
    this.status = AutoUpdateStatus.idle,
    this.updateInfo,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.installerPath,
    this.errorMessage,
    this.isDismissed = false,
    this.isCollapsed = false,
  });

  double get receivedMb => receivedBytes / (1024 * 1024);
  double get totalMb => totalBytes / (1024 * 1024);

  AutoUpdateState copyWith({
    AutoUpdateStatus? status,
    UpdateInfo? updateInfo,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    String? installerPath,
    String? errorMessage,
    bool? isDismissed,
    bool? isCollapsed,
  }) {
    return AutoUpdateState(
      status: status ?? this.status,
      updateInfo: updateInfo ?? this.updateInfo,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      installerPath: installerPath ?? this.installerPath,
      errorMessage: errorMessage ?? this.errorMessage,
      isDismissed: isDismissed ?? this.isDismissed,
      isCollapsed: isCollapsed ?? this.isCollapsed,
    );
  }
}

class AutoUpdateNotifier extends StateNotifier<AutoUpdateState> {
  final UpdateService _updateService;
  CancelToken? _cancelToken;

  AutoUpdateNotifier({UpdateService? updateService})
      : _updateService = updateService ?? UpdateService.instance,
        super(const AutoUpdateState());

  /// Checks if a new release is available on GitHub and automatically begins
  /// background downloading without blocking the user.
  Future<void> checkForUpdateAndAutoDownload({bool force = false}) async {
    if (kIsWeb) return;

    if (state.status == AutoUpdateStatus.downloading ||
        state.status == AutoUpdateStatus.readyToInstall) {
      return;
    }

    state = state.copyWith(status: AutoUpdateStatus.checking, errorMessage: null);

    try {
      final updateInfo = await _updateService.checkForUpdate(force: force);
      if (updateInfo == null || !updateInfo.isUpdateAvailable) {
        state = state.copyWith(status: AutoUpdateStatus.idle);
        return;
      }

      // New update available! Automatically start downloading in background
      state = state.copyWith(
        status: AutoUpdateStatus.downloading,
        updateInfo: updateInfo,
        progress: 0.0,
        receivedBytes: 0,
        totalBytes: 0,
        isDismissed: false,
      );

      _cancelToken = CancelToken();

      final file = await _updateService.downloadInstaller(
        updateInfo,
        cancelToken: _cancelToken,
        onProgress: (received, total) {
          final progress = (total > 0) ? (received / total).clamp(0.0, 1.0) : 0.0;
          state = state.copyWith(
            progress: progress,
            receivedBytes: received,
            totalBytes: total,
          );
        },
      );

      state = state.copyWith(
        status: AutoUpdateStatus.readyToInstall,
        progress: 1.0,
        installerPath: file.path,
      );
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) {
        state = state.copyWith(status: AutoUpdateStatus.idle);
        return;
      }
      AppLogger.instance.error('Background auto-update download failed: $e', e, stack);
      state = state.copyWith(
        status: AutoUpdateStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void toggleCollapsed() {
    state = state.copyWith(isCollapsed: !state.isCollapsed);
  }

  void dismiss() {
    state = state.copyWith(isDismissed: true);
  }

  void reopen() {
    state = state.copyWith(isDismissed: false, isCollapsed: false);
  }

  Future<void> retry() async {
    await checkForUpdateAndAutoDownload(force: true);
  }

  Future<void> applyUpdateAndRestart() async {
    if (state.installerPath != null) {
      try {
        await _updateService.launchInstallerAndExit(state.installerPath!);
      } catch (e, stack) {
        AppLogger.instance.error('Failed to launch installer: $e', e, stack);
        state = state.copyWith(
          status: AutoUpdateStatus.error,
          errorMessage: 'Failed to launch installer: $e',
        );
      }
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel('User cancelled download');
    state = state.copyWith(status: AutoUpdateStatus.idle, isDismissed: true);
  }
}

final autoUpdateProvider = StateNotifierProvider<AutoUpdateNotifier, AutoUpdateState>((ref) {
  return AutoUpdateNotifier();
});
