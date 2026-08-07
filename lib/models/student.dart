import 'package:uuid/uuid.dart';

class Student {
  final String id;
  final String name;
  final String? firstName;
  final String? lastName;
  final String? dob;
  final String? gender;
  final String? bloodGroup;
  final String? photographPath;
  final String? caste;
  final String? religion;
  final String? aadhaarNumber;
  final String? admissionNumber;
  final String? rollNumber;
  final String gradeLevel;
  final String? section;
  final String? classId;
  final String? sectionId;
  final String? admissionDate;
  final String? fatherName;
  final String? fatherOccupation;
  final String? fatherPhone;
  final String? motherName;
  final String? motherOccupation;
  final String? motherPhone;
  final String? guardianPhone;
  final String? residentialAddress;
  final String? permanentAddress;
  final String? transportRouteId;
  final String? hostelId;
  final double currentBalance;
  final bool isActive;
  final bool isAlumni;
  final String? tcNumber;
  final String? tcDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Student({
    required this.id,
    required this.name,
    this.firstName,
    this.lastName,
    this.dob,
    this.gender,
    this.bloodGroup,
    this.photographPath,
    this.caste,
    this.religion,
    this.aadhaarNumber,
    this.admissionNumber,
    this.rollNumber,
    required this.gradeLevel,
    this.section,
    this.classId,
    this.sectionId,
    this.admissionDate,
    this.fatherName,
    this.fatherOccupation,
    this.fatherPhone,
    this.motherName,
    this.motherOccupation,
    this.motherPhone,
    this.guardianPhone,
    this.residentialAddress,
    this.permanentAddress,
    this.transportRouteId,
    this.hostelId,
    this.currentBalance = 0.0,
    this.isActive = true,
    this.isAlumni = false,
    this.tcNumber,
    this.tcDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new Student with a generated UUID
  factory Student.create({
    required String name,
    required String gradeLevel,
    String? firstName,
    String? lastName,
    String? dob,
    String? gender,
    String? bloodGroup,
    String? photographPath,
    String? caste,
    String? religion,
    String? aadhaarNumber,
    String? admissionNumber,
    String? rollNumber,
    String? section,
    String? classId,
    String? sectionId,
    String? admissionDate,
    String? fatherName,
    String? fatherOccupation,
    String? fatherPhone,
    String? motherName,
    String? motherOccupation,
    String? motherPhone,
    String? guardianPhone,
    String? residentialAddress,
    String? permanentAddress,
    String? transportRouteId,
    String? hostelId,
  }) {
    final now = DateTime.now();
    return Student(
      id: const Uuid().v4(),
      name: name,
      firstName: firstName,
      lastName: lastName,
      dob: dob,
      gender: gender,
      bloodGroup: bloodGroup,
      photographPath: photographPath,
      caste: caste,
      religion: religion,
      aadhaarNumber: aadhaarNumber,
      admissionNumber: admissionNumber,
      rollNumber: rollNumber,
      gradeLevel: gradeLevel,
      section: section,
      classId: classId,
      sectionId: sectionId,
      admissionDate: admissionDate,
      fatherName: fatherName,
      fatherOccupation: fatherOccupation,
      fatherPhone: fatherPhone,
      motherName: motherName,
      motherOccupation: motherOccupation,
      motherPhone: motherPhone,
      guardianPhone: guardianPhone,
      residentialAddress: residentialAddress,
      permanentAddress: permanentAddress,
      transportRouteId: transportRouteId,
      hostelId: hostelId,
      currentBalance: 0.0,
      isActive: true,
      isAlumni: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Deserialize from SQLite row
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as String,
      name: map['name'] as String,
      firstName: map['first_name'] as String?,
      lastName: map['last_name'] as String?,
      dob: map['dob'] as String?,
      gender: map['gender'] as String?,
      bloodGroup: map['blood_group'] as String?,
      photographPath: map['photograph_path'] as String?,
      caste: map['caste'] as String?,
      religion: map['religion'] as String?,
      aadhaarNumber: map['aadhaar_number'] as String?,
      admissionNumber: map['admission_number'] as String?,
      rollNumber: map['roll_number'] as String?,
      gradeLevel: map['grade_level'] as String,
      section: map['section'] as String?,
      classId: map['class_id'] as String?,
      sectionId: map['section_id'] as String?,
      admissionDate: map['admission_date'] as String?,
      fatherName: map['father_name'] as String?,
      fatherOccupation: map['father_occupation'] as String?,
      fatherPhone: map['father_phone'] as String?,
      motherName: map['mother_name'] as String?,
      motherOccupation: map['mother_occupation'] as String?,
      motherPhone: map['mother_phone'] as String?,
      guardianPhone: map['guardian_phone'] as String?,
      residentialAddress: map['residential_address'] as String?,
      permanentAddress: map['permanent_address'] as String?,
      transportRouteId: map['transport_route_id'] as String?,
      hostelId: map['hostel_id'] as String?,
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0.0,
      isActive: (map['is_active'] as int?) == 1,
      isAlumni: (map['is_alumni'] as int?) == 1,
      tcNumber: map['tc_number'] as String?,
      tcDate: map['tc_date'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Serialize to SQLite row
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'first_name': firstName,
      'last_name': lastName,
      'dob': dob,
      'gender': gender,
      'blood_group': bloodGroup,
      'photograph_path': photographPath,
      'caste': caste,
      'religion': religion,
      'aadhaar_number': aadhaarNumber,
      'admission_number': admissionNumber,
      'roll_number': rollNumber,
      'grade_level': gradeLevel,
      'section': section,
      'class_id': classId,
      'section_id': sectionId,
      'admission_date': admissionDate,
      'father_name': fatherName,
      'father_occupation': fatherOccupation,
      'father_phone': fatherPhone,
      'mother_name': motherName,
      'mother_occupation': motherOccupation,
      'mother_phone': motherPhone,
      'guardian_phone': guardianPhone,
      'residential_address': residentialAddress,
      'permanent_address': permanentAddress,
      'transport_route_id': transportRouteId,
      'hostel_id': hostelId,
      'current_balance': currentBalance,
      'is_active': isActive ? 1 : 0,
      'is_alumni': isAlumni ? 1 : 0,
      'tc_number': tcNumber,
      'tc_date': tcDate,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Student copyWith({
    String? id,
    String? name,
    String? firstName,
    String? lastName,
    String? dob,
    String? gender,
    String? bloodGroup,
    String? photographPath,
    String? caste,
    String? religion,
    String? aadhaarNumber,
    String? admissionNumber,
    String? rollNumber,
    String? gradeLevel,
    String? section,
    String? classId,
    String? sectionId,
    String? admissionDate,
    String? fatherName,
    String? fatherOccupation,
    String? fatherPhone,
    String? motherName,
    String? motherOccupation,
    String? motherPhone,
    String? guardianPhone,
    String? residentialAddress,
    String? permanentAddress,
    String? transportRouteId,
    String? hostelId,
    double? currentBalance,
    bool? isActive,
    bool? isAlumni,
    String? tcNumber,
    String? tcDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      photographPath: photographPath ?? this.photographPath,
      caste: caste ?? this.caste,
      religion: religion ?? this.religion,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      rollNumber: rollNumber ?? this.rollNumber,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      section: section ?? this.section,
      classId: classId ?? this.classId,
      sectionId: sectionId ?? this.sectionId,
      admissionDate: admissionDate ?? this.admissionDate,
      fatherName: fatherName ?? this.fatherName,
      fatherOccupation: fatherOccupation ?? this.fatherOccupation,
      fatherPhone: fatherPhone ?? this.fatherPhone,
      motherName: motherName ?? this.motherName,
      motherOccupation: motherOccupation ?? this.motherOccupation,
      motherPhone: motherPhone ?? this.motherPhone,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      residentialAddress: residentialAddress ?? this.residentialAddress,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      transportRouteId: transportRouteId ?? this.transportRouteId,
      hostelId: hostelId ?? this.hostelId,
      currentBalance: currentBalance ?? this.currentBalance,
      isActive: isActive ?? this.isActive,
      isAlumni: isAlumni ?? this.isAlumni,
      tcNumber: tcNumber ?? this.tcNumber,
      tcDate: tcDate ?? this.tcDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Student(id: $id, name: $name, gradeLevel: $gradeLevel, '
        'guardianPhone: $guardianPhone, currentBalance: $currentBalance, '
        'isActive: $isActive, isAlumni: $isAlumni)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Student && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
