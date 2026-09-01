import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_management_system/app.dart';
import 'package:school_management_system/core/database/database_helper.dart';
import 'package:school_management_system/services/app_logger.dart';
import 'package:school_management_system/services/crash_reporting_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 1. Load environment variables safely
      try {
        await dotenv.load(fileName: '.env');
      } catch (e) {
        debugPrint('Notice: .env load fallback: $e');
      }

      // 2. Initialize telemetry & logging systems
      try {
        await CrashReportingService.instance.initialize();
        await AppLogger.instance.initialize();
        AppLogger.instance.info('Application starting...');
      } catch (e) {
        debugPrint('Logger initialization error: $e');
      }

      // Catch uncaught Flutter framework errors
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        AppLogger.instance.error(
          'Flutter Framework Error: ${details.exceptionAsString()}',
          details.exception,
          details.stack,
        );
      };

      // 4. Initialize SQLite database
      try {
        final dbHelper = DatabaseHelper();
        await dbHelper.database;
        AppLogger.instance.info('Database initialized successfully.');
      } catch (e) {
        debugPrint('Database initialization notice: $e');
      }

      // 5. Initialize Auto Updater (Desktop Only) - Removed as we use custom UpdateService

      // 5. Mount application UI
      runApp(
        const ProviderScope(
          child: SchoolManagementApp(),
        ),
      );
    },
    (error, stackTrace) {
      debugPrint('Uncaught async error: $error\n$stackTrace');
      AppLogger.instance.error(
        'Uncaught async error',
        error,
        stackTrace,
      );
    },
  );
}

