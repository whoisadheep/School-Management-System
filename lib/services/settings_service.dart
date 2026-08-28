import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_service.dart';

/// Service managing persistent system settings, output paths, and school profile info.
class SettingsService {
  final DatabaseService _dbService;

  SettingsService({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  /// Retrieve a setting value by key
  Future<String?> getSetting(String key) async {
    if (kIsWeb) return null;
    try {
      final db = await _dbService.rawDb;
      final results = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return results.first['value'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Save or update a setting value by key
  Future<void> setSetting(String key, String value) async {
    if (kIsWeb) return;
    try {
      final db = await _dbService.rawDb;
      await db.insert(
        'app_settings',
        {
          'key': key,
          'value': value,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  /// Get configured receipt export path or default to Documents/Eduvia/Receipts/
  Future<String> getReceiptExportPath() async {
    final configuredPath = await getSetting('receipt_export_path');
    if (configuredPath != null && configuredPath.isNotEmpty) {
      return configuredPath;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, 'Eduvia', 'Receipts');
  }

  /// Update receipt export path to user-chosen custom folder or shared network drive
  Future<void> setReceiptExportPath(String path) async {
    await setSetting('receipt_export_path', path);
  }
}
