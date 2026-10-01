import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/ui/widgets/cute_animal_empty_state.dart';

void main() {
  group('CuteAnimalEmptyState Widget Tests', () {
    testWidgets('renders detectivePuppy character with title, subtitle, and action', (tester) async {
      bool actionPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuteAnimalEmptyState(
              character: EmptyStateCharacter.detectivePuppy,
              title: 'No students found',
              subtitle: 'Try adjusting your search filters.',
              action: ElevatedButton(
                onPressed: () => actionPressed = true,
                child: const Text('Reset'),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CuteAnimalEmptyState), findsOneWidget);
      expect(find.text('No students found'), findsOneWidget);
      expect(find.text('Try adjusting your search filters.'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      // Tap action button
      await tester.tap(find.text('Reset'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(actionPressed, isTrue);

      // Test mouse hover directly on the puppy
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      final stateFinder = find.byType(CuteAnimalEmptyState);
      await gesture.moveTo(tester.getCenter(stateFinder));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the puppy illustration (boop reaction)
      await tester.tap(find.byType(CustomPaint).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('renders sleepingCat character', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CuteAnimalEmptyState(
              character: EmptyStateCharacter.sleepingCat,
              title: 'All Fees Fully Paid! 🎉',
              subtitle: 'No pending dues.',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CuteAnimalEmptyState), findsOneWidget);
      expect(find.text('All Fees Fully Paid! 🎉'), findsOneWidget);
    });

    testWidgets('renders scholarOwl character', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CuteAnimalEmptyState(
              character: EmptyStateCharacter.scholarOwl,
              title: 'No books found',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CuteAnimalEmptyState), findsOneWidget);
      expect(find.text('No books found'), findsOneWidget);
    });
  });
}
