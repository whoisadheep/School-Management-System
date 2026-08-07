import 'dart:convert';

class AttendanceSettings {
  final String id;
  final String academicYear;
  final double lowAttendanceThresholdPercent;

  const AttendanceSettings({
    required this.id,
    required this.academicYear,
    this.lowAttendanceThresholdPercent = 75.0,
  });

  AttendanceSettings copyWith({
    String? id,
    String? academicYear,
    double? lowAttendanceThresholdPercent,
  }) {
    return AttendanceSettings(
      id: id ?? this.id,
      academicYear: academicYear ?? this.academicYear,
      lowAttendanceThresholdPercent: lowAttendanceThresholdPercent ?? this.lowAttendanceThresholdPercent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'academic_year': academicYear,
      'low_attendance_threshold_percent': lowAttendanceThresholdPercent,
    };
  }

  factory AttendanceSettings.fromMap(Map<String, dynamic> map) {
    return AttendanceSettings(
      id: map['id'] as String,
      academicYear: map['academic_year'] as String,
      lowAttendanceThresholdPercent: (map['low_attendance_threshold_percent'] as num).toDouble(),
    );
  }

  String toJson() => json.encode(toMap());

  factory AttendanceSettings.fromJson(String source) =>
      AttendanceSettings.fromMap(json.decode(source) as Map<String, dynamic>);
}
