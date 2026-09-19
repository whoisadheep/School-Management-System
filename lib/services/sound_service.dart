import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

typedef _PlaySoundWNative = Int32 Function(Pointer<Utf16> pszSound, IntPtr hmod, Uint32 fdwSound);
typedef _PlaySoundWDart = int Function(Pointer<Utf16> pszSound, int hmod, int fdwSound);

/// Audio micro-feedback service for Eduvia.
///
/// Provides satisfying, ultra-low-latency sound cues for desktop POS interactions,
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

  // Pre-allocated Windows Win32 UTF-16 pointers for instantaneous 0ms playback
  _PlaySoundWDart? _winPlaySound;
  Pointer<Utf16>? _winSuccessPtr;
  Pointer<Utf16>? _winClickPtr;
  Pointer<Utf16>? _winAlertPtr;

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

      if (!kIsWeb && Platform.isWindows) {
        try {
          final winmm = DynamicLibrary.open('winmm.dll');
          _winPlaySound = winmm.lookupFunction<_PlaySoundWNative, _PlaySoundWDart>('PlaySoundW');

          // Pre-allocate native UTF-16 strings to eliminate runtime allocation delay completely
          if (_successPath != null) {
            _winSuccessPtr = _successPath!.replaceAll('/', '\\').toNativeUtf16();
          }
          if (_clickPath != null) {
            _winClickPtr = _clickPath!.replaceAll('/', '\\').toNativeUtf16();
          }
          if (_alertPath != null) {
            _winAlertPtr = _alertPath!.replaceAll('/', '\\').toNativeUtf16();
          }
        } catch (e) {
          debugPrint('Eduvia SoundService Win32 PlaySound init notice: $e');
        }
      } else if (!kIsWeb && Platform.isLinux) {
        // Detect fastest available Linux audio player
        for (final cmd in ['pw-play', 'paplay', 'canberra-gtk-play', 'aplay']) {
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
    _triggerSound(
      winPtr: _winSuccessPtr,
      cachedPath: _successPath,
      fallbackAsset: 'assets/sounds/success.wav',
    );
  }

  /// Plays subtle tactile mechanical micro-click for keyboard navigation & month cycling
  void playClick() {
    _triggerSound(
      winPtr: _winClickPtr,
      cachedPath: _clickPath,
      fallbackAsset: 'assets/sounds/click.wav',
    );
  }

  /// Plays gentle double-tone alert for past arrears or validation warnings
  void playAlert() {
    _triggerSound(
      winPtr: _winAlertPtr,
      cachedPath: _alertPath,
      fallbackAsset: 'assets/sounds/alert.wav',
    );
  }

  void _triggerSound({
    required Pointer<Utf16>? winPtr,
    required String? cachedPath,
    required String fallbackAsset,
  }) {
    if (!soundEnabled) return;

    // Windows Fast-Path: Instant Win32 native API execution (0ms delay)
    if (!kIsWeb && Platform.isWindows && _winPlaySound != null && winPtr != null) {
      // SND_ASYNC (0x0001) | SND_FILENAME (0x00020000) | SND_NODEFAULT (0x0002)
      const flags = 0x00020001 | 0x0002;
      _winPlaySound!(winPtr, 0, flags);
      return;
    }

    // Non-Windows or async fallback
    Future.microtask(() async {
      try {
        if (!_initialized) {
          await init();
        }

        // Check Windows fast-path again if init just finished
        if (!kIsWeb && Platform.isWindows && _winPlaySound != null && winPtr != null) {
          const flags = 0x00020001 | 0x0002;
          _winPlaySound!(winPtr, 0, flags);
          return;
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
              Process.start('aplay', ['-q', path]);
            } else if (player == 'canberra-gtk-play') {
              Process.start('canberra-gtk-play', ['-f', path]);
            } else {
              Process.start(player, [path]);
            }
          } else {
            SystemSound.play(SystemSoundType.click);
          }
        } else if (Platform.isMacOS) {
          if (path != null && File(path).existsSync()) {
            Process.start('afplay', [path]);
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
