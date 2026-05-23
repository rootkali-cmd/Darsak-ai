import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import 'exam_questions_screen.dart';
import 'exam_results_screen.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> with TickerProviderStateMixin {
  late AnimationController _listController;
  late Animation<double> _listAnimation;
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _exams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _listAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _listController, curve: Curves.easeOutCubic));
    _listController.forward();
    _loadExams();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);
    try {
      final exams = await _api.getExams();
      if (!mounted) return;
      setState(() { _exams = exams.cast<Map<String, dynamic>>(); _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                Text('الاختبارات', style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                const Spacer(),
                _buildActionButton('إنشاء يدوي', Icons.edit_note, AppTheme.accent, () => _showCreateDialog(context)),
                const SizedBox(width: 8),
                _buildActionButton('AI + رفع ملف', Icons.auto_awesome, AppTheme.success, () => _showAiUploadDialog(context)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('إدارة الاختبارات وتوليد الأسئلة بالذكاء الاصطناعي', style: TextStyle(color: textMuted, fontSize: 13)),
          ),
          const SizedBox(height: 24),
          Expanded(child: _buildContent(context, isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted)),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, Color surfaceColor, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_exams.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(60),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.quiz_outlined, size: 56, color: textMuted),
            const SizedBox(height: 16),
            Text('لا توجد اختبارات', style: TextStyle(color: textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            Text('أنشئ اختبارك الأول باستخدام AI أو يدوياً', style: TextStyle(color: textMuted, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showAiUploadDialog(context),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('إنشاء اختبار بالذكاء الاصطناعي'),
            ),
          ]),
        ),
      );
    }

    return FadeTransition(
      opacity: _listAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _exams.map((exam) => _buildExamCard(context, exam, isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted)).toList(),
        ),
      ),
    );
  }

  Widget _buildExamCard(BuildContext context, Map<String, dynamic> exam, bool isDark, Color surfaceColor, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted) {
    final id = exam['id'] ?? '';
    final title = exam['title'] ?? 'بدون عنوان';
    final status = exam['status'] ?? 'draft';
    final duration = exam['duration_minutes'] ?? 30;
    final questionsCount = exam['total_points'] ?? 0;
    final createdAt = exam['created_at'] ?? '';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'published': statusColor = AppTheme.success; statusLabel = 'منشور'; break;
      case 'closed': statusColor = AppTheme.danger; statusLabel = 'مغلق'; break;
      default: statusColor = AppTheme.warning; statusLabel = 'مسودة'; break;
    }

    return Container(
      width: 320,
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [statusColor.withValues(alpha: 0.1), Colors.transparent]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            if (createdAt.isNotEmpty)
              Text(createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt, style: TextStyle(color: textMuted, fontSize: 11)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(title, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Icon(Icons.timer_outlined, size: 14, color: textMuted),
            const SizedBox(width: 4), Text('$duration دقيقة', style: TextStyle(color: textMuted, fontSize: 12)),
            const SizedBox(width: 16),
            Icon(Icons.help_outline, size: 14, color: textMuted),
            const SizedBox(width: 4), Text('$questionsCount سؤال', style: TextStyle(color: textMuted, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            _buildCardButton('الأسئلة', AppTheme.accent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamQuestionsScreen(examId: id, examTitle: title)))),
            const SizedBox(width: 8),
            _buildCardButton('النتائج', AppTheme.accent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamResultsScreen(examId: id, examTitle: title)))),
            const Spacer(),
            if (status == 'draft')
              GestureDetector(
                onTap: () => _confirmPublish(context, id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Text('نشر', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCardButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _confirmPublish(BuildContext context, String examId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurface : AppTheme.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد النشر'),
        content: const Text('بعد نشر الاختبار سيصبح متاحاً للطلاب. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.publishExam(examId);
                _loadExams();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل النشر: $e'), backgroundColor: AppTheme.danger));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text('نشر'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final titleCtl = TextEditingController();
    final descCtl = TextEditingController();
    final durationCtl = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderColor)),
          title: Text('اختبار جديد', style: TextStyle(color: textPrimary)),
          content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'عنوان الاختبار', filled: true), textDirection: TextDirection.rtl),
            const SizedBox(height: 12),
            TextField(controller: descCtl, decoration: const InputDecoration(labelText: 'وصف (اختياري)', filled: true), maxLines: 3, textDirection: TextDirection.rtl),
            const SizedBox(height: 12),
            TextField(controller: durationCtl, decoration: const InputDecoration(labelText: 'المدة بالدقائق', filled: true), keyboardType: TextInputType.number),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await _api.createExam(titleCtl.text.trim(), int.tryParse(durationCtl.text) ?? 30, description: descCtl.text.trim());
                  _loadExams();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الإنشاء: $e'), backgroundColor: AppTheme.danger));
                }
              },
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAiUploadDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final titleCtl = TextEditingController();
    final subjectCtl = TextEditingController();
    final durationCtl = TextEditingController(text: '30');
    String? selectedFilePath;
    String? selectedFileName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderColor)),
          title: Text('توليد أسئلة بالذكاء الاصطناعي', style: TextStyle(color: textPrimary)),
          content: SizedBox(width: 450, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'عنوان الاختبار', filled: true), textDirection: TextDirection.rtl),
            const SizedBox(height: 12),
            TextField(controller: subjectCtl, decoration: const InputDecoration(labelText: 'المادة (اختياري)', filled: true), textDirection: TextDirection.rtl),
            const SizedBox(height: 12),
            TextField(controller: durationCtl, decoration: const InputDecoration(labelText: 'المدة بالدقائق', filled: true), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final result = await FilePicker.pickFiles(type: FileType.any, allowMultiple: false);
                if (result != null && result.files.isNotEmpty) {
                  setDialogState(() {
                    selectedFilePath = result.files.first.path;
                    selectedFileName = result.files.first.name;
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selectedFilePath != null ? AppTheme.success : borderColor, width: selectedFilePath != null ? 2 : 1),
                ),
                child: Column(children: [
                  Icon(selectedFilePath != null ? Icons.check_circle : Icons.upload_file, size: 32, color: selectedFilePath != null ? AppTheme.success : AppTheme.accent),
                  const SizedBox(height: 8),
                  Text(selectedFileName ?? 'اضغط لاختيار ملف PDF أو صورة', style: TextStyle(color: selectedFilePath != null ? AppTheme.success : AppTheme.accent, fontSize: 13)),
                ]),
              ),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: selectedFilePath == null ? null : () async {
                Navigator.pop(ctx);
                try {
                  await _api.aiGenerateExam(titleCtl.text.trim(), selectedFilePath!, subject: subjectCtl.text.trim(), durationMinutes: int.tryParse(durationCtl.text) ?? 30);
                  _loadExams();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التوليد: $e'), backgroundColor: AppTheme.danger));
                }
              },
              child: const Text('توليد'),
            ),
          ],
        ),
      ),
    );
  }
}
