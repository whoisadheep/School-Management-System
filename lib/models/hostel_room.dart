import 'dart:convert';

class HostelRoom {
  final String id;
  final String blockId;
  final String roomNumber;
  final int floor;
  final int capacity;
  final int currentOccupancy;

  const HostelRoom({
    required this.id,
    required this.blockId,
    required this.roomNumber,
    required this.floor,
    required this.capacity,
    this.currentOccupancy = 0,
  });

  HostelRoom copyWith({
    String? id,
    String? blockId,
    String? roomNumber,
    int? floor,
    int? capacity,
    int? currentOccupancy,
  }) {
    return HostelRoom(
      id: id ?? this.id,
      blockId: blockId ?? this.blockId,
      roomNumber: roomNumber ?? this.roomNumber,
      floor: floor ?? this.floor,
      capacity: capacity ?? this.capacity,
      currentOccupancy: currentOccupancy ?? this.currentOccupancy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'block_id': blockId,
      'room_number': roomNumber,
      'floor': floor,
      'capacity': capacity,
      'current_occupancy': currentOccupancy,
    };
  }

  factory HostelRoom.fromMap(Map<String, dynamic> map) {
    return HostelRoom(
      id: map['id'] as String,
      blockId: map['block_id'] as String,
      roomNumber: map['room_number'] as String,
      floor: map['floor'] as int,
      capacity: map['capacity'] as int,
      currentOccupancy: map['current_occupancy'] as int? ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory HostelRoom.fromJson(String source) =>
      HostelRoom.fromMap(json.decode(source) as Map<String, dynamic>);
}
