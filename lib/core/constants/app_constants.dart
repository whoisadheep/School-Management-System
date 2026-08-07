/// Application-wide constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'School Management System';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Admin & Accounting Module';

  // Database
  static const String databaseName = 'school_management.db';
  static const int databaseVersion = 1;

  // UI Constants — Desktop-optimized sizing
  static const double sidebarWidth = 260.0;
  static const double sidebarCollapsedWidth = 72.0;
  static const double topBarHeight = 64.0;
  static const double defaultPadding = 16.0;
  static const double cardBorderRadius = 12.0;

  // Table Constants
  static const int defaultPageSize = 25;
  static const List<int> pageSizeOptions = [10, 25, 50, 100];

  // Currency
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';

  // Date Formats
  static const String dateFormat = 'dd MMM yyyy';
  static const String dateTimeFormat = 'dd MMM yyyy, hh:mm a';
  static const String monthYearFormat = 'MMMM yyyy';
}
