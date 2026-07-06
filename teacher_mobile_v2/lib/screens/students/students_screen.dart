import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';
import '../../core/subscription_guard.dart';
import 'add_edit_student_screen.dart';
import 'student_detail_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  List<dynamic> _students = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents({String? search}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = <String, dynamic>{};
      if (search != null && search.isNotEmpty) query['search'] = search;
      final resp = await ApiService().dio.get('/students/', queryParameters: query.isNotEmpty ? query : null);
      final data = resp.data;
      if (data is Map && data.containsKey('data')) {
        _students = data['data'] as List<dynamic>;
      } else if (data is List) {
        _students = data;
      } else {
        _students = [];
      }
    } on DioException catch (e) {
      _error = 'فشل تحميل الطلاب: ${getDioErrorMessage(e)}';
    } catch (e) {
      _error = 'حدث خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onSearchChanged(String value) {
    _loadStudents(search: value.trim());
  }

  Future<void> _deleteStudent(dynamic student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الطالب'),
        content: Text('هل تريد حذف "${student['full_name'] ?? ''}"؟'),
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
      await ApiService().dio.delete('/students/${student['id']}');
      _loadStudents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحذف'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _openStudent(dynamic student) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student)),
    );
    _loadStudents();
  }

  void _addStudent() async {
    if (!checkSubscription(context)) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditStudentScreen()),
    );
    _loadStudents();
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
        appBar: GlassTheme.glassAppBar('الطلاب'),
        floatingActionButton: GlassTheme.glassFAB(_addStudent),
        body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: TextStyle(color: GlassTheme.textPrimary(context)),
              decoration: GlassTheme.glassInput(context, 'بحث عن طالب...', Icons.search),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadStudents(),
              color: GlassTheme.indigo,
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: GlassTheme.indigo))
                  : _error != null
                      ? _buildError()
                      : _students.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline, size: 64, color: GlassTheme.textSecondary(context)),
                                  const SizedBox(height: 16),
                                  Text('لا يوجد طلاب', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 16)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _students.length,
                              itemBuilder: (_, i) {
                                final s = _students[i];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: GlassTheme.glassCard(context),
                                  child: ListTile(
                                    onTap: () => _openStudent(s),
                                    onLongPress: () => _deleteStudent(s),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: GlassTheme.indigo.withValues(alpha: 0.2),
                                      child: Text(
                                        _getInitials(s['full_name'] ?? ''),
                                        style: const TextStyle(color: GlassTheme.indigo, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    title: Text(s['full_name'] ?? 'بدون اسم', style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.w600)),
                                    subtitle: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(s['code'] ?? '', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 13)),
                                        if ((s['code'] ?? '').toString().isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: s['code'].toString()));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('تم النسخ'), duration: Duration(seconds: 1)),
                                              );
                                            },
                                            child: Icon(Icons.copy, size: 14, color: GlassTheme.textSecondary(context)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: GlassTheme.iconSecondary(context)),
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
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
          ElevatedButton(
            onPressed: () => _loadStudents(),
            style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.indigo),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
