import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Route Stop model
class RouteStop {
  final String id;
  final String routeId;
  final String stopName;
  final int stopOrder;
  final String? pickupTime;
  final String? dropTime;

  const RouteStop({
    required this.id,
    required this.routeId,
    required this.stopName,
    required this.stopOrder,
    this.pickupTime,
    this.dropTime,
  });

  factory RouteStop.create({
    required String routeId,
    required String stopName,
    required int stopOrder,
    String? pickupTime,
    String? dropTime,
  }) {
    return RouteStop(
      id: const Uuid().v4(),
      routeId: routeId,
      stopName: stopName,
      stopOrder: stopOrder,
      pickupTime: pickupTime,
      dropTime: dropTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'route_id': routeId,
      'stop_name': stopName,
      'stop_order': stopOrder,
      'pickup_time': pickupTime,
      'drop_time': dropTime,
    };
  }

  factory RouteStop.fromMap(Map<String, dynamic> map) {
    return RouteStop(
      id: map['id'] as String,
      routeId: map['route_id'] as String,
      stopName: map['stop_name'] as String,
      stopOrder: (map['stop_order'] as num).toInt(),
      pickupTime: map['pickup_time'] as String?,
      dropTime: map['drop_time'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory RouteStop.fromJson(String source) =>
      RouteStop.fromMap(json.decode(source) as Map<String, dynamic>);

  RouteStop copyWith({
    String? id,
    String? routeId,
    String? stopName,
    int? stopOrder,
    String? pickupTime,
    String? dropTime,
  }) {
    return RouteStop(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      stopName: stopName ?? this.stopName,
      stopOrder: stopOrder ?? this.stopOrder,
      pickupTime: pickupTime ?? this.pickupTime,
      dropTime: dropTime ?? this.dropTime,
    );
  }
}
