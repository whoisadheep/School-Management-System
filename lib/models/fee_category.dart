import 'package:uuid/uuid.dart';

/// Billing cycle for a fee category
enum FeeCycle {
  monthly,
  yearly;

  static FeeCycle fromString(String value) {
    return FeeCycle.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FeeCycle.monthly,
    );
  }

  String get displayName {
    switch (this) {
      case FeeCycle.monthly:
        return 'Monthly';
      case FeeCycle.yearly:
        return 'Yearly';
    }
  }
}

class FeeCategory {
  final String id;
  final String name;
  final double defaultAmount;
  final FeeCycle cycle;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeeCategory({
    required this.id,
    required this.name,
    required this.defaultAmount,
    required this.cycle,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeeCategory.create({
    required String name,
    required double defaultAmount,
    required FeeCycle cycle,
  }) {
    final now = DateTime.now();
    return FeeCategory(
      id: const Uuid().v4(),
      name: name,
      defaultAmount: defaultAmount,
      cycle: cycle,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Deserialize from SQLite row
  factory FeeCategory.fromMap(Map<String, dynamic> map) {
    return FeeCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      defaultAmount: (map['default_amount'] as num).toDouble(),
      cycle: FeeCycle.fromString(map['cycle'] as String),
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Serialize to SQLite row
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'default_amount': defaultAmount,
      'cycle': cycle.name,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FeeCategory copyWith({
    String? id,
    String? name,
    double? defaultAmount,
    FeeCycle? cycle,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeeCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultAmount: defaultAmount ?? this.defaultAmount,
      cycle: cycle ?? this.cycle,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'FeeCategory(id: $id, name: $name, defaultAmount: $defaultAmount, '
        'cycle: ${cycle.name}, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeeCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
