# Eduvia Project Rules & Architecture Quick-Reference

> **Context**: This file is loaded automatically by Antigravity and Gemini agents. For the complete directory and view index, refer to [AGENTS.md](file:///home/whoisadheep/Documents/School%20Management%20System/School%20Management%20System/AGENTS.md).

## Critical Guidelines for AI Assistants

1. **Do Not Hallucinate State Management**:
   - Always use **Flutter Riverpod**.
   - Consume providers with `ref.watch()` inside `build()` and `ref.read()` in callbacks.
   - Central providers reside in `lib/providers/services_provider.dart` and domain-specific files in `lib/providers/`.

2. **Database Queries Must Go Through `DatabaseService`**:
   - Never write raw SQLite queries in UI files.
   - All DB operations must be routed through `DatabaseService` (`lib/services/database_service.dart`).
   - Database schema and migrations are handled in `lib/core/database/database_helper.dart`.

3. **Theme & Styling**:
   - Use tokens from `AppTheme` (`lib/core/theme/app_theme.dart`): `primaryPurple`, `bgMain`, `bgSurface`, `cardDecoration()`.
   - Typography uses Google Fonts `Poppins`.

4. **Model Serialization**:
   - All models in `lib/models/` must provide `toMap()` and `fromMap(Map<String, dynamic>)` matching SQLite columns.

5. **Code Generation**:
   - When modifying files with `@riverpod` annotations, run:
     `dart run build_runner build --delete-conflicting-outputs`
