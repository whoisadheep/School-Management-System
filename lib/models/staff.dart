import 'dart:convert';

class Staff {
  final String id;
  final String? staffCode;
  final String firstName;
  final String lastName;
  final String? dob;
  final String? gender;
  final String? bloodGroup;
  final String? photographPath;
  final String role; // 'teacher', 'principal', 'support_staff', 'driver'
  final String? departmentId;
  final String? designation;
  final String? joiningDate;
  final String? qualification;
  final int? experienceYears;
  final String? email;
  final String? phone;
  final String? address;
  final String? emergencyContact;
  final double? basicSalary;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? panNumber;
  final String? aadhaarNumber;
  final String? lastWorkingDay;
  final String? exitReason;
  final String? updatedBy;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Staff({
    required this.id,
    this.staffCode,
    required this.firstName,
    required this.lastName,
    this.dob,
    this.gender,
    this.bloodGroup,
    this.photographPath,
    required this.role,
    this.departmentId,
    this.designation,
    this.joiningDate,
    this.qualification,
    this.experienceYears,
    this.email,
    this.phone,
    this.address,
    this.emergencyContact,
    this.basicSalary,
    this.bankAccountNumber,
    this.bankIfsc,
    this.panNumber,
    this.aadhaarNumber,
    this.lastWorkingDay,
    this.exitReason,
    this.updatedBy,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName => '$firstName $lastName';

  Staff copyWith({
    String? id,
    String? staffCode,
    String? firstName,
    String? lastName,
    String? dob,
    String? gender,
    String? bloodGroup,
    String? photographPath,
    String? role,
    String? departmentId,
    String? designation,
    String? joiningDate,
    String? qualification,
    int? experienceYears,
    String? email,
    String? phone,
    String? address,
    String? emergencyContact,
    double? basicSalary,
    String? bankAccountNumber,
    String? bankIfsc,
    String? panNumber,
    String? aadhaarNumber,
    String? lastWorkingDay,
    String? exitReason,
    String? updatedBy,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Staff(
      id: id ?? this.id,
      staffCode: staffCode ?? this.staffCode,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      photographPath: photographPath ?? this.photographPath,
      role: role ?? this.role,
      departmentId: departmentId ?? this.departmentId,
      designation: designation ?? this.designation,
      joiningDate: joiningDate ?? this.joiningDate,
      qualification: qualification ?? this.qualification,
      experienceYears: experienceYears ?? this.experienceYears,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      basicSalary: basicSalary ?? this.basicSalary,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      panNumber: panNumber ?? this.panNumber,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      lastWorkingDay: lastWorkingDay ?? this.lastWorkingDay,
      exitReason: exitReason ?? this.exitReason,
      updatedBy: updatedBy ?? this.updatedBy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staff_code': staffCode,
      'first_name': firstName,
      'last_name': lastName,
      'dob': dob,
      'gender': gender,
      'blood_group': bloodGroup,
      'photograph_path': photographPath,
      'role': role,
      'department_id': departmentId,
      'designation': designation,
      'joining_date': joiningDate,
      'qualification': qualification,
      'experience_years': experienceYears,
      'email': email,
      'phone': phone,
      'address': address,
      'emergency_contact': emergencyContact,
      'basic_salary': basicSalary,
      'bank_account_number': bankAccountNumber,
      'bank_ifsc': bankIfsc,
      'pan_number': panNumber,
      'aadhaar_number': aadhaarNumber,
      'last_working_day': lastWorkingDay,
      'exit_reason': exitReason,
      'updated_by': updatedBy,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Staff.fromMap(Map<String, dynamic> map) {
    return Staff(
      id: map['id'] as String,
      staffCode: map['staff_code'] as String?,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      dob: map['dob'] as String?,
      gender: map['gender'] as String?,
      bloodGroup: map['blood_group'] as String?,
      photographPath: map['photograph_path'] as String?,
      role: map['role'] as String,
      departmentId: map['department_id'] as String?,
      designation: map['designation'] as String?,
      joiningDate: map['joining_date'] as String?,
      qualification: map['qualification'] as String?,
      experienceYears: map['experience_years'] as int?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      emergencyContact: map['emergency_contact'] as String?,
      basicSalary: map['basic_salary'] as double?,
      bankAccountNumber: map['bank_account_number'] as String?,
      bankIfsc: map['bank_ifsc'] as String?,
      panNumber: map['pan_number'] as String?,
      aadhaarNumber: map['aadhaar_number'] as String?,
      lastWorkingDay: map['last_working_day'] as String?,
      exitReason: map['exit_reason'] as String?,
      updatedBy: map['updated_by'] as String?,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory Staff.fromJson(String source) => Staff.fromMap(json.decode(source) as Map<String, dynamic>);
}
