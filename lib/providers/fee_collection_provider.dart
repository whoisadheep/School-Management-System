import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'services_provider.dart';

/// Currently selected student provider for Split-Pane view
final selectedStudentProvider = StateProvider<Student?>((ref) => null);

/// Search query string provider for student filter
final studentSearchQueryProvider = StateProvider<String>((ref) => '');

/// Grade level filter provider
final gradeFilterProvider = StateProvider<String?>((ref) => null);

/// Student Invoices List Provider for selected student
final selectedStudentInvoicesProvider = FutureProvider<List<Invoice>>((ref) async {
  final student = ref.watch(selectedStudentProvider);
  if (student == null) return [];

  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getInvoicesByStudentId(student.id);
});
