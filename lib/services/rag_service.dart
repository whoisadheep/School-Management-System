import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../providers/navigation_provider.dart';

/// Represents a discrete section of the Eduvia Knowledge Base.
class KnowledgeChunk {
  final String id;
  final String sourceFile;
  final String title;
  final String? section;
  final NavigationTab? navTab;
  final String content;
  final Set<String> keywords;

  const KnowledgeChunk({
    required this.id,
    required this.sourceFile,
    required this.title,
    this.section,
    this.navTab,
    required this.content,
    required this.keywords,
  });
}

/// Intent classified by the Query Controller.
enum AssistantIntent {
  greeting,
  navigation,
  knowledgeHowTo,
  databaseQuery,
}

/// Search result holding the ranked chunk and relevance score.
class RankedKnowledgeResult {
  final KnowledgeChunk chunk;
  final double score;

  const RankedKnowledgeResult({
    required this.chunk,
    required this.score,
  });
}

/// Advanced RAG Service for Eduvia School Management System.
///
/// Features:
/// 1. Query Control & Intent Routing (Greeting vs Nav vs How-To vs DB SQL)
/// 2. Query Transformation (Synonym expansion, terminology mapping, de-contextualization)
/// 3. Hybrid BM25-style Keyword & Heading Matching
/// 4. Re-Ranking & Score Calibration
/// 5. Strict Guardrail Filtering for Unsupported Features (00_capabilities_and_limitations.md)
/// 6. Deep-Link Navigation Resolution
class RagService {
  static final RagService _instance = RagService._internal();
  factory RagService() => _instance;
  RagService._internal();

  List<KnowledgeChunk>? _cachedChunks;
  bool _isLoading = false;

  static const List<String> _knowledgeFiles = [
    'assets/knowledge_base/00_capabilities_and_limitations.md',
    'assets/knowledge_base/01_navigation_and_roles.md',
    'assets/knowledge_base/02_classes_and_curriculum.md',
    'assets/knowledge_base/03_examinations_and_marks.md',
    'assets/knowledge_base/04_fee_collection_and_billing.md',
    'assets/knowledge_base/05_admissions_and_students.md',
    'assets/knowledge_base/06_staff_and_payroll.md',
    'assets/knowledge_base/07_student_attendance.md',
    'assets/knowledge_base/08_auxiliary_modules.md',
    'assets/knowledge_base/09_finance_and_expenses.md',
    'assets/knowledge_base/10_system_settings_and_license.md',
  ];

  /// Mapping from navigation tab keys to NavigationTab enum
  static final Map<String, NavigationTab> _tabKeyMap = {
    'dashboard': NavigationTab.dashboard,
    'feeCollection': NavigationTab.feeCollection,
    'feecollection': NavigationTab.feeCollection,
    'admission': NavigationTab.admission,
    'students': NavigationTab.students,
    'staff': NavigationTab.staff,
    'expenses': NavigationTab.expenses,
    'classes': NavigationTab.classes,
    'feeStructure': NavigationTab.feeStructure,
    'feestructure': NavigationTab.feeStructure,
    'feeReports': NavigationTab.feeReports,
    'feereports': NavigationTab.feeReports,
    'attendance': NavigationTab.attendance,
    'transport': NavigationTab.transport,
    'exams': NavigationTab.exams,
    'hostel': NavigationTab.hostel,
    'library': NavigationTab.library,
    'inventory': NavigationTab.inventory,
    'assistant': NavigationTab.assistant,
    'manageUsers': NavigationTab.manageUsers,
    'manageusers': NavigationTab.manageUsers,
    'activityLog': NavigationTab.activityLog,
    'activitylog': NavigationTab.activityLog,
    'settings': NavigationTab.settings,
  };

