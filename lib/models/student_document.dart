import 'package:uuid/uuid.dart';

class StudentDocument {
  final String id;
  final String studentId;
  final String title;
  final String documentType; // 'Birth Certificate', 'Aadhaar', 'Marks Card', 'Transfer Certificate', 'Other'
  final String filePath;
  final DateTime uploadedAt;

  const StudentDocument({
    required this.id,
    required this.studentId,
    required this.title,
    required this.documentType,
    required this.filePath,
    required this.uploadedAt,
  });

  factory StudentDocument.create({
    required String studentId,
    required String title,
    required String documentType,
    required String filePath,
  }) {
    return StudentDocument(
      id: const Uuid().v4(),
      studentId: studentId,
      title: title,
      documentType: documentType,
      filePath: filePath,
      uploadedAt: DateTime.now(),
    );
  }

  factory StudentDocument.fromMap(Map<String, dynamic> map) {
    return StudentDocument(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      title: map['title'] as String,
      documentType: map['document_type'] as String,
      filePath: map['file_path'] as String,
      uploadedAt: DateTime.parse(map['uploaded_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'title': title,
      'document_type': documentType,
      'file_path': filePath,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }
}
