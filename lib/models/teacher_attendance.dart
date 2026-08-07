import 'dart:convert';

class TeacherAttendance {
  final String id;
  final String staffId;
  final String date; // YYYY-MM-DD
  final String? checkIn; // HH:mm
  final String? checkOut; // HH:mm
  final String status; // 'present', 'absent', 'half_day', 'late'
  final String? markedBy;
  final String? correctedBy;
  final String? correctedAt;

  const TeacherAttendance({
    required this.id,
    required this.staffId,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.status,
    this.markedBy,
    this.correctedBy,
    this.correctedAt,
  });

  TeacherAttendance copyWith({
    String? id,
    String? staffId,
    String? date,
    String? checkIn,
    String? checkOut,
    String? status,
    String? markedBy,
    String? correctedBy,
    String? correctedAt,
  }) {
    return TeacherAttendance(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      date: date ?? this.date,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      status: status ?? this.status,
      markedBy: markedBy ?? this.markedBy,
      correctedBy: correctedBy ?? this.correctedBy,
      correctedAt: correctedAt ?? this.correctedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staff_id': staffId,
      'date': date,
      'check_in': checkIn,
      'check_out': checkOut,
      'status': status,
      'marked_by': markedBy,
      'corrected_by': correctedBy,
      'corrected_at': correctedAt,
    };
  }

  factory TeacherAttendance.fromMap(Map<String, dynamic> map) {
    return TeacherAttendance(
      id: map['id'] as String,
      staffId: map['staff_id'] as String,
      date: map['date'] as String,
      checkIn: map['check_in'] as String?,
      checkOut: map['check_out'] as String?,
      status: map['status'] as String,
      markedBy: map['marked_by'] as String?,
      correctedBy: map['corrected_by'] as String?,
      correctedAt: map['corrected_at'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory TeacherAttendance.fromJson(String source) =>
      TeacherAttendance.fromMap(json.decode(source) as Map<String, dynamic>);
}

class TeacherAttendanceSummary {
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int halfDayCount;
  final int totalDays;

  const TeacherAttendanceSummary({
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.halfDayCount,
    required this.totalDays,
  });

  double get attendancePercentage =>
      totalDays == 0 ? 0.0 : ((presentCount + lateCount + (halfDayCount * 0.5)) / totalDays) * 100;
}
