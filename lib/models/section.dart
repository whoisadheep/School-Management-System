import 'dart:convert';

class Section {
  final String id;
  final String classId;
  final String name; // e.g. "A", "B", "C"
  final int? capacity;
  final String? classTeacherId;

  const Section({
    required this.id,
    required this.classId,
    required this.name,
    this.capacity,
    this.classTeacherId,
  });

  Section copyWith({
    String? id,
    String? classId,
    String? name,
    int? capacity,
    String? classTeacherId,
  }) {
    return Section(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      classTeacherId: classTeacherId ?? this.classTeacherId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class_id': classId,
      'name': name,
      'capacity': capacity,
      'class_teacher_id': classTeacherId,
    };
  }

  factory Section.fromMap(Map<String, dynamic> map) {
    return Section(
      id: map['id'] as String,
      classId: map['class_id'] as String,
      name: map['name'] as String,
      capacity: map['capacity'] as int?,
      classTeacherId: map['class_teacher_id'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory Section.fromJson(String source) =>
      Section.fromMap(json.decode(source) as Map<String, dynamic>);
}
