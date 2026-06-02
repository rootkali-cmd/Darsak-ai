import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/error_utils.dart';
import 'lesson_detail_screen.dart';

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  List<dynamic> _lessons = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ApiService();
      final resp = await api.dio.get('/lessons/?skip=0&limit=100');
      final data = resp.data;
      _lessons = data is List ? data : [];
    } on DioException catch (e) {
      _error = 'فشل تحميل الدروس: ${getDioErrorMessage(e)}';
    } catch (e) {
      _error = 'حدث خطأ: $e';
    }

    if (mounted) setState(() => _loading = false);
  }

  void _openLesson(dynamic lesson) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LessonDetailScreen(lesson: lesson)),
    );
    _loadLessons();
  }

  void _openNewLesson() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LessonDetailScreen()),
    );
    _loadLessons();
  }

  Future<void> _deleteLesson(dynamic lesson) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الدرس'),
        content: Text('هل تريد حذف "${lesson['title']}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService().dio.delete('/lessons/${lesson['id']}');
      _loadLessons();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحذف'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدروس'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLessons),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewLesson,
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _lessons.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.video_library, size: 64, color: AppTheme.textMuted),
                          SizedBox(height: 16),
                          Text('لا توجد دروس', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _lessons.length,
                      itemBuilder: (_, i) {
                        final l = _lessons[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            onTap: () => _openLesson(l),
                            onLongPress: () => _deleteLesson(l),
                            leading: CircleAvatar(
                              backgroundColor: l['is_published'] == true
                                  ? AppTheme.success.withValues(alpha: 0.2)
                                  : AppTheme.warning.withValues(alpha: 0.2),
                              child: Icon(
                                l['tg_file_id'] != null ? Icons.play_circle : Icons.article,
                                color: l['is_published'] == true ? AppTheme.success : AppTheme.warning,
                                size: 24,
                              ),
                            ),
                            title: Text(l['title'] ?? 'بدون عنوان'),
                            subtitle: Text(
                              [
                                if (l['subject']?.toString().isNotEmpty ?? false) l['subject'],
                                if (l['week_number'] != null) 'الأسبوع ${l['week_number']}',
                              ].join(' • '),
                            ),
                            trailing: l['tg_file_id'] != null
                                ? const Icon(Icons.check_circle, color: AppTheme.success, size: 20)
                                : null,
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadLessons, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}
