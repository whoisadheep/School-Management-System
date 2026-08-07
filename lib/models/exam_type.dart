import 'dart:convert';
import 'package:uuid/uuid.dart';

/// ExamType model representing categories of exams (e.g. Unit Test 1, Mid-Term, Final) with weightage
class ExamType {
  final String id;
  final String name;
  final double weightagePercent;

  const ExamType({
    required this.id,
    required this.name,
    required this.weightagePercent,
  });

  factory ExamType.create({
    required String name,
    required double weightagePercent,
  }) {
    return ExamType(
      id: const Uuid().v4(),
      name: name,
      weightagePercent: weightagePercent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'weightage_percent': weightagePercent,
    };
  }

  factory ExamType.fromMap(Map<String, dynamic> map) {
    return ExamType(
      id: map['id'] as String,
      name: map['name'] as String,
      weightagePercent: (map['weightage_percent'] as num).toDouble(),
    );
  }

  String toJson() => json.encode(toMap());

  factory ExamType.fromJson(String source) =>
      ExamType.fromMap(json.decode(source) as Map<String, dynamic>);

  ExamType copyWith({
    String? id,
    String? name,
    double? weightagePercent,
  }) {
    return ExamType(
      id: id ?? this.id,
      name: name ?? this.name,
      weightagePercent: weightagePercent ?? this.weightagePercent,
    );
  }
}
