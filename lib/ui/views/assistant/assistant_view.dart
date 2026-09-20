import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../widgets/thinking_orb_widget.dart';
import 'widgets/assistant_message_content.dart';

class AssistantView extends ConsumerStatefulWidget {
  const AssistantView({super.key});

  @override
  ConsumerState<AssistantView> createState() => _AssistantViewState();
}

class AssistantMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  AssistantMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class _AssistantViewState extends ConsumerState<AssistantView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  final List<AssistantMessage> _messages = [
    AssistantMessage(
      text: '👋 Hello! I am your **Eduvia Support Agent**.\n\n'
          'I am here to help you navigate the software, guide you through tasks, and look up school information.\n\n'
          'How can I help you today?',
      isUser: false,
    ),
  ];
  bool _isProcessing = false;
  bool? _isAiOnline;
  OrbState _currentOrbState = OrbState.breathing;
  String _currentThinkingLabel = 'Thinking...';

  @override
  void initState() {
    super.initState();
    _verifyAiConnection();
  }

  Future<void> _verifyAiConnection() async {
    try {
      final service = ref.read(assistantServiceProvider);
      final result = await service.testConnection();
      if (mounted) {
        setState(() {
          _isAiOnline = result['success'] == true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAiOnline = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _controller.text).trim();
    if (text.isEmpty) return;

    OrbState orbState = OrbState.working;
    String thinkingLabel = 'Thinking...';
    final lower = text.toLowerCase();
    if (lower.contains('fee') ||
        lower.contains('paid') ||
        lower.contains('due') ||
        lower.contains('balance') ||
        lower.contains('calculate') ||
        lower.contains('sum') ||
        lower.contains('total') ||
        lower.contains('salary')) {
      orbState = OrbState.solving;
      thinkingLabel = 'Analyzing records & calculating metrics...';
    } else if (lower.contains('find') ||
        lower.contains('search') ||
        lower.contains('show') ||
        lower.contains('who') ||
        lower.contains('list') ||
        lower.contains('which') ||
        lower.contains('where')) {
      orbState = OrbState.searching;
      thinkingLabel = 'Searching school database...';
    } else if (lower.contains('write') ||
        lower.contains('compose') ||
        lower.contains('generate') ||
        lower.contains('draft') ||
        lower.contains('report')) {
      orbState = OrbState.composing;
      thinkingLabel = 'Composing response...';
    } else {
      orbState = OrbState.working;
      thinkingLabel = 'Consulting Eduvia Assistant...';
    }

    setState(() {
      _messages.add(AssistantMessage(text: text, isUser: true));
      _isProcessing = true;
      _currentOrbState = orbState;
      _currentThinkingLabel = thinkingLabel;
      if (presetText == null) _controller.clear();
    });
    
    _scrollToBottom();

    try {
      final service = ref.read(assistantServiceProvider);
      final response = await service.handleCommand(text);

      if (mounted) {
        setState(() {
          _messages.add(AssistantMessage(text: response, isUser: false));
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(AssistantMessage(text: 'Error generating response: $e', isUser: false));
          _isProcessing = false;
        });
      }
    }

    _scrollToBottom();
  }
  
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: EduviaThinkingOrb(
                size: 24,
                state: _isProcessing ? _currentOrbState : OrbState.breathing,
                showGlow: true,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Eduvia Support Agent', 
                  style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isAiOnline == true
                            ? const Color(0xFF10B981)
                            : (_isAiOnline == false ? Colors.amber.shade700 : Colors.blueGrey),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isAiOnline == true
                          ? 'Support Agent • Online'
                          : (_isAiOnline == false ? 'Support Agent • Offline Mode' : 'Connecting...'),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _isAiOnline == true
                            ? const Color(0xFF059669)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: const [
          SizedBox(width: 16),
        ],
        backgroundColor: AppTheme.bgMain,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(
                  left: AppTheme.spacingMd,
                  right: AppTheme.spacingMd,
                  top: AppTheme.spacingMd,
                  bottom: AppTheme.spacingXl,
                ),
                itemCount: _messages.length + (_isProcessing ? 1 : 0) + ( _messages.length == 1 ? 1 : 0),
                itemBuilder: (context, index) {
                  // Show suggestions after the first message
                  if (_messages.length == 1 && index == 1) {
                    return _buildSuggestions();
                  }
                  
                  // Adjust index if suggestions are shown
                  final messageIndex = (_messages.length == 1 && index > 1) ? index - 1 : index;
                  
                  if (messageIndex == _messages.length && _isProcessing) {
                    return _buildTypingIndicator();
                  }
                  
                  final message = _messages[messageIndex];
                  return _buildMessageBubble(message);
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = [
      "Show total students enrolled",
      "How much fee is collected and overdue?",
      "Show list of teachers and staff",
      "Show school bus fleet and routes",
      "Which books are available in library?",
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 24),
              child: Column(
                children: [
                  const EduviaThinkingOrb(
                    size: 64,
                    state: OrbState.breathing,
                    showGlow: true,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Eduvia Intelligence Ready',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ask anything about students, staff, fee collection, attendance, or schedules',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              "POPULAR QUERIES",
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((text) => ActionChip(
              avatar: const Icon(Icons.auto_awesome, size: 14, color: AppTheme.primaryPurple),
              label: Text(text, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primaryDark, fontWeight: FontWeight.w500)),
              backgroundColor: AppTheme.primarySoft,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              onPressed: () => _sendMessage(text),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AssistantMessage message) {
    final isUser = message.isUser;
    
    // Parse deep-link navigation tag if present (e.g. [NAV:classes])
    NavigationTab? navTab;
    String displayText = message.text;
    final navMatch = RegExp(r'\[NAV:([a-zA-Z0-9_]+)\]').firstMatch(displayText);
    if (navMatch != null) {
      final key = navMatch.group(1);
      if (key != null) {
        try {
          navTab = NavigationTab.values.firstWhere(
            (t) => t.name.toLowerCase() == key.toLowerCase(),
          );
        } catch (_) {}
      }
      displayText = displayText.replaceAll(navMatch.group(0)!, '').trim();
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 10, top: 2),
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppTheme.primaryPurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isUser ? null : AppTheme.bgSurface,
                gradient: isUser ? const LinearGradient(
                  colors: [AppTheme.primaryLight, AppTheme.primaryPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ) : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? AppTheme.primaryPurple : Colors.black).withValues(alpha: isUser ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FormattedAssistantMessageContent(
                    text: displayText,
                    isUser: isUser,
                  ),
                  if (navTab != null && !isUser) ...[
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          ref.read(selectedTabProvider.notifier).state = navTab!;
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.open_in_new_rounded, size: 16, color: AppTheme.primaryPurple),
                              const SizedBox(width: 8),
                              Text(
                                'Open ${navTab.title}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryPurple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: AppTheme.primarySoft,
              shape: BoxShape.circle,
            ),
            child: EduviaThinkingOrb(
              state: _currentOrbState,
              size: 28,
              showGlow: false,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                EduviaThinkingOrb(
                  state: _currentOrbState,
                  size: 18,
                  showGlow: false,
                ),
                const SizedBox(width: 10),
                Text(
                  _currentThinkingLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: AppTheme.bgMain,
        boxShadow: [
          BoxShadow(
            color: AppTheme.bgMain.withValues(alpha: 0.95),
            blurRadius: 20,
            spreadRadius: 8,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: AppTheme.primarySoft.withValues(alpha: 0.8), width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                  maxLines: 4,
                  minLines: 1,
                  style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask anything about students, fees, teachers, transport...',
                    hintStyle: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryLight, AppTheme.primaryPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _isProcessing ? null : () => _sendMessage(),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white.withValues(alpha: _isProcessing ? 0.5 : 1.0),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