  /// Terminology expansion dictionary for Query Transformation
  static final Map<String, List<String>> _synonymDictionary = {
    'subject': ['curriculum', 'classes', 'assign subject', 'class_subject', 'exam'],
    'subjects': ['curriculum', 'classes', 'assign subject', 'class_subject', 'exam'],
    'curriculum': ['subjects', 'classes', 'class and section setup'],
    'roster': ['marks entry roster', 'marks', 'examinations', 'exam'],
    'rooster': ['marks entry roster', 'marks', 'examinations', 'exam'],
    'marks': ['marks entry roster', 'examinations', 'exam', 'grade', 'report card'],
    'grade': ['grade scale', 'report card', 'marks', 'percentage'],
    'admit card': ['report card', 'exam roll', 'examinations'],
    'hall ticket': ['report card', 'exam roll', 'examinations'],
    'scholarship': ['discount', 'concession', 'fee structure', 'student discount'],
    'concession': ['discount', 'scholarship', 'fee structure', 'student discount'],
    'discount': ['concession', 'scholarship', 'fee structure', 'student discount'],
    'bill': ['fee collection', 'invoicing', 'receipt', 'student fee ledger'],
    'invoice': ['fee collection', 'invoicing', 'receipt', 'student fee ledger', 'thermal'],
    'receipt': ['fee collection', 'thermal', '80mm', 'a4 invoice', 'print receipt'],
    'biometric': ['capabilities', 'limitations', 'not supported', 'attendance', 'fingerprint'],
    'fingerprint': ['capabilities', 'limitations', 'not supported', 'attendance', 'biometric'],
    'rfid': ['capabilities', 'limitations', 'not supported', 'attendance'],
    'sms': ['capabilities', 'limitations', 'not supported', 'whatsapp', 'notification'],
    'whatsapp': ['capabilities', 'limitations', 'not supported', 'sms', 'notification'],
    'mobile app': ['capabilities', 'limitations', 'not supported', 'parent app'],
    'online payment': ['capabilities', 'limitations', 'not supported', 'gateway', 'razorpay', 'stripe', 'card'],
    'gateway': ['capabilities', 'limitations', 'not supported', 'online payment'],
    'cloud sync': ['capabilities', 'limitations', 'not supported', 'backup', 'restore'],
    'branch': ['capabilities', 'limitations', 'not supported', 'multi-branch'],
    'bus': ['transport', 'route', 'stop', 'vehicle', 'driver'],
    'van': ['transport', 'vehicle', 'driver'],
    'driver': ['transport', 'vehicle', 'staff'],
    'bed': ['hostel', 'room', 'block', 'allocation'],
    'dorm': ['hostel', 'room', 'bed', 'dormitory'],
    'book': ['library', 'isbn', 'catalog', 'issue', 'return'],
    'borrow': ['library', 'issue book', 'due date'],
    'salary': ['staff', 'payroll', 'pay slip', 'allowance', 'deduction'],
    'payslip': ['staff', 'payroll', 'salary slip', 'earnings'],
    'pay slip': ['staff', 'payroll', 'salary slip'],
    'payroll': ['staff', 'salary', 'allowance', 'deduction', 'pay slip'],
    'absent': ['student attendance', 'daily attendance', 'leave'],
    'attendance': ['student attendance', 'monthly register', 'teacher attendance'],
    'computer': ['inventory', 'asset', 'equipment'],
    'desk': ['inventory', 'furniture', 'asset'],
    'asset': ['inventory', 'condition', 'vendor'],
    'backup': ['database backup', 'recovery', 'settings', 'sqlite'],
    'restore': ['database restore', 'recovery', 'settings'],
    'license': ['hardware id', 'hwid', 'activation', 'system settings'],
    'hwid': ['hardware id', 'license', 'activation'],
    'msvcp140': ['visual c++', 'redistributable', 'vc_redist', 'troubleshooting', 'dll'],
    'vc redist': ['visual c++', 'redistributable', 'vc_redist', 'msvcp140', 'dll'],
    'dll': ['msvcp140', 'vcruntime140', 'visual c++', 'troubleshooting'],
    'school name': ['system settings', 'branding', 'school identity', 'persist'],
  };

