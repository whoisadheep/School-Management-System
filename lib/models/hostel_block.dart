import 'dart:convert';

class HostelBlock {
  final String id;
  final String blockName;
  final String? wardenStaffId;
  final int totalRooms;
  final bool isActive;

  const HostelBlock({
    required this.id,
    required this.blockName,
    this.wardenStaffId,
    required this.totalRooms,
    this.isActive = true,
  });

  HostelBlock copyWith({
    String? id,
    String? blockName,
    String? wardenStaffId,
    int? totalRooms,
    bool? isActive,
  }) {
    return HostelBlock(
      id: id ?? this.id,
      blockName: blockName ?? this.blockName,
      wardenStaffId: wardenStaffId ?? this.wardenStaffId,
      totalRooms: totalRooms ?? this.totalRooms,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'block_name': blockName,
      'warden_staff_id': wardenStaffId,
      'total_rooms': totalRooms,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory HostelBlock.fromMap(Map<String, dynamic> map) {
    return HostelBlock(
      id: map['id'] as String,
      blockName: map['block_name'] as String,
      wardenStaffId: map['warden_staff_id'] as String?,
      totalRooms: map['total_rooms'] as int,
      isActive: (map['is_active'] as int?) == 1,
    );
  }

  String toJson() => json.encode(toMap());

  factory HostelBlock.fromJson(String source) =>
      HostelBlock.fromMap(json.decode(source) as Map<String, dynamic>);
}
