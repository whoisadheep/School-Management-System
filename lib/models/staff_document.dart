import 'dart:convert';

class StaffDocument {
  final String id;
  final String staffId;
  final String docType;
  final String filePath;
  final DateTime uploadedAt;

  const StaffDocument({
    required this.id,
    required this.staffId,
    required this.docType,
    required this.filePath,
    required this.uploadedAt,
  });

  StaffDocument copyWith({
    String? id,
    String? staffId,
    String? docType,
    String? filePath,
    DateTime? uploadedAt,
  }) {
    return StaffDocument(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      docType: docType ?? this.docType,
      filePath: filePath ?? this.filePath,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staff_id': staffId,
      'doc_type': docType,
      'file_path': filePath,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }

  factory StaffDocument.fromMap(Map<String, dynamic> map) {
    return StaffDocument(
      id: map['id'] as String,
      staffId: map['staff_id'] as String,
      docType: map['doc_type'] as String,
      filePath: map['file_path'] as String,
      uploadedAt: DateTime.parse(map['uploaded_at'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory StaffDocument.fromJson(String source) => StaffDocument.fromMap(json.decode(source) as Map<String, dynamic>);
}
