import 'dart:convert';

class TimetableEntry {
  final String id;
  final String classAssigned;
  final String section;
  final int dayOfWeek; // 1 = Monday, 6 = Saturday
  final int periodNumber; // 1..8
  final String startTime;
  final String endTime;
  final String subject;
  final String staffId;

  const TimetableEntry({
    required this.id,
    required this.classAssigned,
    required this.section,
    required this.dayOfWeek,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.staffId,
  });

  TimetableEntry copyWith({
    String? id,
    String? classAssigned,
    String? section,
    int? dayOfWeek,
    int? periodNumber,
    String? startTime,
    String? endTime,
    String? subject,
    String? staffId,
  }) {
    return TimetableEntry(
      id: id ?? this.id,
      classAssigned: classAssigned ?? this.classAssigned,
      section: section ?? this.section,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      periodNumber: periodNumber ?? this.periodNumber,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      subject: subject ?? this.subject,
      staffId: staffId ?? this.staffId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class': classAssigned,
      'section': section,
      'day_of_week': dayOfWeek,
      'period_number': periodNumber,
      'start_time': startTime,
      'end_time': endTime,
      'subject': subject,
      'staff_id': staffId,
    };
  }

  factory TimetableEntry.fromMap(Map<String, dynamic> map) {
    return TimetableEntry(
      id: map['id'] as String,
      classAssigned: map['class'] as String,
      section: map['section'] as String,
      dayOfWeek: map['day_of_week'] as int,
      periodNumber: map['period_number'] as int,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      subject: map['subject'] as String,
      staffId: map['staff_id'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory TimetableEntry.fromJson(String source) =>
      TimetableEntry.fromMap(json.decode(source) as Map<String, dynamic>);
}
