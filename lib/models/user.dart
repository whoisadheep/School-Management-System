import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

enum UserRole {
  admin,
  accountant,
  teacher,
  viewer;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserRole.accountant,
    );
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin (Full Access)';
      case UserRole.accountant:
        return 'Accountant';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.viewer:
        return 'Viewer / Auditor';
    }
  }
}

class User {
  final String id;
  final String username;
  final String fullName;
  final UserRole role;
  final String pinHash;
  final String? staffId;
  final bool canViewFinance;
  final bool canMarkOwnAttendance;
  final bool canUploadMarks;
  final bool canViewAllStudents;
  final bool canApproveLeave;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.pinHash,
    this.staffId,
    this.canViewFinance = false,
    this.canMarkOwnAttendance = false,
    this.canUploadMarks = false,
    this.canViewAllStudents = false,
    this.canApproveLeave = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Hash raw PIN string using SHA-256 for secure storage
  static String hashPin(String rawPin) {
    final bytes = utf8.encode('SMS_SALT_$rawPin');
    return sha256.convert(bytes).toString();
  }

  /// Verify raw PIN against this user's stored pinHash
  bool verifyPin(String rawPin) {
    return hashPin(rawPin) == pinHash;
  }

  User copyWith({
    String? id,
    String? username,
    String? fullName,
    UserRole? role,
    String? pinHash,
    String? staffId,
    bool? canViewFinance,
    bool? canMarkOwnAttendance,
    bool? canUploadMarks,
    bool? canViewAllStudents,
    bool? canApproveLeave,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      pinHash: pinHash ?? this.pinHash,
      staffId: staffId ?? this.staffId,
      canViewFinance: canViewFinance ?? this.canViewFinance,
      canMarkOwnAttendance: canMarkOwnAttendance ?? this.canMarkOwnAttendance,
      canUploadMarks: canUploadMarks ?? this.canUploadMarks,
      canViewAllStudents: canViewAllStudents ?? this.canViewAllStudents,
      canApproveLeave: canApproveLeave ?? this.canApproveLeave,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory User.create({
    required String username,
    required String fullName,
    required UserRole role,
    required String rawPin,
    String? staffId,
    bool canViewFinance = false,
    bool canMarkOwnAttendance = false,
    bool canUploadMarks = false,
    bool canViewAllStudents = false,
    bool canApproveLeave = false,
  }) {
    final now = DateTime.now();
    final isAdmin = role == UserRole.admin;
    return User(
      id: const Uuid().v4(),
      username: username,
      fullName: fullName,
      role: role,
      pinHash: hashPin(rawPin),
      staffId: staffId,
      canViewFinance: isAdmin ? true : canViewFinance,
      canMarkOwnAttendance: isAdmin ? true : canMarkOwnAttendance,
      canUploadMarks: isAdmin ? true : canUploadMarks,
      canViewAllStudents: isAdmin ? true : canViewAllStudents,
      canApproveLeave: isAdmin ? true : canApproveLeave,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory User.fromMap(Map<String, dynamic> map) {
    final role = UserRole.fromString(map['role'] as String);
    final isAdmin = role == UserRole.admin;

    return User(
      id: map['id'] as String,
      username: map['username'] as String,
      fullName: map['full_name'] as String,
      role: role,
      pinHash: map['pin_hash'] as String? ?? hashPin('1234'),
      staffId: map['staff_id'] as String?,
      canViewFinance: isAdmin ? true : (map['can_view_finance'] as int? ?? 0) == 1,
      canMarkOwnAttendance: isAdmin ? true : (map['can_mark_own_attendance'] as int? ?? 0) == 1,
      canUploadMarks: isAdmin ? true : (map['can_upload_marks'] as int? ?? 0) == 1,
      canViewAllStudents: isAdmin ? true : (map['can_view_all_students'] as int? ?? 0) == 1,
      canApproveLeave: isAdmin ? true : (map['can_approve_leave'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'role': role.name,
      'pin_hash': pinHash,
      'staff_id': staffId,
      'can_view_finance': canViewFinance ? 1 : 0,
      'can_mark_own_attendance': canMarkOwnAttendance ? 1 : 0,
      'can_upload_marks': canUploadMarks ? 1 : 0,
      'can_view_all_students': canViewAllStudents ? 1 : 0,
      'can_approve_leave': canApproveLeave ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String toJson() => json.encode(toMap());

  factory User.fromJson(String source) => User.fromMap(json.decode(source) as Map<String, dynamic>);
}
