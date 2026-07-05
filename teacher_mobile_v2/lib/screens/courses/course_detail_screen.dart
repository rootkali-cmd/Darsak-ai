import 'package:flutter/material.dart';
import '../../core/glass_theme.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});
  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  bool _loading = true;
  Map<String, dynamic> _course = {};
  List<dynamic> _chapters = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ApiService();
      final results = await Future.wait([
        api.getCourse(widget.courseId),
        api.getChapters(widget.courseId),
      ]);
      if (!mounted) return;
      setState(() {
        _course = Map<String, dynamic>.from(results[0] as Map);
        _chapters = List<dynamic>.from(results[1] as List);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _togglePublish() async {
    try {
      final api = ApiService();
      final current = _course['status'] == 'published';
      await api.updateCourse(widget.courseId, {'status': current ? 'draft' : 'published'});
      _course['status'] = current ? 'draft' : 'published';
      setState(() {});
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل التحديث'), backgroundColor: AppTheme.danger));
    }
  }

  Future<void> _createChapter() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('فصل جديد'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'اسم الفصل')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('إنشاء')),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      await ApiService().createChapter(widget.courseId, {'title': result});
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الإنشاء'), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _course['title'] ?? '';
    final desc = _course['description'] ?? '';
    final isPublished = _course['status'] == 'published';
    return Scaffold(
      appBar: GlassTheme.glassAppBar(title.toString().isNotEmpty ? title : 'تفاصيل الكورس'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _createChapter,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: GlassTheme.cardBg(context),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context), fontFamily: 'Cairo')),
                              ),
                              Switch(
                                value: isPublished,
                                onChanged: (_) => _togglePublish(),
                                activeColor: AppTheme.success,
                              ),
                            ],
                          ),
                          if (desc.toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(desc, style: TextStyle(fontSize: 14, color: GlassTheme.textSecondary(context))),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('الفصول (${_chapters.length})', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context), fontFamily: 'Cairo')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_chapters.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('لا توجد فصول بعد. اضغط + لإضافة فصل', style: TextStyle(color: GlassTheme.textSecondary(context))),
                      ),
                    ),
                  ..._chapters.map((ch) => Card(
                    color: GlassTheme.cardBg(context),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(Icons.book_outlined, color: AppTheme.primary),
                      title: Text(ch['title'] ?? '', style: TextStyle(color: GlassTheme.textPrimary(context), fontFamily: 'Cairo')),
                      subtitle: Text('${ch['lessons_count'] ?? 0} درس', style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary(context))),
                      trailing: Icon(Icons.chevron_right, color: GlassTheme.textSecondary(context)),
                      onTap: () {},
                    ),
                  )),
                ],
              ),
            ),
    );
  }
}
