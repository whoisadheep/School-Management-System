import re

with open('lib/core/database/database_helper.dart', 'r') as f:
    content = f.read()

migration_code = """
  /// Migrate legacy database from 'SchoolManagementSystem' to 'Eduvia' if needed
  Future<void> _migrateLegacyDatabasePath(String appDocPath) async {
    final legacyDir = Directory(p.join(appDocPath, 'SchoolManagementSystem'));
    final legacyDb = File(p.join(legacyDir.path, 'school_management.db'));
    
    final newDir = Directory(p.join(appDocPath, 'Eduvia'));
    final newDb = File(p.join(newDir.path, 'school_management.db'));
    
    if (await legacyDb.exists() && !(await newDb.exists())) {
      print('Legacy database found! Migrating data to new Eduvia directory...');
      if (!(await newDir.exists())) {
        await newDir.create(recursive: true);
      }
      
      // Copy database file
      await legacyDb.copy(newDb.path);
      
      // Also attempt to migrate Receipts, Backups, Reports, etc. if they exist
      final legacyFolders = ['Receipts', 'Backups', 'ReportCards', 'Logs', 'Media', 'ID_Cards', 'Certificates'];
      for (final folder in legacyFolders) {
        final oldFolder = Directory(p.join(legacyDir.path, folder));
        if (await oldFolder.exists()) {
          final targetFolder = Directory(p.join(newDir.path, folder));
          if (!(await targetFolder.exists())) {
            await targetFolder.create(recursive: true);
          }
          // We don't recursively copy files in pure Dart easily without a package, but moving the directory works if on same drive
          try {
            await oldFolder.rename(targetFolder.path);
          } catch (e) {
            print('Could not move $folder: $e');
          }
        }
      }
    }
  }
"""

# Insert _migrateLegacyDatabasePath into DatabaseHelper class
pattern = r'class DatabaseHelper \{'
replacement = r'class DatabaseHelper {\n' + migration_code
content = re.sub(pattern, replacement, content)

# Call it in database getter
getter_pattern = r'final String dbPath = p\.join\(appDocDir\.path, \x27Eduvia\x27, _databaseName\);'
getter_replacement = r'await _migrateLegacyDatabasePath(appDocDir.path);\n      final String dbPath = p.join(appDocDir.path, \'Eduvia\', _databaseName);'
content = re.sub(getter_pattern, getter_replacement, content)

with open('lib/core/database/database_helper.dart', 'w') as f:
    f.write(content)
print("Added legacy migration.")
