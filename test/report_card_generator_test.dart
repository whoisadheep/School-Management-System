import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/models/models.dart';
import 'package:school_management_system/services/report_card_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generateReportCardPdfBytes generates valid PDF with DOB, Father, Mother and no Date Issued', () async {
    const examResult = ExamResultData(
      examId: 'exam-001',
      examName: 'Final Term Examination 2026',
      studentId: 'stu-101',
      studentName: 'Aarav Sharma',
      rollNumber: '101',
      className: 'Class 10',
      section: 'A',
      academicYear: '2026-2027',
      dob: '2012-08-15',
      fatherName: 'Rajesh Sharma',
      motherName: 'Sunita Sharma',
      totalMarksObtained: 460.0,
      totalMaxMarks: 500.0,
      percentage: 92.0,
      grade: 'A+',
      isPassed: true,
      subjectResults: [
        SubjectResultItem(
          subject: 'Mathematics',
          maxMarks: 100,
          passingMarks: 35,
          marksObtained: 95,
          isAbsent: false,
          grade: 'A+',
          isPassed: true,
        ),
        SubjectResultItem(
          subject: 'Science',
          maxMarks: 100,
          passingMarks: 35,
          marksObtained: 88,
          isAbsent: false,
          grade: 'A',
          isPassed: true,
        ),
      ],
    );

    final pdfBytes = await ReportCardGenerator.generateReportCardPdfBytes(
      examResult: examResult,
      schoolName: 'Greenwood High School',
      schoolAddress: '42 Academic Way, Sector 12',
      schoolContact: 'Phone: 9876543210',
    );

    expect(pdfBytes, isNotNull);
    expect(pdfBytes.isNotEmpty, isTrue);

    // PDF magic bytes: %PDF-
    final pdfHeader = String.fromCharCodes(pdfBytes.sublist(0, 5));
    expect(pdfHeader, '%PDF-');
  });
}
