import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/data_provider.dart';
import '../../../core/theme/app_theme.dart';

class AddEditExamScreen extends StatefulWidget {
  final Map<String, dynamic>? exam;

  const AddEditExamScreen({super.key, this.exam});

  @override
  State<AddEditExamScreen> createState() => _AddEditExamScreenState();
}

class _AddEditExamScreenState extends State<AddEditExamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  bool _saving = false;
  List<Map<String, dynamic>> _questions = [];
  bool _loadingQuestions = false;
  DateTime? _deadlineAt;
  DateTime? _showResultsAt;

  bool get _isEdit => widget.exam != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final e = widget.exam!;
      _titleCtrl.text = e['title'] ?? '';
      _descCtrl.text = e['description'] ?? '';
      _durationCtrl.text = e['duration_minutes']?.toString() ?? '';
      _deadlineAt = _parseDt(e['deadline_at']);
      _showResultsAt = _parseDt(e['show_results_at']);
      _loadQuestions();
    }
  }

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadQuestions() async {
    if (!_isEdit) return;
    setState(() => _loadingQuestions = true);
    try {
      final api = context.read<DataProvider>().api;
      final data = await api.getExamQuestions(widget.exam!['id']);
      if (data is List) {
        _questions = data.cast<Map<String, dynamic>>();
      } else if (data is Map && data['questions'] is List) {
        _questions = (data['questions'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingQuestions = false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'duration_minutes': int.tryParse(_durationCtrl.text.trim()),
        'deadline_at': _deadlineAt?.toUtc().toIso8601String(),
        'show_results_at': _showResultsAt?.toUtc().toIso8601String(),
      };

      final api = context.read<DataProvider>().api;
      if (_isEdit) {
        await api.updateExam(widget.exam!['id'], body);
      } else {
        await api.createExam(
          _titleCtrl.text.trim(),
          int.tryParse(_durationCtrl.text.trim()) ?? 30,
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'تم تحديث الاختبار' : 'تم إضافة الاختبار'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.danger, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showAddQuestionDialog() async {
    final questionCtrl = TextEditingController();
    final opt1Ctrl = TextEditingController();
    final opt2Ctrl = TextEditingController();
    final opt3Ctrl = TextEditingController();
    final opt4Ctrl = TextEditingController();
    final pointsCtrl = TextEditingController(text: '1');
    int correctAnswer = 0;
    String questionType = 'multiple_choice';

    final result = await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final dlgSurface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
          final dlgBorder = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
          final dlgTextPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
          final dlgTextSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

          return AlertDialog(
            backgroundColor: dlgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: dlgBorder),
            ),
            title: Text('إضافة سؤال', style: TextStyle(color: dlgTextPrimary)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'multiple_choice', label: Text('اختيار من متعدد')),
                        ButtonSegment(value: 'essay', label: Text('تحريري')),
                      ],
                      selected: <String>{questionType},
                      onSelectionChanged: (Set<String> newSelection) {
                        setDialogState(() => questionType = newSelection.first);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: questionCtrl,
                      decoration: const InputDecoration(labelText: 'نص السؤال *', alignLabelWithHint: true),
                      maxLines: 3,
                      textDirection: TextDirection.rtl,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    if (questionType == 'multiple_choice') ...[
                      ...List.generate(4, (i) {
                        final labels = ['A', 'B', 'C', 'D'];
                        final ctrls = [opt1Ctrl, opt2Ctrl, opt3Ctrl, opt4Ctrl];
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
                                        color: correctAnswer == i ? AppTheme.success : dlgBorder,
                                        width: correctAnswer == i ? 2 : 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        labels[i],
                                        style: TextStyle(
                                          color: correctAnswer == i ? Colors.white : dlgTextPrimary,
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
                                  controller: ctrls[i],
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    labelText: 'الخيار ${labels[i]}${i < 2 ? ' *' : ''}',
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
                      }),
                    ] else ...[
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
                                style: TextStyle(color: dlgTextSecondary, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: pointsCtrl,
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
                  onPressed: () {
                    if (questionCtrl.text.trim().isEmpty) return;
                    if (questionType == 'multiple_choice') {
                      if (opt1Ctrl.text.trim().isEmpty || opt2Ctrl.text.trim().isEmpty) return;
                    }
                    final keys = ['أ', 'ب', 'ج', 'د'];
                    final optCtrls = [opt1Ctrl, opt2Ctrl, opt3Ctrl, opt4Ctrl];
                    Navigator.pop(ctx, {
                      'question_text': questionCtrl.text.trim(),
                      'type': questionType,
                      'options': questionType == 'multiple_choice'
                          ? [
                              for (int i = 0; i < 4; i++)
                                if (optCtrls[i].text.trim().isNotEmpty)
                                  {'key': keys[i], 'text': optCtrls[i].text.trim(), 'is_correct': correctAnswer == i},
                            ]
                          : [],
                      'correct_answer': questionType == 'multiple_choice' ? keys[correctAnswer] : '',
                      'points': int.tryParse(pointsCtrl.text.trim()) ?? 1,
                    });
                  },
                  child: const Text('إضافة'),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && mounted) {
      try {
        final api = context.read<DataProvider>().api;
        await api.addQuestion(widget.exam!['id'], result);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة السؤال'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadQuestions();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إضافة السؤال: $e'), backgroundColor: AppTheme.danger, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<DateTime?> _pickDateTime({required DateTime initial}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'اختر الوقت',
    );
    if (time == null || !mounted) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
                  _isEdit ? 'تعديل الاختبار' : 'اختبار جديد',
                  style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _titleCtrl,
                            style: TextStyle(color: textPrimary),
                            decoration: const InputDecoration(labelText: 'العنوان *', prefixIcon: Icon(Icons.title, size: 20)),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'العنوان مطلوب' : null,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.characters,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descCtrl,
                            style: TextStyle(color: textPrimary),
                            decoration: const InputDecoration(labelText: 'الوصف', prefixIcon: Icon(Icons.description, size: 20)),
                            maxLines: 3,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.characters,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _durationCtrl,
                            style: TextStyle(color: textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'المدة (دقيقة)',
                              prefixIcon: Icon(Icons.timer_outlined, size: 20),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 20),

                          // ─── Scheduling: deadline ─────────────────
                          _buildDateTimeTile(
                            context,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            icon: Icons.event_busy,
                            title: 'موعد التسليم',
                            subtitle: _deadlineAt == null
                                ? 'بدون موعد نهائي'
                                : DateFormat('yyyy/MM/dd - HH:mm').format(_deadlineAt!),
                            hasValue: _deadlineAt != null,
                            onTap: () => _pickDateTime(initial: _deadlineAt ?? DateTime.now().add(const Duration(hours: 2)))
                                .then((dt) { if (dt != null && mounted) setState(() => _deadlineAt = dt); }),
                            onClear: _deadlineAt == null ? null : () => setState(() => _deadlineAt = null),
                          ),
                          const SizedBox(height: 10),

                          // ─── Scheduling: show results ─────────────
                          _buildDateTimeTile(
                            context,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            icon: Icons.visibility,
                            title: 'إظهار النتائج للطلاب',
                            subtitle: _showResultsAt == null
                                ? 'تظهر فور التصحيح'
                                : DateFormat('yyyy/MM/dd - HH:mm').format(_showResultsAt!),
                            hasValue: _showResultsAt != null,
                            onTap: () => _pickDateTime(initial: _showResultsAt ?? DateTime.now().add(const Duration(days: 1)))
                                .then((dt) { if (dt != null && mounted) setState(() => _showResultsAt = dt); }),
                            onClear: _showResultsAt == null ? null : () => setState(() => _showResultsAt = null),
                          ),
                          if (_showResultsAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, right: 4),
                              child: Text(
                                'سيتم إخفاء الإجابات الصحيحة والنسب عن الطلاب حتى هذا التاريخ',
                                style: TextStyle(fontSize: 12, color: textSecondary),
                              ),
                            ),
                          const SizedBox(height: 28),

                          // ─── Save button ─────────────────────────
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      _isEdit ? 'تحديث' : 'إضافة',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),

                          // ─── Questions section (edit mode only) ──
                          if (_isEdit) ...[
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'الأسئلة',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                                ),
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: TextButton.icon(
                                    onPressed: _showAddQuestionDialog,
                                    icon: const Icon(Icons.add, color: AppTheme.accent),
                                    label: const Text('إضافة سؤال', style: TextStyle(color: AppTheme.accent)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_loadingQuestions)
                              const Center(child: CircularProgressIndicator())
                            else if (_questions.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Center(
                                  child: Text('لا توجد أسئلة بعد', style: TextStyle(color: textSecondary)),
                                ),
                              )
                            else
                              ..._questions.asMap().entries.map((entry) {
                                final i = entry.key;
                                final q = entry.value;
                                final opts = q['options'] as List? ?? [];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: surfaceColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28, height: 28,
                                        decoration: BoxDecoration(
                                          color: AppTheme.accent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${i + 1}',
                                            style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(q['question_text'] ?? '', style: TextStyle(color: textPrimary, fontSize: 13)),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${opts.length} خيارات - ${q['points'] ?? 1} نقاط',
                                              style: TextStyle(color: textSecondary, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 20),
                                          onPressed: () async {
                                            try {
                                              final api = context.read<DataProvider>().api;
                                              await api.deleteQuestion(widget.exam!['id'], q['id'].toString());
                                              _loadQuestions();
                                            } catch (_) {}
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeTile(
    BuildContext context, {
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool hasValue,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final accent = hasValue ? AppTheme.accent : textSecondary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: hasValue ? 0.06 : 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withValues(alpha: hasValue ? 0.35 : 0.12)),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: accent)),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close, size: 18, color: textSecondary),
                  onPressed: onClear,
                  tooltip: 'إزالة',
                )
              else
                Icon(Icons.chevron_right, color: textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
