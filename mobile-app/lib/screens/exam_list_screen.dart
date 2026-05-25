import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/shimmer_loading.dart';
import 'exam_take_screen.dart';
import 'exam_result_screen.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _availableExams = [];
  List<dynamic> _myResults = [];
  bool _isLoading = true;
  String _tab = 'available';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getAvailableExams(),
        _api.getMyExamResults(),
      ]);
      if (!mounted) return;
      setState(() {
        _availableExams = results[0];
        _myResults = results[1];
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
      appBar: AppBar(
        title: const Text('الاختبارات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const ShimmerList()
          : Column(
              children: [
                _buildTabs(),
                Expanded(
                  child: _tab == 'available'
                      ? _availableExams.isEmpty
                          ? const EmptyState(
                              icon: Icons.quiz_outlined,
                              title: 'لا توجد اختبارات متاحة',
                              subtitle: 'سيتم إضافة اختبارات جديدة من معلمك',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _availableExams.length,
                              itemBuilder: (_, i) => _buildExamCard(_availableExams[i]),
                            )
                      : _myResults.isEmpty
                          ? const EmptyState(
                              icon: Icons.assignment_turned_in_outlined,
                              title: 'لم تخضع لأي اختبار بعد',
                              subtitle: 'بعد حل الاختبار ستظهر نتائجك هنا',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _myResults.length,
                              itemBuilder: (_, i) => _buildResultCard(_myResults[i]),
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = 'available'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _tab == 'available' ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'الاختبارات المتاحة (${_availableExams.length})',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _tab == 'available' ? Colors.white : Colors.grey[500],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = 'results'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _tab == 'results' ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'نتائجي (${_myResults.length})',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _tab == 'results' ? Colors.white : Colors.grey[500],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
    final examId = exam['id'] ?? '';
    final title = exam['title'] ?? 'اختبار';
    final description = exam['description'] ?? '';
    final duration = exam['duration_minutes'] ?? 30;
    final questionsCount = exam['total_points'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.quiz, color: AppTheme.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFFF5F5F5), fontWeight: FontWeight.bold, fontSize: 15)),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: Colors.grey[500], fontSize: 12), maxLines: 2),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildInfoChip(Icons.timer_outlined, '$duration دقيقة'),
                    const SizedBox(width: 8),
                    _buildInfoChip(Icons.help_outline, '$questionsCount سؤال'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ExamTakeScreen(examId: examId, examTitle: title, durationMinutes: duration)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ابدأ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ],
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    final exam = result['exam'] as Map<String, dynamic>? ?? {};
    final title = exam['title'] ?? 'اختبار';
    final status = result['status'] ?? 'submitted';
    final score = result['total_score'];
    final maxScore = result['max_score'];
    double pct = 0;
    if (score != null && maxScore != null && maxScore > 0) {
      pct = (score as num).toDouble() / (maxScore as num).toDouble() * 100;
    }

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'graded':
        statusColor = AppTheme.success;
        statusLabel = 'تم التصحيح';
        break;
      case 'submitted':
        statusColor = AppTheme.warning;
        statusLabel = 'في انتظار التصحيح';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = 'قيد التنفيذ';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.assignment_turned_in, color: statusColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFFF5F5F5), fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11)),
                ),
                if (status == 'graded') ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('$score / $maxScore', style: const TextStyle(color: Color(0xFFF5F5F5), fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text(
                        '(${pct.toStringAsFixed(1)}%)',
                        style: TextStyle(color: pct >= 50 ? AppTheme.success : AppTheme.danger, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (status == 'graded')
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.grey),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ExamResultScreen(studentExamId: result['id'] ?? '', examTitle: title)),
              ),
            ),
        ],
      ),
    );
  }
}
