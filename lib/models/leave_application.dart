import 'dart:convert';

class LeaveApplication {
  final String id;
  final String staffId;
  final String leaveTypeId;
  final String startDate; // YYYY-MM-DD
  final String endDate; // YYYY-MM-DD
  final String reason;
  final String status; // 'pending', 'approved', 'rejected'
  final String? approvedBy;
  final String appliedAt;

  const LeaveApplication({
    required this.id,
    required this.staffId,
    required this.leaveTypeId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    this.approvedBy,
    required this.appliedAt,
  });

  LeaveApplication copyWith({
    String? id,
    String? staffId,
    String? leaveTypeId,
    String? startDate,
    String? endDate,
    String? reason,
    String? status,
    String? approvedBy,
    String? appliedAt,
  }) {
    return LeaveApplication(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      leaveTypeId: leaveTypeId ?? this.leaveTypeId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      appliedAt: appliedAt ?? this.appliedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staff_id': staffId,
      'leave_type_id': leaveTypeId,
      'start_date': startDate,
      'end_date': endDate,
      'reason': reason,
      'status': status,
      'approved_by': approvedBy,
      'applied_at': appliedAt,
    };
  }

  factory LeaveApplication.fromMap(Map<String, dynamic> map) {
    return LeaveApplication(
      id: map['id'] as String,
      staffId: map['staff_id'] as String,
      leaveTypeId: map['leave_type_id'] as String,
      startDate: map['start_date'] as String,
      endDate: map['end_date'] as String,
      reason: map['reason'] as String,
      status: map['status'] as String,
      approvedBy: map['approved_by'] as String?,
      appliedAt: map['applied_at'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory LeaveApplication.fromJson(String source) =>
      LeaveApplication.fromMap(json.decode(source) as Map<String, dynamic>);
}
