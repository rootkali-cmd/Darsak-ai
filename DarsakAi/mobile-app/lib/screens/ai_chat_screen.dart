import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/ai_service.dart';
import '../core/theme.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> with TickerProviderStateMixin {
  final AiService _ai = AiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _hasError = false;
  static const String _storageKey = 'ai_chat_messages';
  late AnimationController _thinkingAnimCtrl;
  late Animation<double> _thinkingAnim;

  @override
  void initState() {
    super.initState();
    _thinkingAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _thinkingAnim = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: _thinkingAnimCtrl, curve: Curves.easeInOut),
    );
    _init();
  }

  Future<void> _init() async {
    try {
      await _ai.loadUsage();
      await _loadMessages();
      if (_messages.isEmpty) {
        _messages.add(_ChatMessage(
          text: 'مرحباً! أنا مساعد درسك AI.\n\nاسألني أي سؤال عن دراستك، '
              'المناهج التعليمية، أو أي موضوع يهمك.',
          isUser: false,
        ));
      }
      setState(() => _isLoading = false);
    } catch (_) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final List<dynamic> decoded = jsonDecode(raw);
        _messages.clear();
        for (final item in decoded) {
          _messages.add(_ChatMessage(
            text: item['text'] ?? '',
            isUser: item['isUser'] ?? false,
            isError: item['isError'] ?? false,
            isSmall: item['isSmall'] ?? false,
          ));
        }
      }
    } catch (_) {}
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_messages.map((m) => {
        'text': m.text,
        'isUser': m.isUser,
        'isError': m.isError,
        'isSmall': m.isSmall,
      }).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isSending = true;
    });
    _saveMessages();
    _scrollDown();

    try {
      final history = _messages
          .where((m) => !m.isSmall && !m.isError)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();
      history.removeLast();

      final answer = await _ai.ask(text, history: history);
      setState(() {
        _messages.add(_ChatMessage(text: answer, isUser: false));
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
    _saveMessages();
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
    _thinkingAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مساعد درسك AI'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
            onPressed: _messages.isEmpty ? null : _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('حدث خطأ في التحميل', style: TextStyle(color: AppColors.textSecondary(context))),
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
                            return _buildThinkingIndicator();
                          }
                          return _buildMessage(_messages[index], index);
                        },
                      ),
          ),
          if (false)
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.surfaceHigher(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block, color: Colors.grey, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'انتهى حد الأسئلة لليوم، ارجع غداً',
                    style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
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

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.dialogBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('مسح المحادثة', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Text('هل تريد مسح جميع الرسائل؟', style: TextStyle(color: AppColors.textSecondary(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
                _messages.add(_ChatMessage(
                  text: 'مرحباً! أنا مساعد درسك AI.\n\nاسألني أي سؤال عن دراستك.',
                  isUser: false,
                ));
              });
              _saveMessages();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(_ChatMessage msg, int index) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: ValueKey('msg_$index'),
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        padding: EdgeInsets.all(msg.isSmall ? 8 : 14),
        decoration: BoxDecoration(
          color: msg.isError
              ? AppTheme.danger.withValues(alpha: 0.1)
              : msg.isUser
                  ? AppTheme.accent
                  : AppColors.surfaceHigher(context),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: msg.isUser ? const Radius.circular(4) : const Radius.circular(16),
            bottomRight: msg.isUser ? const Radius.circular(16) : const Radius.circular(4),
          ),
        ),
        child: msg.isUser || msg.isSmall || msg.isError
            ? Text(
                msg.text,
                style: TextStyle(
                  color: msg.isUser
                      ? Colors.white
                      : msg.isError
                          ? AppTheme.danger
                          : msg.isSmall
                              ? AppColors.textSecondary(context)
                              : AppColors.textPrimary(context),
                  fontSize: msg.isSmall ? 11 : 14,
                  height: 1.5,
                ),
              )
            : _buildFormattedText(msg.text),
      ),
    );
  }

  Widget _buildFormattedText(String text) {
    final segments = _parseThinkingAndQuiz(text);
    return RichText(
      textDirection: TextDirection.rtl,
      text: TextSpan(
        children: segments,
        style: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: AppColors.textPrimary(context),
        ),
      ),
    );
  }

  List<TextSpan> _parseThinkingAndQuiz(String text) {
    final List<TextSpan> spans = [];
    final thinkingRegex = RegExp(r'🤔 تفكير:.*(?:\n|$)', multiLine: true);
    final quizRegex = RegExp(r'📝 كويز:.*(?:\n|$)', multiLine: true);

    int lastEnd = 0;

    final matches = <_SegmentMatch>[];
    for (final m in thinkingRegex.allMatches(text)) {
      matches.add(_SegmentMatch(m.start, m.end, true));
    }
    for (final m in quizRegex.allMatches(text)) {
      matches.add(_SegmentMatch(m.start, m.end, false, isQuiz: true));
    }
    matches.sort((a, b) => a.start.compareTo(b.start));

    for (final seg in matches) {
      if (seg.start > lastEnd) {
        spans.addAll(_parseMarkdown(text.substring(lastEnd, seg.start)));
      }
      if (seg.isThinking) {
        final lineEnd = text.indexOf('\n', seg.start);
        final endIdx = lineEnd > 0 ? lineEnd + 1 : text.length;
        spans.add(TextSpan(
          text: '\n${text.substring(seg.start, endIdx).trim()}\n\n',
          style: const TextStyle(
            color: Color(0xFFA0A0C0),
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ));
        lastEnd = endIdx;
      } else {
        final lineEnd = text.indexOf('\n', seg.start);
        final endIdx = lineEnd > 0 ? lineEnd + 1 : text.length;
        spans.add(TextSpan(
          text: '\n${text.substring(seg.start, endIdx).trim()}\n\n',
          style: const TextStyle(
            color: Color(0xFF818cf8),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ));
        lastEnd = endIdx;
      }
    }

    if (lastEnd < text.length) {
      spans.addAll(_parseMarkdown(text.substring(lastEnd)));
    }

    return spans;
  }

  List<TextSpan> _parseMarkdown(String text) {
    final List<TextSpan> spans = [];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.startsWith('### ')) {
        spans.add(TextSpan(
          text: '${line.substring(4)}\n',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF818cf8)),
        ));
      } else if (line.startsWith('## ')) {
        spans.add(TextSpan(
          text: '${line.substring(3)}\n',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF818cf8)),
        ));
      } else if (line.startsWith('# ')) {
        spans.add(TextSpan(
          text: '${line.substring(2)}\n',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF818cf8)),
        ));
      } else if (line.startsWith('- ') || line.startsWith('• ')) {
        spans.add(const TextSpan(text: '  •  '));
        spans.addAll(_parseInline(line.substring(2)));
        spans.add(const TextSpan(text: '\n'));
      } else if (RegExp(r'^\d+[\.\)]\s').hasMatch(line)) {
        final match = RegExp(r'^(\d+[\.\)])\s(.+)').firstMatch(line);
        if (match != null) {
          spans.add(TextSpan(
            text: '  ${match.group(1)} ',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF818cf8)),
          ));
          spans.addAll(_parseInline(match.group(2)!));
          spans.add(const TextSpan(text: '\n'));
        } else {
          spans.addAll(_parseInline(line));
          if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
        }
      } else {
        spans.addAll(_parseInline(line));
        if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
      }
    }

    return spans;
  }

  List<TextSpan> _parseInline(String text) {
    final List<TextSpan> spans = [];
    final boldRegex = RegExp(r'\*\*(.+?)\*\*');
    final italicRegex = RegExp(r'\*(.+?)\*');
    final codeRegex = RegExp(r'`(.+?)`');

    int lastEnd = 0;
    final allMatches = <_InlineMatch>[];

    for (final m in boldRegex.allMatches(text)) {
      allMatches.add(_InlineMatch(m.start, m.end, m.group(1)!, _InlineType.bold));
    }
    for (final m in italicRegex.allMatches(text)) {
      if (!allMatches.any((a) => a.start <= m.start && a.end >= m.end)) {
        allMatches.add(_InlineMatch(m.start, m.end, m.group(1)!, _InlineType.italic));
      }
    }
    for (final m in codeRegex.allMatches(text)) {
      allMatches.add(_InlineMatch(m.start, m.end, m.group(1)!, _InlineType.code));
    }

    allMatches.sort((a, b) => a.start.compareTo(b.start));

    for (final match in allMatches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      switch (match.type) {
        case _InlineType.bold:
          spans.add(TextSpan(text: match.content, style: const TextStyle(fontWeight: FontWeight.bold)));
          break;
        case _InlineType.italic:
          spans.add(TextSpan(text: match.content, style: const TextStyle(fontStyle: FontStyle.italic)));
          break;
        case _InlineType.code:
          spans.add(TextSpan(
            text: match.content,
            style: TextStyle(
              backgroundColor: AppColors.surfaceHigher(context).withValues(alpha: 0.5),
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ));
          break;
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return spans;
  }

  Widget _buildThinkingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigher(context),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: const Radius.circular(4),
          ),
          border: Border.all(
            color: const Color(0xFFA0A0C0).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _thinkingAnim,
              builder: (_, child) => Opacity(
                opacity: _thinkingAnim.value,
                child: child,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🧠', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Text(
                    'تفكير...',
                    style: TextStyle(
                      color: Color(0xFFA0A0C0),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        border: Border(top: BorderSide(color: AppColors.border(context))),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.newline,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
                decoration: InputDecoration(
                  hintText: _ai.remaining > 0 ? 'اسأل أي سؤال...' : '',
                  hintStyle: TextStyle(color: AppColors.textSecondary(context)),
                  filled: true,
                  fillColor: AppColors.inputFill(context),
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

enum _InlineType { bold, italic, code }

class _InlineMatch {
  final int start;
  final int end;
  final String content;
  final _InlineType type;

  _InlineMatch(this.start, this.end, this.content, this.type);
}

class _SegmentMatch {
  final int start;
  final int end;
  final bool isThinking;
  final bool isQuiz;

  _SegmentMatch(this.start, this.end, this.isThinking, {this.isQuiz = false});
}
