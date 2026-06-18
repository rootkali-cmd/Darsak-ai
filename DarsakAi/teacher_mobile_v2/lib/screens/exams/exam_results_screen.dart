import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';

class ExamResultsScreen extends StatefulWidget {
  final String examId;
  final String examTitle;
  const ExamResultsScreen({super.key, required this.examId, required this.examTitle});

  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> {
  List<dynamic> _results = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await ApiService().dio.get('/exams/${widget.examId}/results');
      final data = resp.data;
      _results = data is List ? data : [];
    } on DioException catch (e) {
      _error = 'فشل تحميل النتائج: ${getDioErrorMessage(e)}';
    } catch (e) {
      _error = 'حدث خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showStudentDetail(BuildContext context, dynamic result, String studentName) {
    final studentExamId = result['id'];
    final score = (result['total_score'] ?? 0).toDouble();
    final maxScore = (result['max_score'] ?? 0).toDouble();
    final pct = maxScore > 0 ? (score / maxScore * 100) : 0.0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ExamStudentDetailScreen(
          studentExamId: studentExamId.toString(),
          studentName: studentName,
          score: score,
          maxScore: maxScore,
          pct: pct,
          examTitle: widget.examTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: GlassTheme.glassAppBar(widget.examTitle),
      body: RefreshIndicator(
        onRefresh: _loadResults,
        color: GlassTheme.indigo,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: GlassTheme.indigo))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: GlassTheme.red),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: GlassTheme.textMuted(context))),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadResults, style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.indigo), child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  )
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_turned_in_outlined, size: 64, color: GlassTheme.textSecondary(context)),
                            const SizedBox(height: 16),
                            Text('لا توجد نتائج بعد', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final r = _results[i];
                          final studentName = r['student_name'] ?? 'طالب';
                          final score = (r['total_score'] ?? 0).toDouble();
                          final maxScore = (r['max_score'] ?? 0).toDouble();
                          final pct = maxScore > 0 ? (score / maxScore * 100) : 0.0;
                          final status = r['status'] ?? '';
                          Color barColor;
                          if (pct >= 80) {
                            barColor = GlassTheme.green;
                          } else if (pct >= 50) {
                            barColor = const Color(0xFFF59E0B);
                          } else {
                            barColor = GlassTheme.red;
                          }
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: GlassTheme.glassCard(context),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: barColor.withValues(alpha: 0.15),
                                  child: Text(
                                    studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                                    style: TextStyle(color: barColor, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(studentName, style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.w500)),
                                subtitle: Row(
                                  children: [
                                    Text('$score / $maxScore', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Text('${pct.toStringAsFixed(1)}%', style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                    if (status == 'graded') ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: GlassTheme.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                        child: const Text('مصحح', style: TextStyle(color: GlassTheme.green, fontSize: 10)),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Icon(Icons.chevron_left, color: GlassTheme.textSecondary(context)),
                                onTap: () {
                                  _showStudentDetail(context, r, studentName);
                                },
                              ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _ExamStudentDetailScreen extends StatefulWidget {
  final String studentExamId;
  final String studentName;
  final double score;
  final double maxScore;
  final double pct;
  final String examTitle;

  const _ExamStudentDetailScreen({
    required this.studentExamId,
    required this.studentName,
    required this.score,
    required this.maxScore,
    required this.pct,
    required this.examTitle,
  });

  @override
  State<_ExamStudentDetailScreen> createState() => _ExamStudentDetailScreenState();
}

class _ExamStudentDetailScreenState extends State<_ExamStudentDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await ApiService().dio.get('/exams/result/${widget.studentExamId}');
      _detail = resp.data is Map ? resp.data as Map<String, dynamic> : {};
    } on DioException catch (e) {
      _error = 'فشل تحميل التفاصيل: ${getDioErrorMessage(e)}';
    } catch (e) {
      _error = 'حدث خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: GlassTheme.glassAppBar(widget.studentName),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GlassTheme.indigo))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: GlassTheme.red),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: GlassTheme.textMuted(context))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDetail,
                        style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.indigo),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _detail == null || _detail!.isEmpty
                  ? const Center(child: Text('لا توجد تفاصيل'))
                  : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final questions = _detail!['questions'] as List<dynamic>? ?? [];
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: GlassTheme.glassCard(context),
          child: Column(
            children: [
              Text(
                '${widget.score} / ${widget.maxScore}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: widget.pct >= 80
                      ? GlassTheme.green
                      : widget.pct >= 50
                          ? const Color(0xFFF59E0B)
                          : GlassTheme.red,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.pct.toStringAsFixed(1)}%',
                style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: questions.length,
            itemBuilder: (_, i) {
              final q = questions[i];
              final isCorrect = q['is_correct'] == true;
              final type = q['type'] ?? '';
              final options = q['options'] as List<dynamic>? ?? [];
              final studentAnswer = q['student_answer']?.toString() ?? '';
              final correctAnswer = q['correct_answer']?.toString() ?? '';
              
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: GlassTheme.glassCard(context),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCorrect ? GlassTheme.green.withValues(alpha: 0.15) : GlassTheme.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'سؤال ${i + 1}',
                              style: TextStyle(
                                color: isCorrect ? GlassTheme.green : GlassTheme.red,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              q['question_text'] ?? q['question'] ?? '',
                              style: TextStyle(color: GlassTheme.textPrimary(context), fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (type == 'multiple_choice' && options.isNotEmpty)
                        ...options.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final optText = entry.value.toString();
                          final optionLabel = String.fromCharCode(65 + idx); // A, B, C, D
                          final isStudentAnswer = studentAnswer.toUpperCase() == optionLabel || studentAnswer == optText;
                          final isCorrectOption = correctAnswer.toUpperCase() == optionLabel || correctAnswer == optText;
                          
                          Color bgColor = Colors.transparent;
                          Color borderColor = GlassTheme.textSecondary(context).withValues(alpha: 0.3);
                          Color textColor = GlassTheme.textPrimary(context);
                          Widget? trailing;
                          
                          if (isCorrectOption) {
                            bgColor = GlassTheme.green.withValues(alpha: 0.1);
                            borderColor = GlassTheme.green;
                            textColor = GlassTheme.green;
                            trailing = const Icon(Icons.check_circle, color: GlassTheme.green, size: 18);
                          }
                          if (isStudentAnswer && !isCorrectOption) {
                            bgColor = GlassTheme.red.withValues(alpha: 0.1);
                            borderColor = GlassTheme.red;
                            textColor = GlassTheme.red;
                            trailing = const Icon(Icons.cancel, color: GlassTheme.red, size: 18);
                          }
                          if (isStudentAnswer && isCorrectOption) {
                            trailing = const Icon(Icons.check_circle, color: GlassTheme.green, size: 18);
                          }
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor, width: 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isCorrectOption
                                        ? GlassTheme.green
                                        : isStudentAnswer
                                            ? GlassTheme.red
                                            : GlassTheme.textSecondary(context).withValues(alpha: 0.2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      optionLabel,
                                      style: TextStyle(
                                        color: isCorrectOption || isStudentAnswer ? Colors.white : GlassTheme.textSecondary(context),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    optText,
                                    style: TextStyle(color: textColor, fontSize: 13),
                                  ),
                                ),
                                if (trailing != null) trailing,
                              ],
                            ),
                          );
                        })
                      else if (type == 'multiple_choice') ...[
                        Row(
                          children: [
                            Text('إجابتك: ', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 13)),
                            Expanded(
                              child: Text(
                                studentAnswer.isNotEmpty ? studentAnswer : '-',
                                style: TextStyle(
                                  color: isCorrect ? GlassTheme.green : GlassTheme.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isCorrect && correctAnswer.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('الإجابة الصحيحة: ', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 13)),
                              Text(
                                correctAnswer,
                                style: const TextStyle(color: GlassTheme.green, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ] else ...[
                        Row(
                          children: [
                            Text('إجابتك: ', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 13)),
                            Expanded(
                              child: Text(
                                studentAnswer.isNotEmpty ? studentAnswer : '-',
                                style: TextStyle(
                                  color: GlassTheme.textPrimary(context),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}