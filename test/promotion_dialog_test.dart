import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management_system/core/theme/app_theme.dart';
import 'package:school_management_system/models/models.dart';

void main() {
  testWidgets('Fee Clearance Warning Dialog renders without IntrinsicWidth or RenderFlex exception', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const mockDues = [
      StudentFeeDuesSummary(
        studentId: 'st-1',
        studentName: 'Aarav Sharma',
        rollNumber: '101',
        gradeLevel: 'Class 10th',
        totalDue: 5000.0,
        totalPaid: 0.0,
        unpaidLedgerCount: 1,
        unpaidBalance: 5000.0,
        unpaidDetails: ['Tuition Fee: ₹5000'],
      ),
      StudentFeeDuesSummary(
        studentId: 'st-2',
        studentName: 'Diya Patel',
        rollNumber: '102',
        gradeLevel: 'Class 10th',
        totalDue: 2500.0,
        totalPaid: 0.0,
        unpaidLedgerCount: 1,
        unpaidBalance: 2500.0,
        unpaidDetails: ['Exam Fee: ₹2500'],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: GoogleFonts.poppins().fontFamily),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (modalCtx) {
                      return AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Fee Clearance & Arrears Warning', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF92400E))),
                                Text('Step 2: Session End Financial Audit (2025-2026)', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                        content: SizedBox(
                          width: 620,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 450),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '2 of 10 student(s) have uncleared dues totaling ₹7500 in session 2025-2026.',
                                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text('Students with Uncleared Fee Obligations:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                  const SizedBox(height: 8),
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 180),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bgSurface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.divider),
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      itemCount: mockDues.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
                                      itemBuilder: (context, idx) {
                                        final item = mockDues[idx];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor: const Color(0xFFFEF3C7),
                                                child: Text('${idx + 1}', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFB45309))),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(item.studentName, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                                    Text(
                                                      'Roll: ${item.rollNumber ?? "N/A"} • ${item.unpaidDetails.join(', ')}',
                                                      style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                '₹${item.unpaidBalance.toStringAsFixed(0)} Due',
                                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.error),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () {}, child: const Text('Cancel')),
                          ElevatedButton(onPressed: () {}, child: const Text('Promote & Rollover')),
                        ],
                      );
                    },
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      ),
    );

    // Tap to open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify dialog opened successfully with no layout error
    expect(find.text('Fee Clearance & Arrears Warning'), findsOneWidget);
    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.text('Diya Patel'), findsOneWidget);
    expect(find.text('Promote & Rollover'), findsOneWidget);
  });

  testWidgets('Class Promotion Dialog renders without IntrinsicWidth or RenderFlex exception', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: GoogleFonts.poppins().fontFamily),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        backgroundColor: Colors.white,
                        title: Row(
                          children: [
                            const Icon(Icons.published_with_changes_rounded, color: AppTheme.primaryPurple),
                            const SizedBox(width: 10),
                            Text('STUDENT PROMOTION TOOL', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        content: SizedBox(
                          width: 650,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Promote students to a new academic session and assign them to a class/section.', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: 'Class 10th',
                                          decoration: const InputDecoration(labelText: 'From Class (Current)'),
                                          items: const [DropdownMenuItem(value: 'Class 10th', child: Text('Class 10th'))],
                                          onChanged: (_) {},
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: 'Class 11th',
                                          decoration: const InputDecoration(labelText: 'To Class (Target)'),
                                          items: const [DropdownMenuItem(value: 'Class 11th', child: Text('Class 11th'))],
                                          onChanged: (_) {},
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () {}, child: const Text('Cancel')),
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                            label: const Text('PROMOTE 1 STUDENT(S)'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text('Open Promotion Dialog'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Promotion Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('STUDENT PROMOTION TOOL'), findsOneWidget);
    expect(find.text('PROMOTE 1 STUDENT(S)'), findsOneWidget);
  });

  test('MassClassPromotionMapping model handles creation and copyWith properly', () {
    const mapping = MassClassPromotionMapping(
      fromClass: 'Class 10th',
      fromClassId: 'cls-10',
      toClass: 'Class 11th',
      toClassId: 'cls-11',
      isAlumni: false,
      studentIds: ['st-1', 'st-2'],
    );

    expect(mapping.fromClass, 'Class 10th');
    expect(mapping.toClass, 'Class 11th');
    expect(mapping.isAlumni, false);
    expect(mapping.studentIds.length, 2);

    final graduated = mapping.copyWith(
      toClass: 'Alumni / Graduated',
      toClassId: null,
      isAlumni: true,
      studentIds: ['st-1'],
    );

    expect(graduated.toClass, 'Alumni / Graduated');
    expect(graduated.isAlumni, true);
    expect(graduated.studentIds, ['st-1']);
  });

  testWidgets('Whole-School Mass Promotion Dialog renders correctly without overflow or IntrinsicWidth errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final classNames = ['Class 1st', 'Class 2nd', 'Class 12th'];
    final routeTargets = {
      'Class 1st': 'Class 2nd',
      'Class 2nd': 'Class 3rd',
      'Class 12th': 'Alumni / Graduated',
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: GoogleFonts.poppins().fontFamily),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogCtx) {
                      return AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.rocket_launch_rounded, color: AppTheme.primaryPurple, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'WHOLE-SCHOOL MASS PROMOTION',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  '1-Click Session Transition: 2026-2027  ➔  2027-2028',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        content: SizedBox(
                          width: 760,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 500),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Stats summary
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        Text('Total Active Students: 120', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                        Text('Active Classes: 3', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  // Financial Alert
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'FINANCIAL AUDIT ALERT: UNPAID FEES DETECTED',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF92400E),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '5 student(s) have pending fee dues totaling ₹25,000.',
                                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF78350F)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Class routes
                                  ...classNames.map((c) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Text(c, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward_rounded, size: 16),
                                        const SizedBox(width: 8),
                                        Text(routeTargets[c]!, style: GoogleFonts.poppins(color: AppTheme.primaryPurple)),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () {}, child: const Text('Cancel')),
                          OutlinedButton(onPressed: () {}, child: const Text('Promote Cleared Only (115)')),
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                            label: const Text('1-Click Promote All & Rollover (120)'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text('Open Whole School Dialog'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Whole School Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('WHOLE-SCHOOL MASS PROMOTION'), findsOneWidget);
    expect(find.text('FINANCIAL AUDIT ALERT: UNPAID FEES DETECTED'), findsOneWidget);
    expect(find.text('1-Click Promote All & Rollover (120)'), findsOneWidget);
    expect(find.text('Promote Cleared Only (115)'), findsOneWidget);
    expect(find.text('Alumni / Graduated'), findsOneWidget);
  });
}
