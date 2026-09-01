import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/admin_user.dart';
import '../../../models/audit_log.dart';
import '../../layout/widgets/glass_card.dart';
import '../../../core/auth/permission_helper.dart';

final adminUsersProvider = FutureProvider.autoDispose<List<AdminUser>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  final db = await dbService.rawDb;
  final results = await db.query('admin_users');
  return results.map((m) => AdminUser.fromMap(m)).toList();
});

class AdminUsersView extends ConsumerStatefulWidget {
  const AdminUsersView({super.key});

  @override
  ConsumerState<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends ConsumerState<AdminUsersView> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final adminRole = authState.currentAdmin?.role.toLowerCase();
    final isAdmin = adminRole == 'admin' || adminRole == 'principal' || authState.currentAdmin?.username.toLowerCase() == 'admin';
    if (!isAdmin) {
      return Center(
        child: Text(
          'Access Denied: Admin access required',
          style: GoogleFonts.poppins(color: AppTheme.error, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Manage Admin Users', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showAddUserDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add User', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
          ),
          const SizedBox(width: 24),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassCard(
          child: usersAsync.when(
            data: (users) {
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 320,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  mainAxisExtent: 260,
                ),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final u = users[index];
                  final isCurrentUser = authState.currentUser?.id == u.id;
                  
                  return Container(
                    decoration: AppTheme.cardDecoration(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: u.role == 'admin' ? AppTheme.primarySoft : AppTheme.infoLight,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                u.role.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: u.role == 'admin' ? AppTheme.primaryPurple : AppTheme.info,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: AppTheme.textHint),
                              onSelected: (val) {
                                if (val == 'edit') _showEditUserDialog(context, u);
                                if (val == 'reset') _showResetPasswordDialog(context, u);
                                if (val == 'toggle' && !isCurrentUser) _toggleUserActive(u, !u.isActive);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')]),
                                ),
                                PopupMenuItem(
                                  value: 'reset',
                                  child: Row(children: [Icon(Icons.lock_reset, size: 18, color: AppTheme.error), SizedBox(width: 8), Text('Reset Password', style: TextStyle(color: AppTheme.error))]),
                                ),
                                if (!isCurrentUser)
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Row(children: [
                                      Icon(u.isActive ? Icons.block : Icons.check_circle_outline, size: 18), 
                                      SizedBox(width: 8), 
                                      Text(u.isActive ? 'Deactivate' : 'Reactivate')
                                    ]),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: u.isActive ? AppTheme.primaryPurple : Colors.grey.shade400,
                          child: Text(
                            u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                            style: GoogleFonts.poppins(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          u.fullName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: u.isActive ? AppTheme.textPrimary : AppTheme.textHint,
                            decoration: u.isActive ? null : TextDecoration.lineThrough,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${u.username}',
                          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        const Spacer(),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.bgMain,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Last Login: ${u.lastLogin != null ? DateFormat('MMM d, yyyy HH:mm').format(u.lastLogin!) : 'Never'}',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Text('Error: $e'),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleUserActive(AdminUser user, bool val) async {
    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.manageAdminUsers)) return;
    
    final dbService = ref.read(databaseServiceProvider);
    final db = await dbService.rawDb;
    final currentUserId = ref.read(authProvider).currentUser?.id;
    
    await db.update('admin_users', {'is_active': val ? 1 : 0}, where: 'id = ?', whereArgs: [user.id]);
    
    // Log action
    final auditLog = AuditLog(
      id: const Uuid().v4(),
      adminUserId: currentUserId,
      actionType: 'update',
      module: 'Admin Users',
      entityType: 'admin_users',
      entityId: user.id,
      description: '${val ? 'Reactivated' : 'Deactivated'} user @${user.username}',
      oldValue: '{"is_active": ${user.isActive ? 1 : 0}}',
      newValue: '{"is_active": ${val ? 1 : 0}}',
      timestamp: DateTime.now(),
    );
    await db.insert('audit_logs', auditLog.toMap());
    
    ref.invalidate(adminUsersProvider);
  }

  void _showAddUserDialog(BuildContext context) {
    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.manageAdminUsers)) return;

    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    String role = 'user';
    String? errorMsg;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add New Admin User', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMsg != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(errorMsg!, style: GoogleFonts.poppins(color: AppTheme.error, fontSize: 12)),
                      ),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
                    const SizedBox(height: 12),
                    TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Username *')),
                    const SizedBox(height: 12),
                    TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password *'), obscureText: true),
                    const SizedBox(height: 12),
                    TextField(controller: confirmPassCtrl, decoration: const InputDecoration(labelText: 'Confirm Password *'), obscureText: true),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(labelText: 'Role *'),
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('Admin (Full Access)')),
                        DropdownMenuItem(value: 'user', child: Text('User (Limited Access)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => role = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || userCtrl.text.isEmpty || passCtrl.text.isEmpty) {
                    setState(() => errorMsg = 'Please fill all fields');
                    return;
                  }
                  if (passCtrl.text != confirmPassCtrl.text) {
                    setState(() => errorMsg = 'Passwords do not match');
                    return;
                  }

                  final dbService = ref.read(databaseServiceProvider);
                  final db = await dbService.rawDb;

                  // Check uniqueness
                  final existing = await db.query('admin_users', where: 'username = ?', whereArgs: [userCtrl.text.trim()]);
                  if (existing.isNotEmpty) {
                    setState(() => errorMsg = 'Username is already taken');
                    return;
                  }

                  final newId = const Uuid().v4();
                  final hash = BCrypt.hashpw(passCtrl.text, BCrypt.gensalt());
                  
                  await db.insert('admin_users', {
                    'id': newId,
                    'username': userCtrl.text.trim(),
                    'password_hash': hash,
                    'full_name': nameCtrl.text.trim(),
                    'role': role,
                    'is_active': 1,
                    'created_at': DateTime.now().toIso8601String(),
                  });

                  final currentUserId = ref.read(authProvider).currentUser?.id;
                  final auditLog = AuditLog(
                    id: const Uuid().v4(),
                    adminUserId: currentUserId,
                    actionType: 'create',
                    module: 'Admin Users',
                    entityType: 'admin_users',
                    entityId: newId,
                    description: 'Created new user @${userCtrl.text.trim()}',
                    newValue: '{"username": "${userCtrl.text.trim()}", "role": "$role"}',
                    timestamp: DateTime.now(),
                  );
                  await db.insert('audit_logs', auditLog.toMap());

                  ref.invalidate(adminUsersProvider);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, AdminUser user) {
    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.manageAdminUsers)) return;

    final nameCtrl = TextEditingController(text: user.fullName);
    String role = user.role;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Edit User: @${user.username}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Role *'),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Admin (Full Access)')),
                      DropdownMenuItem(value: 'user', child: Text('User (Limited Access)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => role = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;

                  final dbService = ref.read(databaseServiceProvider);
                  final db = await dbService.rawDb;

                  final updates = {
                    'full_name': nameCtrl.text.trim(),
                    'role': role,
                  };
                  
                  await db.update('admin_users', updates, where: 'id = ?', whereArgs: [user.id]);

                  final currentUserId = ref.read(authProvider).currentUser?.id;
                  final auditLog = AuditLog(
                    id: const Uuid().v4(),
                    adminUserId: currentUserId,
                    actionType: 'update',
                    module: 'Admin Users',
                    entityType: 'admin_users',
                    entityId: user.id,
                    description: 'Updated user @${user.username}',
                    oldValue: '{"full_name": "${user.fullName}", "role": "${user.role}"}',
                    newValue: '{"full_name": "${nameCtrl.text.trim()}", "role": "$role"}',
                    timestamp: DateTime.now(),
                  );
                  await db.insert('audit_logs', auditLog.toMap());

                  ref.invalidate(adminUsersProvider);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, AdminUser user) {
    if (!PermissionHelper.requireAdminRole(context, ref, RiskyAction.manageAdminUsers)) return;

    final passCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    String? errorMsg;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Reset Password: @${user.username}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(errorMsg!, style: GoogleFonts.poppins(color: AppTheme.error, fontSize: 12)),
                    ),
                  const Text('Enter a temporary password for this user.'),
                  const SizedBox(height: 12),
                  TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'New Password *'), obscureText: true),
                  const SizedBox(height: 12),
                  TextField(controller: confirmPassCtrl, decoration: const InputDecoration(labelText: 'Confirm Password *'), obscureText: true),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
                onPressed: () async {
                  if (passCtrl.text.isEmpty) {
                    setState(() => errorMsg = 'Please enter a password');
                    return;
                  }
                  if (passCtrl.text != confirmPassCtrl.text) {
                    setState(() => errorMsg = 'Passwords do not match');
                    return;
                  }

                  final dbService = ref.read(databaseServiceProvider);
                  final db = await dbService.rawDb;

                  final hash = BCrypt.hashpw(passCtrl.text, BCrypt.gensalt());
                  await db.update('admin_users', {'password_hash': hash}, where: 'id = ?', whereArgs: [user.id]);

                  final currentUserId = ref.read(authProvider).currentUser?.id;
                  final auditLog = AuditLog(
                    id: const Uuid().v4(),
                    adminUserId: currentUserId,
                    actionType: 'update',
                    module: 'Admin Users',
                    entityType: 'admin_users',
                    entityId: user.id,
                    description: 'Reset password for user @${user.username}',
                    timestamp: DateTime.now(),
                  );
                  await db.insert('audit_logs', auditLog.toMap());

                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Reset'),
              ),
            ],
          );
        },
      ),
    );
  }
}
