import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';
import '../../core/subscription_guard.dart';

class AddEditExamScreen extends StatefulWidget {
  final dynamic exam;

  const AddEditExamScreen({super.key, this.exam});

  @override
  State<AddEditExamScreen> createState() => _AddEditExamScreenState();
}

class _AddEditExamScreenState extends State<AddEditExamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _totalPointsCtrl = TextEditingController();
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
      _totalPointsCtrl.text = e['total_points']?.toString() ?? '';
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
      final resp = await ApiService().dio.get('/exams/${widget.exam!['id']}/questions');
      final data = resp.data;
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
    _totalPointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!checkSubscription(context)) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final body = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'duration_minutes': int.tryParse(_durationCtrl.text.trim()),
        'total_points': double.tryParse(_totalPointsCtrl.text.trim()),
        'deadline_at': _deadlineAt?.toUtc().toIso8601String(),
        'show_results_at': _showResultsAt?.toUtc().toIso8601String(),
      };

      if (_isEdit) {
        await ApiService().dio.put('/exams/${widget.exam!['id']}', data: body);
      } else {
        await ApiService().dio.post('/exams', data: body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'تم تحديث الاختبار' : 'تم إضافة الاختبار'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحفظ: ${getDioErrorMessage(e)}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.danger),
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
    int correctAnswer = 1;

    final result = await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إضافة سؤال'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: questionCtrl, decoration: GlassTheme.glassFormInput(ctx, 'السؤال *', Icons.help_outline)),
                const SizedBox(height: 8),
                TextField(controller: opt1Ctrl, decoration: GlassTheme.glassFormInput(ctx, 'الخيار 1 *', Icons.looks_one)),
                const SizedBox(height: 8),
                TextField(controller: opt2Ctrl, decoration: GlassTheme.glassFormInput(ctx, 'الخيار 2 *', Icons.looks_two)),
                const SizedBox(height: 8),
                TextField(controller: opt3Ctrl, decoration: GlassTheme.glassFormInput(ctx, 'الخيار 3', Icons.looks_3)),
                const SizedBox(height: 8),
                TextField(controller: opt4Ctrl, decoration: GlassTheme.glassFormInput(ctx, 'الخيار 4', Icons.looks_4)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: correctAnswer,
                  decoration: GlassTheme.glassFormInput(ctx, 'الإجابة الصحيحة', Icons.check),
                  dropdownColor: Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF111111) : Colors.white,
                  items: [1, 2, 3, 4].map((i) => DropdownMenuItem(value: i, child: Text('الخيار $i'))).toList(),
                  onChanged: (v) => setDialogState(() => correctAnswer = v ?? 1),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pointsCtrl,
                  decoration: GlassTheme.glassFormInput(ctx, 'النقاط', Icons.star),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (questionCtrl.text.trim().isEmpty || opt1Ctrl.text.trim().isEmpty || opt2Ctrl.text.trim().isEmpty) return;
                final keys = ['أ', 'ب', 'ج', 'د'];
                Navigator.pop(ctx, {
                  'question_text': questionCtrl.text.trim(),
                  'type': 'multiple_choice',
                  'options': [
                    {'key': keys[0], 'text': opt1Ctrl.text.trim(), 'is_correct': correctAnswer == 1},
                    {'key': keys[1], 'text': opt2Ctrl.text.trim(), 'is_correct': correctAnswer == 2},
                    if (opt3Ctrl.text.trim().isNotEmpty)
                      {'key': keys[2], 'text': opt3Ctrl.text.trim(), 'is_correct': correctAnswer == 3},
                    if (opt4Ctrl.text.trim().isNotEmpty)
                      {'key': keys[3], 'text': opt4Ctrl.text.trim(), 'is_correct': correctAnswer == 4},
                  ],
                  'correct_answer': keys[correctAnswer - 1],
                  'points': int.tryParse(pointsCtrl.text.trim()) ?? 1,
                });
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      try {
        await ApiService().dio.post('/exams/${widget.exam!['id']}/questions', data: result);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إضافة السؤال'), backgroundColor: AppTheme.success),
        );
        _loadQuestions();
      } on DioException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إضافة السؤال: ${getDioErrorMessage(e)}'), backgroundColor: AppTheme.danger),
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

  Widget _buildDateTimeTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool hasValue,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final accent = hasValue ? GlassTheme.indigo : GlassTheme.textSecondary(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: GlassTheme.indigo.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GlassTheme.indigo.withValues(alpha: hasValue ? 0.35 : 0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary(context))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: accent)),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, size: 18, color: GlassTheme.textSecondary(context)),
                onPressed: onClear,
                tooltip: 'إزالة',
              )
            else
              Icon(Icons.chevron_left, color: GlassTheme.textSecondary(context), size: 20),
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
        appBar: GlassTheme.glassAppBar(_isEdit ? 'تعديل الاختبار' : 'اختبار جديد'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: GlassTheme.glassCard(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  decoration: GlassTheme.glassFormInput(context, 'العنوان *', Icons.title),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'العنوان مطلوب' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descCtrl,
                  style: TextStyle(color: GlassTheme.textPrimary(context)),
                  decoration: GlassTheme.glassFormInput(context, 'الوصف', Icons.description),
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _durationCtrl,
                        style: TextStyle(color: GlassTheme.textPrimary(context)),
                        decoration: GlassTheme.glassFormInput(context, 'المدة (دقيقة)', Icons.timer),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _totalPointsCtrl,
                        style: TextStyle(color: GlassTheme.textPrimary(context)),
                        decoration: GlassTheme.glassFormInput(context, 'مجموع النقاط', Icons.stars),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // ─── Scheduling: deadline + results visibility ─────────────────
                _buildDateTimeTile(
                  context,
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
                _buildDateTimeTile(
                  context,
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
                      style: TextStyle(fontSize: 11, color: GlassTheme.textSecondary(context)),
                    ),
                  ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _saving ? 'جاري الحفظ...' : (_isEdit ? 'تحديث' : 'إضافة'),
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الأسئلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
                      TextButton.icon(
                        onPressed: _showAddQuestionDialog,
                        icon: const Icon(Icons.add, color: GlassTheme.indigo),
                        label: const Text('إضافة سؤال', style: TextStyle(color: GlassTheme.indigo)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_loadingQuestions)
                    const Center(child: CircularProgressIndicator())
                  else if (_questions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: GlassTheme.glassCard(context),
                      child: Center(
                        child: Text('لا توجد أسئلة بعد', style: TextStyle(color: GlassTheme.textSecondary(context))),
                      ),
                    )
                  else
                    ..._questions.asMap().entries.map((entry) {
                      final i = entry.key;
                      final q = entry.value;
                      final opts = q['options'] as List? ?? [];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: GlassTheme.glassCard(context),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: GlassTheme.indigo.withValues(alpha: 0.2),
                              child: Text('${i + 1}', style: const TextStyle(color: GlassTheme.indigo, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(q['question_text'] ?? '', style: TextStyle(color: GlassTheme.textPrimary(context), fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text('${opts.length} خيارات - ${q['points'] ?? 1} نقاط', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 11)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 20),
                              onPressed: () async {
                                try {
                                  await ApiService().dio.delete('/exams/${widget.exam!['id']}/questions/${q['id']}');
                                  _loadQuestions();
                                } catch (_) {}
                              },
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
    );
  }
}
