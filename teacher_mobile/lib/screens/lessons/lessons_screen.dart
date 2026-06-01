import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_widget.dart' as app_err;
import 'lesson_detail_screen.dart';

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  List<dynamic> _lessons = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ApiService();
      final response = await api.dio.get('/lessons/?skip=0&limit=100');
      _lessons = response.data is List ? response.data as List<dynamic> : [];
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _createLesson() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LessonDetailScreen()),
    ).then((_) => _loadLessons());
  }

  void _openLesson(dynamic lesson) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LessonDetailScreen(lesson: lesson)),
    ).then((_) => _loadLessons());
  }

  Future<void> _deleteLesson(dynamic lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الدرس؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        final api = ApiService();
        await api.dio.delete('/lessons/${lesson['id']}');
        _loadLessons();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدروس'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _createLesson),
        ],
      ),
      body: _isLoading
          ? const AppLoadingIndicator()
          : _error != null && _lessons.isEmpty
              ? app_err.AppErrorWidget(message: _error!, onRetry: _loadLessons)
              : _lessons.isEmpty
                  ? const EmptyState(message: 'لا توجد دروس', icon: Icons.video_library)
                  : RefreshIndicator(
                      onRefresh: _loadLessons,
                      color: AppTheme.accent,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _lessons.length,
                        itemBuilder: (context, index) {
                          final lesson = _lessons[index];
                          final title = lesson['title'] ?? 'بدون عنوان';
                          final subject = lesson['subject']?.toString() ?? '';
                          final hasVideo = lesson['tg_file_id'] != null;
                          final published = lesson['is_published'] == true;
                          final week = lesson['week_number']?.toString();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              onTap: () => _openLesson(lesson),
                              onLongPress: () => _deleteLesson(lesson),
                              leading: CircleAvatar(
                                backgroundColor: hasVideo
                                    ? AppTheme.success.withValues(alpha: 0.2)
                                    : AppTheme.warning.withValues(alpha: 0.2),
                                child: Icon(
                                  hasVideo ? Icons.play_circle : Icons.upload_file,
                                  color: hasVideo ? AppTheme.success : AppTheme.warning,
                                ),
                              ),
                              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                [
                                  if (subject.isNotEmpty) subject,
                                  if (week != null) 'الأسبوع $week',
                                  if (!published) 'مسودة',
                                ].join(' • '),
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (published)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.success.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'منشور',
                                        style: TextStyle(color: AppTheme.success, fontSize: 11),
                                      ),
                                    ),
                                  const Icon(Icons.arrow_back_ios_new, size: 14),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createLesson,
        child: const Icon(Icons.add),
      ),
    );
  }
}
