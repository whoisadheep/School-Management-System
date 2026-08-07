import 'dart:convert';

class Circular {
  final String id;
  final String title;
  final String body;
  final String sentBy;
  final String sentAt; // YYYY-MM-DD HH:mm:ss
  final String targetType; // 'all', 'department', 'individual'
  final String? targetId;

  const Circular({
    required this.id,
    required this.title,
    required this.body,
    required this.sentBy,
    required this.sentAt,
    required this.targetType,
    this.targetId,
  });

  Circular copyWith({
    String? id,
    String? title,
    String? body,
    String? sentBy,
    String? sentAt,
    String? targetType,
    String? targetId,
  }) {
    return Circular(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      sentBy: sentBy ?? this.sentBy,
      sentAt: sentAt ?? this.sentAt,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'sent_by': sentBy,
      'sent_at': sentAt,
      'target_type': targetType,
      'target_id': targetId,
    };
  }

  factory Circular.fromMap(Map<String, dynamic> map) {
    return Circular(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      sentBy: map['sent_by'] as String,
      sentAt: map['sent_at'] as String,
      targetType: map['target_type'] as String,
      targetId: map['target_id'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory Circular.fromJson(String source) =>
      Circular.fromMap(json.decode(source) as Map<String, dynamic>);
}
