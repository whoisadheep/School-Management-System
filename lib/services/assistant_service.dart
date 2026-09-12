import 'package:dio/dio.dart';
import 'ai_provider_service.dart';
import 'database_service.dart';

class AssistantService {
  final DatabaseService _dbService;
  late final AiProviderService _aiProvider;
  final Dio _http = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 25),
  ));

  static String get defaultGeminiKey => AiProviderService.defaultGeminiKey;
  static String get defaultOpenRouterKey => AiProviderService.defaultOpenRouterKey;
  static String get defaultGroqKey => AiProviderService.defaultGroqKey;

  AssistantService(this._dbService) {
    _aiProvider = AiProviderService(_dbService);
  }

  /// Handles user questions using the strict fallback cascade:
  /// 1. OpenRouter (Llama 3.3 70B)
  /// 2. Groq (Qwen 3.8 27B)
  /// 3. Google Gemini (Gemini Flash)
  /// 4. Built-in Local SQLite Offline Engine
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
      return '👋 **Hello! Welcome to Eduvia AI Assistant**\n\n'
          'I am your intelligent school assistant with direct access to your database. You can ask me:\n\n'
          '• 📊 **Students**: *"How many students are enrolled?"* or *"Show class breakdown"*\n'
          '• 💰 **Fees & Dues**: *"Show fee collection summary"* or *"What are overdue balances?"*\n'
          '• 👥 **Staff & Teachers**: *"Show faculty details"* or *"How many staff members?"*\n'
          '• 🚌 **Transport**: *"Show bus fleet and routes"*\n'
          '• 📚 **Library**: *"Show available books"*\n'
          '• 📝 **Exams**: *"Show scheduled exams"*\n\n'
          'How can I help you today?';
    }

    // 1. Strict Multi-Provider Cascade: OpenRouter -> Groq -> Gemini
    try {
      final schema = await _getSchema();
      final aiResult = await _aiProvider.executeSqlAssistantLoop(
        userQuestion: command,
        schema: schema,
        executeSql: _executeSql,
      );
      if (aiResult != null && aiResult.text.trim().isNotEmpty) {
        return aiResult.text.trim();
      }
    } catch (_) {
      // If remote providers fail, fall through to offline engine
    }

    // 2. Stage 4: Built-in local offline smart query engine
    return await _handleOfflineQuery(command);
  }

  Future<String> getActiveApiKey() => _aiProvider.getGeminiKey();
  Future<String> getOpenRouterKey() => _aiProvider.getOpenRouterKey();
  Future<String> getGroqKey() => _aiProvider.getGroqKey();

  Future<bool> setApiKey(String key) => _aiProvider.setProviderKey('gemini_api_key', key);
  Future<bool> setOpenRouterKey(String key) => _aiProvider.setProviderKey('openrouter_api_key', key);
  Future<bool> setGroqKey(String key) => _aiProvider.setProviderKey('groq_api_key', key);

  Future<Map<String, dynamic>> testConnection([String? testKey]) async {
    // If a specific test key was passed in (e.g. from the settings dialog)
    if (testKey != null && testKey.trim().isNotEmpty) {
      final key = testKey.trim();
      if (key.startsWith('sk-or-')) {
        return _testOpenRouterDirect(key);
      } else if (key.startsWith('gsk_')) {
        return _testGroqDirect(key);
      } else {
        return _testGeminiDirect(key);
      }
    }

    // Default: test through the multi-provider cascade
    final stopwatch = Stopwatch()..start();
    final result = await _aiProvider.generateText(
      prompt: 'Hello! Respond with: Connected to Eduvia AI.',
      maxTokens: 50,
    );
    stopwatch.stop();

    if (result != null) {
      return {
        'success': true,
        'provider': result.provider,
        'model': '${result.provider} (${result.model})',
        'latencyMs': result.latencyMs,
      };
    }

    return {'success': false, 'error': 'All AI providers unreachable. Operating in offline mode.'};
  }

  Future<Map<String, dynamic>> _testOpenRouterDirect(String apiKey) async {
    try {
      final sw = Stopwatch()..start();
      final res = await _http.post(
        'https://openrouter.ai/api/v1/chat/completions',
        data: {
          'model': 'meta-llama/llama-3.3-70b-instruct',
          'messages': [{'role': 'user', 'content': 'hi'}],
          'max_tokens': 10,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://eduvia.school',
          'X-Title': 'Eduvia School Management System',
        }),
      );
      sw.stop();
      if (res.statusCode == 200) {
        return {
          'success': true,
          'provider': 'OpenRouter',
          'model': 'Llama 3.3 70B',
          'latencyMs': sw.elapsedMilliseconds,
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'OpenRouter test failed: $e'};
    }
    return {'success': false, 'error': 'Unable to reach OpenRouter.'};
  }

  Future<Map<String, dynamic>> _testGroqDirect(String apiKey) async {
    try {
      final sw = Stopwatch()..start();
      final res = await _http.post(
        'https://api.groq.com/openai/v1/chat/completions',
        data: {
          'model': 'qwen/qwen3.8-27b',
          'messages': [{'role': 'user', 'content': 'hi'}],
          'max_tokens': 10,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        }),
      );
      sw.stop();
      if (res.statusCode == 200) {
        return {
          'success': true,
          'provider': 'Groq',
          'model': 'Qwen 3.8 27B',
          'latencyMs': sw.elapsedMilliseconds,
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Groq test failed: $e'};
    }
    return {'success': false, 'error': 'Unable to reach Groq.'};
  }

  Future<Map<String, dynamic>> _testGeminiDirect(String apiKey) async {
    final models = ['gemini-flash-latest', 'gemini-flash-lite-latest'];
    for (final model in models) {
      try {
        final stopwatch = Stopwatch()..start();
        final url =
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';
        final body = {
          'contents': [
            {
              'role': 'user',
              'parts': [{'text': 'Hello! Respond with: Connected to Eduvia AI.'}],
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
            'provider': 'Gemini',
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
      return '🤖 **Eduvia AI Assistant (Offline Mode)**\n\n'
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
