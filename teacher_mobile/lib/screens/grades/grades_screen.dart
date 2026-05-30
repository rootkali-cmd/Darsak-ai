import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/grades_provider.dart';
import '../../providers/students_provider.dart';
import '../../core/app_theme.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/empty_state.dart';
import 'add_edit_grade_screen.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GradesProvider>(context, listen: false).loadGrades();
      Provider.of<StudentsProvider>(context, listen: false).loadStudents();
    });
  }

  void _showAddGrade() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditGradeScreen()),
    );
  }

  void _showEditGrade(dynamic grade) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditGradeScreen(grade: grade)),
    );
  }

  Future<void> _deleteGrade(dynamic grade) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه الدرجة؟'),
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
      final provider = Provider.of<GradesProvider>(context, listen: false);
      final success = await provider.deleteGrade(grade['id'] as int);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'تم الحذف بنجاح' : (provider.error ?? 'فشل الحذف'))),
        );
      }
    }
  }

  void _showFilterDialog() {
    final gradesProvider = Provider.of<GradesProvider>(context, listen: false);
    final subjects = gradesProvider.grades
        .map((g) => g['subject']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تصفية حسب المادة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('الكل'),
              onTap: () {
                setState(() => _selectedSubject = null);
                gradesProvider.loadGrades();
                Navigator.pop(ctx);
              },
            ),
            ...subjects.map((s) => ListTile(
              title: Text(s),
              trailing: _selectedSubject == s ? const Icon(Icons.check, color: AppTheme.accent) : null,
              onTap: () {
                setState(() => _selectedSubject = s);
                gradesProvider.loadGrades(subject: s);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدرجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddGrade,
          ),
        ],
      ),
      body: Consumer<GradesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const AppLoadingIndicator();
          }
          if (provider.error != null && provider.grades.isEmpty) {
            return AppErrorWidget(
              message: provider.error!,
              onRetry: () => provider.loadGrades(subject: _selectedSubject),
            );
          }
          if (provider.grades.isEmpty) {
            return const EmptyState(message: 'لا توجد درجات', icon: Icons.grade);
          }
          return RefreshIndicator(
            onRefresh: () => provider.loadGrades(subject: _selectedSubject),
            color: AppTheme.accent,
            backgroundColor: colorScheme.surface,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: provider.grades.length,
              itemBuilder: (context, index) {
                final grade = provider.grades[index];
                final student = grade['student'] ?? {};
                final studentName = student['full_name'] ?? student['name'] ?? '—';
                final examName = grade['exam_name']?.toString() ?? grade['exam']?.toString() ?? '—';
                final subject = grade['subject']?.toString() ?? '';
                final score = grade['score'] ?? 0;
                final maxScore = grade['max_score'] ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => _showEditGrade(grade),
                    onLongPress: () => _deleteGrade(grade),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
                      child: const Icon(Icons.grade, color: AppTheme.accent),
                    ),
                    title: Text(
                      studentName,
                      style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '$examName ${subject.isNotEmpty ? '• $subject' : ''}',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
                        fontSize: 12,
                      ),
                    ),
                    trailing: Text(
                      '$score / $maxScore',
                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGrade,
        child: const Icon(Icons.add),
      ),
    );
  }
}
