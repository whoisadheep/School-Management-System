import 'dart:convert';

class Substitution {
  final String id;
  final String date; // YYYY-MM-DD
  final int periodNumber;
  final String classAssigned;
  final String subject;
  final String originalStaffId;
  final String substituteStaffId;
  final String createdAt;

  const Substitution({
    required this.id,
    required this.date,
    required this.periodNumber,
    required this.classAssigned,
    required this.subject,
    required this.originalStaffId,
    required this.substituteStaffId,
    required this.createdAt,
  });

  Substitution copyWith({
    String? id,
    String? date,
    int? periodNumber,
    String? classAssigned,
    String? subject,
    String? originalStaffId,
    String? substituteStaffId,
    String? createdAt,
  }) {
    return Substitution(
      id: id ?? this.id,
      date: date ?? this.date,
      periodNumber: periodNumber ?? this.periodNumber,
      classAssigned: classAssigned ?? this.classAssigned,
      subject: subject ?? this.subject,
      originalStaffId: originalStaffId ?? this.originalStaffId,
      substituteStaffId: substituteStaffId ?? this.substituteStaffId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'period_number': periodNumber,
      'class': classAssigned,
      'subject': subject,
      'original_staff_id': originalStaffId,
      'substitute_staff_id': substituteStaffId,
      'created_at': createdAt,
    };
  }

  factory Substitution.fromMap(Map<String, dynamic> map) {
    return Substitution(
      id: map['id'] as String,
      date: map['date'] as String,
      periodNumber: map['period_number'] as int,
      classAssigned: map['class'] as String,
      subject: map['subject'] as String,
      originalStaffId: map['original_staff_id'] as String,
      substituteStaffId: map['substitute_staff_id'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory Substitution.fromJson(String source) =>
      Substitution.fromMap(json.decode(source) as Map<String, dynamic>);
}
