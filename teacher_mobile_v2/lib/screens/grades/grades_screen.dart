import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';
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
      _error = 'فشل تحميل الدرجات: ${getDioErrorMessage(e)}';
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
        return GlassTheme.red;
      case 'homework':
      case 'واجب':
        return AppTheme.warning;
      case 'quiz':
      case 'اختبار':
        return GlassTheme.indigo;
      default:
        return GlassTheme.cyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: GlassTheme.glassAppBar('الدرجات'),
      floatingActionButton: GlassTheme.glassFAB(_addGrade),
      body: RefreshIndicator(
        onRefresh: _loadGrades,
        color: GlassTheme.indigo,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: GlassTheme.indigo))
            : _error != null
                ? _buildError()
                : _grades.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.grade_outlined, size: 64, color: Color(0xFF94A3B8)),
                            SizedBox(height: 16),
                            Text('لا توجد درجات', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
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
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: GlassTheme.glassCard,
                            child: ListTile(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AddEditGradeScreen(grade: g)),
                                );
                                _loadGrades();
                              },
                              onLongPress: () => _deleteGrade(g),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: GlassTheme.cyan.withValues(alpha: 0.15),
                                child: Text(
                                  '${g['score'] ?? 0}/${g['max_score'] ?? 0}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GlassTheme.cyan),
                                ),
                              ),
                              title: Text(g['student_name'] ?? g['student']?['full_name'] ?? '—', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                              subtitle: Text(g['subject'] ?? '—', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.15),
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
          const Icon(Icons.error_outline, size: 48, color: GlassTheme.red),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadGrades, style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.indigo), child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}
