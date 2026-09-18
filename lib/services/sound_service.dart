import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Audio micro-feedback service for Eduvia.
///
/// Provides satisfying, low-latency sound cues for desktop POS interactions,
/// financial receipts, keyboard shortcuts, and alert notifications.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  bool soundEnabled = true;

  void toggleSound() {
    soundEnabled = !soundEnabled;
  }

  // Cached file paths for synthesized WAV assets
  String? _successPath;
  String? _clickPath;
  String? _alertPath;
  bool _initialized = false;
  String? _linuxPlayer;

  /// Initialize sound files from assets into temporary cache directory
  Future<void> init() async {
    if (_initialized) return;
    try {
      final cacheDir = Directory(p.join(Directory.systemTemp.path, 'eduvia_sounds'));
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }

      _successPath = await _extractAsset('assets/sounds/success.wav', cacheDir, 'success.wav');
      _clickPath = await _extractAsset('assets/sounds/click.wav', cacheDir, 'click.wav');
      _alertPath = await _extractAsset('assets/sounds/alert.wav', cacheDir, 'alert.wav');

      if (!kIsWeb && Platform.isLinux) {
        // Detect fastest available Linux audio player
        for (final cmd in ['pw-play', 'paplay', 'aplay', 'canberra-gtk-play']) {
          final res = await Process.run('which', [cmd]);
          if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
            _linuxPlayer = cmd;
            break;
          }
        }
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Eduvia SoundService init notice: $e');
    }
  }

  Future<String> _extractAsset(String assetPath, Directory targetDir, String filename) async {
    final targetFile = File(p.join(targetDir.path, filename));
    if (!targetFile.existsSync() || targetFile.lengthSync() == 0) {
      try {
        final byteData = await rootBundle.load(assetPath);
        final bytes = byteData.buffer.asUint8List();
        await targetFile.writeAsBytes(bytes, flush: true);
      } catch (_) {
        final localFile = File(assetPath);
        if (localFile.existsSync()) {
          return localFile.absolute.path;
        }
      }
    }
    return targetFile.absolute.path;
  }

  /// Plays crisp cash-register / payment success chime
  void playSuccess() {
    _playSound(_successPath, fallbackAsset: 'assets/sounds/success.wav');
  }

  /// Plays subtle tactile mechanical micro-click for keyboard navigation & month cycling
  void playClick() {
    _playSound(_clickPath, fallbackAsset: 'assets/sounds/click.wav');
  }

  /// Plays gentle double-tone alert for past arrears or validation warnings
  void playAlert() {
    _playSound(_alertPath, fallbackAsset: 'assets/sounds/alert.wav');
  }

  void _playSound(String? cachedPath, {required String fallbackAsset}) {
    if (!soundEnabled) return;

    // Fire and forget asynchronously
    Future.microtask(() async {
      try {
        if (!_initialized) {
          await init();
        }

        final path = cachedPath ?? (File(fallbackAsset).existsSync() ? fallbackAsset : null);

        if (kIsWeb) {
          SystemSound.play(SystemSoundType.click);
          return;
        }

        if (Platform.isLinux) {
          if (path != null && File(path).existsSync()) {
            final player = _linuxPlayer ?? 'aplay';
            if (player == 'aplay') {
              Process.run('aplay', ['-q', path]);
            } else if (player == 'canberra-gtk-play') {
              Process.run('canberra-gtk-play', ['-f', path]);
            } else {
              Process.run(player, [path]);
            }
          } else {
            SystemSound.play(SystemSoundType.click);
          }
        } else if (Platform.isWindows) {
          if (path != null && File(path).existsSync()) {
            final winPath = path.replaceAll('/', '\\');
            Process.start(
              'powershell',
              [
                '-NoProfile',
                '-NonInteractive',
                '-Command',
                "(New-Object Media.SoundPlayer '$winPath').PlaySync()"
              ],
              runInShell: true,
            );
          } else {
            SystemSound.play(SystemSoundType.click);
          }
        } else if (Platform.isMacOS) {
          if (path != null && File(path).existsSync()) {
            Process.run('afplay', [path]);
          } else {
            SystemSound.play(SystemSoundType.click);
          }
        } else {
          SystemSound.play(SystemSoundType.click);
        }
      } catch (_) {
        // Silently fail if audio device is unavailable
      }
    });
  }
}
