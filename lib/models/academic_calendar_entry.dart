import 'dart:convert';

class AcademicCalendarEntry {
  final String id;
  final String date;
  final String dayType;
  final String? remarks;

  const AcademicCalendarEntry({
    required this.id,
    required this.date,
    required this.dayType,
    this.remarks,
  });

  AcademicCalendarEntry copyWith({
    String? id,
    String? date,
    String? dayType,
    String? remarks,
  }) {
    return AcademicCalendarEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      dayType: dayType ?? this.dayType,
      remarks: remarks ?? this.remarks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'day_type': dayType,
      'remarks': remarks,
    };
  }

  factory AcademicCalendarEntry.fromMap(Map<String, dynamic> map) {
    return AcademicCalendarEntry(
      id: map['id'] as String,
      date: map['date'] as String,
      dayType: map['day_type'] as String,
      remarks: map['remarks'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory AcademicCalendarEntry.fromJson(String source) =>
      AcademicCalendarEntry.fromMap(json.decode(source) as Map<String, dynamic>);
}
