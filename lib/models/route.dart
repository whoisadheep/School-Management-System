import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'route_stop.dart';

/// Transport Route model
class Route {
  final String id;
  final String routeName;
  final String? vehicleId;
  final String? vehicleNumber; // Enriched helper
  final String startPoint;
  final String endPoint;
  final List<RouteStop> stops; // Enriched stops list

  const Route({
    required this.id,
    required this.routeName,
    this.vehicleId,
    this.vehicleNumber,
    required this.startPoint,
    required this.endPoint,
    this.stops = const [],
  });

  factory Route.create({
    required String routeName,
    String? vehicleId,
    String? vehicleNumber,
    required String startPoint,
    required String endPoint,
    List<RouteStop> stops = const [],
  }) {
    return Route(
      id: const Uuid().v4(),
      routeName: routeName,
      vehicleId: vehicleId,
      vehicleNumber: vehicleNumber,
      startPoint: startPoint,
      endPoint: endPoint,
      stops: stops,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'route_name': routeName,
      'vehicle_id': vehicleId,
      'start_point': startPoint,
      'end_point': endPoint,
    };
  }

  factory Route.fromMap(Map<String, dynamic> map, [List<RouteStop>? stops]) {
    return Route(
      id: map['id'] as String,
      routeName: map['route_name'] as String,
      vehicleId: map['vehicle_id'] as String?,
      vehicleNumber: map['vehicle_number'] as String?,
      startPoint: (map['start_point'] as String?) ?? '',
      endPoint: (map['end_point'] as String?) ?? '',
      stops: stops ?? const [],
    );
  }

  String toJson() => json.encode(toMap());

  factory Route.fromJson(String source) =>
      Route.fromMap(json.decode(source) as Map<String, dynamic>);

  Route copyWith({
    String? id,
    String? routeName,
    String? vehicleId,
    String? vehicleNumber,
    String? startPoint,
    String? endPoint,
    List<RouteStop>? stops,
  }) {
    return Route(
      id: id ?? this.id,
      routeName: routeName ?? this.routeName,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      stops: stops ?? this.stops,
    );
  }
}
