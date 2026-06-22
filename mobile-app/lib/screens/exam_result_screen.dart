import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/theme.dart';

class ExamResultScreen extends StatefulWidget {
  final String studentExamId;
  final String examTitle;

  const ExamResultScreen({
    super.key,
    required this.studentExamId,
    required this.examTitle,
  });

  @override
  State<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends State<ExamResultScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _result;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResult();
  }

  Future<void> _loadResult() async {
    try {
      final result = await _api.getStudentExamResult(widget.studentExamId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.examTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _result == null || _result!.isEmpty
              ? const Center(child: Text('النتيجة غير متاحة', style: TextStyle(color: Colors.grey)))
              : _buildResult(),
    );
  }

  Widget _buildResult() {
    final status = _result!['status'] ?? '';
    final scorePercentage = (_result!['score_percentage'] as num?)?.toDouble() ?? 0;
    final correctPercentage = (_result!['correct_percentage'] as num?)?.toDouble();
    final wrongPercentage = (_result!['wrong_percentage'] as num?)?.toDouble();
    final resultsHiddenUntil = _result!['results_hidden_until'] as String?;
    final bool resultsHidden = correctPercentage == null && wrongPercentage == null && resultsHiddenUntil != null;

    // Results hidden until a teacher-set date: show waiting state instead of 0/0
    if (resultsHidden) {
      String untilText = '';
      try {
        final dt = DateTime.parse(resultsHiddenUntil).toLocal();
        untilText = '${dt.day}/${dt.month}/${dt.year} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        untilText = resultsHiddenUntil;
      }
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock, color: AppTheme.warning, size: 48),
              const SizedBox(height: 12),
              Text('النتائج مخفية مؤقتاً', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('ستظهر نتيجتك التفصيلية في:', style: TextStyle(color: AppColors.textSecondary(context))),
              const SizedBox(height: 4),
              Text(untilText, style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Text('درجتك: ${scorePercentage.toStringAsFixed(1)}%', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if (status == 'graded') {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildScoreCircle(scorePercentage),
            const SizedBox(height: 24),
            _buildPercentagesCard(correctPercentage!, wrongPercentage!),
          ],
        ),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty, color: AppTheme.warning, size: 48),
            const SizedBox(height: 12),
            Text('الاختبار في انتظار التصحيح', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('سيتم إشعارك بنتيجة الاختبار بعد مراجعته', style: TextStyle(color: AppColors.textSecondary(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCircle(double pct) {
    Color color;
    String label;
    IconData icon;
    if (pct >= 85) {
      color = AppTheme.success;
      label = 'ممتاز';
      icon = Icons.emoji_events;
    } else if (pct >= 65) {
      color = AppTheme.accent;
      label = 'جيد';
      icon = Icons.thumb_up;
    } else if (pct >= 50) {
      color = AppTheme.warning;
      label = 'مقبول';
      icon = Icons.check_circle;
    } else {
      color = AppTheme.danger;
      label = 'ضعيف';
      icon = Icons.warning;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.1), AppColors.background(context)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: pct / 100,
                    strokeWidth: 10,
                    backgroundColor: AppColors.border(context),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${pct.toStringAsFixed(1)}%', style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
                    Text('الدرجة', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentagesCard(double correctPct, double wrongPct) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          _buildPercentageRow(
            'صحيحة',
            correctPct,
            AppTheme.success,
            Icons.check_circle_outline,
          ),
          Divider(color: AppColors.border(context), height: 1),
          _buildPercentageRow(
            'خاطئة',
            wrongPct,
            AppTheme.danger,
            Icons.cancel_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageRow(String label, double pct, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 15)),
          ),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
