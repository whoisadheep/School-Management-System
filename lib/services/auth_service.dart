import 'package:bcrypt/bcrypt.dart';
import 'package:uuid/uuid.dart';
import 'package:school_management_system/core/database/database_helper.dart';
import 'package:school_management_system/models/admin_user.dart';

class AuthService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<AdminUser?> loginAdmin(String username, String password) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'admin_users',
      where: 'username = ? AND is_active = 1',
      whereArgs: [username],
      limit: 1,
    );

    if (results.isEmpty) {
      await db.insert('audit_logs', {
        'id': const Uuid().v4(),
        'admin_user_id': null,
        'action_type': 'login',
        'module': 'Security',
        'description': 'Failed login attempt for unknown user: $username',
        'timestamp': DateTime.now().toIso8601String(),
      });
      return null;
    }

    final userMap = results.first;
    final storedHash = userMap['password_hash'] as String;

    if (BCrypt.checkpw(password, storedHash)) {
      // Update last login
      await db.update(
        'admin_users',
        {'last_login': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [userMap['id']],
      );
      
      await db.insert('audit_logs', {
        'id': const Uuid().v4(),
        'admin_user_id': userMap['id'],
        'action_type': 'login',
        'module': 'Security',
        'description': 'Successful login',
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Fetch updated record
      final updatedResults = await db.query(
        'admin_users',
        where: 'id = ?',
        whereArgs: [userMap['id']],
        limit: 1,
      );
      
      return AdminUser.fromMap(userMap);
    }
    
    await db.insert('audit_logs', {
      'id': const Uuid().v4(),
      'admin_user_id': userMap['id'],
      'action_type': 'login',
      'module': 'Security',
      'description': 'Failed login attempt (wrong password)',
      'timestamp': DateTime.now().toIso8601String(),
    });

    return null;
  }

  Future<void> changePassword(String userId, String newPassword) async {
    final db = await _dbHelper.database;
    final newHash = BCrypt.hashpw(newPassword, BCrypt.gensalt());
    await db.update(
      'admin_users',
      {
        'password_hash': newHash,
        'force_password_change': 0,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}
