import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Route Stop model
class RouteStop {
  final String id;
  final String routeId;
  final String stopName;
  final int stopOrder;
  final double fee; // Monthly transport fee for this stop

  const RouteStop({
    required this.id,
    required this.routeId,
    required this.stopName,
    required this.stopOrder,
    this.fee = 0,
  });

  factory RouteStop.create({
    required String routeId,
    required String stopName,
    required int stopOrder,
    double fee = 0,
  }) {
    return RouteStop(
      id: const Uuid().v4(),
      routeId: routeId,
      stopName: stopName,
      stopOrder: stopOrder,
      fee: fee,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'route_id': routeId,
      'stop_name': stopName,
      'stop_order': stopOrder,
      'fee': fee,
    };
  }

  factory RouteStop.fromMap(Map<String, dynamic> map) {
    return RouteStop(
      id: map['id'] as String,
      routeId: map['route_id'] as String,
      stopName: map['stop_name'] as String,
      stopOrder: (map['stop_order'] as num).toInt(),
      fee: (map['fee'] as num?)?.toDouble() ?? 0,
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
    double? fee,
  }) {
    return RouteStop(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      stopName: stopName ?? this.stopName,
      stopOrder: stopOrder ?? this.stopOrder,
      fee: fee ?? this.fee,
    );
  }
}
