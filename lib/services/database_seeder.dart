import 'dart:math';
import '../models/models.dart';
import 'database_service.dart';

class DatabaseSeeder {
  final DatabaseService _dbService;

  DatabaseSeeder({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  /// Seed 10 realistic student records with initial invoices into SQLite
  Future<void> seedSampleStudents() async {
    final List<Map<String, String>> sampleData = [
      {
        'first': 'Aarav',
        'last': 'Sharma',
        'grade': 'Grade 1',
        'section': 'A',
        'father': 'Rajesh Sharma',
        'father_phone': '9876543210',
        'mother': 'Sunita Sharma',
        'gender': 'Male',
        'blood': 'A+',
        'dob': '2018-04-12',
        'aadhaar': '4512-8923-1092',
      },
      {
        'first': 'Ananya',
        'last': 'Verma',
        'grade': 'Grade 2',
        'section': 'B',
        'father': 'Sanjay Verma',
        'father_phone': '9812345678',
        'mother': 'Pooja Verma',
        'gender': 'Female',
        'blood': 'B+',
        'dob': '2017-09-25',
        'aadhaar': '8821-3310-9941',
      },
      {
        'first': 'Rohan',
        'last': 'Gupta',
        'grade': 'Grade 3',
        'section': 'A',
        'father': 'Amit Gupta',
        'father_phone': '9934127850',
        'mother': 'Neha Gupta',
        'gender': 'Male',
        'blood': 'O+',
        'dob': '2016-11-05',
        'aadhaar': '1092-4458-7712',
      },
      {
        'first': 'Diya',
        'last': 'Patel',
        'grade': 'Grade 4',
        'section': 'C',
        'father': 'Vikram Patel',
        'father_phone': '9723451098',
        'mother': 'Meera Patel',
        'gender': 'Female',
        'blood': 'AB+',
        'dob': '2015-02-18',
        'aadhaar': '5519-2041-3829',
      },
      {
        'first': 'Kabir',
        'last': 'Singh',
        'grade': 'Grade 5',
        'section': 'A',
        'father': 'Gurpreet Singh',
        'father_phone': '9898123456',
        'mother': 'Harpreet Kaur',
        'gender': 'Male',
        'blood': 'A-',
        'dob': '2014-07-30',
        'aadhaar': '7712-4091-8823',
      },
      {
        'first': 'Ishaan',
        'last': 'Joshi',
        'grade': 'Grade 6',
        'section': 'B',
        'father': 'Manoj Joshi',
        'father_phone': '9612348765',
        'mother': 'Anjali Joshi',
        'gender': 'Male',
        'blood': 'B-',
        'dob': '2013-12-14',
        'aadhaar': '3321-9081-4451',
      },
      {
        'first': 'Sanya',
        'last': 'Reddy',
        'grade': 'Grade 7',
        'section': 'A',
        'father': 'Srinivas Reddy',
        'father_phone': '9543210987',
        'mother': 'Lakshmi Reddy',
        'gender': 'Female',
        'blood': 'O-',
        'dob': '2012-05-22',
        'aadhaar': '9941-2018-5532',
      },
      {
        'first': 'Vihaan',
        'last': 'Mehta',
        'grade': 'Grade 8',
        'section': 'B',
        'father': 'Rakesh Mehta',
        'father_phone': '9412356789',
        'mother': 'Kavita Mehta',
        'gender': 'Male',
        'blood': 'A+',
        'dob': '2011-08-09',
        'aadhaar': '2214-7789-1094',
      },
      {
        'first': 'Kavya',
        'last': 'Nair',
        'grade': 'Grade 9',
        'section': 'A',
        'father': 'Ramesh Nair',
        'father_phone': '9321098765',
        'mother': 'Shobha Nair',
        'gender': 'Female',
        'blood': 'B+',
        'dob': '2010-03-17',
        'aadhaar': '6632-1109-4482',
      },
      {
        'first': 'Aditya',
        'last': 'Kumar',
        'grade': 'Grade 10',
        'section': 'C',
        'father': 'Pankaj Kumar',
        'father_phone': '9210987654',
        'mother': 'Sunita Devi',
        'gender': 'Male',
        'blood': 'AB-',
        'dob': '2009-10-01',
        'aadhaar': '8841-5520-3319',
      },
    ];

    final random = Random();
    int count = 1;

    for (final data in sampleData) {
      final String fn = data['first']!;
      final String ln = data['last']!;
      final String fullName = '$fn $ln';
      final String seqStr = count.toString().padLeft(4, '0');
      final String admNo = '2026-$seqStr';
      final String rollNo = '$count';
      count++;

      final student = Student.create(
        name: fullName,
        firstName: fn,
        lastName: ln,
        dob: data['dob'],
        gender: data['gender'],
        bloodGroup: data['blood'],
        caste: 'General',
        religion: 'Hindu',
        aadhaarNumber: data['aadhaar'],
        admissionNumber: admNo,
        rollNumber: rollNo,
        gradeLevel: data['grade']!,
        section: data['section'],
        admissionDate: DateTime.now().toIso8601String().substring(0, 10),
        fatherName: data['father'],
        fatherPhone: data['father_phone'],
        motherName: data['mother'],
        guardianPhone: data['father_phone'],
        residentialAddress: 'Flat ${random.nextInt(500) + 101}, Sector ${random.nextInt(30) + 1}, Academic City',
      );

      await _dbService.insertStudent(student);

      // Create an initial tuition invoice for each student
      final double amount = (random.nextInt(4) + 1) * 1200.0;
      final int daysAhead = random.nextBool() ? 15 : -5; // Some active, some overdue for realistic test data!
      final dueDate = DateTime.now().add(Duration(days: daysAhead));

      final invoice = Invoice.create(
        studentId: student.id,
        totalAmount: amount,
        dueDate: dueDate,
        notes: 'Q1 Tuition & Academic Fee',
      );

      await _dbService.insertInvoice(invoice);
    }
  }
}
