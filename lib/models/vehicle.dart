import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Vehicle model for transport management fleet (Bus/Van)
class Vehicle {
  final String id;
  final String vehicleNumber;
  final String vehicleType; // 'bus' or 'van'
  final int capacity;
  final String? driverStaffId;
  final String? driverName; // Enriched helper
  final String? conductorName;
  final DateTime? insuranceExpiry;
  final DateTime? fitnessExpiry;
  final bool isActive;

  const Vehicle({
    required this.id,
    required this.vehicleNumber,
    this.vehicleType = 'bus',
    required this.capacity,
    this.driverStaffId,
    this.driverName,
    this.conductorName,
    this.insuranceExpiry,
    this.fitnessExpiry,
    this.isActive = true,
  });

  factory Vehicle.create({
    required String vehicleNumber,
    String vehicleType = 'bus',
    required int capacity,
    String? driverStaffId,
    String? driverName,
    String? conductorName,
    DateTime? insuranceExpiry,
    DateTime? fitnessExpiry,
    bool isActive = true,
  }) {
    return Vehicle(
      id: const Uuid().v4(),
      vehicleNumber: vehicleNumber,
      vehicleType: vehicleType,
      capacity: capacity,
      driverStaffId: driverStaffId,
      driverName: driverName,
      conductorName: conductorName,
      insuranceExpiry: insuranceExpiry,
      fitnessExpiry: fitnessExpiry,
      isActive: isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'capacity': capacity,
      'driver_staff_id': driverStaffId,
      'conductor_name': conductorName,
      'insurance_expiry': insuranceExpiry?.toIso8601String(),
      'fitness_expiry': fitnessExpiry?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] as String,
      vehicleNumber: map['vehicle_number'] as String,
      vehicleType: (map['vehicle_type'] as String?) ?? 'bus',
      capacity: (map['capacity'] as num).toInt(),
      driverStaffId: map['driver_staff_id'] as String?,
      driverName: map['driver_name'] as String?,
      conductorName: map['conductor_name'] as String?,
      insuranceExpiry: map['insurance_expiry'] != null
          ? DateTime.tryParse(map['insurance_expiry'] as String)
          : null,
      fitnessExpiry: map['fitness_expiry'] != null
          ? DateTime.tryParse(map['fitness_expiry'] as String)
          : null,
      isActive: (map['is_active'] as int?) == 1 || map['is_active'] == true,
    );
  }

  String toJson() => json.encode(toMap());

  factory Vehicle.fromJson(String source) =>
      Vehicle.fromMap(json.decode(source) as Map<String, dynamic>);

  Vehicle copyWith({
    String? id,
    String? vehicleNumber,
    String? vehicleType,
    int? capacity,
    String? driverStaffId,
    String? driverName,
    String? conductorName,
    DateTime? insuranceExpiry,
    DateTime? fitnessExpiry,
    bool? isActive,
  }) {
    return Vehicle(
      id: id ?? this.id,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      capacity: capacity ?? this.capacity,
      driverStaffId: driverStaffId ?? this.driverStaffId,
      driverName: driverName ?? this.driverName,
      conductorName: conductorName ?? this.conductorName,
      insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
      fitnessExpiry: fitnessExpiry ?? this.fitnessExpiry,
      isActive: isActive ?? this.isActive,
    );
  }

  /// True if insurance or fitness expires within the given days (default 30)
  bool isRenewalNeeded([int withinDays = 30]) {
    final now = DateTime.now();
    final threshold = now.add(Duration(days: withinDays));

    final insuranceExpiringSoon = insuranceExpiry != null &&
        insuranceExpiry!.isBefore(threshold);
    final fitnessExpiringSoon = fitnessExpiry != null &&
        fitnessExpiry!.isBefore(threshold);

    return insuranceExpiringSoon || fitnessExpiringSoon;
  }
}
