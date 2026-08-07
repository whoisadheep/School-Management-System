import 'dart:convert';

class StaffSubjectAssignment {
  final String id;
  final String staffId;
  final String subject;
  final String classAssigned;

  const StaffSubjectAssignment({
    required this.id,
    required this.staffId,
    required this.subject,
    required this.classAssigned,
  });

  StaffSubjectAssignment copyWith({
    String? id,
    String? staffId,
    String? subject,
    String? classAssigned,
  }) {
    return StaffSubjectAssignment(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      subject: subject ?? this.subject,
      classAssigned: classAssigned ?? this.classAssigned,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staff_id': staffId,
      'subject': subject,
      'class_assigned': classAssigned,
    };
  }

  factory StaffSubjectAssignment.fromMap(Map<String, dynamic> map) {
    return StaffSubjectAssignment(
      id: map['id'] as String,
      staffId: map['staff_id'] as String,
      subject: map['subject'] as String,
      classAssigned: map['class_assigned'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory StaffSubjectAssignment.fromJson(String source) => StaffSubjectAssignment.fromMap(json.decode(source) as Map<String, dynamic>);
}
