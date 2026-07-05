import 'package:flutter/material.dart';
import '../../core/glass_theme.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import 'course_detail_screen.dart';
import 'create_course_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});
  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _courses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ApiService();
      _courses = await api.getCourses();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = 'فشل تحميل الكورسات'; _loading = false; });
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الكورس'),
        content: const Text('هل أنت متأكد من حذف هذا الكورس؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService().deleteCourse(id);
      _courses.removeWhere((c) => c['id'] == id);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الحذف'), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassTheme.glassAppBar('الكورسات'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCourseScreen()));
          _load();
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(color: GlassTheme.textSecondary(context))),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : _courses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school_outlined, size: 64, color: GlassTheme.textSecondary(context).withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text('لا توجد كورسات بعد', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _courses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final c = _courses[i];
                          final title = c['title'] ?? '';
                          final desc = c['description'] ?? '';
                          final studentsCount = c['students_count'] ?? 0;
                          final price = c['price'] ?? 0;
                          final isPublished = c['status'] == 'published';
                          return Card(
                            color: GlassTheme.cardBg(context),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: c['id'])));
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context), fontFamily: 'Cairo')),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isPublished ? AppTheme.success.withOpacity(0.15) : AppTheme.warning.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(isPublished ? 'منشور' : 'مسودة', style: TextStyle(fontSize: 12, color: isPublished ? AppTheme.success : AppTheme.warning, fontWeight: FontWeight.w600)),
                                        ),
                                        const SizedBox(width: 8),
                                        PopupMenuButton<String>(
                                          onSelected: (v) {
                                            if (v == 'delete') _delete(c['id']);
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(value: 'delete', child: Text('حذف')),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (desc.toString().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary(context))),
                                    ],
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        _badge(Icons.people_outline, '$studentsCount طالب', context),
                                        const SizedBox(width: 16),
                                        _badge(Icons.monetization_on_outlined, '$price ج.م', context),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _badge(IconData icon, String text, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: GlassTheme.textSecondary(context)),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary(context))),
      ],
    );
  }
}
