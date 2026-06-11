import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../core/glass_theme.dart';

class SharedLectureScreen extends StatefulWidget {
  const SharedLectureScreen({super.key});

  @override
  State<SharedLectureScreen> createState() => _SharedLectureScreenState();
}

class _SharedLectureScreenState extends State<SharedLectureScreen> {
  List<Map<String, dynamic>> _sharedLectures = [];
  List<dynamic> _allGroups = [];
  bool _loading = true;
  static const _storageKey = 'shared_lectures';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Load groups
      final resp = await ApiService().dio.get('/groups/');
      _allGroups = resp.data is List ? resp.data : [];

      // Load shared lectures from local storage
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_storageKey);
      if (cached != null) {
        final list = jsonDecode(cached);
        if (list is List) _sharedLectures = list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createSharedLecture() async {
    final selectedGroups = <String>{};
    final nameCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('محاضرة مشتركة جديدة', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'اسم المحاضرة',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _allGroups.isEmpty
                      ? const Center(child: Text('لا توجد مجموعات', style: TextStyle(color: Color(0xFF94A3B8))))
                      : ListView(
                          children: _allGroups.map((g) {
                            final gid = g['id'].toString();
                            final isSelected = selectedGroups.contains(gid);
                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (v) {
                                setDialogState(() {
                                  if (v == true) selectedGroups.add(gid); else selectedGroups.remove(gid);
                                });
                              },
                              title: Text(g['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                              subtitle: Text(
                                [g['subject']?.toString() ?? '', g['day_of_week']?.toString() ?? ''].where((s) => s.isNotEmpty).join(' • '),
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                              checkColor: Colors.white,
                              activeColor: const Color(0xFF6366F1),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || selectedGroups.isEmpty) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final name = nameCtrl.text.trim();
    final selectedList = _allGroups.where((g) => selectedGroups.contains(g['id'].toString())).map((g) => {
      'id': g['id'].toString(),
      'name': g['name'] ?? '',
      'day': g['day_of_week'] ?? '',
      'time': g['time_slot'] ?? '',
    }).toList();

    _sharedLectures.add({
      'name': name,
      'groups': selectedList,
      'created_at': DateTime.now().toIso8601String(),
    });

    await _saveToStorage();
    if (mounted) setState(() {});
  }

  Future<void> _deleteLecture(int index) async {
    _sharedLectures.removeAt(index);
    await _saveToStorage();
    if (mounted) setState(() {});
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_sharedLectures));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: GlassTheme.indigo));

    if (_sharedLectures.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_awesome, size: 64, color: GlassTheme.textSecondary(context)),
          const SizedBox(height: 16),
          Text('لا توجد محاضرات مشتركة', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 15)),
          const SizedBox(height: 8),
          Text('اضغط على الزر لإنشاء محاضرة مشتركة', style: TextStyle(color: GlassTheme.textMuted(context), fontSize: 12)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createSharedLecture,
            icon: const Icon(Icons.add),
            label: const Text('إنشاء محاضرة مشتركة'),
            style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.indigo),
          ),
        ]),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: _createSharedLecture,
            icon: const Icon(Icons.add),
            label: const Text('محاضرة مشتركة جديدة'),
            style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.indigo, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _sharedLectures.length,
            itemBuilder: (_, i) {
              final lec = _sharedLectures[i];
              final groups = (lec['groups'] as List?) ?? [];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: GlassTheme.glassCard(context),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(lec['name'] ?? '', style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.w600)),
                  subtitle: Text('${groups.length} مجموعات', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: GlassTheme.red, size: 20),
                    onPressed: () => _deleteLecture(i),
                  ),
                  children: groups.map((g) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.group, color: GlassTheme.cyan, size: 18),
                    title: Text(g['name'] ?? '', style: TextStyle(color: GlassTheme.textPrimary(context), fontSize: 13)),
                    subtitle: Text('${g['day'] ?? ''} ${g['time'] ?? ''}', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 11)),
                  )).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
