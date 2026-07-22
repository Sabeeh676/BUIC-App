import 'package:flutter/material.dart';
import 'package:buic_app/services/chatbot_service.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage>
    with TickerProviderStateMixin {
  final ChatbotService _chatbotService = ChatbotService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _serverOnline = false;
  bool _checkingServer = true;

  // Suggested starter questions
  final List<String> _suggestions = [
    'What is the attendance policy?',
    'How are GPA and CGPA calculated?',
    'What are the scholarship criteria?',
    'What is the repeat course policy?',
    'How to apply for a leave?',
    'What are the grading rules?',
  ];

  // BUIC theme colors
  static const Color _primaryTeal = Color(0xFF00695C);
  static const Color _lightBg = Color(0xFFF4F7F6);
  static const Color _userBubble = Color(0xFF00897B);
  static const Color _botBubble = Color(0xFFFFFFFF);
  static const Color _accentGold = Color(0xFFF9A825);

  @override
  void initState() {
    super.initState();
    _checkServer();
    _addBotMessage(
      '👋 Assalamu Alaikum! I\'m your **BU Handbook Assistant**.\n\n'
      'I\'m trained on the official Bahria University student handbook. '
      'Ask me anything about university policies, grading, attendance, scholarships, and more!',
    );
  }

  Future<void> _checkServer() async {
    final online = await _chatbotService.isServerReachable();
    if (mounted) {
      setState(() {
        _serverOnline = online;
        _checkingServer = false;
      });
      if (!online) {
        _addBotMessage(
          '⚠️ I\'m having trouble connecting to the server right now. '
          'Please make sure the BU Chatbot server is running and try again.',
        );
      }
    }
  }

  void _addBotMessage(String text, {List<String> sources = const []}) {
    setState(() {
      _messages.add(
          ChatMessage(text: text, isUser: false, sources: sources));
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();

    // Grab existing conversation history before adding new user message
    final history = _messages
        .where((m) =>
            !m.text.startsWith('👋 Assalamu Alaikum!') &&
            !m.text.startsWith('⚠️'))
        .toList();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();

    final response = await _chatbotService.sendMessage(text, history);

    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add(response);
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_checkingServer) _buildServerCheckBanner(),
          if (!_checkingServer && !_serverOnline) _buildOfflineBanner(),
          Expanded(child: _buildMessagesList()),
          if (_messages.length <= 2) _buildSuggestions(),
          _buildInputBar(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _primaryTeal,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('🎓', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BU Handbook Assistant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _serverOnline ? Colors.greenAccent : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _checkingServer
                        ? 'Connecting...'
                        : _serverOnline
                            ? 'Online'
                            : 'Offline',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
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
          icon: const Icon(Icons.delete_outline, color: Colors.white),
          tooltip: 'Clear Chat',
          onPressed: _clearChat,
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Reconnect',
          onPressed: () {
            setState(() => _checkingServer = true);
            _checkServer();
          },
        ),
      ],
    );
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _addBotMessage(
        '👋 Assalamu Alaikum! Conversation reset.\n\n'
        'Ask me anything about university policies, grading, attendance, scholarships, and more!',
      );
    });
  }

  Widget _buildServerCheckBanner() {
    return Container(
      color: Colors.orange.shade50,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          const Text('Connecting to BU Chatbot server...',
              style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      color: Colors.red.shade50,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Server offline — run the Python backend first',
              style: TextStyle(fontSize: 13, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isTyping && index == _messages.length) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _primaryTeal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('🎓', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? _userBubble : _botBubble,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF222222),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
                // Source context expandable
                if (!isUser && message.sources.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: GestureDetector(
                      onTap: () => _showSources(message.sources),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline,
                              size: 13, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Text(
                            'View handbook sources',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _primaryTeal,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('🎓', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _dot(0),
                const SizedBox(width: 4),
                _dot(150),
                const SizedBox(width: 4),
                _dot(300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      builder: (_, value, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: _primaryTeal.withOpacity(0.3 + 0.7 * value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      color: _lightBg,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              'Suggested questions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _sendMessage(_suggestions[index]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _primaryTeal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _primaryTeal.withOpacity(0.3)),
                    ),
                    child: Text(
                      _suggestions[index],
                      style: TextStyle(
                        fontSize: 12,
                        color: _primaryTeal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F3),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Ask about BU policies...',
                    hintStyle: TextStyle(
                        color: Colors.grey[400], fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                  ),
                  onSubmitted: _sendMessage,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _sendMessage(_controller.text),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primaryTeal,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryTeal.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSources(List<String> sources) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
              mainAxisAlignment: MainAxisAlignment.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.menu_book, color: _primaryTeal),
                const SizedBox(width: 8),
                const Text(
                  'Handbook Sources',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...sources.asMap().entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _primaryTeal.withOpacity(0.2)),
                ),
                child: Text(
                  entry.value,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}
