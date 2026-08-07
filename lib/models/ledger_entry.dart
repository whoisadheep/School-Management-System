import 'package:uuid/uuid.dart';

/// Ledger entry type: income or expense
enum LedgerType {
  income,
  expense;

  static LedgerType fromString(String value) {
    return LedgerType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LedgerType.income,
    );
  }

  String get displayName {
    switch (this) {
      case LedgerType.income:
        return 'Income';
      case LedgerType.expense:
        return 'Expense';
    }
  }
}

class LedgerEntry {
  final String id;
  final DateTime date;
  final LedgerType type;
  final String category;
  final double amount;
  final String? description;
  final String? referenceId;
  final DateTime createdAt;

  const LedgerEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.category,
    required this.amount,
    this.description,
    this.referenceId,
    required this.createdAt,
  });

  factory LedgerEntry.create({
    required DateTime date,
    required LedgerType type,
    required String category,
    required double amount,
    String? description,
    String? referenceId,
  }) {
    return LedgerEntry(
      id: const Uuid().v4(),
      date: date,
      type: type,
      category: category,
      amount: amount,
      description: description,
      referenceId: referenceId,
      createdAt: DateTime.now(),
    );
  }

  /// Deserialize from SQLite row
  factory LedgerEntry.fromMap(Map<String, dynamic> map) {
    return LedgerEntry(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      type: LedgerType.fromString(map['type'] as String),
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      referenceId: map['reference_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Serialize to SQLite row
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'type': type.name,
      'category': category,
      'amount': amount,
      'description': description,
      'reference_id': referenceId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  LedgerEntry copyWith({
    String? id,
    DateTime? date,
    LedgerType? type,
    String? category,
    double? amount,
    String? description,
    String? referenceId,
    DateTime? createdAt,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      referenceId: referenceId ?? this.referenceId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'LedgerEntry(id: $id, date: $date, type: ${type.name}, '
        'category: $category, amount: $amount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LedgerEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
