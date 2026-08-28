import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'database_service.dart';

class AssistantService {
  final DatabaseService _dbService;
  final Dio _http = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 25),
  ));

  static const String defaultGeminiKey = 'YOUR_API_KEY';

  AssistantService(this._dbService);

  Future<String> handleCommand(String command) async {
    final normalized = command.trim().toLowerCase();

    if (normalized.isEmpty) {
      return 'Please type a question or type "help" for examples.';
    }

    final greetings = [
      'hi', 'hy', 'hyy', 'hey', 'heyy', 'hii', 'hiii', 'hello', 'helloo',
      'good morning', 'good afternoon', 'good evening', 'namaste', 'sup',
      "what's up", 'how are you', 'who are you', 'help', 'commands'
    ];

    if (greetings.any((g) => normalized == g || normalized.startsWith('$g '))) {
      return '👋 **Hello! Welcome to Kishan Company AI Assistant**\n\n'
          'I am your intelligent school assistant with direct access to your database. You can ask me:\n\n'
          '• 📊 **Students**: *"How many students are enrolled?"* or *"Show class breakdown"*\n'
          '• 💰 **Fees & Dues**: *"Show fee collection summary"* or *"What are overdue balances?"*\n'
          '• 👥 **Staff & Teachers**: *"Show faculty details"* or *"How many staff members?"*\n'
          '• 🚌 **Transport**: *"Show bus fleet and routes"*\n'
          '• 📚 **Library**: *"Show available books"*\n'
          '• 📝 **Exams**: *"Show scheduled exams"*\n\n'
          'How can I help you today?';
    }

    // 1. Try Direct Google Gemini API first
    try {
      final geminiKey = await getActiveApiKey();
      if (geminiKey.isNotEmpty) {
        final geminiResponse = await _queryGeminiDirect(command, geminiKey);
        if (geminiResponse != null && geminiResponse.trim().isNotEmpty) {
          return geminiResponse.trim();
        }
      }
    } catch (_) {
      // If Gemini is unreachable or hits quota, seamlessly fallback to offline engine
    }

    // 2. Fallback to built-in offline smart query engine
    return await _handleOfflineQuery(command);
  }

  Future<String> getActiveApiKey() async {
    try {
      final db = await _dbService.rawDb;
      final settingRows = await db.rawQuery(
        'SELECT setting_value FROM app_settings WHERE setting_key = ? LIMIT 1',
        ['gemini_api_key'],
      );
      if (settingRows.isNotEmpty && settingRows.first['setting_value'] != null) {
        final val = settingRows.first['setting_value'].toString().trim();
        if (val.isNotEmpty) return val;
      }
    } catch (_) {}

    final envKey = dotenv.env['GEMINI_API_KEY']?.trim() ??
        dotenv.env['ASSISTANT_INSTALLATION_KEY']?.trim() ??
        '';
    if (envKey.isNotEmpty) return envKey;

    return defaultGeminiKey;
  }

  Future<bool> setApiKey(String key) async {
    try {
      final db = await _dbService.rawDb;
      await db.rawInsert(
        'INSERT OR REPLACE INTO app_settings (setting_key, setting_value, updated_at) VALUES (?, ?, ?)',
        ['gemini_api_key', key.trim(), DateTime.now().toIso8601String()],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> testConnection([String? testKey]) async {
    final key = (testKey != null && testKey.trim().isNotEmpty) ? testKey.trim() : await getActiveApiKey();
    if (key.isEmpty) {
      return {'success': false, 'error': 'API key is empty.'};
    }

    final models = ['gemini-flash-latest', 'gemini-flash-lite-latest'];
    for (final model in models) {
      try {
        final stopwatch = Stopwatch()..start();
        final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key';
        final body = {
          'contents': [
            {
              'role': 'user',
              'parts': [{'text': 'Hello! Respond with: Connected to Kishan AI.'}],
            }
          ],
        };

        final response = await _http.post(
          url,
          data: body,
          options: Options(headers: {'Content-Type': 'application/json'}),
        );
        stopwatch.stop();

        if (response.statusCode == 200) {
          return {
            'success': true,
            'model': model,
            'latencyMs': stopwatch.elapsedMilliseconds,
          };
        }
      } catch (_) {
        continue;
      }
    }

    return {'success': false, 'error': 'Unable to reach Gemini API with this key.'};
  }

  Future<String?> _queryGeminiDirect(String command, String apiKey) async {
    final schema = await _getSchema();
    final systemInstruction = '''You are an advanced AI Assistant for Kishan Company School Management System.
You have direct read-only access to the local SQLite database via function calls.
When you need data to answer the user's question, output ONLY:
CALL_FUNCTION:execute_sql_query|{"query": "SELECT ..."}
Only SELECT queries are permitted for data safety.
When you have the data (or if no SQL query is needed), answer the question directly, accurately, and politely in formatted Markdown with bullet points or tables.

Database Schema:
$schema''';

    final contents = <Map<String, dynamic>>[
      {
        'role': 'user',
        'parts': [{'text': command}],
      }
    ];

    final models = ['gemini-flash-latest', 'gemini-flash-lite-latest'];

    String? lastError;
    for (final model in models) {
      try {
        for (int turn = 0; turn < 4; turn++) {
          final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';
          final body = {
            'systemInstruction': {
              'parts': [{'text': systemInstruction}],
            },
            'contents': contents,
            'generationConfig': {
              'maxOutputTokens': 2048,
              'temperature': 0.2,
            },
          };

          final response = await _http.post(
            url,
            data: body,
            options: Options(headers: {'Content-Type': 'application/json'}),
          );

          if (response.statusCode != 200) {
            lastError = 'Status ${response.statusCode}: ${response.data}';
            break;
          }

          final data = response.data is String ? jsonDecode(response.data) : response.data;
          final candidates = data['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) {
            lastError = 'No candidates returned.';
            break;
          }

          final parts = candidates[0]['content']?['parts'] as List?;
          if (parts == null || parts.isEmpty) {
            lastError = 'No parts returned.';
            break;
          }

          final text = parts.map((p) => p['text'] ?? '').join('\n').trim();

          // Check for function call
          if (text.contains('CALL_FUNCTION:')) {
            contents.add({
              'role': 'model',
              'parts': [{'text': text}],
            });

            final lines = text.split('\n');
            String? sqlQuery;
            for (final line in lines) {
              if (line.contains('CALL_FUNCTION:')) {
                final rest = line.substring(line.indexOf('CALL_FUNCTION:') + 14).trim();
                final idx = rest.indexOf('|');
                if (idx > 0) {
                  final fnName = rest.substring(0, idx).trim();
                  final jsonArgs = rest.substring(idx + 1).trim();
                  if (fnName == 'execute_sql_query') {
                    try {
                      // Attempt strict parse first
                      final parsedArgs = jsonDecode(jsonArgs);
                      sqlQuery = parsedArgs['query'];
                    } catch (_) {
                      // Fallback: extract everything between "query": " and the last "
                      final startIdx = jsonArgs.indexOf('"query":');
                      if (startIdx != -1) {
                        final queryStart = jsonArgs.indexOf('"', startIdx + 8) + 1;
                        final queryEnd = jsonArgs.lastIndexOf('"');
                        if (queryStart > 0 && queryEnd > queryStart) {
                          sqlQuery = jsonArgs.substring(queryStart, queryEnd).replaceAll('\\"', '"');
                        }
                      }
                    }
                  }
                }
              }
            }

            if (sqlQuery != null && sqlQuery.trim().toUpperCase().startsWith('SELECT')) {
              try {
                final rows = await _executeSql(sqlQuery);
                contents.add({
                  'role': 'user',
                  'parts': [{'text': '[Function Result for execute_sql_query]: ${jsonEncode(rows)}'}],
                });
                continue; // Loop back for Gemini to process SQL result
              } catch (e) {
                contents.add({
                  'role': 'user',
                  'parts': [{'text': '[Function Result for execute_sql_query]: Error executing query: $e'}],
                });
                continue;
              }
            } else if (text.contains('CALL_FUNCTION:')) {
              contents.add({
                'role': 'user',
                'parts': [{'text': '[Function Error]: Invalid JSON or missing SELECT query. Please use exact format: CALL_FUNCTION:execute_sql_query|{"query": "SELECT ..."}'}],
              });
              continue; // Loop back for Gemini to fix its mistake
            }
          }

          // Return final processed text
          return text;
        }
      } on DioException catch (e) {
        lastError = 'DioException: ${e.response?.data ?? e.message}';
        continue;
      } catch (e) {
        lastError = e.toString();
        // If current model fails, try next model in fallback list
        continue;
      }
    }

    return null;
  }

  Future<String> _handleOfflineQuery(String command) async {
    final lower = command.toLowerCase();
    try {
      final db = await _dbService.rawDb;

      // 1. Students Query
      if (lower.contains('student') || lower.contains('enrol') || lower.contains('admission')) {
        final countRes = await db.rawQuery('SELECT COUNT(*) as total FROM students WHERE is_active = 1');
        final total = countRes.first['total'] as int? ?? 0;
        final classBreakdown = await db.rawQuery(
          'SELECT grade_level, COUNT(*) as count FROM students WHERE is_active = 1 GROUP BY grade_level ORDER BY grade_level'
        );
        final breakdownStr = classBreakdown.map((r) => '• ${r['grade_level'] ?? "Unassigned"}: ${r['count']} students').join('\n');
        return '📊 **Student Overview (Offline Mode)**\n\nTotal Active Students: **$total**\n\n**Class-wise Distribution:**\n$breakdownStr';
      }

      // 2. Fee / Dues Query
      if (lower.contains('fee') || lower.contains('due') || lower.contains('collect') || lower.contains('payment')) {
        final ledgerRes = await db.rawQuery('''
          SELECT 
            COALESCE(SUM(amount_due), 0) as total_due,
            COALESCE(SUM(amount_paid), 0) as total_paid,
            COALESCE(SUM(CASE WHEN status = 'overdue' THEN amount_due - amount_paid ELSE 0 END), 0) as overdue
          FROM student_fee_ledger
        ''');
        final due = ledgerRes.first['total_due'] as num? ?? 0;
        final paid = ledgerRes.first['total_paid'] as num? ?? 0;
        final overdue = ledgerRes.first['overdue'] as num? ?? 0;
        final pending = due - paid;
        return '💰 **Fee Analytics Summary (Offline Mode)**\n\n'
            '• Total Fees Generated: **₹${due.toStringAsFixed(2)}**\n'
            '• Total Fees Collected: **₹${paid.toStringAsFixed(2)}**\n'
            '• Total Outstanding Dues: **₹${pending.toStringAsFixed(2)}**\n'
            '• Overdue Balance: **₹${overdue.toStringAsFixed(2)}**';
      }

      // 3. Staff / Teacher Query
      if (lower.contains('staff') || lower.contains('teacher') || lower.contains('faculty') || lower.contains('employee')) {
        final staffCount = await db.rawQuery('SELECT COUNT(*) as total FROM staff WHERE is_active = 1');
        final total = staffCount.first['total'] as int? ?? 0;
        final roleBreakdown = await db.rawQuery(
          'SELECT role, COUNT(*) as count FROM staff WHERE is_active = 1 GROUP BY role'
        );
        final breakdownStr = roleBreakdown.map((r) => '• ${r['role']}: ${r['count']}').join('\n');
        return '👥 **Staff & Faculty Overview (Offline Mode)**\n\nTotal Active Staff: **$total**\n\n$breakdownStr';
      }

      // 4. Transport Query
      if (lower.contains('transport') || lower.contains('bus') || lower.contains('vehicle') || lower.contains('route')) {
        final vehCount = await db.rawQuery('SELECT COUNT(*) as total FROM vehicles WHERE is_active = 1');
        final routesCount = await db.rawQuery('SELECT COUNT(*) as total FROM routes');
        final totalV = vehCount.first['total'] as int? ?? 0;
        final totalR = routesCount.first['total'] as int? ?? 0;
        final vehList = await db.rawQuery('SELECT vehicle_number, vehicle_type, capacity FROM vehicles WHERE is_active = 1 LIMIT 5');
        final listStr = vehList.map((r) => '• ${r['vehicle_number']} (${r['vehicle_type']}, ${r['capacity']} seats)').join('\n');
        return '🚌 **Transport Fleet Overview (Offline Mode)**\n\n'
            '• Active Vehicles: **$totalV**\n'
            '• Configured Routes: **$totalR**\n\n'
            '${listStr.isNotEmpty ? "**Vehicles:**\n$listStr" : ""}';
      }

      // 5. Library Query
      if (lower.contains('book') || lower.contains('library') || lower.contains('issue')) {
        final bookCount = await db.rawQuery('SELECT COUNT(*) as total, COALESCE(SUM(total_copies), 0) as copies, COALESCE(SUM(available_copies), 0) as avail FROM books');
        final titles = bookCount.first['total'] as int? ?? 0;
        final copies = bookCount.first['copies'] as int? ?? 0;
        final avail = bookCount.first['avail'] as int? ?? 0;
        return '📚 **Library Catalog Summary (Offline Mode)**\n\n'
            '• Total Book Titles: **$titles**\n'
            '• Total Physical Copies: **$copies**\n'
            '• Available for Issue: **$avail**';
      }

      // 6. Exams Query
      if (lower.contains('exam') || lower.contains('test') || lower.contains('mark') || lower.contains('grade')) {
        final exams = await db.rawQuery('SELECT name, class, start_date, end_date FROM exams ORDER BY start_date DESC LIMIT 5');
        if (exams.isEmpty) {
          return '📝 **Examination Module (Offline Mode)**\n\nNo scheduled examinations found yet. You can create exams in the **Exams & Performance** tab.';
        }
        final listStr = exams.map((r) => '• **${r['name']}** (${r['class']}) - ${r['start_date']} to ${r['end_date']}').join('\n');
        return '📝 **Recent & Scheduled Exams (Offline Mode)**\n\n$listStr';
      }

      // Default smart assistance summary
      return '🤖 **Kishan Company AI Assistant (Offline Mode)**\n\n'
          'I am ready to help you manage your school. You can ask me about:\n'
          '• **Students & Admissions**: "How many students are enrolled?"\n'
          '• **Fees & Dues**: "Show fee dues summary"\n'
          '• **Staff & Teachers**: "How many teachers do we have?"\n'
          '• **Transport & Fleet**: "Show bus and route status"\n'
          '• **Library Books**: "Show library catalog summary"\n'
          '• **Exams & Tests**: "Show upcoming exams"';
    } catch (e) {
      return 'AI Assistant is running in offline mode. Type "help" or ask about students, fees, staff, transport, or library.';
    }
  }

  Future<String> _getSchema() async {
    try {
      final db = await _dbService.rawDb;
      final res = await db.rawQuery("SELECT sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
      return res
          .map((row) => (row['sql'] as String?) ?? '')
          .where((sql) => sql.isNotEmpty)
          .join('\n\n');
    } catch (e) {
      return 'Error retrieving schema: $e';
    }
  }
  
  Future<List<Map<String, dynamic>>> _executeSql(String query) async {
    final db = await _dbService.rawDb;
    return await db.rawQuery(query);
  }
}
