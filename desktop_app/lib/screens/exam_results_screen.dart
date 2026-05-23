import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/api_service.dart';

class ExamResultsScreen extends StatefulWidget {
  final String examId;
  final String examTitle;
  const ExamResultsScreen({super.key, required this.examId, required this.examTitle});

  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> with TickerProviderStateMixin {
  late AnimationController _listController;
  late Animation<double> _listAnimation;
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _listAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _listController, curve: Curves.easeOutCubic));
    _listController.forward();
    _loadResults();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    try {
      final results = await _api.getExamResults(widget.examId);
      if (!mounted) return;
      setState(() { _results = results.cast<Map<String, dynamic>>(); _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _analyzeStudent(String studentExamId) async {
    setState(() => _analyzing = true);
    try {
      final analysis = await _api.analyzeStudentExam(studentExamId);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurface : AppTheme.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تحليل AI'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (analysis['strengths'] is List) ...[
                  const Text('نقاط القوة', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                  ...analysis['strengths'].map<Widget>((s) => Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $s', style: const TextStyle(color: Colors.grey)))),
                ],
                if (analysis['weaknesses'] is List) ...[
                  const SizedBox(height: 12),
                  const Text('نقاط الضعف', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
                  ...analysis['weaknesses'].map<Widget>((w) => Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $w', style: const TextStyle(color: Colors.grey)))),
                ],
                if (analysis['recommendations'] is List) ...[
                  const SizedBox(height: 12),
                  const Text('التوصيات', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                  ...analysis['recommendations'].map<Widget>((r) => Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $r', style: const TextStyle(color: Colors.grey)))),
                ],
                if (analysis['overall_assessment'] != null) ...[
                  const SizedBox(height: 12),
                  const Text('التقييم العام', style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(analysis['overall_assessment'], style: const TextStyle(color: Colors.grey)),
                ],
              ]),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التحليل: $e'), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _analyzing = false);
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
            Text('نتائج ${widget.examTitle}', style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${_results.length} طالب', style: TextStyle(color: textMuted, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 24),
        Expanded(child: _buildContent(context, isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted)),
      ]),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, Color surfaceColor, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_results.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(60),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.assessment_outlined, size: 56, color: textMuted),
            const SizedBox(height: 16),
            Text('لا توجد نتائج بعد', style: TextStyle(color: textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            Text('بانتظار الطلاب لحل الاختبار', style: TextStyle(color: textMuted, fontSize: 13)),
          ]),
        ),
      );
    }

    return FadeTransition(
      opacity: _listAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        itemCount: _results.length,
        itemBuilder: (_, i) => _buildResultRow(context, _results[i], isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
      ),
    );
  }

  Widget _buildResultRow(BuildContext context, Map<String, dynamic> result, bool isDark, Color surfaceColor, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted) {
    final status = result['status'] ?? 'submitted';
    final score = result['total_score'];
    final maxScore = result['max_score'];
    final studentExamId = result['id'] ?? '';

    double pct = 0;
    if (score != null && maxScore != null && maxScore > 0) {
      pct = (score as num).toDouble() / (maxScore as num).toDouble() * 100;
    }

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'graded': statusColor = AppTheme.success; statusLabel = 'مصحح'; break;
      case 'submitted': statusColor = AppTheme.warning; statusLabel = 'بانتظار التصحيح'; break;
      default: statusColor = Colors.grey; statusLabel = 'قيد التنفيذ'; break;
    }

    Color pctColor;
    if (pct >= 75) pctColor = AppTheme.success;
    else if (pct >= 50) pctColor = AppTheme.warning;
    else pctColor = AppTheme.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.person, color: statusColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
              child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11)),
            ),
          ]),
          if (status == 'graded') ...[
            const SizedBox(height: 6),
            Row(children: [
              Text('$score / $maxScore', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: pctColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text('${pct.toStringAsFixed(1)}%', style: TextStyle(color: pctColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _analyzing ? null : () => _analyzeStudent(studentExamId),
                icon: _analyzing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, size: 16),
                label: Text(_analyzing ? 'جاري...' : 'تحليل AI'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
            ]),
          ],
        ])),
      ]),
    );
  }
}
