import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import 'add_edit_grade_screen.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  List<dynamic> _grades = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService().dio.get('/grades/');
      final data = resp.data;
      _grades = data is List ? data : [];
    } on DioException catch (e) {
      _error = 'فشل تحميل الدرجات: ${e.response?.statusCode ?? e.message}';
    } catch (e) {
      _error = 'حدث خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteGrade(dynamic grade) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الدرجة'),
        content: const Text('هل تريد حذف هذه الدرجة؟'),
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
      await ApiService().dio.delete('/grades/${grade['id']}');
      _loadGrades();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحذف'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _addGrade() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditGradeScreen()),
    );
    _loadGrades();
  }

  Color _getTypeColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'exam':
      case 'امتحان':
        return AppTheme.danger;
      case 'homework':
      case 'واجب':
        return AppTheme.warning;
      case 'quiz':
      case 'اختبار':
        return AppTheme.accent;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الدرجات')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGrade,
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadGrades,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _grades.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.grade_outlined, size: 64, color: AppTheme.textMuted),
                            SizedBox(height: 16),
                            Text('لا توجد درجات', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _grades.length,
                        itemBuilder: (_, i) {
                          final g = _grades[i];
                          final type = g['type'] ?? '';
                          final typeColor = _getTypeColor(type);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AddEditGradeScreen(grade: g)),
                                );
                                _loadGrades();
                              },
                              onLongPress: () => _deleteGrade(g),
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                child: Text(
                                  '${g['score'] ?? 0}/${g['max_score'] ?? 0}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                ),
                              ),
                              title: Text(g['student_name'] ?? g['student']?['full_name'] ?? '—'),
                              subtitle: Text(g['subject'] ?? '—'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  type.isNotEmpty ? type : '—',
                                  style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold),
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
          const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadGrades, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}
