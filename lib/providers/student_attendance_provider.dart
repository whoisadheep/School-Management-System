import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'services_provider.dart';

final classAttendanceProvider = FutureProvider.family<List<StudentAttendance>, String>((ref, params) async {
  final db = ref.watch(databaseServiceProvider);
  final parts = params.split('|');
  final className = parts[0];
  final section = parts[1];
  final date = parts[2];
  return await db.getClassAttendanceForDate(className, section, date);
});

final studentAttendanceHistoryProvider = FutureProvider.family<List<StudentAttendance>, String>((ref, studentId) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getAttendanceForStudent(studentId);
});

final lowAttendanceReportProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, params) async {
  final db = ref.watch(databaseServiceProvider);
  final parts = params.split('|');
  final className = parts[0];
  final section = parts[1];
  final academicYear = parts[2];
  return await db.getLowAttendanceStudents(className, section, academicYear);
});
