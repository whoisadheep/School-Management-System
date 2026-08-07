import 'package:flutter/foundation.dart';

@immutable
class AuditLog {
  final String id;
  final String? adminUserId;
  final String actionType; // 'create','update','delete','login','risky_action_blocked'
  final String module;
  final String? entityType;
  final String? entityId;
  final String description;
  final String? oldValue;
  final String? newValue;
  final DateTime timestamp;

  const AuditLog({
    required this.id,
    this.adminUserId,
    required this.actionType,
    required this.module,
    this.entityType,
    this.entityId,
    required this.description,
    this.oldValue,
    this.newValue,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'admin_user_id': adminUserId,
      'action_type': actionType,
      'module': module,
      'entity_type': entityType,
      'entity_id': entityId,
      'description': description,
      'old_value': oldValue,
      'new_value': newValue,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'],
      adminUserId: map['admin_user_id'],
      actionType: map['action_type'],
      module: map['module'],
      entityType: map['entity_type'],
      entityId: map['entity_id'],
      description: map['description'],
      oldValue: map['old_value'],
      newValue: map['new_value'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
