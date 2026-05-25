import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/theme.dart';

class ExamTakeScreen extends StatefulWidget {
  final String examId;
  final String examTitle;
  final int durationMinutes;

  const ExamTakeScreen({
    super.key,
    required this.examId,
    required this.examTitle,
    required this.durationMinutes,
  });

  @override
  State<ExamTakeScreen> createState() => _ExamTakeScreenState();
}

class _ExamTakeScreenState extends State<ExamTakeScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _isLoading = true;
  bool _submitting = false;
  bool _submitted = false;
  final Map<String, String> _answers = {};

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.durationMinutes * 60;
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await _api.getExamQuestions(widget.examId);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _autoSubmit();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  Future<void> _autoSubmit() async {
    if (_submitted) return;
    await _submitExam();
  }

  Future<void> _submitExam() async {
    if (_submitted || _submitting) return;
    setState(() => _submitting = true);
    _timer?.cancel();
    try {
      final answers = _questions.map((q) => {
        'question_id': q['id'],
        'answer': _answers[q['id']] ?? '',
      }).toList();
      await _api.submitExam(widget.examId, answers);
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسليم الاختبار بنجاح!'), backgroundColor: Color(0xFF10B981)),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التسليم: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  String get _formattedTime {
    final min = _remainingSeconds ~/ 60;
    final sec = _remainingSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _submitted,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final result = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF141414),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF2A2A2A))),
            title: const Text('تأكيد الخروج', style: TextStyle(color: Color(0xFFF5F5F5))),
            content: const Text('سيتم فقد الإجابات غير المسلمة. هل أنت متأكد؟', style: TextStyle(color: Colors.grey)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger), child: const Text('خروج')),
            ],
          ),
        );
        if (result == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.examTitle),
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _remainingSeconds < 60 ? Colors.red.withValues(alpha: 0.1) : const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, size: 18, color: _remainingSeconds < 60 ? Colors.red : Colors.white),
                  const SizedBox(width: 4),
                  Text(_formattedTime, style: TextStyle(color: _remainingSeconds < 60 ? Colors.red : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _questions.isEmpty
                ? const Center(child: Text('لا توجد أسئلة', style: TextStyle(color: Colors.grey)))
                : Column(
                    children: [
                      _buildProgressBar(),
                      Expanded(child: _buildQuestion()),
                      _buildNavigation(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final total = _questions.length;
    final answered = _answers.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('السؤال ${_currentIndex + 1} من $total', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
              Text('تم حل $answered من $total', style: TextStyle(color: answered == total ? AppTheme.success : Colors.grey[500], fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? answered / total : 0,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation<Color>(answered == total ? AppTheme.success : AppTheme.accent),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_currentIndex] as Map<String, dynamic>;
    final qId = q['id'] ?? '';
    final type = q['type'] ?? 'multiple_choice';
    final questionText = q['question_text'] ?? '';
    final options = q['options'] as List<dynamic>? ?? [];
    final selected = _answers[qId];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: type == 'multiple_choice' ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type == 'multiple_choice' ? 'اختيار من متعدد' : 'مقالي',
                        style: TextStyle(
                          color: type == 'multiple_choice' ? AppTheme.accent : AppTheme.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text('${q['points'] ?? 1} درجة', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(questionText, style: const TextStyle(color: Color(0xFFF5F5F5), fontSize: 16, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (type == 'multiple_choice')
            ...options.map((opt) => _buildOption(
                  key: opt['key'] ?? '',
                  text: opt['text'] ?? '',
                  isSelected: selected == opt['key'],
                  onTap: () {
                    setState(() => _answers[qId] = opt['key'] ?? '');
                  },
                ))
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: TextField(
                maxLines: 8,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'اكتب إجابتك هنا...',
                  hintTextDirection: TextDirection.rtl,
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Color(0xFFF5F5F5), fontSize: 15, height: 1.5),
                onChanged: (v) => _answers[qId] = v,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOption({required String key, required String text, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withValues(alpha: 0.1) : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.accent : const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.accent : Colors.transparent,
                border: Border.all(color: isSelected ? AppTheme.accent : const Color(0xFF2A2A2A)),
              ),
              child: Center(child: Text(key, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[500], fontWeight: FontWeight.bold, fontSize: 13))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFF5F5F5), fontSize: 14))),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentIndex > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _currentIndex--),
                  icon: const Icon(Icons.arrow_right, size: 20),
                  label: const Text('السابق'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[400],
                    side: const BorderSide(color: Color(0xFF2A2A2A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            if (_currentIndex > 0) const SizedBox(width: 12),
            if (_currentIndex < _questions.length - 1)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _currentIndex++),
                  icon: const Icon(Icons.arrow_left, size: 20),
                  label: const Text('التالي'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            if (_currentIndex == _questions.length - 1)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _showConfirmSubmit,
                  icon: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 20),
                  label: Text(_submitting ? 'جاري التسليم...' : 'تسليم'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    disabledBackgroundColor: AppTheme.success.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showConfirmSubmit() {
    final unanswered = _questions.length - _answers.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF2A2A2A))),
        title: const Text('تأكيد التسليم', style: TextStyle(color: Color(0xFFF5F5F5))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('هل أنت متأكد من تسليم الاختبار؟', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text('الأسئلة التي تم حلها: ${_answers.length} من ${_questions.length}',
              style: const TextStyle(color: Color(0xFFF5F5F5))),
            if (unanswered > 0)
              Text('$unanswered سؤال لم يتم حلها', style: const TextStyle(color: AppTheme.danger)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('مراجعة', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () { Navigator.pop(ctx); _submitExam(); }, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success), child: const Text('تسليم')),
        ],
      ),
    );
  }
}
