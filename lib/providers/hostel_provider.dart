import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'services_provider.dart';

final hostelBlocksProvider = FutureProvider<List<HostelBlock>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getHostelBlocks();
});

final allHostelRoomsProvider = FutureProvider<List<HostelRoom>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getAllHostelRooms();
});

final availableHostelRoomsProvider = FutureProvider.family<List<HostelRoom>, String>((ref, blockId) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getAvailableRooms(blockId);
});

final hostelAllocationsProvider = FutureProvider<List<HostelAllocation>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getHostelAllocations();
});

final outpassesProvider = FutureProvider<List<Outpass>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getOutpasses();
});
