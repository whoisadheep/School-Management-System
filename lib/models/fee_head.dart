import 'dart:convert';

class FeeHead {
  final String id;
  final String name; // e.g. "Tuition Fee", "Transport Fee"
  final String? description;
  final bool isRecurring;
  final String frequency; // 'monthly', 'quarterly', 'annual', 'one_time'

  const FeeHead({
    required this.id,
    required this.name,
    this.description,
    this.isRecurring = true,
    required this.frequency,
  });

  FeeHead copyWith({
    String? id,
    String? name,
    String? description,
    bool? isRecurring,
    String? frequency,
  }) {
    return FeeHead(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isRecurring: isRecurring ?? this.isRecurring,
      frequency: frequency ?? this.frequency,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_recurring': isRecurring ? 1 : 0,
      'frequency': frequency,
    };
  }

  factory FeeHead.fromMap(Map<String, dynamic> map) {
    return FeeHead(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      isRecurring: (map['is_recurring'] as int?) == 1,
      frequency: map['frequency'] as String? ?? 'monthly',
    );
  }

  String toJson() => json.encode(toMap());

  factory FeeHead.fromJson(String source) =>
      FeeHead.fromMap(json.decode(source) as Map<String, dynamic>);
}
