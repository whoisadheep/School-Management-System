import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/ui/views/auth/login_view.dart';
import 'package:school_management_system/ui/widgets/interactive_login_mascot.dart';

void main() {
  testWidgets('AdminLoginView renders mascot and tracks mouse hover', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminLoginView(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(InteractiveLoginMascot), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    // Hover mouse around different parts of the screen
    await gesture.moveTo(const Offset(300, 400));
    await tester.pump(const Duration(milliseconds: 50));

    await gesture.moveTo(const Offset(900, 300));
    await tester.pump(const Duration(milliseconds: 50));

    // Hover directly over the mascot
    final mascotFinder = find.byType(InteractiveLoginMascot);
    await gesture.moveTo(tester.getCenter(mascotFinder));
    await tester.pump(const Duration(milliseconds: 50));

    // Tap the mascot
    await tester.tap(mascotFinder);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(InteractiveLoginMascot), findsOneWidget);
  });
}
