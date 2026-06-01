import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import 'add_edit_group_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<dynamic> _groups = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService().dio.get('/groups/');
      final data = resp.data;
      _groups = data is List ? data : [];
    } on DioException catch (e) {
      _error = 'فشل تحميل المجموعات: ${e.response?.statusCode ?? e.message}';
    } catch (e) {
      _error = 'حدث خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteGroup(dynamic group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المجموعة'),
        content: Text('هل تريد حذف "${group['name'] ?? ''}"؟'),
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
      await ApiService().dio.delete('/groups/${group['id']}');
      _loadGroups();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحذف'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _addGroup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditGroupScreen()),
    );
    _loadGroups();
  }

  void _editGroup(dynamic group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditGroupScreen(group: group)),
    );
    _loadGroups();
  }

  IconData _getSubjectIcon(String? subject) {
    switch (subject?.toLowerCase()) {
      case 'رياضيات':
        return Icons.calculate;
      case 'علوم':
        return Icons.science;
      case 'عربي':
      case 'لغة عربية':
        return Icons.menu_book;
      case 'إنجليزي':
      case 'لغة إنجليزية':
        return Icons.language;
      case 'فيزياء':
        return Icons.bolt;
      case 'كيمياء':
        return Icons.science_outlined;
      default:
        return Icons.school;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المجموعات')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGroup,
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _groups.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.group_work_outlined, size: 64, color: AppTheme.textMuted),
                            SizedBox(height: 16),
                            Text('لا توجد مجموعات', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _groups.length,
                        itemBuilder: (_, i) {
                          final g = _groups[i];
                          final subject = g['subject'] ?? '';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () => _editGroup(g),
                              onLongPress: () => _deleteGroup(g),
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                                child: Icon(_getSubjectIcon(subject), color: AppTheme.accent, size: 24),
                              ),
                              title: Text(g['name'] ?? 'بدون اسم'),
                              subtitle: Text(subject.isNotEmpty ? subject : 'بدون مادة'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (g['day_of_week'] != null || g['time_slot'] != null)
                                    Text(
                                      [g['day_of_week'] ?? '', g['time_slot'] ?? ''].where((s) => s.toString().isNotEmpty).join(' • '),
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                ],
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
          ElevatedButton(onPressed: _loadGroups, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}
