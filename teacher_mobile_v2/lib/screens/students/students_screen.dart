import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/error_utils.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('الطلاب')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addStudent,
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'بحث عن طالب...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadStudents(),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : _students.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline, size: 64, color: AppTheme.textMuted),
                                  SizedBox(height: 16),
                                  Text('لا يوجد طلاب', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _students.length,
                              itemBuilder: (_, i) {
                                final s = _students[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    onTap: () => _openStudent(s),
                                    onLongPress: () => _deleteStudent(s),
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                                      child: Text(
                                        _getInitials(s['full_name'] ?? ''),
                                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(s['full_name'] ?? 'بدون اسم'),
                                    subtitle: Text(s['code'] ?? ''),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
          const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => _loadStudents(), child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}
