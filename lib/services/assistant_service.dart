import '../models/models.dart';
import 'database_service.dart';

class AssistantService {
  final DatabaseService _dbService;

  AssistantService(this._dbService);

  Future<String> handleCommand(String command) async {
    final normalized = command.trim().toLowerCase();

    if (normalized.isEmpty) {
      return 'Please type a command or type "help" for examples.';
    }

    if (normalized == 'help' || normalized == 'commands' || normalized == 'hi' || normalized == 'hello') {
      return _helpText();
    }

    if (normalized.contains('initialize attendance sheet')) {
      return await _initializeAttendanceSheet(command);
    }

    if (normalized.contains('attendance') && normalized.contains('student')) {
      return await _handleStudentAttendance(command);
    }

    if (normalized.contains('search student') || normalized.startsWith('find student')) {
      return await _handleSearchStudent(command);
    }

    if (normalized.contains('student details') || normalized.contains('get student')) {
      return await _handleStudentDetails(command);
    }

    if (normalized.contains('search staff') || normalized.startsWith('find staff')) {
      return await _handleSearchStaff(command);
    }

    if (normalized.contains('staff details') || normalized.contains('get staff')) {
      return await _handleStaffDetails(command);
    }

    if (normalized.contains('invoice') || normalized.contains('invoices')) {
      return await _handleStudentInvoices(command);
    }

    if (normalized.contains('low attendance')) {
      return await _handleLowAttendance(command);
    }

    if (normalized.contains('fleet overview') || (normalized.contains('vehicle') && normalized.contains('overview')) || normalized.contains('vehicle status')) {
      return await _handleFleetOverview();
    }

    if (normalized.contains('vehicle') && (normalized.contains('details') || normalized.contains('driver'))) {
      return await _handleVehicleDetails(command);
    }

    if (normalized.contains('route') && normalized.contains('students')) {
      return await _handleRouteWithStudents(command);
    }

    if (normalized.contains('route') && normalized.contains('details')) {
      return await _handleRouteDetails(command);
    }

    if (normalized.contains('library') || normalized.contains('book') || normalized.contains('borrower')) {
      return await _handleLibraryCommand(command);
    }

    if (normalized.contains('hostel')) {
      return await _handleHostelInfo(command);
    }

    if (normalized.contains('transport') || normalized.contains('bus') || normalized.contains('van')) {
      return await _handleStudentTransport(command);
    }

    if (normalized.contains('fee ledger') || normalized.contains('net payable') || normalized.contains('payable fees') || normalized.contains('fee summary') || normalized.contains('fees for student')) {
      return await _handleStudentFeeSummary(command);
    }

    if (normalized.contains('exam result') || normalized.contains('class ranking') || normalized.contains('rankings') || normalized.contains('grade for student')) {
      return await _handleExamCommand(command);
    }

    if ((normalized.contains('students in') || normalized.contains('students from') || normalized.contains('student list')) && (normalized.contains('grade') || normalized.contains('class'))) {
      return await _handleClassStudents(command);
    }

    return 'I did not understand that command. Type "help" for examples.';
  }

  String _helpText() {
    return '''I can help you retrieve information and perform attendance tasks across students, staff, transport, library, hostel, fees, and exams.

Examples:
• search student John Doe
• show student details 12345
• show student invoices 12345
• attendance for student John Doe in September 2026
• low attendance for Grade 2 section B in 2026-2027
• initialize attendance sheet for class Grade 1 section A on 2026-09-01
• search staff Alice
• staff details S-123
• fleet overview
• vehicle details BUS-01
• route students for Route A
• search book algebra
• hostel info for student 12345
• transport info for student 12345 in 2026-2027
• fee summary for student 12345 in 2026-2027
• exam result for student John Doe in Midterm
''';
  }

  Future<String> _handleSearchStudent(String command) async {
    final matcher = RegExp(r'(?:search|find) student(?: for)? (.+)', caseSensitive: false);
    final match = matcher.firstMatch(command);
    if (match == null) {
      return 'Please specify the student name or query. Example: search student John Doe';
    }

    final query = match.group(1)!.trim();
    final students = await _dbService.searchStudents(query);

    if (students.isEmpty) {
      return 'No students matched "$query".';
    }

    final lines = students.map((student) {
      return '${student.id} • ${student.name} • ${student.gradeLevel} ${student.section ?? ''}'.trim();
    }).join('\n');

    return 'Found ${students.length} student(s):\n$lines';
  }

