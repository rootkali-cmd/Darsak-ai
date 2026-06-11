import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';
import 'add_edit_group_screen.dart';
import 'shared_lecture_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<dynamic> _groups = [];
  bool _loading = true;
  String? _error;
  static const _cacheKey = 'groups_cache';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadCachedGroups();
    _loadGroups();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCachedGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final data = jsonDecode(cached);
        if (data is List && mounted) {
          setState(() { _groups = data; _loading = false; });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadGroups() async {
    try {
      final resp = await ApiService().dio.get('/groups/');
      final data = resp.data;
      if (data is List) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(data));
        if (mounted) setState(() { _groups = data; _loading = false; _error = null; });
      }
    } on DioException catch (e) {
      if (mounted) setState(() { _loading = false; if (_groups.isEmpty) _error = 'فشل تحميل المجموعات: ${getDioErrorMessage(e)}'; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; if (_groups.isEmpty) _error = 'حدث خطأ: $e'; });
    }
  }

  Future<void> _deleteGroup(dynamic group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المجموعة'),
        content: Text('هل تريد حذف "${group['name'] ?? ''}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService().dio.delete('/groups/${group['id']}');
      _loadGroups();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الحذف'), backgroundColor: AppTheme.danger));
    }
  }

  void _addGroup() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditGroupScreen()));
    _loadGroups();
  }

  void _editGroup(dynamic group) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditGroupScreen(group: group)));
    _loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: GlassTheme.glassAppBar('المجموعات', bottom: TabBar(
        controller: _tabCtrl,
        indicatorColor: GlassTheme.indigo,
        labelColor: GlassTheme.textPrimary(context),
        unselectedLabelColor: GlassTheme.textSecondary(context),
        tabs: const [Tab(text: 'المجموعات'), Tab(text: 'محاضرات مشتركة')],
      )),
      floatingActionButton: _tabCtrl.index == 0 ? GlassTheme.glassFAB(_addGroup) : null,
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildGroupsTab(isDark),
          const SharedLectureScreen(),
        ],
      ),
    );
  }

  Widget _buildGroupsTab(bool isDark) {
    if (_loading && _groups.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: GlassTheme.indigo));
    }
    if (_error != null && _groups.isEmpty) return _buildError();
    return RefreshIndicator(
      onRefresh: _loadGroups,
      color: GlassTheme.indigo,
      child: _groups.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.group_work_outlined, size: 64, color: GlassTheme.textSecondary(context)),
                const SizedBox(height: 16),
                Text('لا توجد مجموعات', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 16)),
              ]),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _groups.length,
              itemBuilder: (_, i) {
                final g = _groups[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: GlassTheme.glassCard(context),
                  child: ListTile(
                    onTap: () => _editGroup(g),
                    onLongPress: () => _deleteGroup(g),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(backgroundColor: GlassTheme.cyan.withValues(alpha: 0.15), child: Icon(Icons.group, color: GlassTheme.cyan, size: 22)),
                    title: Text(g['name'] ?? 'بدون اسم', style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      [g['subject']?.toString() ?? '', g['level']?.toString() ?? '', g['day_of_week']?.toString() ?? ''].where((s) => s.isNotEmpty).join(' • '),
                      style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 12),
                    ),
                    trailing: Icon(Icons.arrow_back_ios, color: GlassTheme.textSecondary(context), size: 14),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildError() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: GlassTheme.red),
      const SizedBox(height: 12),
      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: GlassTheme.textMuted(context))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _loadGroups, style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.indigo), child: const Text('إعادة المحاولة')),
    ]));
  }
}
