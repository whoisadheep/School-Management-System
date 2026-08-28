import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/services_provider.dart';

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

class _AssistantViewState extends ConsumerState<AssistantView> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  final List<AssistantMessage> _messages = [
    AssistantMessage(
      text: '👋 Hello! I am your **Kishan Company AI Assistant**.\n\n'
          'I am connected directly to your school database and Google Gemini AI. '
          'You can ask me about students, fees, pending balances, teachers, attendance, transport routes, and exams!',
      isUser: false,
    ),
  ];
  bool _isProcessing = false;
  bool? _isAiOnline;
  String _activeModel = 'gemini-flash-latest';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _verifyAiConnection();
  }

  Future<void> _verifyAiConnection() async {
    try {
      final service = ref.read(assistantServiceProvider);
      final result = await service.testConnection();
      if (mounted) {
        setState(() {
          _isAiOnline = result['success'] == true;
          if (result['model'] != null) {
            _activeModel = result['model'].toString();
          }
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
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _controller.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(AssistantMessage(text: text, isUser: true));
      _isProcessing = true;
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

  void _showAiSettingsDialog() async {
    final service = ref.read(assistantServiceProvider);
    final currentKey = await service.getActiveApiKey();
    final keyController = TextEditingController(text: currentKey);
    bool testing = false;
    String? testResultMsg;
    bool? testSuccess;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology, color: AppTheme.primaryPurple, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'AI Engine & API Key',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Google Gemini API Key',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: keyController,
                    obscureText: true,
                    style: GoogleFonts.sourceCodePro(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter your Gemini API key (AQ... or AIza...)',
                      filled: true,
                      fillColor: AppTheme.bgSurface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.divider),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste_rounded, size: 18),
                        tooltip: 'Paste from clipboard',
                        onPressed: () {},
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (testResultMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: testSuccess == true
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: testSuccess == true ? Colors.green : Colors.redAccent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            testSuccess == true ? Icons.check_circle : Icons.error_outline,
                            color: testSuccess == true ? Colors.green : Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              testResultMsg!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: testSuccess == true ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: testing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.network_ping, size: 16),
                        label: Text(testing ? 'Testing...' : 'Test Connection'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryPurple,
                          side: const BorderSide(color: AppTheme.primaryPurple),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: testing
                            ? null
                            : () async {
                                setDialogState(() {
                                  testing = true;
                                  testResultMsg = null;
                                });
                                final res = await service.testConnection(keyController.text.trim());
                                setDialogState(() {
                                  testing = false;
                                  testSuccess = res['success'] == true;
                                  testResultMsg = res['success'] == true
                                      ? 'Connected to ${res['model']} (${res['latencyMs']}ms)'
                                      : 'Failed: ${res['error']}';
                                });
                              },
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final key = keyController.text.trim();
                          await service.setApiKey(key);
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          _verifyAiConnection();
                        },
                        child: const Text('Save & Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome, color: AppTheme.primaryPurple, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Assistant', 
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
                          ? 'Google Gemini Online (${_activeModel.replaceAll("gemini-", "")})'
                          : (_isAiOnline == false ? 'Built-in DB Engine (Offline)' : 'Checking status...'),
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
        actions: [
          IconButton(
            tooltip: 'Configure AI Key & Engine',
            icon: const Icon(Icons.tune_rounded, color: AppTheme.textPrimary),
            onPressed: _showAiSettingsDialog,
          ),
          const SizedBox(width: 12),
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
              child: SelectableText(
                message.text,
                style: GoogleFonts.poppins(
                  color: isUser ? Colors.white : AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
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
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppTheme.primaryPurple,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
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
                FadeTransition(
                  opacity: _pulseAnimation,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryLight,
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Thinking...',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
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
