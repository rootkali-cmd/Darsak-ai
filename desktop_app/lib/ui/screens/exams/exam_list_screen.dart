import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/exam.dart';
import '../../../core/database/database_service.dart';
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
  List<ExamModel> _exams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _listAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _listController, curve: Curves.easeOutCubic),
    );
    _listController.forward();
    _loadExams();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  void _loadExams() async {
    // 1. Load local cache INSTANTLY
    final cached = DatabaseService.instance.getAllExams();
    if (cached.isNotEmpty) {
      setState(() {
        _exams = cached.map(ExamModel.fromJson).toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = true);
    }

    // 2. Background API call
    try {
      final raw = await context.read<DataProvider>().api.getExams().timeout(const Duration(seconds: 8));
      if (!mounted) return;
      DatabaseService.instance.saveExams(raw.map((j) => j as Map<String, dynamic>).toList());
      setState(() {
        _exams = raw.map((j) => ExamModel.fromJson(j as Map<String, dynamic>)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final sync = context.watch<SyncProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      body: Column(
        children: [
          if (data.isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.15),
                border: Border(bottom: BorderSide(color: AppTheme.warning.withValues(alpha: 0.3))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 16, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  Text(
                    'وضع عدم الاتصال',
                    style: TextStyle(color: AppTheme.warning, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (sync.isSyncing) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warning),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _listAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(_listAnimation),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'الاختبارات',
                                style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_exams.length}',
                                  style: TextStyle(color: AppTheme.accent, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildActionButton(
                                'توليد بالذكاء الاصطناعي',
                                Icons.auto_awesome,
                                AppTheme.success,
                                () => _showAiUploadDialog(context),
                              ),
                              const SizedBox(width: 8),
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showCreateDialog(context),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('إنشاء امتحان'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'إدارة الاختبارات وتوليد الأسئلة بالذكاء الاصطناعي',
                        style: TextStyle(color: textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (_exams.isEmpty)
                        _buildEmptyState(surfaceColor, borderColor, textSecondary, textMuted)
                      else
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: _exams.map((exam) => _buildExamCard(
                            context, exam, isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted,
                          )).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color surfaceColor, Color borderColor, Color textSecondary, Color textMuted) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(60),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined, size: 56, color: textMuted),
            const SizedBox(height: 16),
            Text('لا يوجد امتحانات', style: TextStyle(color: textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            Text('أنشئ امتحانك الأول باستخدام AI أو يدوياً', style: TextStyle(color: textMuted, fontSize: 13)),
            const SizedBox(height: 20),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ElevatedButton.icon(
                onPressed: () => _showAiUploadDialog(context),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('إنشاء امتحان بالذكاء الاصطناعي'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamCard(BuildContext context, ExamModel exam, bool isDark, Color surfaceColor, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted) {
    final statusColor = exam.published ? AppTheme.success : AppTheme.warning;
    final statusLabel = exam.published ? 'منشور' : 'مسودة';

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [statusColor.withValues(alpha: 0.1), Colors.transparent]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(
                  exam.createdAt.toString().substring(0, 10),
                  style: TextStyle(color: textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              exam.title,
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (exam.description != null && exam.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                exam.description!,
                style: TextStyle(color: textMuted, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 14, color: textMuted),
                const SizedBox(width: 4),
                Text('${exam.durationMinutes} دقيقة', style: TextStyle(color: textMuted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                _buildCardButton('الأسئلة', AppTheme.accent, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExamQuestionsScreen(examId: exam.id, examTitle: exam.title),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                if (exam.published)
                  _buildCardButton('النتائج', AppTheme.success, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExamResultsScreen(examId: exam.id, examTitle: exam.title),
                      ),
                    );
                  }),
                const Spacer(),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _showExamMenu(context, exam),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.more_vert, size: 18, color: AppTheme.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardButton(String label, Color color, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _showExamMenu(BuildContext context, ExamModel exam) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        title: const Text('خيارات الامتحان'),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: AppTheme.accent),
                title: const Text('تعديل'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditDialog(context, exam);
                },
              ),
              if (!exam.published)
                ListTile(
                  leading: const Icon(Icons.publish, color: AppTheme.success),
                  title: const Text('نشر'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmPublish(context, exam.id);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
                title: const Text('حذف'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context, exam.id);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ],
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
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await context.read<DataProvider>().api.publishExam(examId).timeout(const Duration(seconds: 8));
                  _loadExams();
                } catch (e) {
                  if (!context.mounted) return;
                  setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              child: const Text('نشر'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String examId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurface : AppTheme.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الاختبار؟'),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await context.read<DataProvider>().api.deleteExam(examId).timeout(const Duration(seconds: 8));
                  _loadExams();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف الاختبار'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              child: const Text('حذف'),
            ),
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
    final totalQuestionsCtl = TextEditingController(text: '10');
    final essayQuestionsCtl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          title: Text('إنشاء امتحان جديد', style: TextStyle(color: textPrimary)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(labelText: 'عنوان الامتحان *'),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtl,
                    decoration: const InputDecoration(labelText: 'وصف (اختياري)'),
                    maxLines: 3,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: durationCtl,
                          decoration: const InputDecoration(
                            labelText: 'المدة (دقيقة)',
                            prefixIcon: Icon(Icons.timer_outlined, size: 20),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: totalQuestionsCtl,
                          decoration: const InputDecoration(
                            labelText: 'عدد الأسئلة',
                            prefixIcon: Icon(Icons.format_list_numbered, size: 20),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: essayQuestionsCtl,
                    decoration: const InputDecoration(
                      labelText: 'عدد أسئلة التحريري (اختياري)',
                      prefixIcon: Icon(Icons.edit_note, size: 20),
                      helperText: 'السؤال الي الطالب بيكتب فيه مش بيختار',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleCtl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);
                  
                  final totalQuestions = int.tryParse(totalQuestionsCtl.text) ?? 10;
                  final essayQuestions = int.tryParse(essayQuestionsCtl.text) ?? 0;
                  
                  // Save locally first (optimistic)
                  final tempExam = ExamModel(
                    id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                    title: titleCtl.text.trim(),
                    description: descCtl.text.trim().isNotEmpty ? descCtl.text.trim() : null,
                    durationMinutes: int.tryParse(durationCtl.text) ?? 30,
                    published: false,
                    createdAt: DateTime.now(),
                    totalQuestions: totalQuestions,
                    essayQuestions: essayQuestions,
                  );
                  final currentExams = [..._exams, tempExam];
                  setState(() => _exams = currentExams);
                  DatabaseService.instance.saveExams(currentExams.map((e) => e.toJson()).toList());
                  
                  try {
                    await context.read<DataProvider>().api.createExam(
                      titleCtl.text.trim(),
                      int.tryParse(durationCtl.text) ?? 30,
                      description: descCtl.text.trim().isNotEmpty ? descCtl.text.trim() : null,
                      totalQuestions: totalQuestions,
                      essayQuestions: essayQuestions,
                    ).timeout(const Duration(seconds: 25));
                    _loadExams();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إنشاء الامتحان'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم الحفظ محلياً. سيتم رفع الامتحان عند استعادة الاتصال.'),
                        backgroundColor: AppTheme.warning,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('إنشاء'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, ExamModel exam) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final titleCtl = TextEditingController(text: exam.title);
    final descCtl = TextEditingController(text: exam.description);
    final durationCtl = TextEditingController(text: exam.durationMinutes.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          title: Text('تعديل الامتحان', style: TextStyle(color: textPrimary)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtl,
                  decoration: const InputDecoration(labelText: 'عنوان الامتحان *'),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtl,
                  decoration: const InputDecoration(labelText: 'وصف (اختياري)'),
                  maxLines: 3,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationCtl,
                  decoration: const InputDecoration(
                    labelText: 'المدة بالدقائق',
                    prefixIcon: Icon(Icons.timer_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleCtl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    await context.read<DataProvider>().api.updateExam(
                      exam.id,
                      {
                        'title': titleCtl.text.trim(),
                        'description': descCtl.text.trim(),
                        'duration_minutes': int.tryParse(durationCtl.text) ?? exam.durationMinutes,
                      },
                    ).timeout(const Duration(seconds: 8));
                    _loadExams();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث الامتحان'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    setState(() => _isLoading = false);
                  }
                },
                child: const Text('حفظ'),
              ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          title: Text('توليد أسئلة بالذكاء الاصطناعي', style: TextStyle(color: textPrimary)),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtl,
                  decoration: const InputDecoration(labelText: 'عنوان الامتحان *'),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectCtl,
                  decoration: const InputDecoration(labelText: 'المادة (اختياري)'),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationCtl,
                  decoration: const InputDecoration(
                    labelText: 'المدة بالدقائق',
                    prefixIcon: Icon(Icons.timer_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () async {
                      final result = await FilePicker.pickFiles(
                        type: FileType.any,
                        allowMultiple: false,
                      );
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
                        border: Border.all(
                          color: selectedFilePath != null ? AppTheme.success : borderColor,
                          width: selectedFilePath != null ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            selectedFilePath != null ? Icons.check_circle : Icons.upload_file,
                            size: 32,
                            color: selectedFilePath != null ? AppTheme.success : AppTheme.accent,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedFileName ?? 'اضغط لاختيار ملف PDF أو صورة',
                            style: TextStyle(
                              color: selectedFilePath != null ? AppTheme.success : AppTheme.accent,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ElevatedButton(
                onPressed: selectedFilePath == null || titleCtl.text.trim().isEmpty
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        try {
                          await context.read<DataProvider>().api.aiGenerateExam(
                            titleCtl.text.trim(),
                            selectedFilePath!,
                            subject: subjectCtl.text.trim().isNotEmpty ? subjectCtl.text.trim() : null,
                            durationMinutes: int.tryParse(durationCtl.text) ?? 30,
                          ).timeout(const Duration(seconds: 8));
                          _loadExams();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إنشاء الامتحان بالذكاء الاصطناعي'),
                              backgroundColor: AppTheme.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          setState(() => _isLoading = false);
                        }
                      },
                child: const Text('توليد'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
