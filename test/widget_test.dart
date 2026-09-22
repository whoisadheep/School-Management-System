import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/ui/views/license/license_activation_view.dart';

void main() {
  testWidgets('LicenseActivationView renders title and action button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LicenseActivationView(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('License Activation'), findsOneWidget);
    expect(find.text('Activate License'), findsOneWidget);
    expect(find.text('Your Hardware ID'), findsOneWidget);
  });
}
