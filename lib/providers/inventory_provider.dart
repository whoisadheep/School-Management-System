import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory.dart';
import 'services_provider.dart';

final inventoryCategoriesProvider = FutureProvider<List<InventoryCategory>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getInventoryCategories();
});

final inventoryItemsProvider = FutureProvider.family<List<InventoryItem>, String?>((ref, categoryId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getInventoryItems(categoryId: categoryId);
});

final lowStockItemsProvider = FutureProvider<List<InventoryItem>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getLowStockItems();
});

final itemTransactionHistoryProvider = FutureProvider.family<List<StockTransaction>, String?>((ref, itemId) async {
  if (itemId == null || itemId.isEmpty) return [];
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getItemTransactionHistory(itemId);
});
