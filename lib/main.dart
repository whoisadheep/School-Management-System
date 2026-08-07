import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_management_system/app.dart';
import 'package:school_management_system/core/database/database_helper.dart';
import 'package:school_management_system/services/app_logger.dart';
import 'package:firebase_core/firebase_core.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      
      try {
        await Firebase.initializeApp();
        AppLogger.instance.info('Firebase initialized successfully.');
      } catch (e) {
        AppLogger.instance.error('Failed to initialize Firebase: $e');
      }

      // Initialize the centralized logging system
      await AppLogger.instance.initialize();
      AppLogger.instance.info('Application starting...');

      // Catch uncaught Flutter framework errors
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        AppLogger.instance.error(
          'Flutter Framework Error: ${details.exceptionAsString()}',
          details.exception,
          details.stack,
        );
      };

      // Initialize the SQLite database (FFI for desktop)
      final dbHelper = DatabaseHelper();
      await dbHelper.database;
      AppLogger.instance.info('Database initialized successfully.');

      runApp(
        const ProviderScope(
          child: SchoolManagementApp(),
        ),
      );
    },
    (error, stackTrace) {
      AppLogger.instance.error(
        'Uncaught async error',
        error,
        stackTrace,
      );
    },
  );
}

