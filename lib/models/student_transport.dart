import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Student Transport assignment model
class StudentTransport {
  final String id;
  final String studentId;
  final String routeId;
  final String stopId;
  final double monthlyFee;
  final String academicYear;
  final bool isActive;

  // Enriched fields for UI display
  final String? studentName;
  final String? rollNumber;
  final String? gradeLevel;
  final String? section;
  final String? routeName;
  final String? stopName;
  final double? stopFee; // Fee configured on the stop

  const StudentTransport({
    required this.id,
    required this.studentId,
    required this.routeId,
    required this.stopId,
    required this.monthlyFee,
    required this.academicYear,
    this.isActive = true,
    this.studentName,
    this.rollNumber,
    this.gradeLevel,
    this.section,
    this.routeName,
    this.stopName,
    this.stopFee,
  });

  factory StudentTransport.create({
    required String studentId,
    required String routeId,
    required String stopId,
    required double monthlyFee,
    required String academicYear,
    bool isActive = true,
  }) {
    return StudentTransport(
      id: const Uuid().v4(),
      studentId: studentId,
      routeId: routeId,
      stopId: stopId,
      monthlyFee: monthlyFee,
      academicYear: academicYear,
      isActive: isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'route_id': routeId,
      'stop_id': stopId,
      'monthly_fee': monthlyFee,
      'academic_year': academicYear,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory StudentTransport.fromMap(Map<String, dynamic> map) {
    return StudentTransport(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      routeId: map['route_id'] as String,
      stopId: map['stop_id'] as String,
      monthlyFee: (map['monthly_fee'] as num).toDouble(),
      academicYear: map['academic_year'] as String,
      isActive: (map['is_active'] as int?) == 1 || map['is_active'] == true,
      studentName: map['student_name'] as String?,
      rollNumber: map['roll_number'] as String?,
      gradeLevel: map['grade_level'] as String?,
      section: map['section'] as String?,
      routeName: map['route_name'] as String?,
      stopName: map['stop_name'] as String?,
      stopFee: (map['stop_fee'] as num?)?.toDouble(),
    );
  }

  String toJson() => json.encode(toMap());

  factory StudentTransport.fromJson(String source) =>
      StudentTransport.fromMap(json.decode(source) as Map<String, dynamic>);

  StudentTransport copyWith({
    String? id,
    String? studentId,
    String? routeId,
    String? stopId,
    double? monthlyFee,
    String? academicYear,
    bool? isActive,
    String? studentName,
    String? rollNumber,
    String? gradeLevel,
    String? section,
    String? routeName,
    String? stopName,
    double? stopFee,
  }) {
    return StudentTransport(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      routeId: routeId ?? this.routeId,
      stopId: stopId ?? this.stopId,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      academicYear: academicYear ?? this.academicYear,
      isActive: isActive ?? this.isActive,
      studentName: studentName ?? this.studentName,
      rollNumber: rollNumber ?? this.rollNumber,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      section: section ?? this.section,
      routeName: routeName ?? this.routeName,
      stopName: stopName ?? this.stopName,
      stopFee: stopFee ?? this.stopFee,
    );
  }
}
