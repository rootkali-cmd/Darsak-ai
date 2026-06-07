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
      final results = await _api.getMyExamResults();
      if (!mounted) return;
      final found = results.firstWhere(
        (r) => r is Map && r['id'] == widget.studentExamId,
        orElse: () => <String, dynamic>{},
      );
      setState(() {
        _result = found;
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
    final score = _result!['total_score'];
    final maxScore = _result!['max_score'];
    final status = _result!['status'] ?? '';

    double pct = 0;
    if (score != null && maxScore != null && maxScore > 0) {
      pct = (score as num).toDouble() / (maxScore as num).toDouble() * 100;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (status == 'graded') ...[
            _buildScoreCircle(pct),
            const SizedBox(height: 24),
            _buildScoreDetails(score, maxScore, pct),
          ] else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.hourglass_empty, color: AppTheme.warning, size: 48),
                  const SizedBox(height: 12),
                  Text('الاختبار في انتظار التصحيح', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('سيتم إشعارك بنتيجة الاختبار بعد مراجعته', style: TextStyle(color: AppColors.textSecondary(context))),
                ],
              ),
            ),
        ],
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

  Widget _buildScoreDetails(dynamic score, dynamic maxScore, double pct) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          _buildDetailRow('الدرجة', '$score / $maxScore'),
          Divider(color: AppColors.border(context), height: 1),
          _buildDetailRow('النسبة', '${pct.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14)),
          Text(value, style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
