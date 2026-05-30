import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/exams_provider.dart';
import '../../core/app_theme.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/empty_state.dart';
import 'add_edit_exam_screen.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExamsProvider>(context, listen: false).loadExams();
    });
  }

  void _showAddExam() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditExamScreen()),
    );
  }

  void _showEditExam(dynamic exam) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditExamScreen(exam: exam)),
    );
  }

  Future<void> _deleteExam(dynamic exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الاختبار؟'),
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
      final provider = Provider.of<ExamsProvider>(context, listen: false);
      final success = await provider.deleteExam(exam['id'] as int);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'تم الحذف بنجاح' : (provider.error ?? 'فشل الحذف'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الاختبارات'),
      ),
      body: Consumer<ExamsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const AppLoadingIndicator();
          }
          if (provider.error != null && provider.exams.isEmpty) {
            return AppErrorWidget(
              message: provider.error!,
              onRetry: () => provider.loadExams(),
            );
          }
          if (provider.exams.isEmpty) {
            return const EmptyState(message: 'لا توجد اختبارات', icon: Icons.quiz);
          }
          return RefreshIndicator(
            onRefresh: () => provider.loadExams(),
            color: AppTheme.accent,
            backgroundColor: const Color(0xFF1a1a2e),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: provider.exams.length,
              itemBuilder: (context, index) {
                final exam = provider.exams[index];
                final title = exam['title']?.toString() ?? '—';
                final status = exam['status']?.toString() ?? 'draft';
                final duration = exam['duration']?.toString() ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => _showEditExam(exam),
                    onLongPress: () => _deleteExam(exam),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.warning.withValues(alpha: 0.2),
                      child: const Icon(Icons.quiz, color: AppTheme.warning),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'الحالة: $status ${duration.isNotEmpty ? '• المدة: $duration د' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: AppTheme.danger),
                      onPressed: () => _deleteExam(exam),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExam,
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
