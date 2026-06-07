import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';
import 'add_edit_exam_screen.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  List<dynamic> _exams = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService().dio.get('/exams');
      final data = resp.data;
      _exams = data is List ? data : [];
    } on DioException catch (e) {
      _error = 'فشل تحميل الاختبارات: ${getDioErrorMessage(e)}';
    } catch (e) {
      _error = 'حدث خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteExam(dynamic exam) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الاختبار'),
        content: Text('هل تريد حذف "${exam['title'] ?? ''}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService().dio.delete('/exams/${exam['id']}');
      _loadExams();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحذف'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _addExam() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditExamScreen()),
    );
    _loadExams();
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'published':
      case 'منشور':
        return GlassTheme.green;
      case 'draft':
      case 'مسودة':
        return AppTheme.warning;
      case 'closed':
      case 'مغلق':
        return GlassTheme.textSecondary(context);
      default:
        return GlassTheme.textSecondary(context);
    }
  }

  String _getStatusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'published':
        return 'منشور';
      case 'draft':
        return 'مسودة';
      case 'closed':
        return 'مغلق';
      default:
        return status ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: GlassTheme.glassAppBar('الاختبارات'),
      floatingActionButton: GlassTheme.glassFAB(_addExam),
      body: RefreshIndicator(
        onRefresh: _loadExams,
        color: GlassTheme.indigo,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: GlassTheme.indigo))
            : _error != null
                ? _buildError()
                : _exams.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.quiz_outlined, size: 64, color: GlassTheme.textSecondary(context)),
                            const SizedBox(height: 16),
                            Text('لا توجد اختبارات', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _exams.length,
                        itemBuilder: (_, i) {
                          final e = _exams[i];
                          final status = e['status'] ?? '';
                          final statusColor = _getStatusColor(status);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: GlassTheme.glassCard(context),
                            child: ListTile(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AddEditExamScreen(exam: e)),
                                );
                                _loadExams();
                              },
                              onLongPress: () => _deleteExam(e),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: statusColor.withValues(alpha: 0.15),
                                child: Icon(Icons.quiz, color: statusColor, size: 22),
                              ),
                              title: Text(e['title'] ?? 'بدون عنوان', style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                [
                                  if (e['duration_minutes'] != null) '${e['duration_minutes']} دقيقة',
                                  if (e['question_count'] != null) '${e['question_count']} سؤال',
                                ].join(' • '),
                                style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 13),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusLabel(status),
                                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: GlassTheme.red),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: GlassTheme.textMuted(context))),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadExams, style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.indigo), child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}
