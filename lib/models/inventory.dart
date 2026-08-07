import 'dart:convert';

class InventoryCategory {
  final String id;
  final String name;

  const InventoryCategory({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory InventoryCategory.fromMap(Map<String, dynamic> map) {
    return InventoryCategory(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }
}

class InventoryItem {
  final String id;
  final String name;
  final String categoryId;
  final String unit;
  final double currentStock;
  final double reorderThreshold;
  final double? unitCost;
  final String? storageLocation;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.unit,
    required this.currentStock,
    required this.reorderThreshold,
    this.unitCost,
    this.storageLocation,
  });

  InventoryItem copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? unit,
    double? currentStock,
    double? reorderThreshold,
    double? unitCost,
    String? storageLocation,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      reorderThreshold: reorderThreshold ?? this.reorderThreshold,
      unitCost: unitCost ?? this.unitCost,
      storageLocation: storageLocation ?? this.storageLocation,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'unit': unit,
      'current_stock': currentStock,
      'reorder_threshold': reorderThreshold,
      'unit_cost': unitCost,
      'storage_location': storageLocation,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      categoryId: map['category_id'] as String,
      unit: map['unit'] as String,
      currentStock: (map['current_stock'] as num).toDouble(),
      reorderThreshold: (map['reorder_threshold'] as num).toDouble(),
      unitCost: map['unit_cost'] != null ? (map['unit_cost'] as num).toDouble() : null,
      storageLocation: map['storage_location'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory InventoryItem.fromJson(String source) => InventoryItem.fromMap(json.decode(source) as Map<String, dynamic>);
}

class StockTransaction {
  final String id;
  final String itemId;
  final String transactionType;
  final double quantity;
  final String? issuedToType;
  final String? issuedToId;
  final String transactionDate;
  final String? remarks;
  final String recordedBy;

  const StockTransaction({
    required this.id,
    required this.itemId,
    required this.transactionType,
    required this.quantity,
    this.issuedToType,
    this.issuedToId,
    required this.transactionDate,
    this.remarks,
    required this.recordedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_id': itemId,
      'transaction_type': transactionType,
      'quantity': quantity,
      'issued_to_type': issuedToType,
      'issued_to_id': issuedToId,
      'transaction_date': transactionDate,
      'remarks': remarks,
      'recorded_by': recordedBy,
    };
  }

  factory StockTransaction.fromMap(Map<String, dynamic> map) {
    return StockTransaction(
      id: map['id'] as String,
      itemId: map['item_id'] as String,
      transactionType: map['transaction_type'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      issuedToType: map['issued_to_type'] as String?,
      issuedToId: map['issued_to_id'] as String?,
      transactionDate: map['transaction_date'] as String,
      remarks: map['remarks'] as String?,
      recordedBy: map['recorded_by'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory StockTransaction.fromJson(String source) => StockTransaction.fromMap(json.decode(source) as Map<String, dynamic>);
}
