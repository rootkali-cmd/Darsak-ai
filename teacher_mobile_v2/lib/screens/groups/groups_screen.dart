import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';
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
      _error = 'فشل تحميل المجموعات: ${getDioErrorMessage(e)}';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: GlassTheme.glassAppBar('المجموعات'),
      floatingActionButton: GlassTheme.glassFAB(_addGroup),
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        color: GlassTheme.indigo,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: GlassTheme.indigo))
            : _error != null
                ? _buildError()
                : _groups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.group_work_outlined, size: 64, color: GlassTheme.textSecondary(context)),
                            const SizedBox(height: 16),
                            Text('لا توجد مجموعات', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _groups.length,
                        itemBuilder: (_, i) {
                          final g = _groups[i];
                          final subject = g['subject'] ?? '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: GlassTheme.glassCard(context),
                            child: ListTile(
                              onTap: () => _editGroup(g),
                              onLongPress: () => _deleteGroup(g),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: GlassTheme.cyan.withValues(alpha: 0.15),
                                child: Icon(_getSubjectIcon(subject), color: GlassTheme.cyan, size: 22),
                              ),
                              title: Text(g['name'] ?? 'بدون اسم', style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.w500)),
                              subtitle: Text(subject.isNotEmpty ? subject : 'بدون مادة', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 13)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (g['day_of_week'] != null || g['time_slot'] != null)
                                    Text(
                                      [g['day_of_week'] ?? '', g['time_slot'] ?? ''].where((s) => s.toString().isNotEmpty).join(' • '),
                                      style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary(context)),
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
          const Icon(Icons.error_outline, size: 48, color: GlassTheme.red),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: GlassTheme.textMuted(context))),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadGroups, style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.indigo), child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}
