import 'dart:convert';

class Appraisal {
  final String id;
  final String staffId;
  final String reviewPeriod; // e.g. '2024-2025 Q1', 'Annual 2025'
  final String selfAssessment;
  final String principalRemarks;
  final int rating; // 1 to 5
  final String createdAt;

  const Appraisal({
    required this.id,
    required this.staffId,
    required this.reviewPeriod,
    required this.selfAssessment,
    required this.principalRemarks,
    required this.rating,
    required this.createdAt,
  });

  Appraisal copyWith({
    String? id,
    String? staffId,
    String? reviewPeriod,
    String? selfAssessment,
    String? principalRemarks,
    int? rating,
    String? createdAt,
  }) {
    return Appraisal(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      reviewPeriod: reviewPeriod ?? this.reviewPeriod,
      selfAssessment: selfAssessment ?? this.selfAssessment,
      principalRemarks: principalRemarks ?? this.principalRemarks,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staff_id': staffId,
      'review_period': reviewPeriod,
      'self_assessment': selfAssessment,
      'principal_remarks': principalRemarks,
      'rating': rating,
      'created_at': createdAt,
    };
  }

  factory Appraisal.fromMap(Map<String, dynamic> map) {
    return Appraisal(
      id: map['id'] as String,
      staffId: map['staff_id'] as String,
      reviewPeriod: map['review_period'] as String,
      selfAssessment: map['self_assessment'] as String,
      principalRemarks: map['principal_remarks'] as String,
      rating: map['rating'] as int,
      createdAt: map['created_at'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory Appraisal.fromJson(String source) =>
      Appraisal.fromMap(json.decode(source) as Map<String, dynamic>);
}
