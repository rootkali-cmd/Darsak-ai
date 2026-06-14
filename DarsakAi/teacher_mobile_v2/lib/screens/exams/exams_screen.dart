import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';
import '../../core/subscription_guard.dart';
import 'add_edit_exam_screen.dart';
import 'ai_generate_exam_screen.dart';
import 'exam_results_screen.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});
  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  List<dynamic> _exams = [];
  bool _loading = true;
  String? _error;
  String? _publishingExamId;
  static const _cacheKey = 'exams_cache';

  @override
  void initState() {
    super.initState();
    _loadCached();
    _loadExams();
  }

  Future<void> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final data = jsonDecode(cached);
        if (data is List && mounted) setState(() { _exams = data; _loading = false; });
      }
    } catch (_) {}
  }

  Future<void> _loadExams() async {
    try {
      final resp = await ApiService().dio.get('/exams');
      final data = resp.data;
      if (data is List) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(data));
        if (mounted) setState(() { _exams = data; _loading = false; _error = null; });
      } else {
        if (mounted) setState(() { _exams = []; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'فشل تحميل الاختبارات: $e'; });
    }
  }

  void _showCreateOptions() {
    if (!checkSubscription(context)) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            _buildOption(
              icon: Icons.auto_awesome,
              color: GlassTheme.indigo,
              title: 'اختبار بالذكاء الاصطناعي',
              subtitle: 'ارفع PDF وAI يعمل اختبار جاهز',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AiGenerateExamScreen())).then((v) {
                  if (v == true) _loadExams();
                });
              },
            ),
            const SizedBox(height: 12),
            _buildOption(
              icon: Icons.edit_note,
              color: GlassTheme.green,
              title: 'اختبار يدوياً',
              subtitle: 'أنشئ اختبار وأضف الأسئلة بنفسك',
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditExamScreen()));
                _loadExams();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.3), size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: GlassTheme.glassAppBar('الاختبارات'),
      floatingActionButton: GlassTheme.glassFAB(_showCreateOptions),
      body: RefreshIndicator(
        onRefresh: _loadExams,
        color: GlassTheme.indigo,
        child: _loading && _exams.isEmpty
            ? const Center(child: CircularProgressIndicator(color: GlassTheme.indigo))
            : _exams.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.quiz_outlined, size: 64, color: GlassTheme.textSecondary(context)),
                    const SizedBox(height: 16),
                    Text('لا توجد اختبارات', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 16)),
                    const SizedBox(height: 12),
                    TextButton.icon(onPressed: _loadExams, icon: const Icon(Icons.refresh, size: 18), label: const Text('تحديث'), style: TextButton.styleFrom(foregroundColor: GlassTheme.indigo)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _exams.length,
                    itemBuilder: (_, i) {
                      final e = _exams[i];
                      final status = e['status']?.toString() ?? '';
                          final isDraft = status == 'draft';
                      final isPublished = status == 'published' || status == 'closed';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: GlassTheme.glassCard(context),
                        child: ListTile(
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditExamScreen(exam: e)));
                            _loadExams();
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(backgroundColor: GlassTheme.indigo.withValues(alpha: 0.15), child: const Icon(Icons.quiz, color: GlassTheme.indigo, size: 22)),
                          title: Text(e['title'] ?? 'بدون عنوان', style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.w500)),
                          subtitle: Row(
                            children: [
                              Text(e['subject']?.toString() ?? '', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 13)),
                              if (isPublished) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ExamResultsScreen(examId: e['id'] ?? '', examTitle: e['title'] ?? '')));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: GlassTheme.cyan.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.assignment, size: 12, color: GlassTheme.cyan),
                                        const SizedBox(width: 3),
                                        Text('النتائج', style: TextStyle(color: GlassTheme.cyan, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: isDraft
                              ? _publishingExamId == e['id']
                                  ? SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: GlassTheme.green),
                                    )
                                  : GestureDetector(
                                      onTap: () async {
                                        final examId = e['id'];
                                        if (examId == null) return;
                                        setState(() => _publishingExamId = examId);
                                        try {
                                          await ApiService().dio.post('/exams/$examId/publish');
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('تم نشر الاختبار'), backgroundColor: GlassTheme.green),
                                            );
                                          }
                                          _loadExams();
                                        } catch (err) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('فشل النشر: $err'), backgroundColor: GlassTheme.red),
                                            );
                                          }
                                        } finally {
                                          if (mounted) setState(() => _publishingExamId = null);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [GlassTheme.green.withValues(alpha: 0.8), GlassTheme.green],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: GlassTheme.green.withValues(alpha: 0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.publish, color: Colors.white, size: 14),
                                            SizedBox(width: 4),
                                            Text('نشر', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: GlassTheme.indigo.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                  child: Text(status, style: const TextStyle(color: GlassTheme.indigo, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
