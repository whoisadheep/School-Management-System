import 'dart:convert';

class SalaryComponent {
  final String id;
  final String staffId;
  final String componentType;
  final double amount;
  final String effectiveFrom;

  const SalaryComponent({
    required this.id,
    required this.staffId,
    required this.componentType,
    required this.amount,
    required this.effectiveFrom,
  });

  SalaryComponent copyWith({
    String? id,
    String? staffId,
    String? componentType,
    double? amount,
    String? effectiveFrom,
  }) {
    return SalaryComponent(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      componentType: componentType ?? this.componentType,
      amount: amount ?? this.amount,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staff_id': staffId,
      'component_type': componentType,
      'amount': amount,
      'effective_from': effectiveFrom,
    };
  }

  factory SalaryComponent.fromMap(Map<String, dynamic> map) {
    return SalaryComponent(
      id: map['id'] as String,
      staffId: map['staff_id'] as String,
      componentType: map['component_type'] as String,
      amount: map['amount'] as double,
      effectiveFrom: map['effective_from'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory SalaryComponent.fromJson(String source) => SalaryComponent.fromMap(json.decode(source) as Map<String, dynamic>);
}
