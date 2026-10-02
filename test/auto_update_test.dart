import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/providers/auto_update_provider.dart';
import 'package:school_management_system/services/update_service.dart';
import 'package:school_management_system/ui/widgets/auto_update_banner.dart';

void main() {
  group('AutoUpdateState & Notifier Tests', () {
    test('Initial state is idle with zero progress', () {
      final notifier = AutoUpdateNotifier();
      expect(notifier.state.status, AutoUpdateStatus.idle);
      expect(notifier.state.progress, 0.0);
      expect(notifier.state.isDismissed, false);
      expect(notifier.state.isCollapsed, false);
    });

    test('State copyWith updates fields properly', () {
      const state = AutoUpdateState();
      final updated = state.copyWith(
        status: AutoUpdateStatus.downloading,
        progress: 0.45,
        receivedBytes: 45 * 1024 * 1024,
        totalBytes: 100 * 1024 * 1024,
      );

      expect(updated.status, AutoUpdateStatus.downloading);
      expect(updated.progress, 0.45);
      expect(updated.receivedMb, 45.0);
      expect(updated.totalMb, 100.0);
    });

    test('toggleCollapsed, dismiss, and reopen work as expected', () {
      final notifier = AutoUpdateNotifier();
      expect(notifier.state.isCollapsed, false);

      notifier.toggleCollapsed();
      expect(notifier.state.isCollapsed, true);

      notifier.toggleCollapsed();
      expect(notifier.state.isCollapsed, false);

      notifier.dismiss();
      expect(notifier.state.isDismissed, true);

      notifier.reopen();
      expect(notifier.state.isDismissed, false);
      expect(notifier.state.isCollapsed, false);
    });
  });

  group('AutoUpdate Widgets UI Tests', () {
    testWidgets('AutoUpdateTopProgressBar renders only when downloading', (WidgetTester tester) async {
      final notifier = AutoUpdateNotifier();
      notifier.state = const AutoUpdateState(status: AutoUpdateStatus.idle);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            autoUpdateProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AutoUpdateTopProgressBar(),
            ),
          ),
        ),
      );

      expect(find.byType(FractionallySizedBox), findsNothing);

      // Now set to downloading
      notifier.state = const AutoUpdateState(
        status: AutoUpdateStatus.downloading,
        progress: 0.65,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(FractionallySizedBox), findsOneWidget);
    });

    testWidgets('AutoUpdateFloatingBanner renders download progress and handles collapse', (WidgetTester tester) async {
      final notifier = AutoUpdateNotifier();
      notifier.state = AutoUpdateState(
        status: AutoUpdateStatus.downloading,
        progress: 0.52,
        receivedBytes: 52 * 1024 * 1024,
        totalBytes: 100 * 1024 * 1024,
        updateInfo: UpdateInfo(
          isUpdateAvailable: true,
          latestVersion: '1.0.40',
          downloadUrl: 'https://example.com/update.exe',
          sha256: '',
          changelog: 'Test changelog',
          isMandatory: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            autoUpdateProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  AutoUpdateFloatingBanner(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Downloading Update'), findsOneWidget);
      expect(find.text('52%'), findsOneWidget);
      expect(find.textContaining('52.0 MB of 100.0 MB'), findsOneWidget);

      // Tap collapse
      final collapseBtn = find.byIcon(Icons.remove_rounded);
      expect(collapseBtn, findsOneWidget);
      await tester.tap(collapseBtn);
      await tester.pumpAndSettle();

      // Should now show collapsed pill with 52% and unfold icon
      expect(find.text('52%'), findsOneWidget);
      expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
    });

    testWidgets('AutoUpdateFloatingBanner shows Ready to Install when completed', (WidgetTester tester) async {
      final notifier = AutoUpdateNotifier();
      notifier.state = AutoUpdateState(
        status: AutoUpdateStatus.readyToInstall,
        progress: 1.0,
        installerPath: '/dummy/path/Eduvia-Installer.exe',
        updateInfo: UpdateInfo(
          isUpdateAvailable: true,
          latestVersion: '1.0.40',
          downloadUrl: 'https://example.com/update.exe',
          sha256: '',
          changelog: 'Test changelog',
          isMandatory: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            autoUpdateProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  AutoUpdateFloatingBanner(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Update v1.0.40 Ready'), findsOneWidget);
      expect(find.text('Restart & Install'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);

      // Tap Later dismisses the banner
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(find.text('Update v1.0.40 Ready'), findsNothing);
    });
  });
}
