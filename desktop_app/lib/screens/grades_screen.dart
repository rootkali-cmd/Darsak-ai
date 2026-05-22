import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../core/theme.dart';
import '../core/local_db.dart';
import '../providers/data_provider.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> with TickerProviderStateMixin {
  late AnimationController _listController;
  late Animation<double> _listAnimation;

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
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final grades = LocalDB.getAllData(LocalDB.gradesBox);
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
                  Text(
                    'الدرجات',
                    style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddGradeDialog(context, data),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('إضافة درجة'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: OutlinedButton.icon(
                          onPressed: () => _importGradesFromCSV(context, data),
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('رفع CSV'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (grades.isEmpty)
                Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.grade_outlined, size: 48, color: textMuted),
                      const SizedBox(height: 16),
                      Text('لا توجد درجات', style: TextStyle(color: textSecondary, fontSize: 16)),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: grades.length,
                  itemBuilder: (context, index) {
                    final g = grades[index];
                    final score = (g['score'] ?? 0).toDouble();
                    final max = (g['max_score'] ?? 100).toDouble();
                    final pct = max > 0 ? (score / max) * 100 : 0;
                    final color = pct >= 85 ? AppTheme.success : pct >= 50 ? AppTheme.warning : AppTheme.danger;
                    return _GradeRow(
                      examName: g['exam_name'] ?? '-',
                      subject: g['subject'] ?? '-',
                      score: score,
                      maxScore: max,
                      percentage: pct,
                      color: color,
                      index: index,
                    );
                  },
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

  void _showAddGradeDialog(BuildContext context, DataProvider data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final examController = TextEditingController();
    final subjectController = TextEditingController();
    final scoreController = TextEditingController();
    final maxController = TextEditingController(text: '100');
    String? selectedStudentId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        title: Text('إضافة درجة جديدة', style: TextStyle(color: textPrimary)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedStudentId,
                decoration: const InputDecoration(labelText: 'الطالب'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('اختر الطالب')),
                  ...data.students.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.fullName} (${s.code})'),
                      )),
                ],
                onChanged: (v) => selectedStudentId = v,
              ),
              const SizedBox(height: 12),
              TextField(controller: examController, decoration: const InputDecoration(labelText: 'اسم الامتحان')),
              const SizedBox(height: 12),
              TextField(controller: subjectController, decoration: const InputDecoration(labelText: 'المادة')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: scoreController,
                      decoration: const InputDecoration(labelText: 'الدرجة'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: maxController,
                      decoration: const InputDecoration(labelText: 'من'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
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
              onPressed: () {
              if (selectedStudentId != null && examController.text.isNotEmpty) {
                final gradeData = {
                  'student_id': selectedStudentId,
                  'exam_name': examController.text,
                  'subject': subjectController.text,
                  'score': double.tryParse(scoreController.text) ?? 0,
                  'max_score': double.tryParse(maxController.text) ?? 100,
                };
                LocalDB.addToSyncQueue('grade', gradeData);
                LocalDB.saveData(LocalDB.gradesBox, DateTime.now().millisecondsSinceEpoch.toString(), gradeData);
                Navigator.pop(ctx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('تم إضافة الدرجة'),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }
            },
            child: const Text('إضافة'),
          ),  // close ElevatedButton
          ),  // close MouseRegion
        ],
      ),
    );
  }

  Future<void> _importGradesFromCSV(BuildContext context, DataProvider data) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final rows = const CsvDecoder().convert(content);

      if (rows.length < 2) {
        _showSnackBar(context, 'الملف فارغ أو لا يحتوي على بيانات', AppTheme.warning);
        return;
      }

      final headers = rows[0].map((e) => e.toString().trim().toLowerCase()).toList();
      final requiredColumns = ['student_code', 'exam_name', 'score'];
      final missing = requiredColumns.where((c) => !headers.contains(c)).toList();
      if (missing.isNotEmpty) {
        _showSnackBar(context, 'الأعمدة المطلوبة غير موجودة: ${missing.join(', ')}', AppTheme.danger);
        return;
      }

      int added = 0, skipped = 0;
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < headers.length) {
          skipped++;
          continue;
        }

        final rowMap = {for (int j = 0; j < headers.length; j++) headers[j]: row[j].toString().trim()};
        final studentCode = rowMap['student_code'] ?? '';
        final examName = rowMap['exam_name'] ?? '';
        final scoreStr = rowMap['score'] ?? '0';
        final maxStr = rowMap['max_score'] ?? '100';
        final subject = rowMap['subject'] ?? '';

        if (studentCode.isEmpty || examName.isEmpty) {
          skipped++;
          continue;
        }

        final score = double.tryParse(scoreStr) ?? 0;
        final maxScore = double.tryParse(maxStr) ?? 100;

        final gradeData = {
          'student_code': studentCode,
          'exam_name': examName,
          'subject': subject,
          'score': score,
          'max_score': maxScore,
        };
        LocalDB.addToSyncQueue('grade', gradeData);
        LocalDB.saveData(LocalDB.gradesBox, '${studentCode}_${DateTime.now().millisecondsSinceEpoch}_$i', gradeData);
        added++;
      }

      setState(() {});
      _showSnackBar(context, 'تم استيراد $added درجة بنجاح (تم تخطي $skipped صف)', AppTheme.success);
    } catch (e) {
      _showSnackBar(context, 'فشل استيراد الملف: $e', AppTheme.danger);
    }
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _GradeRow extends StatefulWidget {
  final String examName;
  final String subject;
  final double score;
  final double maxScore;
  final double percentage;
  final Color color;
  final int index;

  const _GradeRow({
    required this.examName,
    required this.subject,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.color,
    required this.index,
  });

  @override
  State<_GradeRow> createState() => _GradeRowState();
}

class _GradeRowState extends State<_GradeRow> with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.01).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _hoverController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, _) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered ? widget.color.withValues(alpha: 0.3) : borderColor,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.examName,
                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        widget.subject,
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${widget.score}/${widget.maxScore}',
                  style: TextStyle(color: textMuted, fontSize: 14),
                ),
                const SizedBox(width: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: widget.color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '${widget.percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: widget.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
