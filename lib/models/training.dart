import 'dart:convert';

class Training {
  final String id;
  final String staffId;
  final String trainingName;
  final String provider;
  final String date; // YYYY-MM-DD
  final String? certificatePath;

  const Training({
    required this.id,
    required this.staffId,
    required this.trainingName,
    required this.provider,
    required this.date,
    this.certificatePath,
  });

  Training copyWith({
    String? id,
    String? staffId,
    String? trainingName,
    String? provider,
    String? date,
    String? certificatePath,
  }) {
    return Training(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      trainingName: trainingName ?? this.trainingName,
      provider: provider ?? this.provider,
      date: date ?? this.date,
      certificatePath: certificatePath ?? this.certificatePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staff_id': staffId,
      'training_name': trainingName,
      'provider': provider,
      'date': date,
      'certificate_path': certificatePath,
    };
  }

  factory Training.fromMap(Map<String, dynamic> map) {
    return Training(
      id: map['id'] as String,
      staffId: map['staff_id'] as String,
      trainingName: map['training_name'] as String,
      provider: map['provider'] as String,
      date: map['date'] as String,
      certificatePath: map['certificate_path'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory Training.fromJson(String source) =>
      Training.fromMap(json.decode(source) as Map<String, dynamic>);
}
