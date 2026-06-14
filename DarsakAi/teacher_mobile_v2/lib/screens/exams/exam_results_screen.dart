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
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}