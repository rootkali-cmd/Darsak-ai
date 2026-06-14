import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/data_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/exam.dart';
import '../../../core/database/database_service.dart';

class ExamQuestionsScreen extends StatefulWidget {
  final String examId;
  final String examTitle;

  const ExamQuestionsScreen({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  @override
  State<ExamQuestionsScreen> createState() => _ExamQuestionsScreenState();
}

class _ExamQuestionsScreenState extends State<ExamQuestionsScreen> with TickerProviderStateMixin {
  late AnimationController _listController;
  late Animation<double> _listAnimation;
  List<ExamQuestionModel> _questions = [];
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
    _loadQuestions();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  void _loadQuestions() async {
    // 1. Load local cache INSTANTLY
    final cached = DatabaseService.instance.getExamQuestions(widget.examId);
    if (cached.isNotEmpty) {
      setState(() {
        _questions = cached.map(ExamQuestionModel.fromJson).toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = true);
    }

    // 2. Background API call
    try {
      final raw = await context.read<DataProvider>().api.getExamQuestions(widget.examId).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      DatabaseService.instance.saveExamQuestions(widget.examId, raw.map((j) => j as Map<String, dynamic>).toList());
      setState(() {
        _questions = raw.map((j) => ExamQuestionModel.fromJson(j as Map<String, dynamic>)).toList();
        _isLoading = false;
      });
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
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_right, color: AppTheme.accent),
                        const SizedBox(width: 4),
                        Text('العودة', style: TextStyle(color: AppTheme.accent, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  widget.examTitle,
                  style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_questions.length} أسئلة',
                  style: TextStyle(color: textMuted, fontSize: 13),
                ),
                const SizedBox(width: 16),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddQuestionDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة سؤال'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildContent(context, isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, Color surfaceColor, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_questions.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(60),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.help_outline, size: 56, color: textMuted),
              const SizedBox(height: 16),
              Text('لا توجد أسئلة', style: TextStyle(color: textSecondary, fontSize: 16)),
              const SizedBox(height: 8),
              Text('أضف سؤالاً جديداً للبدء', style: TextStyle(color: textMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _listAnimation,
      child: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        itemCount: _questions.length,
        onReorderItem: _onReorder,
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) => Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              color: surfaceColor,
              child: child,
            ),
            child: child,
          );
        },
        itemBuilder: (_, i) {
          final question = _questions[i];
          return Dismissible(
            key: ValueKey(question.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmDeleteQuestion(context, question),
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 24),
              decoration: BoxDecoration(
                color: AppTheme.danger,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
            ),
            child: _buildQuestionCard(
              context, question, i, isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted,
            ),
          );
        },
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _questions.removeAt(oldIndex);
      _questions.insert(newIndex, item);
    });
  }

  Widget _buildQuestionCard(BuildContext context, ExamQuestionModel q, int index, bool isDark, Color surfaceColor, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted) {
    final labels = ['A', 'B', 'C', 'D'];

    return Container(
      key: ValueKey(q.id),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('اختيار متعدد', style: TextStyle(color: AppTheme.accent, fontSize: 11)),
              ),
              const Spacer(),
              Text(
                '${q.points.toStringAsFixed(0)} درجة',
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
              const SizedBox(width: 12),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _showEditQuestionDialog(context, q),
                  child: Icon(Icons.edit_outlined, size: 18, color: AppTheme.accent),
                ),
              ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _confirmDeleteQuestion(context, q),
                  child: Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.drag_handle, size: 20, color: textMuted),
            ],
          ),
          const SizedBox(height: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _showEditQuestionDialog(context, q),
              child: Text(
                q.questionText,
                style: TextStyle(color: textPrimary, fontSize: 14, height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(q.options.length, (optIdx) {
            final isCorrect = optIdx == q.correctAnswer;
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCorrect ? AppTheme.success.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCorrect ? AppTheme.success.withValues(alpha: 0.3) : borderColor,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCorrect ? AppTheme.success : Colors.transparent,
                      border: Border.all(
                        color: isCorrect ? AppTheme.success : borderColor,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        labels[optIdx],
                        style: TextStyle(
                          color: isCorrect ? Colors.white : textMuted,
                          fontSize: 11,
                          fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      q.options[optIdx],
                      style: TextStyle(
                        color: isCorrect ? textPrimary : textSecondary,
                        fontSize: 13,
                        fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isCorrect)
                    const Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<bool> _confirmDeleteQuestion(BuildContext context, ExamQuestionModel question) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا السؤال؟'),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<DataProvider>().api.deleteQuestion(widget.examId, question.id).timeout(const Duration(seconds: 8));
        _loadQuestions();
        if (!context.mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف السؤال'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!context.mounted) return false;
        setState(() => _isLoading = false);
      }
    }
    return confirmed ?? false;
  }

  void _showAddQuestionDialog(BuildContext context) {
    _showQuestionDialog(context);
  }

  void _showEditQuestionDialog(BuildContext context, ExamQuestionModel question) {
    _showQuestionDialog(context, question: question);
  }

  void _showQuestionDialog(BuildContext context, {ExamQuestionModel? question}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final isEditing = question != null;
    final questionCtl = TextEditingController(text: question?.questionText ?? '');
    final optionCtrls = List.generate(4, (i) => TextEditingController(
      text: question != null && i < question.options.length ? question.options[i] : '',
    ));
    final pointsCtl = TextEditingController(
      text: question != null ? question.points.toStringAsFixed(0) : '1',
    );
    int correctAnswer = question?.correctAnswer ?? 0;
    String questionType = question?.type ?? 'multiple_choice'; // 'multiple_choice' or 'essay'

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          title: Text(
            isEditing ? 'تعديل السؤال' : 'إضافة سؤال جديد',
            style: TextStyle(color: textPrimary),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'multiple_choice', label: Text('اختيار من متعدد')),
                            ButtonSegment(value: 'essay', label: Text('تحريري')),
                          ],
                          selected: <String>{questionType},
                          onSelectionChanged: (Set<String> newSelection) {
                            setDialogState(() {
                              questionType = newSelection.first;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: questionCtl,
                    decoration: const InputDecoration(
                      labelText: 'نص السؤال *',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 16),
                  if (questionType == 'multiple_choice')
                    ...List.generate(4, (i) {
                    final labels = ['A', 'B', 'C', 'D'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => setDialogState(() => correctAnswer = i),
                              child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: correctAnswer == i ? AppTheme.success : Colors.transparent,
                                  border: Border.all(
                                    color: correctAnswer == i ? AppTheme.success : borderColor,
                                    width: correctAnswer == i ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    labels[i],
                                    style: TextStyle(
                                      color: correctAnswer == i ? Colors.white : textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: optionCtrls[i],
                              decoration: InputDecoration(
                                labelText: 'الخيار ${labels[i]}',
                                suffixIcon: correctAnswer == i
                                    ? const Icon(Icons.check_circle, color: AppTheme.success, size: 20)
                                    : null,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AppTheme.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'الطالب هيخلي مساحة فاضية يكتب فيها إجابته',
                            style: TextStyle(color: textPrimary.withValues(alpha: 0.7), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: pointsCtl,
                  decoration: const InputDecoration(
                    labelText: 'الدرجة',
                    prefixIcon: Icon(Icons.star_outline, size: 20),
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
                  if (questionCtl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('نص السؤال مطلوب'),
                        backgroundColor: AppTheme.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  if (questionType == 'multiple_choice') {
                    final hasEmptyOption = optionCtrls.any((c) => c.text.trim().isEmpty);
                    if (hasEmptyOption) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('جميع الخيارات مطلوبة'),
                          backgroundColor: AppTheme.danger,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                  }
                  Navigator.pop(ctx);
                  final data = {
                    'question_text': questionCtl.text.trim(),
                    'options': questionType == 'multiple_choice' ? optionCtrls.map((c) => c.text.trim()).toList() : [],
                    'correct_answer': questionType == 'multiple_choice' ? correctAnswer : 0,
                    'points': double.tryParse(pointsCtl.text) ?? 1,
                    'type': questionType,
                  };
                  
                  // Save locally first (optimistic)
                  final tempQuestion = ExamQuestionModel(
                    id: isEditing ? question.id : 'temp_${DateTime.now().millisecondsSinceEpoch}',
                    examId: widget.examId,
                    questionNumber: _questions.length + 1,
                    questionText: questionCtl.text.trim(),
                    options: questionType == 'multiple_choice' ? optionCtrls.map((c) => c.text.trim()).toList() : [],
                    correctAnswer: questionType == 'multiple_choice' ? correctAnswer : 0,
                    points: double.tryParse(pointsCtl.text) ?? 1,
                    type: questionType,
                  );
                  if (!isEditing) {
                    final currentQuestions = [..._questions, tempQuestion];
                    setState(() => _questions = currentQuestions);
                    DatabaseService.instance.saveExamQuestions(widget.examId, currentQuestions.map((q) => q.toJson()).toList());
                  }
                  
                  try {
                    if (isEditing) {
                      await context.read<DataProvider>().api.updateQuestion(widget.examId, question.id, data).timeout(const Duration(seconds: 25));
                    } else {
                      await context.read<DataProvider>().api.addQuestion(widget.examId, data).timeout(const Duration(seconds: 25));
                    }
                    _loadQuestions();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? 'تم تحديث السؤال' : 'تم إضافة السؤال'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    setState(() => _isLoading = false);
                    if (!isEditing) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم الحفظ محلياً. سيتم رفع السؤال عند استعادة الاتصال.'),
                          backgroundColor: AppTheme.warning,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                child: Text(isEditing ? 'حفظ' : 'إضافة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
