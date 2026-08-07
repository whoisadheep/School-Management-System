import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'services_provider.dart';

final allBooksProvider = FutureProvider.autoDispose<List<Book>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getAllBooks();
});

final activeBookIssuesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getActiveIssues();
});

final overdueBookIssuesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getOverdueIssues();
});
