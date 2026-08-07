import 'dart:convert';

class HostelAllocation {
  final String id;
  final String studentId;
  final String roomId;
  final int? bedNumber;
  final String academicYear;
  final String allocatedDate;
  final String? vacatedDate;
  final bool isActive;

  const HostelAllocation({
    required this.id,
    required this.studentId,
    required this.roomId,
    this.bedNumber,
    required this.academicYear,
    required this.allocatedDate,
    this.vacatedDate,
    this.isActive = true,
  });

  HostelAllocation copyWith({
    String? id,
    String? studentId,
    String? roomId,
    int? bedNumber,
    String? academicYear,
    String? allocatedDate,
    String? vacatedDate,
    bool? isActive,
  }) {
    return HostelAllocation(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      roomId: roomId ?? this.roomId,
      bedNumber: bedNumber ?? this.bedNumber,
      academicYear: academicYear ?? this.academicYear,
      allocatedDate: allocatedDate ?? this.allocatedDate,
      vacatedDate: vacatedDate ?? this.vacatedDate,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'room_id': roomId,
      'bed_number': bedNumber,
      'academic_year': academicYear,
      'allocated_date': allocatedDate,
      'vacated_date': vacatedDate,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory HostelAllocation.fromMap(Map<String, dynamic> map) {
    return HostelAllocation(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      roomId: map['room_id'] as String,
      bedNumber: map['bed_number'] as int?,
      academicYear: map['academic_year'] as String,
      allocatedDate: map['allocated_date'] as String,
      vacatedDate: map['vacated_date'] as String?,
      isActive: (map['is_active'] as int?) == 1,
    );
  }

  String toJson() => json.encode(toMap());

  factory HostelAllocation.fromJson(String source) =>
      HostelAllocation.fromMap(json.decode(source) as Map<String, dynamic>);
}
