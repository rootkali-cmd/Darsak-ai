import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/data_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/grade.dart';

final class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

final class _GradesScreenState extends State<GradesScreen> {
  String _search = '';
  String _subjectFilter = '';
  List<GradeModel> _grades = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  void _loadGrades() async {
    // 1. Show local data IMMEDIATELY (even if empty)
    final localGrades = DatabaseService.instance.getAllGrades();
    if (mounted) {
      setState(() {
        _grades = localGrades.map((g) => GradeModel.fromJson(g)).toList();
        _isLoading = false;
      });
    }

    // 2. Background API call
    try {
      final data = context.read<DataProvider>();
      final gradesData = await data.api.getGrades().timeout(const Duration(seconds: 25));
      if (mounted) {
        setState(() {
          _grades = gradesData.map((g) => GradeModel.fromJson(g as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<GradeModel> get _filteredGrades {
    var result = _grades;
    if (_search.isNotEmpty) {
      final q = _search.trim().toLowerCase();
      final students = context.read<DataProvider>().students;
      final matchingIds = students
          .where((s) => s.fullName.toLowerCase().contains(q) || s.code.toLowerCase().contains(q))
          .map((s) => s.id)
          .toSet();
      result = result.where((g) => matchingIds.contains(g.studentId)).toList();
    }
    if (_subjectFilter.isNotEmpty) {
      result = result.where((g) => g.subject == _subjectFilter).toList();
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Set<String> get _subjects => _grades.map((g) => g.subject).where((s) => s.isNotEmpty).toSet();

  double get _average {
    final list = _filteredGrades;
    if (list.isEmpty) return 0;
    return list.fold(0.0, (sum, g) => sum + g.percentage) / list.length;
  }

  double get _highest {
    final list = _filteredGrades;
    if (list.isEmpty) return 0;
    return list.map((g) => g.percentage).reduce((a, b) => a > b ? a : b);
  }

  double get _lowest {
    final list = _filteredGrades;
    if (list.isEmpty) return 0;
    return list.map((g) => g.percentage).reduce((a, b) => a < b ? a : b);
  }

  String _studentName(String studentId) {
    final students = context.read<DataProvider>().students;
    final s = students.where((s) => s.id == studentId).firstOrNull;
    return s?.fullName ?? studentId;
  }

  Color _gradeColor(double percentage) {
    if (percentage >= 75) return AppTheme.success;
    if (percentage >= 50) return AppTheme.warning;
    return AppTheme.danger;
  }

  Future<void> _showAddGradeDialog() async {
    final data = context.read<DataProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final examController = TextEditingController();
    final subjectController = TextEditingController();
    final scoreController = TextEditingController();
    final maxScoreController = TextEditingController(text: '100');
    final wrongQuestionsController = TextEditingController();
    final notesController = TextEditingController();
    String? selectedStudentId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          title: Text('إضافة درجة جديدة', style: TextStyle(color: textPrimary)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return [];
                      final q = textEditingValue.text.trim().toLowerCase();
                      return data.students
                          .where((s) => s.fullName.toLowerCase().contains(q) || s.code.toLowerCase().contains(q))
                          .map((s) => '${s.fullName} (${s.code})');
                    },
                    onSelected: (selection) {
                      final code = selection.substring(selection.indexOf('(') + 1, selection.indexOf(')'));
                      final student = data.students.where((s) => s.code == code).firstOrNull;
                      if (student != null) selectedStudentId = student.id;
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: 'البحث عن طالب', hintText: 'اسم الطالب أو الكود'),
                        onSubmitted: (_) => onFieldSubmitted(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: examController,
                    decoration: const InputDecoration(labelText: 'اسم الامتحان *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(labelText: 'المادة'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: scoreController,
                          decoration: const InputDecoration(labelText: 'الدرجة *'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxScoreController,
                          decoration: const InputDecoration(labelText: 'من'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: wrongQuestionsController,
                    decoration: const InputDecoration(labelText: 'أسئلة خاطئة (مفصولة بفواصل)', hintText: 'مثال: 1,3,5,7'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                    maxLines: 2,
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
                  if (selectedStudentId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى اختيار طالب'), backgroundColor: AppTheme.warning, behavior: SnackBarBehavior.floating),
                    );
                    return;
                  }
                  if (examController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال اسم الامتحان'), backgroundColor: AppTheme.warning, behavior: SnackBarBehavior.floating),
                    );
                    return;
                  }
                  final score = double.tryParse(scoreController.text);
                  if (score == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال درجة صحيحة'), backgroundColor: AppTheme.warning, behavior: SnackBarBehavior.floating),
                    );
                    return;
                  }
                  final maxScore = double.tryParse(maxScoreController.text) ?? 100;

                  List<int>? wrongQuestions;
                  if (wrongQuestionsController.text.trim().isNotEmpty) {
                    wrongQuestions = wrongQuestionsController.text
                        .split(',')
                        .map((s) => int.tryParse(s.trim()))
                        .where((n) => n != null)
                        .cast<int>()
                        .toList();
                    if (wrongQuestions.isEmpty) wrongQuestions = null;
                  }

                  final payload = {
                    'student_id': selectedStudentId,
                    'exam_name': examController.text,
                    'subject': subjectController.text,
                    'score': score,
                    'max_score': maxScore,
                    if (wrongQuestions != null) 'wrong_questions': wrongQuestions,
                    if (notesController.text.isNotEmpty) 'notes': notesController.text,
                  };

                  try {
                    final dataProvider = context.read<DataProvider>();
                    await dataProvider.api.createGrade(payload).timeout(const Duration(seconds: 8));
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _loadGrades();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إضافة الدرجة بنجاح'), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                  }
                },
                child: const Text('إضافة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final filtered = _filteredGrades;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'إدارة الدرجات',
                              style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: ElevatedButton.icon(
                                onPressed: _showAddGradeDialog,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('إضافة درجة'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  labelText: 'بحث عن طالب',
                                  prefixIcon: Icon(Icons.search, size: 20),
                                ),
                                onChanged: (v) => setState(() => _search = v),
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 200,
                              child: DropdownButtonFormField<String>(
                                initialValue: _subjectFilter.isEmpty ? null : _subjectFilter,
                                decoration: const InputDecoration(labelText: 'المادة'),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('جميع المواد')),
                                  ..._subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                                ],
                                onChanged: (v) => setState(() => _subjectFilter = v ?? ''),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (filtered.isNotEmpty)
                          _buildStatsRow(filtered, textPrimary, textSecondary, surfaceColor, borderColor),
                        const SizedBox(height: 20),
                        if (_isLoading || data.isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (filtered.isEmpty)
                          _buildEmptyState(textSecondary, textMuted, surfaceColor, borderColor)
                        else
                          ...filtered.map((g) => _buildGradeRow(g, textPrimary, textSecondary, textMuted, surfaceColor, borderColor, isDark)),
                      ],
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

  Widget _buildStatsRow(List<GradeModel> grades, Color textPrimary, Color textSecondary, Color surfaceColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          _StatsBox(label: 'المتوسط', value: '${_average.toStringAsFixed(1)}%', color: _gradeColor(_average)),
          Container(width: 1, height: 40, color: borderColor),
          _StatsBox(label: 'أعلى درجة', value: '${_highest.toStringAsFixed(1)}%', color: AppTheme.success),
          Container(width: 1, height: 40, color: borderColor),
          _StatsBox(label: 'أقل درجة', value: '${_lowest.toStringAsFixed(1)}%', color: AppTheme.danger),
          Container(width: 1, height: 40, color: borderColor),
          _StatsBox(label: 'إجمالي', value: '${grades.length}', color: textPrimary),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _loadGrades,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 16, color: AppTheme.accent),
                  const SizedBox(width: 4),
                  Text('تحديث', style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color textSecondary, Color textMuted, Color surfaceColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(60),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.grade_outlined, size: 48, color: textMuted),
          const SizedBox(height: 16),
          Text('لا توجد درجات', style: TextStyle(color: textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text('أضف أول درجة الآن', style: TextStyle(color: textMuted, fontSize: 13)),
          const SizedBox(height: 20),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton.icon(
              onPressed: _showAddGradeDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة درجة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeRow(GradeModel grade, Color textPrimary, Color textSecondary, Color textMuted, Color surfaceColor, Color borderColor, bool isDark) {
    final pct = grade.percentage;
    final color = _gradeColor(pct);
    final studentName = _studentName(grade.studentId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      grade.examName,
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    if (grade.subject.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(grade.subject, style: TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${grade.score.toStringAsFixed(grade.score == grade.score.roundToDouble() ? 0 : 1)} / ${grade.maxScore.toStringAsFixed(grade.maxScore == grade.maxScore.roundToDouble() ? 0 : 1)}',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${pct.toStringAsFixed(1)}%',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

final class _StatsBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatsBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
