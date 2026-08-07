class AdminUser {
  final String id;
  final String username;
  final String fullName;
  final String role;
  final bool isActive;
  final bool forcePasswordChange;
  final DateTime createdAt;
  final DateTime? lastLogin;

  const AdminUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.forcePasswordChange,
    required this.createdAt,
    this.lastLogin,
  });

  factory AdminUser.fromMap(Map<String, dynamic> map) {
    return AdminUser(
      id: map['id'] as String,
      username: map['username'] as String,
      fullName: map['full_name'] as String,
      role: map['role'] as String,
      isActive: (map['is_active'] as int?) == 1,
      forcePasswordChange: (map['force_password_change'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastLogin: map['last_login'] != null ? DateTime.parse(map['last_login'] as String) : null,
    );
  }
}
