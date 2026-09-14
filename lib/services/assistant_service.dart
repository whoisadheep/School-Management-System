import 'package:dio/dio.dart';
import 'ai_provider_service.dart';
import 'database_service.dart';
import 'rag_service.dart';
import '../providers/navigation_provider.dart';

class AssistantService {
  final DatabaseService _dbService;
  late final AiProviderService _aiProvider;
  final RagService _rag = RagService();
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

  /// Handles user questions using the Advanced RAG & Multi-Provider Architecture:
  /// 1. Query Routing (Greeting vs Navigation vs How-To Knowledge vs Database Query)
  /// 2. Advanced RAG Knowledge Base Retrieval (BM25 + Hybrid Re-Ranking)
  /// 3. Strict Multi-Provider Cascade: OpenRouter -> Groq -> Gemini
  /// 4. Built-in Offline Engine Fallback (Offline Knowledge formatting + SQLite metrics)
  Future<String> handleCommand(String command) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty) {
      return 'Please type a question or type "help" for examples.';
    }

    final intent = _rag.classifyIntent(trimmed);

    // 1. Intent: Greeting
    if (intent == AssistantIntent.greeting) {
      return '👋 **Hello! Welcome to Eduvia AI Assistant**\n\n'
          'I am your intelligent school assistant with access to both software guidance and your school database.\n\n'
          'You can ask me:\n'
          '• 📖 **Software Help**: *"How do I assign subjects to Class 1?"* or *"Where do I enter exam marks?"*\n'
          '• 💳 **Fee Collection**: *"How do I collect fee by admission number?"* or *"Can I connect online card payment?"*\n'
          '• 📊 **Live Database Metrics**: *"How many students are enrolled?"* or *"Show fee dues summary"*\n'
          '• 🚀 **Direct Navigation**: *"Take me to Class Setup"* or *"Open fee collection"*\n\n'
          'How can I assist you today?';
    }

    // 2. Intent: Direct Navigation Command
    if (intent == AssistantIntent.navigation) {
      final tab = _rag.resolveTargetTab(trimmed);
      if (tab != null) {
        return 'Navigating you to **${tab.title}**...\n\n[NAV:${tab.name}]';
      }
    }

    // 3. Intent: Knowledge, How-To, or Capabilities Query (RAG Pipeline)
    if (intent == AssistantIntent.knowledgeHowTo) {
      return await _handleKnowledgeQuery(trimmed);
    }

    // 4. Intent: Database / Metrics Query (SQL Execution Cascade)
    try {
      final schema = await _getSchema();
      final aiResult = await _aiProvider.executeSqlAssistantLoop(
        userQuestion: trimmed,
        schema: schema,
        executeSql: _executeSql,
      );
      if (aiResult != null && aiResult.text.trim().isNotEmpty) {
        return aiResult.text.trim();
      }
    } catch (_) {}

    // Fallback to knowledge search if SQL loop didn't produce an answer
    final knowledgeFallback = await _handleKnowledgeQuery(trimmed, isFallback: true);
    if (knowledgeFallback.isNotEmpty) {
      return knowledgeFallback;
    }

    // Stage 4: Built-in local offline smart query engine
    return await _handleOfflineQuery(trimmed);
  }

  /// Processes how-to and capability questions using the Advanced RAG pipeline
  Future<String> _handleKnowledgeQuery(String command, {bool isFallback = false}) async {
    try {
      final rankedResults = await _rag.retrieveRelevantChunks(query: command, topK: 2);
      if (rankedResults.isEmpty) {
        if (isFallback) return '';
        return 'I could not find a specific guide for that in the Eduvia documentation. Please check the sidebar menu or contact support.';
      }

      final contextText = _rag.buildPromptContext(rankedResults);
      final targetTab = _rag.resolveTargetTab(command, rankedResults);

      final systemInstruction = '''You are the expert Copilot for Eduvia School Management System.
Your job is to provide clear, friendly, and beautifully structured guidance to school staff (teachers, accountants, administrators).

CRITICAL INSTRUCTIONS & FORMATTING RULES:
1. Base your answer EXCLUSIVELY on the provided Eduvia Knowledge Base context.
2. Structure your response with clean visual hierarchy:
   - Start with a direct, friendly 1-sentence summary or lead-in.
   - For procedures, provide a numbered step-by-step guide (1., 2., 3.).
   - Highlight key screens, buttons, and fields in **bold** (e.g. **Student Admission Wizard**, click **Complete Admission**).
   - If a step has multiple sub-items or form fields, list them with indented bullet points (   - **Item**).
   - If relevant, include a helpful tip at the end starting with "💡 Tip: ...".
3. If the user asks about an UNSUPPORTED feature (e.g. Biometric/RFID hardware sync, online payment gateways, automated SMS/WhatsApp, parent mobile app, cloud multi-branch sync), politely state that Eduvia does not currently support this feature and provide the recommended manual alternative mentioned in the context.
4. Do NOT invent fictional menus, external plugins, or settings that do not exist.
5. If a relevant screen is identified, ensure the navigation tag [NAV:${targetTab?.name ?? "dashboard"}] is included at the very end of your response.

$contextText''';

      // Run generation across multi-provider cascade (OpenRouter -> Groq -> Gemini)
      final aiResult = await _aiProvider.generateText(
        prompt: command,
        systemInstruction: systemInstruction,
        temperature: 0.2,
      );

      if (aiResult != null && aiResult.text.trim().isNotEmpty) {
        var text = aiResult.text.trim();
        // Ensure the navigation tag is present if we identified a target tab
        if (targetTab != null && !text.contains('[NAV:')) {
          text = '$text\n\n[NAV:${targetTab.name}]';
        }
        return text;
      }

      // Offline Fallback for RAG: Format directly from retrieved chunk
      final bestChunk = rankedResults.first.chunk;
      final buffer = StringBuffer();
      buffer.writeln('📖 **Eduvia Guide: ${bestChunk.title}**\n');
      if (bestChunk.section != null && bestChunk.section != 'General Overview') {
        buffer.writeln('### ${bestChunk.section}\n');
      }
      buffer.writeln(bestChunk.content);
      if (targetTab != null) {
        buffer.writeln('\n\n[NAV:${targetTab.name}]');
      }
      return buffer.toString();
    } catch (e) {
      if (isFallback) return '';
      return 'An error occurred while searching the knowledge base: $e';
    }
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
