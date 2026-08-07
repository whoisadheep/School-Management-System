import 'dart:convert';

class LeaveType {
  final String id;
  final String name;
  final int daysAllowedPerYear;

  const LeaveType({
    required this.id,
    required this.name,
    required this.daysAllowedPerYear,
  });

  LeaveType copyWith({
    String? id,
    String? name,
    int? daysAllowedPerYear,
  }) {
    return LeaveType(
      id: id ?? this.id,
      name: name ?? this.name,
      daysAllowedPerYear: daysAllowedPerYear ?? this.daysAllowedPerYear,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'days_allowed_per_year': daysAllowedPerYear,
    };
  }

  factory LeaveType.fromMap(Map<String, dynamic> map) {
    return LeaveType(
      id: map['id'] as String,
      name: map['name'] as String,
      daysAllowedPerYear: map['days_allowed_per_year'] as int,
    );
  }

  String toJson() => json.encode(toMap());

  factory LeaveType.fromJson(String source) =>
      LeaveType.fromMap(json.decode(source) as Map<String, dynamic>);
}

class LeaveBalance {
  final LeaveType leaveType;
  final int allowedDays;
  final int usedDays;

  const LeaveBalance({
    required this.leaveType,
    required this.allowedDays,
    required this.usedDays,
  });

  int get remainingDays => allowedDays - usedDays;
}
