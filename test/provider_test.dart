import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:school_management_system/providers/services_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
  });

  test('Check provider container initialization', () async {
    final container = ProviderContainer();
    expect(container, isNotNull);
  });

  test('Check schoolNameProvider resolves custom or default school name', () async {
    final container = ProviderContainer(
      overrides: [
        schoolNameProvider.overrideWith((ref) => Future.value('Springfield Academy')),
      ],
    );
    final schoolName = await container.read(schoolNameProvider.future);
    expect(schoolName, 'Springfield Academy');
  });
}
