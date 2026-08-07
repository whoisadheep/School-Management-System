import 'dart:convert';

class DiscountType {
  final String id;
  final String name; // e.g. "Sibling Discount", "Staff Ward"
  final String discountKind; // 'percentage' or 'flat'
  final double value; // e.g. 15.0 for 15% or 5000.0 for flat ₹5000

  const DiscountType({
    required this.id,
    required this.name,
    required this.discountKind,
    required this.value,
  });

  DiscountType copyWith({
    String? id,
    String? name,
    String? discountKind,
    double? value,
  }) {
    return DiscountType(
      id: id ?? this.id,
      name: name ?? this.name,
      discountKind: discountKind ?? this.discountKind,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'discount_kind': discountKind,
      'value': value,
    };
  }

  factory DiscountType.fromMap(Map<String, dynamic> map) {
    return DiscountType(
      id: map['id'] as String,
      name: map['name'] as String,
      discountKind: map['discount_kind'] as String? ?? 'percentage',
      value: (map['value'] as num).toDouble(),
    );
  }

  String toJson() => json.encode(toMap());

  factory DiscountType.fromJson(String source) =>
      DiscountType.fromMap(json.decode(source) as Map<String, dynamic>);
}
