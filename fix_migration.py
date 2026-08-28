import re

with open('lib/core/database/database_helper.dart', 'r') as f:
    content = f.read()

replacement = """
      // Copy database file and WAL files
      await legacyDb.copy(newDb.path);
      
      final legacyWal = File('${legacyDb.path}-wal');
      if (await legacyWal.exists()) {
        await legacyWal.copy('${newDb.path}-wal');
      }
      
      final legacyShm = File('${legacyDb.path}-shm');
      if (await legacyShm.exists()) {
        await legacyShm.copy('${newDb.path}-shm');
      }
"""

content = re.sub(r'// Copy database file\s*await legacyDb\.copy\(newDb\.path\);', replacement, content)

with open('lib/core/database/database_helper.dart', 'w') as f:
    f.write(content)

print("Fixed WAL migration")
