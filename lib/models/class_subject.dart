import 'dart:convert';
import 'package:uuid/uuid.dart';

/// ClassSubject model representing a subject configured for a particular class
class ClassSubject {
  final String id;
  final String classId;
  final String subjectName;
  final double defaultMaxMarks;
  final double defaultPassMarks;
  final DateTime createdAt;

  const ClassSubject({
    required this.id,
    required this.classId,
    required this.subjectName,
    this.defaultMaxMarks = 100.0,
    this.defaultPassMarks = 35.0,
    required this.createdAt,
  });

  factory ClassSubject.create({
    required String classId,
    required String subjectName,
    double defaultMaxMarks = 100.0,
    double defaultPassMarks = 35.0,
  }) {
    return ClassSubject(
      id: const Uuid().v4(),
      classId: classId,
      subjectName: subjectName.trim(),
      defaultMaxMarks: defaultMaxMarks,
      defaultPassMarks: defaultPassMarks,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class_id': classId,
      'subject_name': subjectName,
      'default_max_marks': defaultMaxMarks,
      'default_pass_marks': defaultPassMarks,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ClassSubject.fromMap(Map<String, dynamic> map) {
    return ClassSubject(
      id: map['id'] as String,
      classId: map['class_id'] as String,
      subjectName: map['subject_name'] as String,
      defaultMaxMarks: (map['default_max_marks'] as num?)?.toDouble() ?? 100.0,
      defaultPassMarks: (map['default_pass_marks'] as num?)?.toDouble() ?? 35.0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  ClassSubject copyWith({
    String? id,
    String? classId,
    String? subjectName,
    double? defaultMaxMarks,
    double? defaultPassMarks,
    DateTime? createdAt,
  }) {
    return ClassSubject(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      subjectName: subjectName ?? this.subjectName,
      defaultMaxMarks: defaultMaxMarks ?? this.defaultMaxMarks,
      defaultPassMarks: defaultPassMarks ?? this.defaultPassMarks,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String toJson() => json.encode(toMap());

  factory ClassSubject.fromJson(String source) =>
      ClassSubject.fromMap(json.decode(source) as Map<String, dynamic>);
}
