import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/data_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/exam.dart';
import '../../../core/database/database_service.dart';

class ExamResultsScreen extends StatefulWidget {
  final String examId;
  final String examTitle;

  const ExamResultsScreen({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> with TickerProviderStateMixin {
  late AnimationController _listController;
  late Animation<double> _listAnimation;
  List<ExamResultModel> _results = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _listAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _listController, curve: Curves.easeOutCubic),
    );
    _listController.forward();
    _loadResults();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  void _loadResults() async {
    // 1. Load local cache INSTANTLY
    final cached = DatabaseService.instance.getExamResults(widget.examId);
    if (cached.isNotEmpty) {
      setState(() {
        _results = cached.map(ExamResultModel.fromJson).toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = true);
    }

    // 2. Background API call
    try {
      final raw = await context.read<DataProvider>().api.getExamResults(widget.examId).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      DatabaseService.instance.saveExamResults(widget.examId, raw.map((j) => j as Map<String, dynamic>).toList());
      setState(() {
        _results = raw.map((j) => ExamResultModel.fromJson(j as Map<String, dynamic>)).toList();
        _isLoading = false;
      });
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

    final stats = _calculateStats();

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_right, color: AppTheme.accent),
                        const SizedBox(width: 4),
                        Text('العودة', style: TextStyle(color: AppTheme.accent, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'نتائج ${widget.examTitle}',
                  style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (!_isLoading && _results.isNotEmpty)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: () => _showRecordGradesDialog(context, stats),
                      icon: const Icon(Icons.grade, size: 16),
                      label: const Text('تسجيل الدرجات'),
                    ),
                  ),
                const SizedBox(width: 12),
                Text(
                  '${_results.length} طالب',
                  style: TextStyle(color: textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!_isLoading && _results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _statChip('المتوسط', '${stats['average']}%', AppTheme.accent),
                  const SizedBox(width: 12),
                  _statChip('الأعلى', '${stats['highest']}%', AppTheme.success),
                  const SizedBox(width: 12),
                  _statChip('الأدنى', '${stats['lowest']}%', AppTheme.danger),
                  const SizedBox(width: 12),
                  _statChip('نسبة النجاح', '${stats['passRate']}%', AppTheme.warning),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildContent(context, isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
          ),
        ],
      ),
    );
  }

  Map<String, String> _calculateStats() {
    if (_results.isEmpty) {
      return {'average': '0', 'highest': '0', 'lowest': '0', 'passRate': '0'};
    }
    final percentages = _results.map((r) => r.percentage).toList();
    final avg = percentages.reduce((a, b) => a + b) / percentages.length;
    final highest = percentages.reduce((a, b) => a > b ? a : b);
    final lowest = percentages.reduce((a, b) => a < b ? a : b);
    final passCount = percentages.where((p) => p >= 50).length;
    final passRate = (passCount / percentages.length) * 100;

    return {
      'average': avg.toStringAsFixed(1),
      'highest': highest.toStringAsFixed(1),
      'lowest': lowest.toStringAsFixed(1),
      'passRate': passRate.toStringAsFixed(0),
    };
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, Color surfaceColor, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_results.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(60),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assessment_outlined, size: 56, color: textMuted),
              const SizedBox(height: 16),
              Text('لا توجد نتائج بعد', style: TextStyle(color: textSecondary, fontSize: 16)),
              const SizedBox(height: 8),
              Text('بانتظار الطلاب لحل الاختبار', style: TextStyle(color: textMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _listAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        itemCount: _results.length,
        itemBuilder: (_, i) => _buildResultRow(
          context, _results[i], isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted,
        ),
      ),
    );
  }

