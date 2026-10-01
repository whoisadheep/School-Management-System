import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/ui/widgets/interactive_login_mascot.dart';

void main() {
  testWidgets('InteractiveLoginMascot renders and responds to controller & mouse interactions', (tester) async {
    final controller = InteractiveLoginMascotController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractiveLoginMascot(
              controller: controller,
              size: 160,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(InteractiveLoginMascot), findsOneWidget);

    // Test mouse hover directly over the mascot
    final mascotFinder = find.byType(InteractiveLoginMascot);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    // Hover over center of the mascot
    await gesture.moveTo(tester.getCenter(mascotFinder));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap the mascot (boop reaction)
    await tester.tap(mascotFinder);
    await tester.pump(const Duration(milliseconds: 100));

    // Move outside the mascot
    await gesture.moveTo(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 100));

    // Test controller methods
    controller.setGlobalMousePosition(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 50));

    controller.setChecking(true);
    controller.setLook(60);
    await tester.pump(const Duration(milliseconds: 50));

    controller.setHandsUp(true);
    await tester.pump(const Duration(milliseconds: 50));

    controller.setPeeking(true);
    await tester.pump(const Duration(milliseconds: 50));

    controller.resetGaze();
    await tester.pump(const Duration(milliseconds: 50));

    controller.triggerSuccess();
    await tester.pump(const Duration(milliseconds: 50));

    controller.triggerFail();
    await tester.pump(const Duration(milliseconds: 50));

    // Everything completed without throwing
    expect(find.byType(InteractiveLoginMascot), findsOneWidget);
  });
}
