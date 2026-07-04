import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';
import '../../core/constants.dart';
import 'ai_lesson_summary_screen.dart';
import '../wallet/student_wallet_screen.dart';

class AiLessonPlayerScreen extends StatefulWidget {
  final String? classroomUrl;
  final String? title;

  const AiLessonPlayerScreen({super.key, this.classroomUrl, this.title});

  @override
  State<AiLessonPlayerScreen> createState() => _AiLessonPlayerScreenState();
}

class _AiLessonPlayerScreenState extends State<AiLessonPlayerScreen> {
  final _api = ApiService();
  WebViewController? _webViewController;
  Timer? _timer;
  Timer? _heartbeatTimer;
  String? _sessionId;
  double _rate = 0.42;
  double _balance = 0;
  int _elapsedSeconds = 0;
  bool _loading = true;
  bool _ended = false;
  bool _warning = false;
  String _warningMessage = '';

  @override
  void initState() {
    super.initState();
    _startLesson();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _startLesson() async {
    try {
      final config = await _api.getAiClassroomConfig();
      _rate = (config['rate_per_minute'] as num?)?.toDouble() ?? 0.42;
      _balance = 0;

      final wallet = await _api.getWallet();
      _balance = (wallet['balance'] as num?)?.toDouble() ?? 0;

      final result = await _api.startAiLesson(
        classroomUrl: widget.classroomUrl,
        title: widget.title ?? 'درس AI',
      );
      _sessionId = result['session_id'] as String?;
      if (_sessionId == null) throw Exception('No session ID');

      final url = result['classroom_url'] as String? ?? widget.classroomUrl;
      if (url != null) {
        _webViewController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(url));
      }

      if (mounted) {
        setState(() => _loading = false);
        _startTimer();
        _startHeartbeat();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError(e.toString());
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_ended && mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_ended || _sessionId == null) return;
      try {
        final hb = await _api.aiLessonHeartbeat(_sessionId!);
        if (!mounted) return;
        final bal = (hb['balance'] as num?)?.toDouble() ?? _balance;
        final warn = hb['warning'] as bool? ?? false;
        final forceEnd = hb['force_end'] as bool? ?? false;
        final msg = hb['message'] as String? ?? '';
        setState(() {
          _balance = bal;
          _warning = warn;
          _warningMessage = msg;
        });
        if (forceEnd) {
          _endLesson();
        } else if (warn) {
          Future.delayed(const Duration(minutes: 1), () {
            if (!_ended && _warning && mounted) _endLesson();
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _endLesson() async {
    if (_ended || _sessionId == null) return;
    _ended = true;
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    try {
      final summary = await _api.endAiLesson(_sessionId!);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AiLessonSummaryScreen(data: summary)),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('خطأ'),
        content: Text(msg.contains('402') ? 'رصيد غير كاف. اشحن محفظتك أولاً.' : msg),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('جاري التحميل...'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final cost = (_elapsedSeconds / 60 * _rate);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _webViewController == null
                      ? _buildWebView()
                      : WebViewWidget(controller: _webViewController!),
                ),
                _buildBottomBar(theme, cost),
              ],
            ),
            if (_warning) _buildWarningOverlay(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return const SizedBox.shrink();
  }

  Widget _buildBottomBar(ThemeData theme, double cost) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          _infoChip(Icons.timer_outlined, _formatDuration(_elapsedSeconds), null),
          const SizedBox(width: 8),
          _infoChip(Icons.monetization_on_outlined, '${cost.toStringAsFixed(2)} ج.م', AppTheme.accent),
          const SizedBox(width: 8),
          _infoChip(Icons.account_balance_wallet_outlined, '${_balance.toStringAsFixed(2)} ج.م', null),
          const Spacer(),
          _warning
              ? Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20)
              : const SizedBox.shrink(),
          const SizedBox(width: 4),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('إنهاء الدرس'),
                    content: Text('تأكيد إنهاء الدرس؟\nالمدة: ${_formatDuration(_elapsedSeconds)}\nالتكلفة: ${cost.toStringAsFixed(2)} ج.م'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                      ElevatedButton(
                        onPressed: () { Navigator.pop(ctx); _endLesson(); },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        child: const Text('إنهاء'),
                      ),
                    ],
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('إنهاء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color? color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildWarningOverlay(ThemeData theme) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade700, Colors.orange.shade600],
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('رصيد منخفض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(_warningMessage, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentWalletScreen()));
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('شحن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