  Future<String> _handleStudentDetails(String command) async {
    final matcher = RegExp(r'(?:student details|show student details|get student)(?: for)? (.+)', caseSensitive: false);
    final match = matcher.firstMatch(command);
    if (match == null) {
      return 'Please specify a student ID or name. Example: student details 12345';
    }

    final identifier = match.group(1)!.trim();
    final student = await _findStudentByIdentifier(identifier);

    if (student == null) {
      return 'Could not find a student for "$identifier".';
    }

    return 'Student details:\n'
        'ID: ${student.id}\n'
        'Name: ${student.name}\n'
        'Class: ${student.gradeLevel} ${student.section ?? ''}\n'
        'Phone: ${student.guardianPhone ?? 'N/A'}\n'
        'Status: ${student.isActive ? 'Active' : 'Inactive'}';
  }

  Future<String> _handleStudentInvoices(String command) async {
    final matcher = RegExp(r'(?:student invoices|invoices for student|invoice for student|student invoice)(?: )?(.*)', caseSensitive: false);
    final match = matcher.firstMatch(command);
    if (match == null || match.group(1)?.trim().isEmpty == true) {
      return 'Please specify a student ID or name. Example: show student invoices 12345';
    }

    final identifier = match.group(1)!.trim();
    final student = await _findStudentByIdentifier(identifier);
    if (student == null) {
      return 'Could not find a student for "$identifier".';
    }

    final invoices = await _dbService.getInvoicesByStudentId(student.id);
    if (invoices.isEmpty) {
      return 'No invoices found for ${student.name} (${student.id}).';
    }

    final lines = invoices.map((invoice) {
      return '${invoice.id}: ${invoice.status.name.toUpperCase()} • ${invoice.totalAmount.toStringAsFixed(2)}';
    }).join('\n');

    return 'Invoices for ${student.name}:\n$lines';
  }

  Future<String> _handleStudentAttendance(String command) async {
    final monthYearMatcher = RegExp(r'([A-Za-z]+)\s+(\d{4})');
    final match = monthYearMatcher.firstMatch(command);

    if (match == null) {
      return 'Please specify a month and year. Example: attendance for student John Doe in September 2026';
    }

    final monthName = match.group(1)!;
    final year = int.tryParse(match.group(2)!);
    if (year == null) {
      return 'I could not parse the year. Use a four-digit year like 2026.';
    }

    final month = _monthNameToNumber(monthName);
    if (month == null) {
      return 'I could not parse the month "$monthName". Please use a month name like September.';
    }

    final studentQuery = _extractStudentIdentifier(command);
    if (studentQuery == null) {
      return 'Please specify a student name or ID. Example: attendance for student John Doe in September 2026';
    }

    final student = await _findStudentByIdentifier(studentQuery);
    if (student == null) {
      return 'Could not find a student for "$studentQuery".';
    }

    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);
    final attendance = await _dbService.getAttendanceForStudent(
      student.id,
      startDate: _dateString(startDate),
      endDate: _dateString(endDate),
    );

    if (attendance.isEmpty) {
      return 'No attendance records found for ${student.name} in ${monthName.capitalize()} $year.';
    }

    final presentCount = attendance.where((att) => att.status == 'present').length;
    final absentCount = attendance.where((att) => att.status == 'absent').length;
    final lateCount = attendance.where((att) => att.status == 'late').length;
    final halfDayCount = attendance.where((att) => att.status == 'half_day').length;
    final excusedCount = attendance.where((att) => att.status == 'excused').length;
    final total = attendance.length;
    final percent = total == 0 ? 0.0 : (presentCount + halfDayCount * 0.5 + lateCount) / total * 100;

