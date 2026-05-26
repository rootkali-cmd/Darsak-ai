import 'package:flutter/material.dart';
import '../core/ai_service.dart';
import '../core/theme.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final AiService _ai = AiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _ai.loadUsage();
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(
          text: '👋 مرحباً! أنا مساعد درسك AI.\n\nاسألني أي سؤال عن دراستك، '
              'المناهج التعليمية، أو أي موضوع يهمك. سأبحث وأحضر لك إجابة '
              'مفصلة مع المصادر.\n\n'
              '⚠️ لديك ${_ai.remaining} أسئلة متبقية اليوم',
          isUser: false,
        ));
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isSending = true;
    });
    _scrollDown();

    try {
      final answer = await _ai.ask(text);
      setState(() {
        _messages.add(_ChatMessage(text: answer, isUser: false));
        _messages.add(_ChatMessage(
          text: '💡 لديك ${_ai.remaining} أسئلة متبقية اليوم',
          isUser: false,
          isSmall: true,
        ));
        _isSending = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: e.toString().replaceFirst('Exception: ', ''),
          isUser: false,
          isError: true,
        ));
        _isSending = false;
      });
    }
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
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
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('مساعد درسك AI'),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_ai.remaining > 0 && _ai.remaining <= 2)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.warning.withValues(alpha: 0.1),
              child: Text(
                '⚠️ تبقى ${_ai.remaining} أسئلة فقط اليوم',
                style: const TextStyle(color: AppTheme.warning, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('حدث خطأ في التحميل', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                setState(() { _hasError = false; _isLoading = true; });
                                _init();
                              },
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_isSending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return _buildTypingIndicator();
                          }
                          return _buildMessage(_messages[index]);
                        },
                      ),
          ),
          if (_ai.remaining <= 0 && !_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1A1A1A),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, color: Colors.grey, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'انتهى حد الأسئلة لليوم، ارجع غداً',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessage(_ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        padding: EdgeInsets.all(msg.isSmall ? 8 : 14),
        decoration: BoxDecoration(
          color: msg.isError
              ? AppTheme.danger.withValues(alpha: 0.1)
              : msg.isUser
                  ? AppTheme.accent
                  : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: msg.isUser ? const Radius.circular(4) : const Radius.circular(16),
            bottomRight: msg.isUser ? const Radius.circular(16) : const Radius.circular(4),
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: msg.isUser
                ? Colors.white
                : msg.isError
                    ? AppTheme.danger
                    : msg.isSmall
                        ? Colors.grey
                        : const Color(0xFFF5F5F5),
            fontSize: msg.isSmall ? 11 : 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: const Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(0), _dot(1), _dot(2),
          ],
        ),
      ),
    );
  }

  Widget _dot(int i) {
    return AnimatedOpacity(
      opacity: _isSending ? 1.0 : 0.0,
      duration: Duration(milliseconds: 300 + i * 200),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 8, height: 8,
        decoration: const BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: const TextStyle(color: Color(0xFFF5F5F5), fontSize: 14),
                decoration: InputDecoration(
                  hintText: _ai.remaining > 0 ? 'اسأل أي سؤال...' : '',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color(0xFF141414),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isSending ? null : _send,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _isSending ? Colors.grey[800] : AppTheme.accent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  _isSending ? Icons.hourglass_top : Icons.send_rounded,
                  color: Colors.white, size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final bool isSmall;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.isSmall = false,
  });
}
