import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_management_system/core/theme/app_theme.dart';
import 'package:school_management_system/ui/layout/main_layout.dart';

class SchoolManagementApp extends StatelessWidget {
  const SchoolManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Management System',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const MainLayout(),
    );
  }

  ThemeData _buildTheme() {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppTheme.primaryPurple,
      brightness: Brightness.light,
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: AppTheme.bgMain,
      textTheme: GoogleFonts.poppinsTextTheme(baseTheme.textTheme),
    );
  }
}