    return 'Attendance for ${student.name} in ${monthName.capitalize()} $year:\n'
        'Present: $presentCount\n'
        'Absent: $absentCount\n'
        'Late: $lateCount\n'
        'Half Day: $halfDayCount\n'
        'Excused: $excusedCount\n'
        'Total Records: $total\n'
        'Attendance Rate: ${percent.toStringAsFixed(1)}%';
  }

  Future<String> _handleLowAttendance(String command) async {
    final matcher = RegExp(r'low attendance for ([A-Za-z0-9 ]+) section ([A-Za-z0-9]+) in (\d{4}-\d{4})', caseSensitive: false);
    final match = matcher.firstMatch(command);
    if (match == null) {
      return 'Please specify class, section, and academic year. Example: low attendance for Grade 2 section B in 2026-2027';
    }

    final grade = match.group(1)!.trim();
    final section = match.group(2)!.trim();
    final academicYear = match.group(3)!.trim();

    final lowAttendance = await _dbService.getLowAttendanceStudents(grade, section, academicYear);
    if (lowAttendance.isEmpty) {
      return 'No students with low attendance found for $grade section $section in $academicYear.';
    }

    final lines = lowAttendance.map((item) {
      final student = item['student'] as Student;
      final percent = item['attendancePercent'] as double;
      return '${student.id} • ${student.name} • ${percent.toStringAsFixed(1)}%';
    }).join('\n');

    return 'Low attendance students for $grade section $section ($academicYear):\n$lines';
  }

  Future<String> _initializeAttendanceSheet(String command) async {
    final matcher = RegExp(r'initialize attendance sheet for class ([A-Za-z0-9 ]+) section ([A-Za-z0-9]+) on (\d{4}-\d{2}-\d{2})', caseSensitive: false);
    final match = matcher.firstMatch(command);
    if (match == null) {
      return 'Please use the format: initialize attendance sheet for class Grade 1 section A on 2026-09-01';
    }

    final grade = match.group(1)!.trim();
    final section = match.group(2)!.trim();
    final date = match.group(3)!.trim();

    try {
      await _dbService.initializeAttendanceSheet(grade, section, date, 'admin');
      return 'Attendance sheet initialized for $grade section $section on $date.';
    } catch (e) {
      return 'Failed to initialize attendance sheet: ${e.toString()}';
    }
  }

  Future<Student?> _findStudentByIdentifier(String identifier) async {
    final byId = await _dbService.getStudentById(identifier);
    if (byId != null) {
      return byId;
    }

    final results = await _dbService.searchStudents(identifier);
    if (results.length == 1) {
      return results.first;
    }

    if (results.length > 1) {
      return results.first;
    }

    return null;
  }

  Future<Staff?> _findStaffByIdentifier(String identifier) async {
    final byId = await _dbService.getStaffById(identifier);
    if (byId != null) {
      return byId;
    }

    final allStaff = await _dbService.getAllStaff(page: 0, pageSize: 10000, activeOnly: false);
    final normalized = identifier.trim().toLowerCase();
    final matches = allStaff.where((staff) {
      final fullName = '${staff.firstName} ${staff.lastName}'.toLowerCase();
      return fullName.contains(normalized) || (staff.staffCode?.toLowerCase() ?? '').contains(normalized) || (staff.email?.toLowerCase() ?? '').contains(normalized) || (staff.phone?.toLowerCase() ?? '').contains(normalized);
    }).toList();

    if (matches.length == 1) return matches.first;
    if (matches.isNotEmpty) return matches.first;
    return null;
  }

  String? _extractStudentIdentifier(String command) {
    final matcher = RegExp(r'student(?: (?:named|called))? (.+?) (?:in|for|on|with|during|with|in|during|for)', caseSensitive: false);
    final match = matcher.firstMatch(command);
    if (match != null) {
      return match.group(1)!.trim();
    }

    final genericMatcher = RegExp(r'student(?: )?(.*)', caseSensitive: false);
    final genericMatch = genericMatcher.firstMatch(command);
    if (genericMatch != null) {
      return genericMatch.group(1)!.trim();
    }

    return null;
  }

  int? _monthNameToNumber(String name) {
    final cleaned = name.trim().toLowerCase();
    final months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    return months[cleaned];
  }

  Future<String> _handleSearchStaff(String command) async {
    final matcher = RegExp(r'(?:search|find) staff(?: for)? (.+)', caseSensitive: false);
    final match = matcher.firstMatch(command);
    if (match == null) {
      return 'Please specify the staff name or query. Example: search staff Alice';
    }

    final query = match.group(1)!.trim();
    final allStaff = await _dbService.getAllStaff(page: 0, pageSize: 10000, activeOnly: false);
    final matches = allStaff.where((staff) {
      final fullName = '${staff.firstName} ${staff.lastName}'.toLowerCase();
      return fullName.contains(query.toLowerCase()) || (staff.staffCode?.toLowerCase() ?? '').contains(query.toLowerCase());
    }).toList();

    if (matches.isEmpty) {
      return 'No staff members matched "$query".';
    }

    final lines = matches.map((staff) {
      return '${staff.id} • ${staff.fullName} • ${staff.role}';
    }).join('\n');

    return 'Found ${matches.length} staff member(s):\n$lines';
  }

  Future<String> _handleStaffDetails(String command) async {
    final matcher = RegExp(r'(?:staff details|show staff details|get staff)(?: for)? (.+)', caseSensitive: false);
    final match = matcher.firstMatch(command);
    if (match == null) {
      return 'Please specify a staff ID or name. Example: staff details S-123';
    }

    final identifier = match.group(1)!.trim();
    final staff = await _findStaffByIdentifier(identifier);
    if (staff == null) {
      return 'Could not find a staff member for "$identifier".';
    }

    return 'Staff details:\n'
        'ID: ${staff.id}\n'
        'Name: ${staff.fullName}\n'
        'Role: ${staff.role}\n'
        'Department: ${staff.departmentId ?? 'N/A'}\n'
        'Phone: ${staff.phone ?? 'N/A'}\n'
        'Email: ${staff.email ?? 'N/A'}\n'
        'Status: ${staff.isActive ? 'Active' : 'Inactive'}';
  }

  Future<String> _handleFleetOverview() async {
    final fleet = await _dbService.getFleetOverview();
    if (fleet.isEmpty) {
      return 'No fleet data available.';
    }

    final lines = fleet.map((item) {
      final vehicle = item['vehicle'] as Map<String, dynamic>?;
      final route = item['route'] as Map<String, dynamic>?;
      final vehicleNumber = vehicle?['vehicle_number'] ?? 'Unknown';
      final routeName = route?['route_name'] ?? 'Unassigned';
      final driverName = item['driver_name'] ?? 'Unknown';
      final capacity = item['capacity'] ?? 'N/A';
      return '$vehicleNumber • $routeName • Driver: $driverName • Capacity: $capacity';
    }).join('\n');

    return 'Fleet overview:\n$lines';
  }

  Future<String> _handleVehicleDetails(String command) async {
    final matcher = RegExp(r'vehicle(?: details)?(?: for)? (.+)', caseSensitive: false);
    final match = matcher.firstMatch(command);
    if (match == null || match.group(1)?.trim().isEmpty == true) {
      return 'Please specify a vehicle number or ID. Example: vehicle details BUS-01';
    }

    final identifier = match.group(1)!.trim().toLowerCase();
    final vehicles = await _dbService.getAllVehicles(activeOnly: false);
    final found = vehicles.where((vehicle) {
      return vehicle.vehicleNumber.toLowerCase() == identifier || vehicle.id.toLowerCase() == identifier;
    }).toList();

    if (found.isEmpty) {
      return 'Could not find a vehicle for "$identifier".';
    }

    final vehicle = found.first;
    return 'Vehicle details:\n'
        'ID: ${vehicle.id}\n'
        'Number: ${vehicle.vehicleNumber}\n'
        'Type: ${vehicle.vehicleType}\n'
        'Capacity: ${vehicle.capacity}\n'
        'Driver: ${vehicle.driverName ?? 'N/A'}\n'
        'Conductor: ${vehicle.conductorName ?? 'N/A'}\n'
        'Insurance Expires: ${vehicle.insuranceExpiry?.toIso8601String() ?? 'N/A'}\n'
        'Fitness Expires: ${vehicle.fitnessExpiry?.toIso8601String() ?? 'N/A'}';
  }

  Future<String> _handleRouteWithStudents(String command) async {
    final matcher = RegExp(r'route(?: students)?(?: for)? (.+)', caseSensitive: false);
    final match = matcher.firstMatch(command);
    if (match == null || match.group(1)?.trim().isEmpty == true) {
      return 'Please specify a route name or ID. Example: route students for Route A';
    }

    final identifier = match.group(1)!.trim().toLowerCase();
    final routes = await _dbService.getAllRoutes();
    final matched = routes.where((route) {
      return route.routeName.toLowerCase() == identifier || route.id.toLowerCase() == identifier;
    }).toList();

    if (matched.isEmpty) {
      return 'Could not find a route for "$identifier".';
    }

    final route = matched.first;
    final routeData = await _dbService.getRouteWithStudents(route.id);
    final students = routeData['students'] as List<dynamic>? ?? [];
    final routeName = route.routeName;
    final stops = routeData['stops'] as List<dynamic>? ?? [];

    final studentLines = students.map((student) => '${student['student_id']} • ${student['student_name']}').join('\n');
    final stopLines = stops.map((stop) => '${stop['stop_name']}').join(', ');

    return 'Route $routeName students:\nStops: $stopLines\nStudents:\n${studentLines.isEmpty ? 'None' : studentLines}';
  }

  Future<String> _handleRouteDetails(String command) async {
    final matcher = RegExp(r'route(?: details)?(?: for)? (.+)', caseSensitive: false);
    final match = matcher.firstMatch(command);
    if (match == null || match.group(1)?.trim().isEmpty == true) {
      return 'Please specify a route name or ID. Example: route details for Route A';
    }

    final identifier = match.group(1)!.trim().toLowerCase();
    final routes = await _dbService.getAllRoutes();
    final matched = routes.where((route) {
      return route.routeName.toLowerCase() == identifier || route.id.toLowerCase() == identifier;
    }).toList();

    if (matched.isEmpty) {
      return 'Could not find a route for "$identifier".';
    }

    final route = matched.first;
    final details = 'Route details:\nName: ${route.routeName}\nFrom: ${route.startPoint}\nTo: ${route.endPoint}\nVehicle: ${route.vehicleNumber ?? 'Unassigned'}\nStops: ${route.stops.map((stop) => stop.stopName).join(', ')}';
    return details;
  }

  Future<String> _handleLibraryCommand(String command) async {
    if (command.toLowerCase().contains('search book') || command.toLowerCase().contains('find book')) {
      return await _handleBookSearch(command);
    }

    if (command.toLowerCase().contains('overdue')) {
      final issues = await _dbService.getOverdueIssues();
      if (issues.isEmpty) {
        return 'No overdue library issues found.';
      }
      final lines = issues.take(10).map((issue) => '${issue['borrower_id']} • ${issue['book_title']} • Due ${issue['due_date']}').join('\n');
      return 'Overdue library issues:\n$lines';
    }

    if (command.toLowerCase().contains('active issues') || command.toLowerCase().contains('issued books')) {
      final issues = await _dbService.getActiveIssues();
      if (issues.isEmpty) {
        return 'No active library issues found.';
      }
      final lines = issues.take(10).map((issue) => '${issue['borrower_id']} • ${issue['book_title']} • Due ${issue['due_date']}').join('\n');
      return 'Active library issues:\n$lines';
    }

    return 'Library commands supported: search book <query>, overdue books, active issues.';
  }

  Future<String> _handleBookSearch(String command) async {
    final matcher = RegExp(r'(?:search|find) book(?: for)? (.+)', caseSensitive: false);
    final match = matcher.firstMatch(command);
    if (match == null) {
      return 'Please specify a book name, author, ISBN, or category. Example: search book algebra';
    }

    final query = match.group(1)!.trim();
    final books = await _dbService.searchBooks(query);
    if (books.isEmpty) {
      return 'No books matched "$query".';
    }

    final lines = books.take(10).map((book) => '${book.title} by ${book.author} • ${book.category ?? 'N/A'}').join('\n');
    return 'Found ${books.length} book(s):\n$lines';
  }

  Future<String> _handleHostelInfo(String command) async {
    final studentQuery = _extractStudentIdentifier(command);
    if (studentQuery == null) {
      return 'Please specify a student name or ID. Example: hostel info for student 12345';
    }

    final student = await _findStudentByIdentifier(studentQuery);
    if (student == null) {
      return 'Could not find a student for "$studentQuery".';
    }

    final hostelInfo = await _dbService.getStudentHostelInfo(student.id);
    if (hostelInfo == null) {
      return 'No hostel allocation found for ${student.name}.';
    }

    return 'Hostel info for ${student.name}:\n'
        'Block: ${hostelInfo['block_name'] ?? 'N/A'}\n'
        'Room: ${hostelInfo['room_number'] ?? 'N/A'}\n'
        'Bed: ${hostelInfo['bed_number'] ?? 'N/A'}\n'
        'Allocated: ${hostelInfo['allocated_date'] ?? 'N/A'}';
  }

  Future<String> _handleStudentTransport(String command) async {
    final studentQuery = _extractStudentIdentifier(command);
    if (studentQuery == null) {
      return 'Please specify a student name or ID. Example: transport info for student 12345';
    }

    final student = await _findStudentByIdentifier(studentQuery);
    if (student == null) {
      return 'Could not find a student for "$studentQuery".';
    }

    final academicYearMatcher = RegExp(r'(\d{4}-\d{4})');
    final yearMatch = academicYearMatcher.firstMatch(command);
    final academicYear = yearMatch?.group(1) ?? '2026-2027';
    final transport = await _dbService.getStudentTransport(student.id, academicYear);
    if (transport == null) {
      return 'No transport assignment found for ${student.name} in $academicYear.';
    }

    return 'Transport info for ${student.name}:\n'
        'Route: ${transport.routeName ?? 'N/A'}\n'
        'Stop: ${transport.stopName ?? 'N/A'}\n'
        'Pickup: ${transport.pickupTime ?? 'N/A'}\n'
        'Drop: ${transport.dropTime ?? 'N/A'}\n'
        'Fee: ${transport.monthlyFee.toStringAsFixed(2)}\n'
        'Academic Year: ${transport.academicYear}';
  }

  Future<String> _handleStudentFeeSummary(String command) async {
    final identifierMatcher = RegExp(r'(?:for student|student)(?: )?(.+?)(?: in (\d{4}-\d{4}))?$', caseSensitive: false);
    final match = identifierMatcher.firstMatch(command);
    if (match == null) {
      return 'Please specify a student and academic year. Example: fee summary for student 12345 in 2026-2027';
    }

    final identifier = match.group(1)!.trim();
    final academicYear = match.group(2) ?? '2026-2027';
    final student = await _findStudentByIdentifier(identifier);
    if (student == null) {
      return 'Could not find a student for "$identifier".';
    }

    final feeLedger = await _dbService.getStudentFeeLedger(student.id, academicYear);
    if (feeLedger.isEmpty) {
      return 'No fee ledger entries found for ${student.name} in $academicYear.';
    }

    final totalDue = feeLedger.fold<double>(0, (acc, entry) => acc + entry.amountDue);
    final lines = feeLedger.take(10).map((entry) => '${entry.feeHeadName ?? 'N/A'} • Due: ${entry.amountDue.toStringAsFixed(2)} • Status: ${entry.status}').join('\n');

    return 'Fee ledger summary for ${student.name} ($academicYear):\nTotal due: ${totalDue.toStringAsFixed(2)}\n$lines';
  }

  Future<String> _handleExamCommand(String command) async {
    final studentQuery = _extractStudentIdentifier(command);
    final examQuery = RegExp(r'exam (?:result|for|named|called)? (.+)', caseSensitive: false).firstMatch(command)?.group(1)?.trim();
    if (studentQuery == null || examQuery == null || studentQuery.isEmpty || examQuery.isEmpty) {
      return 'Please specify a student and an exam. Example: exam result for student John Doe in Midterm';
    }

    final student = await _findStudentByIdentifier(studentQuery);
    if (student == null) {
      return 'Could not find a student for "$studentQuery".';
    }

    final exams = await _dbService.getAllExams();
    final matched = exams.where((exam) {
      return exam.name.toLowerCase().contains(examQuery.toLowerCase()) || exam.id.toLowerCase() == examQuery.toLowerCase();
    }).toList();
    if (matched.isEmpty) {
      return 'Could not find an exam matching "$examQuery".';
    }

    final exam = matched.first;
    final result = await _dbService.computeExamResult(exam.id, student.id);
    if (result == null) {
      return 'No exam result found for ${student.name} in ${exam.name}.';
    }

    return 'Exam result for ${student.name} in ${exam.name}:\n'
        'Percentage: ${result.percentage.toStringAsFixed(1)}%\n'
        'Grade: ${result.grade}\n'
        'Status: ${result.isPassed ? 'Passed' : 'Failed'}';
  }

  Future<String> _handleClassStudents(String command) async {
    final matcher = RegExp(r'(?:students in|student list for|students from) (.+?)(?: section| grade| in|$)', caseSensitive: false);
    final match = matcher.firstMatch(command);
    if (match == null) {
      return 'Please specify a class or grade name. Example: students in Grade 10';
    }

    final className = match.group(1)!.trim();
    final students = await _dbService.getStudentsByGrade(className);
    if (students.isEmpty) {
      return 'No active students found for $className.';
    }

    final lines = students.take(10).map((student) => '${student.id} • ${student.name} • Section ${student.section ?? 'N/A'}').join('\n');
    return 'Students in $className:\n$lines';
  }

  String _dateString(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return substring(0, 1).toUpperCase() + substring(1);
  }
}
