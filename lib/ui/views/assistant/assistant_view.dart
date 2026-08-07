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

  AssistantMessage({required this.text, required this.isUser});
}

class _AssistantViewState extends ConsumerState<AssistantView> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  final List<AssistantMessage> _messages = [
    AssistantMessage(
      text: 'Hello! I am your AI assistant. How can I help you manage your school today?',
      isUser: false,
    ),
  ];
  bool _isProcessing = false;

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

    final service = ref.read(assistantServiceProvider);
    final response = await service.handleCommand(text);

    setState(() {
      _messages.add(AssistantMessage(text: response, isUser: false));
      _isProcessing = false;
    });

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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome, color: AppTheme.primaryPurple, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'AI Assistant', 
              style: GoogleFonts.poppins(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ],
        ),
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
      "Help",
      "Check attendance",
      "Get students in Grade 10",
      "Find total fees collected",
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              "SUGGESTIONS",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: suggestions.map((text) => ActionChip(
              label: Text(text, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.primaryDark, fontWeight: FontWeight.w500)),
              backgroundColor: AppTheme.primarySoft,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 12, bottom: 4),
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppTheme.primaryPurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: isUser ? null : AppTheme.bgSurface,
                gradient: isUser ? const LinearGradient(
                  colors: [AppTheme.primaryLight, AppTheme.primaryPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ) : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(isUser ? 24 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? AppTheme.primaryPurple : Colors.black).withValues(alpha: isUser ? 0.25 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: GoogleFonts.poppins(
                  color: isUser ? Colors.white : AppTheme.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 44), // Balance out the avatar on the left
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 12, bottom: 4),
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppTheme.primaryPurple,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FadeTransition(
              opacity: _pulseAnimation,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryLight,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: AppTheme.bgMain,
        boxShadow: [
          BoxShadow(
            color: AppTheme.bgMain.withValues(alpha: 0.95),
            blurRadius: 24,
            spreadRadius: 12,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
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
                  maxLines: 5,
                  minLines: 1,
                  style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask your assistant anything...',
                    hintStyle: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryLight, AppTheme.primaryPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _isProcessing ? null : () => _sendMessage(),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white.withValues(alpha: _isProcessing ? 0.5 : 1.0),
                          size: 24,
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
