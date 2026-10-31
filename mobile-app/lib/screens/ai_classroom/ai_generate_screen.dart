import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';
import 'ai_lesson_player_screen.dart';

class AiGenerateScreen extends StatefulWidget {
  const AiGenerateScreen({super.key});

  @override
  State<AiGenerateScreen> createState() => _AiGenerateScreenState();
}

class _AiGenerateScreenState extends State<AiGenerateScreen>
    with SingleTickerProviderStateMixin {
  final _topicController = TextEditingController();
  final _api = ApiService();
  late AnimationController _pulseController;
  bool _generating = false;
  String? _error;
  double _progress = 0;
  String _step = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    setState(() {
      _generating = true;
      _error = null;
      _progress = 0;
      _step = 'جاري إنشاء الفصل الذكي...';
    });

    try {
      // Step 1: Start generation
      final result = await _api.generateClassroom(topic);
      final jobId = result['job_id'] as String?;
      if (jobId == null) {
        setState(() {
          _error = result['detail'] ?? 'فشل إنشاء الفصل الذكي';
          _generating = false;
        });
        return;
      }

      // Step 2: Poll for completion
      int pollCount = 0;
      while (mounted && _generating) {
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted || !_generating) return;
        pollCount++;

        final poll = await _api.pollClassroomGeneration(jobId);
        final status = poll['status'] as String? ?? '';
        final progress = (poll['progress'] as num?)?.toDouble() ?? 0;
        final message = poll['message'] as String? ?? '';

        setState(() {
          _progress = progress;
          _step = message.isNotEmpty ? message : 'جاري التوليد...';
        });

        if (status == 'succeeded') {
          final classroomUrl = poll['classroom_url'] as String? ?? '';
          if (classroomUrl.isNotEmpty && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AiClassroomWebViewScreen(
                  url: classroomUrl,
                  title: topic,
                ),
              ),
            );
          } else {
            setState(() {
              _error = 'فشل تحميل رابط الفصل الذكي';
              _generating = false;
            });
          }
          return;
        } else if (status == 'failed') {
          setState(() {
            _error = poll['detail'] ?? 'فشل توليد الفصل الذكي';
            _generating = false;
          });
          return;
        } else if (pollCount > 40) {
          setState(() {
            _error = 'انتهت مهلة التوليد. حاول مرة أخرى';
            _generating = false;
          });
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'حدث خطأ: $e';
          _generating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فصل ذكي جديد'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accent
                          .withValues(alpha: 0.3 + _pulseController.value * 0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accent,
                            AppTheme.accent.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                      child: _generating
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Icon(Icons.auto_awesome,
                              color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'موضوع الدرس',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'اكتب الموضوع الذي تريد تعلمه',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.5)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _topicController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              enabled: !_generating,
              decoration: InputDecoration(
                hintText: 'مثال: شرح قوانين نيوتن في الفيزياء',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: const Color(0xFF0A0A0A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              onSubmitted: (_) => _start(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (_generating) ...[
              const SizedBox(height: 16),
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _step,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _generating ? null : _start,
                icon: _generating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.play_arrow, size: 22),
                label: Text(
                    _generating ? 'جاري التوليد...' : 'ابدأ الفصل',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