  /// Loads and chunks the knowledge base documents into memory.
  Future<List<KnowledgeChunk>> ensureLoaded() async {
    if (_cachedChunks != null && _cachedChunks!.isNotEmpty) {
      return _cachedChunks!;
    }

    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _cachedChunks ?? [];
    }

    _isLoading = true;
    final chunks = <KnowledgeChunk>[];

    for (final path in _knowledgeFiles) {
      try {
        final content = await rootBundle.loadString(path);
        final fileChunks = _parseMarkdownIntoChunks(path, content);
        chunks.addAll(fileChunks);
      } catch (e) {
        // Fallback or ignore unbundled asset in testing
      }
    }

    _cachedChunks = chunks;
    _isLoading = false;
    return chunks;
  }

  /// Splits Markdown files into discrete conceptual chunks by headings.
  List<KnowledgeChunk> _parseMarkdownIntoChunks(String filePath, String rawContent) {
    final chunks = <KnowledgeChunk>[];
    final filename = filePath.split('/').last;

    // Detect general tab from filename
    NavigationTab? fileDefaultTab;
    if (filename.contains('classes')) fileDefaultTab = NavigationTab.classes;
    if (filename.contains('examinations') || filename.contains('marks')) fileDefaultTab = NavigationTab.exams;
    if (filename.contains('fee_collection') || filename.contains('billing')) fileDefaultTab = NavigationTab.feeCollection;
    if (filename.contains('admissions') || filename.contains('students')) fileDefaultTab = NavigationTab.admission;
    if (filename.contains('staff') || filename.contains('payroll')) fileDefaultTab = NavigationTab.staff;
    if (filename.contains('attendance')) fileDefaultTab = NavigationTab.attendance;
    if (filename.contains('finance') || filename.contains('expenses')) fileDefaultTab = NavigationTab.expenses;
    if (filename.contains('settings') || filename.contains('license')) fileDefaultTab = NavigationTab.settings;

    final lines = rawContent.split('\n');
    String currentDocTitle = filename.replaceAll('.md', '').replaceAll('_', ' ');
    String currentSection = 'General Overview';
    final sectionBuffer = StringBuffer();

    for (final line in lines) {
      if (line.startsWith('# ') && !line.startsWith('## ')) {
        // Document master title
        currentDocTitle = line.substring(2).trim();
      } else if (line.startsWith('## ')) {
        // Section boundary: flush previous section
        if (sectionBuffer.length > 50) {
          final contentStr = sectionBuffer.toString().trim();
          final tab = _extractNavTab(contentStr) ?? fileDefaultTab;
          chunks.add(_buildChunk(
            filename: filename,
            title: currentDocTitle,
            section: currentSection,
            navTab: tab,
            content: contentStr,
          ));
          sectionBuffer.clear();
        }
        currentSection = line.substring(3).trim();
        sectionBuffer.writeln(line);
      } else {
        sectionBuffer.writeln(line);
      }
    }

    // Flush last section
    if (sectionBuffer.length > 50) {
      final contentStr = sectionBuffer.toString().trim();
      final tab = _extractNavTab(contentStr) ?? fileDefaultTab;
      chunks.add(_buildChunk(
        filename: filename,
        title: currentDocTitle,
        section: currentSection,
        navTab: tab,
        content: contentStr,
      ));
    }

    return chunks;
  }

  NavigationTab? _extractNavTab(String text) {
    final navMatch = RegExp(r'\[NAV:([a-zA-Z0-9_]+)\]').firstMatch(text);
    if (navMatch != null) {
      final key = navMatch.group(1);
      if (key != null && _tabKeyMap.containsKey(key)) {
        return _tabKeyMap[key];
      }
    }
    return null;
  }

  KnowledgeChunk _buildChunk({
    required String filename,
    required String title,
    required String section,
    NavigationTab? navTab,
    required String content,
  }) {
    final id = '$filename#${section.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}';
    final tokens = _tokenize('$title $section $content');

    return KnowledgeChunk(
      id: id,
      sourceFile: filename,
      title: title,
      section: section,
      navTab: navTab,
      content: content,
      keywords: tokens,
    );
  }

  // --------------------------------------------------------------------------
  // Pillar 1: Query Control & Intent Routing
  // --------------------------------------------------------------------------

  AssistantIntent classifyIntent(String query) {
    final q = query.trim().toLowerCase();

    // 1. Greetings / Conversational
    final greetings = [
      'hi', 'hy', 'hey', 'hello', 'namaste', 'good morning', 'good afternoon',
      'good evening', 'who are you', 'what can you do', 'help', 'commands'
    ];
    if (greetings.any((g) => q == g || q.startsWith('$g '))) {
      return AssistantIntent.greeting;
    }

    // 2. Direct Navigation Request
    final navTriggers = ['open ', 'go to ', 'take me to ', 'show screen ', 'navigate to '];
    if (navTriggers.any((t) => q.startsWith(t))) {
      return AssistantIntent.navigation;
    }

    // 3. Knowledge / How-To / Documentation / Capabilities Questions
    final howToTriggers = [
      'how to', 'how do i', 'how can i', 'where do i', 'where can i', 'where is',
      'can eduvia', 'does eduvia', 'is it possible', 'can i connect', 'can i do',
      'can we', 'what if', 'steps to', 'procedure', 'how does', 'explain how',
      'not found', 'error', 'failed', 'issue', 'unsupported', 'redist', 'msvcp140'
    ];
    if (howToTriggers.any((t) => q.contains(t))) {
      return AssistantIntent.knowledgeHowTo;
    }

    // 4. Quantitative / Database metrics questions
    final dbTriggers = [
      'how many', 'total count', 'list of', 'show me all', 'show unpaid',
      'how much fee', 'revenue', 'enrolled', 'breakdown'
    ];
    if (dbTriggers.any((t) => q.contains(t))) {
      return AssistantIntent.databaseQuery;
    }

    // Default to Knowledge How-To if ambiguous, so users get guidance
    return AssistantIntent.knowledgeHowTo;
  }

  // --------------------------------------------------------------------------
  // Pillar 2: Query Transformation
  // --------------------------------------------------------------------------

  String transformQuery(String originalQuery) {
    var expanded = originalQuery.toLowerCase();

    // Check synonym dictionary and append contextual terms
    final words = expanded.split(RegExp(r'\s+'));
    final appendedSynonyms = <String>{};

    for (final entry in _synonymDictionary.entries) {
      if (expanded.contains(entry.key)) {
        appendedSynonyms.addAll(entry.value);
      }
    }

    if (appendedSynonyms.isNotEmpty) {
      expanded = '$originalQuery (${appendedSynonyms.take(6).join(' ')})';
    }

    return expanded;
  }

  // --------------------------------------------------------------------------
  // Pillar 3 & 4: Hybrid BM25 Retrieval & Re-Ranking
  // --------------------------------------------------------------------------

  Future<List<RankedKnowledgeResult>> retrieveRelevantChunks({
    required String query,
    int topK = 2,
  }) async {
    final chunks = await ensureLoaded();
    if (chunks.isEmpty) return [];

    final transformedQuery = transformQuery(query);
    final queryTokens = _tokenize(transformedQuery);
    final rawTokens = _tokenize(query);

    final scoredList = <RankedKnowledgeResult>[];

    final isUnsupportedCheck = query.toLowerCase().contains('biometric') ||
        query.toLowerCase().contains('fingerprint') ||
        query.toLowerCase().contains('sms') ||
        query.toLowerCase().contains('whatsapp') ||
        query.toLowerCase().contains('online payment') ||
        query.toLowerCase().contains('gateway') ||
        query.toLowerCase().contains('mobile app') ||
        query.toLowerCase().contains('cloud sync');

    for (final chunk in chunks) {
      double score = 0.0;

      // 1. Heavy boost for capabilities matrix on unsupported queries
      if (isUnsupportedCheck && chunk.sourceFile.contains('00_capabilities')) {
        score += 25.0;
      }

      // 2. Title and Section match boost
      final sectionLower = (chunk.section ?? '').toLowerCase();
      final titleLower = chunk.title.toLowerCase();

      for (final qt in rawTokens) {
        if (sectionLower.contains(qt)) score += 4.0;
        if (titleLower.contains(qt)) score += 3.0;
      }

      // 3. BM25-style Keyword frequency score
      var matchedCount = 0;
      for (final qt in queryTokens) {
        if (chunk.keywords.contains(qt)) {
          matchedCount++;
          // Rare / longer tokens get higher IDF weight
          final idfWeight = math.log(1.0 + (100.0 / (qt.length > 4 ? 2.0 : 8.0)));
          score += (1.0 * idfWeight);
        }
      }

      // 4. Exact phrase matching bonus
      final contentLower = chunk.content.toLowerCase();
      if (contentLower.contains(query.toLowerCase().trim())) {
        score += 8.0;
      }

      if (score > 1.5) {
        scoredList.add(RankedKnowledgeResult(chunk: chunk, score: score));
      }
    }

    // Sort descending by score
    scoredList.sort((a, b) => b.score.compareTo(a.score));

    return scoredList.take(topK).toList();
  }

  // --------------------------------------------------------------------------
  // Pillar 5: Context Assembly with Strict Grounding Guardrails
  // --------------------------------------------------------------------------

  String buildPromptContext(List<RankedKnowledgeResult> results) {
    if (results.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('=== EDUVIA OFFICIAL KNOWLEDGE BASE CONTEXT ===');

    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      buffer.writeln('\n--- Source: ${r.chunk.sourceFile} (${r.chunk.section}) ---');
      buffer.writeln(r.chunk.content);
      if (r.chunk.navTab != null) {
        buffer.writeln('Associated Navigation Tab: [NAV:${r.chunk.navTab!.name}]');
      }
    }

    buffer.writeln('\n=== END CONTEXT ===');
    return buffer.toString();
  }

  /// Resolves the primary navigation tab suggested by the query or retrieved chunks.
  NavigationTab? resolveTargetTab(String query, [List<RankedKnowledgeResult>? results]) {
    final lower = query.toLowerCase();

    // Direct text triggers
    if (lower.contains('fee') || lower.contains('collect') || lower.contains('bill')) {
      return NavigationTab.feeCollection;
    }
    if (lower.contains('class') || lower.contains('subject') || lower.contains('curriculum')) {
      return NavigationTab.classes;
    }
    if (lower.contains('exam') || lower.contains('mark') || lower.contains('report card') || lower.contains('roster')) {
      return NavigationTab.exams;
    }
    if (lower.contains('admit') || lower.contains('admission') || lower.contains('new student')) {
      return NavigationTab.admission;
    }
    if (lower.contains('student') || lower.contains('directory')) {
      return NavigationTab.students;
    }
    if (lower.contains('staff') || lower.contains('salary') || lower.contains('payroll') || lower.contains('teacher')) {
      return NavigationTab.staff;
    }
    if (lower.contains('attendance') || lower.contains('present') || lower.contains('absent')) {
      return NavigationTab.attendance;
    }
    if (lower.contains('transport') || lower.contains('bus') || lower.contains('route')) {
      return NavigationTab.transport;
    }
    if (lower.contains('hostel') || lower.contains('room') || lower.contains('bed')) {
      return NavigationTab.hostel;
    }
    if (lower.contains('library') || lower.contains('book') || lower.contains('isbn')) {
      return NavigationTab.library;
    }
    if (lower.contains('inventory') || lower.contains('asset')) {
      return NavigationTab.inventory;
    }
    if (lower.contains('expense') || lower.contains('daybook') || lower.contains('ledger')) {
      return NavigationTab.expenses;
    }
    if (lower.contains('setting') || lower.contains('backup') || lower.contains('restore') || lower.contains('license')) {
      return NavigationTab.settings;
    }

    // Fallback to top retrieved chunk tab
    if (results != null && results.isNotEmpty) {
      return results.first.chunk.navTab;
    }

    return null;
  }

  Set<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toSet();
  }
}