  Widget _buildResultRow(BuildContext context, ExamResultModel result, bool isDark, Color surfaceColor, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted) {
    final pct = result.percentage;

    Color pctColor;
    if (pct >= 75) { pctColor = AppTheme.success; }
    else if (pct >= 50) { pctColor = AppTheme.warning; }
    else { pctColor = AppTheme.danger; }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: pctColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                result.studentName.isNotEmpty ? result.studentName[0] : 'ط',
                style: TextStyle(color: pctColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.studentName,
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${result.score.toStringAsFixed(1)} / ${result.maxScore.toStringAsFixed(1)}',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: pctColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: pctColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatDate(result.submittedAt),
                      style: TextStyle(color: textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _analyzeButton(context, result),
        ],
      ),
    );
  }

  Widget _analyzeButton(BuildContext context, ExamResultModel result) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ElevatedButton.icon(
        onPressed: () => _analyzeStudent(context, result.id),
        icon: const Icon(Icons.auto_awesome, size: 16),
        label: const Text('تحليل بالذكاء الاصطناعي'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _showRecordGradesDialog(BuildContext context, Map<String, String> stats) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderColor)),
        title: Text('تسجيل الدرجات', style: TextStyle(color: textPrimary)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('سيتم تسجيل ${_results.length} درجة من نتائج امتحان "${widget.examTitle}".', style: TextStyle(color: textSecondary)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'الطلاب الذين لديهم درجة مسجلة مسبقاً لهذا الامتحان سيتم تخطيهم.',
                        style: TextStyle(color: AppTheme.accent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسجيل')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _recordGradesFromResults();
    }
  }

  Future<void> _recordGradesFromResults() async {
    final data = context.read<DataProvider>();
    final db = DatabaseService.instance;
    int success = 0;
    int skipped = 0;
    int failed = 0;

    setState(() => _isLoading = true);

    // Check existing grades for this exam to avoid duplicates
    final allGrades = db.getAllGrades();
    final existingExamNames = allGrades
        .where((g) => g['exam_name']?.toString().toLowerCase() == widget.examTitle.toLowerCase())
        .map((g) => g['student_id']?.toString())
        .where((id) => id != null)
        .toSet();

    for (final result in _results) {
      if (existingExamNames.contains(result.studentId)) {
        skipped++;
        continue;
      }

      final payload = {
        'student_id': result.studentId,
        'exam_name': widget.examTitle,
        'subject': '',
        'score': result.score,
        'max_score': result.maxScore,
        'wrong_questions': result.wrongQuestions.isNotEmpty ? result.wrongQuestions : null,
        'notes': 'مسجل تلقائياً من نتائج الامتحان',
        'created_at': result.submittedAt.toIso8601String(),
      };

      try {
        await data.api.createGrade(payload).timeout(const Duration(seconds: 8));
        success++;
      } catch (_) {
        // Save locally for later sync
        db.saveGrade(payload);
        failed++;
      }
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    final message = success > 0 && failed == 0
        ? 'تم تسجيل $success درجة بنجاح'
        : success > 0 && failed > 0
            ? 'تم تسجيل $success درجة. $failed تم حفظها محلياً للمزامنة لاحقاً'
            : failed > 0
                ? 'تم حفظ $failed درجة محلياً للمزامنة لاحقاً'
                : 'جميع الدرجات مسجلة مسبقاً ($skipped تم تخطيها)';

    final color = failed == 0 ? AppTheme.success : success > 0 ? AppTheme.warning : AppTheme.accentLight;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _analyzeStudent(BuildContext context, String studentExamId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final analysis = await context.read<DataProvider>().api.analyzeStudentExam(studentExamId).timeout(const Duration(seconds: 8));
      if (!context.mounted) return;
      Navigator.pop(context);
      _showAnalysisDialog(context, analysis);
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showAnalysisDialog(BuildContext context, Map<String, dynamic> analysis) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        title: const Text('تحليل الذكاء الاصطناعي'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (analysis['strengths'] is List) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.trending_up, size: 16, color: AppTheme.success),
                            const SizedBox(width: 6),
                            const Text('نقاط القوة', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...analysis['strengths'].map<Widget>((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ', style: TextStyle(color: AppTheme.success)),
                              Expanded(child: Text('$s', style: const TextStyle(color: Colors.grey))),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
                if (analysis['weaknesses'] is List) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.trending_down, size: 16, color: AppTheme.danger),
                            const SizedBox(width: 6),
                            const Text('نقاط الضعف', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...analysis['weaknesses'].map<Widget>((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ', style: TextStyle(color: AppTheme.danger)),
                              Expanded(child: Text('$w', style: const TextStyle(color: Colors.grey))),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
                if (analysis['recommendations'] is List) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.accent),
                            const SizedBox(width: 6),
                            const Text('التوصيات', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...analysis['recommendations'].map<Widget>((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ', style: TextStyle(color: AppTheme.accent)),
                              Expanded(child: Text('$r', style: const TextStyle(color: Colors.grey))),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
                if (analysis['overall_assessment'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.rate_review_outlined, size: 16, color: AppTheme.warning),
                            const SizedBox(width: 6),
                            const Text('التقييم العام', style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          analysis['overall_assessment'],
                          style: const TextStyle(color: Colors.grey, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ),
        ],
      ),
    );
  }
}
