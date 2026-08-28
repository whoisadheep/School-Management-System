import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/database/database_helper.dart';

class BackupFileInfo {
  final String path;
  final String fileName;
  final int sizeBytes;
  final DateTime modifiedDate;

  const BackupFileInfo({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.modifiedDate,
  });
}

/// Backup and Disaster Recovery Service for desktop SQLite database.
class BackupService {
  final DatabaseHelper _dbHelper;

  BackupService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  /// Gets the path to the current SQLite database file
  Future<File> get _dbFile async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String dbPath = p.join(
        appDocDir.path, 'Eduvia', 'school_management.db');
    return File(dbPath);
  }

  /// Create an automated daily copy of the database in a secondary backup folder
  Future<File> createDailyAutoBackup() async {
    final file = await _dbFile;
    if (!await file.exists()) {
      throw const FileSystemException(
          'Database file does not exist to backup.');
    }

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String backupDirPath =
        p.join(appDocDir.path, 'Eduvia', 'Backups');

    final backupDir = Directory(backupDirPath);
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final String timeStamp =
        DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final String backupFileName = 'school_management_backup_$timeStamp.db';
    final String targetPath = p.join(backupDirPath, backupFileName);

    // Flush the write-ahead log before copying. Without this, a copied main
    // database can be missing recent changes that still live in the WAL file.
    final db = await _dbHelper.database;
    await db.execute('PRAGMA wal_checkpoint(FULL)');

    return await file.copy(targetPath);
  }

  /// Export a full manual backup to any target location chosen by the accountant (e.g. USB flash drive, OneDrive folder)
  Future<File> exportManualBackup(String destinationFolderPath) async {
    final file = await _dbFile;
    if (!await file.exists()) {
      throw const FileSystemException('Database file does not exist.');
    }

    final destDir = Directory(destinationFolderPath);
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final String timeStamp =
        DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final String backupFileName = 'SMS_Full_Backup_$timeStamp.db';
    final String targetPath = p.join(destinationFolderPath, backupFileName);

    final db = await _dbHelper.database;
    await db.execute('PRAGMA wal_checkpoint(FULL)');
    return await file.copy(targetPath);
  }

  /// Restore local database from a backup file path safely
  Future<void> restoreBackup(String backupFilePath) async {
    final backupFile = File(backupFilePath);
    if (!await backupFile.exists()) {
      throw FileSystemException(
          'Backup source file does not exist at $backupFilePath');
    }

    // 1. Safely close database connection
    await _dbHelper.close();

    // 2. Remove sidecar files from the previous database before restoring.
    // Keeping an old WAL alongside a restored main DB can replay stale data.
    final dbFile = await _dbFile;
    for (final suffix in ['-wal', '-shm']) {
      final sidecar = File('${dbFile.path}$suffix');
      if (await sidecar.exists()) {
        await sidecar.delete();
      }
    }

    // 3. Replace current database file with backup file
    await backupFile.copy(dbFile.path);

    // 4. Re-open database connection to verify
    await _dbHelper.database;
  }

  /// List all local automated backup files sorted by newest first
  Future<List<BackupFileInfo>> listAvailableBackups() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String backupDirPath =
        p.join(appDocDir.path, 'Eduvia', 'Backups');

    final backupDir = Directory(backupDirPath);
    if (!await backupDir.exists()) {
      return [];
    }

    final List<FileSystemEntity> files = await backupDir.list().toList();
    final List<BackupFileInfo> backups = [];

    for (final entity in files) {
      if (entity is File && entity.path.endsWith('.db')) {
        final stat = await entity.stat();
        backups.add(BackupFileInfo(
          path: entity.path,
          fileName: p.basename(entity.path),
          sizeBytes: stat.size,
          modifiedDate: stat.modified,
        ));
      }
    }

    backups.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
    return backups;
  }
}
