import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();

  factory AppLogger() {
    return _instance;
  }

  AppLogger._internal();

  static AppLogger get instance => _instance;

  File? _logFile;
  final int _maxLogSizeBytes = 500 * 1024; // 500 KB

  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final logDir = Directory(p.join(docsDir.path, 'Eduvia', 'Logs'));
      
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      
      _logFile = File(p.join(logDir.path, 'app.log'));
      
      if (!await _logFile!.exists()) {
        await _logFile!.create();
      }
    } catch (e) {
      debugPrint('Logger initialization error: $e');
    }
  }

  String? getLogFilePath() {
    return _logFile?.path;
  }

  Future<void> _writeLog(LogLevel level, String message, [Object? error, StackTrace? stackTrace]) async {
    debugPrint('[$level] $message ${error != null ? "Error: $error" : ""}');
    if (kIsWeb || _logFile == null) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase();
    
    final sb = StringBuffer();
    sb.writeln('[$timestamp] [$levelStr] $message');
    
    if (error != null) {
      sb.writeln('Error: $error');
    }
    
    if (stackTrace != null) {
      sb.writeln('StackTrace:\n$stackTrace');
    }

    try {
      await _logFile!.writeAsString(sb.toString(), mode: FileMode.append);
      await _checkLogSize();
    } catch (e) {
      // Print to console if writing to file fails
      print('Failed to write log: $e');
    }
  }

  Future<void> _checkLogSize() async {
    if (_logFile == null) return;

    try {
      final size = await _logFile!.length();
      if (size > _maxLogSizeBytes) {
        final lines = await _logFile!.readAsLines();
        final halfIndex = lines.length ~/ 2;
        
        final newContent = lines.sublist(halfIndex).join('\n') + '\n';
        await _logFile!.writeAsString(newContent, mode: FileMode.write);
      }
    } catch (e) {
      print('Failed to check or truncate log size: $e');
    }
  }

  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _writeLog(LogLevel.debug, message, error, stackTrace);
  }

  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _writeLog(LogLevel.info, message, error, stackTrace);
  }

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _writeLog(LogLevel.warning, message, error, stackTrace);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _writeLog(LogLevel.error, message, error, stackTrace);
  }

  Future<List<String>> getRecentLogs(int count) async {
    if (_logFile == null || !await _logFile!.exists()) return [];

    try {
      final lines = await _logFile!.readAsLines();
      if (lines.length <= count) {
        return lines;
      }
      return lines.sublist(lines.length - count);
    } catch (e) {
      print('Failed to read recent logs: $e');
      return [];
    }
  }
}
