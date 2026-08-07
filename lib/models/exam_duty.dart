import 'dart:convert';

class ExamDuty {
  final String id;
  final String staffId;
  final String examName;
  final String date; // YYYY-MM-DD
  final String timeSlot;
  final String roomOrClass;
  final String dutyType; // 'invigilation', 'paper_setting'

  const ExamDuty({
    required this.id,
    required this.staffId,
    required this.examName,
    required this.date,
    required this.timeSlot,
    required this.roomOrClass,
    required this.dutyType,
  });

  ExamDuty copyWith({
    String? id,
    String? staffId,
    String? examName,
    String? date,
    String? timeSlot,
    String? roomOrClass,
    String? dutyType,
  }) {
    return ExamDuty(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      examName: examName ?? this.examName,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      roomOrClass: roomOrClass ?? this.roomOrClass,
      dutyType: dutyType ?? this.dutyType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staff_id': staffId,
      'exam_name': examName,
      'date': date,
      'time_slot': timeSlot,
      'room_or_class': roomOrClass,
      'duty_type': dutyType,
    };
  }

  factory ExamDuty.fromMap(Map<String, dynamic> map) {
    return ExamDuty(
      id: map['id'] as String,
      staffId: map['staff_id'] as String,
      examName: map['exam_name'] as String,
      date: map['date'] as String,
      timeSlot: map['time_slot'] as String,
      roomOrClass: map['room_or_class'] as String,
      dutyType: map['duty_type'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ExamDuty.fromJson(String source) =>
      ExamDuty.fromMap(json.decode(source) as Map<String, dynamic>);
}
