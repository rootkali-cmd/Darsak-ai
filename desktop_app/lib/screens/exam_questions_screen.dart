import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/api_service.dart';

class ExamQuestionsScreen extends StatefulWidget {
  final String examId;
  final String examTitle;
  const ExamQuestionsScreen({super.key, required this.examId, required this.examTitle});

  @override
  State<ExamQuestionsScreen> createState() => _ExamQuestionsScreenState();
}

class _ExamQuestionsScreenState extends State<ExamQuestionsScreen> with TickerProviderStateMixin {
  late AnimationController _listController;
  late Animation<double> _listAnimation;
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _listAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _listController, curve: Curves.easeOutCubic));
    _listController.forward();
    _loadQuestions();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final qs = await _api.getExamQuestions(widget.examId);
      if (!mounted) return;
      setState(() { _questions = qs.cast<Map<String, dynamic>>(); _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Row(children: [Icon(Icons.arrow_right, color: AppTheme.accent), const SizedBox(width: 4), Text('العودة', style: TextStyle(color: AppTheme.accent, fontSize: 13))]),
            ),
            const SizedBox(width: 16),
            Text(widget.examTitle, style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${_questions.length} أسئلة', style: TextStyle(color: textMuted, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 24),
        Expanded(child: _buildContent(context, isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted)),
      ]),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, Color surfaceColor, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_questions.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(60),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.help_outline, size: 56, color: textMuted),
            const SizedBox(height: 16),
            Text('لا توجد أسئلة', style: TextStyle(color: textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            Text('استخدم AI لتوليد الأسئلة أو أضفها يدوياً', style: TextStyle(color: textMuted, fontSize: 13)),
          ]),
        ),
      );
    }

    return FadeTransition(
      opacity: _listAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        itemCount: _questions.length,
        itemBuilder: (_, i) => _buildQuestionCard(context, _questions[i], i, isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, Map<String, dynamic> q, int index, bool isDark, Color surfaceColor, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted) {
    final type = q['type'] ?? 'multiple_choice';
    final questionText = q['question_text'] ?? '';
    final options = q['options'] as List<dynamic>? ?? [];
    final correctAnswer = q['correct_answer'] ?? '';
    final points = q['points'] ?? 1;
    final isMcq = type == 'multiple_choice';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: isMcq ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text('${index + 1}', style: TextStyle(color: isMcq ? AppTheme.accent : AppTheme.warning, fontWeight: FontWeight.bold, fontSize: 13))),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isMcq ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(isMcq ? 'اختيار متعدد' : 'مقالي', style: TextStyle(color: isMcq ? AppTheme.accent : AppTheme.warning, fontSize: 11)),
          ),
          const Spacer(),
          Text('$points درجة', style: TextStyle(color: textMuted, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        Text(questionText, style: TextStyle(color: textPrimary, fontSize: 14, height: 1.4)),
        if (isMcq && options.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...options.map((opt) => Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (opt['key'] == correctAnswer) ? AppTheme.success.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: (opt['key'] == correctAnswer) ? AppTheme.success.withValues(alpha: 0.3) : borderColor),
            ),
            child: Row(children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (opt['key'] == correctAnswer) ? AppTheme.success : Colors.transparent,
                  border: Border.all(color: (opt['key'] == correctAnswer) ? AppTheme.success : const Color(0xFF2A2A2A)),
                ),
                child: Center(child: Text(opt['key'] ?? '', style: TextStyle(color: (opt['key'] == correctAnswer) ? Colors.white : textMuted, fontSize: 11))),
              ),
              const SizedBox(width: 10),
              Text(opt['text'] ?? '', style: TextStyle(color: textPrimary, fontSize: 13)),
              if (opt['key'] == correctAnswer) ...[const Spacer(), Icon(Icons.check_circle, color: AppTheme.success, size: 16)],
            ]),
          )),
        ],
        if (!isMcq && correctAnswer.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الإجابة النموذجية', style: TextStyle(color: AppTheme.warning, fontSize: 11)),
              const SizedBox(height: 4),
              Text(correctAnswer, style: TextStyle(color: textSecondary, fontSize: 13)),
            ]),
          ),
        ],
      ]),
    );
  }
}
