import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:barcode/barcode.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/local_db.dart';
import '../providers/data_provider.dart';
import '../models/student.dart';
import '../models/group.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> with TickerProviderStateMixin {
  String _search = '';
  String _groupId = '';
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
    final students = data.filterStudents(search: _search, groupId: _groupId);
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
                  Row(
                    children: [
                      Text(
                        'الطلاب',
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
                          '${students.length}',
                          style: TextStyle(color: AppTheme.accent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddStudentDialog(context, data),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('إضافة طالب'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'بحث بالاسم أو الكود',
                        prefixIcon: const Icon(Icons.search, size: 20),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: _groupId.isEmpty ? null : _groupId,
                      decoration: const InputDecoration(labelText: 'المجموعة'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('جميع المجموعات')),
                        ...data.groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))),
                      ],
                      onChanged: (v) => setState(() => _groupId = v ?? ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (data.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (students.isEmpty)
                Container(
                  padding: const EdgeInsets.all(60),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 56, color: textMuted),
                      const SizedBox(height: 16),
                      Text('لا يوجد طلاب', style: TextStyle(color: textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('أضف طالبك الأول للبدء', style: TextStyle(color: textMuted, fontSize: 13)),
                      const SizedBox(height: 20),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddStudentDialog(context, data),
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('إضافة طالب جديد'),
                        ),
                      ),
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return _StudentCard(
                      student: student,
                      index: index,
                      onAnalyze: () => _showStudentAnalysis(context, data, student),
                      onShowBarcode: () => _showStudentBarcode(context, student),
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

  void _showAddStudentDialog(BuildContext context, DataProvider data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final parentPhoneController = TextEditingController();
    final parentPhone2Controller = TextEditingController();
    String? selectedGradeLevel;
    String? selectedGroupId;

    final levels = ['أولى إعدادي', 'ثانية إعدادي', 'ثالثة إعدادي', 'أولى ثانوي', 'ثانية ثانوي', 'ثالثة ثانوي'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          title: Text('إضافة طالب جديد', style: TextStyle(color: textPrimary)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل للطالب *',
                      hintText: 'الاسم الثلاثي',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'رقم هاتف الطالب *',
                      hintText: '01xxxxxxxxx',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: parentPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'رقم ولي الأمر (أب) *',
                      hintText: '01xxxxxxxxx',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: parentPhone2Controller,
                    decoration: const InputDecoration(
                      labelText: 'رقم ولي الأمر الآخر (أم)',
                      hintText: 'اختياري',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedGradeLevel,
                    decoration: const InputDecoration(labelText: 'المرحلة الدراسية *'),
                    items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setDialogState(() {
                      selectedGradeLevel = v;
                      selectedGroupId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedGroupId,
                    decoration: const InputDecoration(labelText: 'المجموعة *'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('اختر المجموعة')),
                      ...data.groups
                          .where((g) => selectedGradeLevel == null || g.level == selectedGradeLevel)
                          .map((g) => DropdownMenuItem(value: g.id, child: Text('${g.name} - ${g.subject}'))),
                    ],
                    onChanged: (v) => setDialogState(() => selectedGroupId = v),
                    disabledHint: const Text('اختر المرحلة أولاً'),
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
                if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty && parentPhoneController.text.isNotEmpty && selectedGroupId != null) {
                  final rng = math.Random();
                  final code = 'STU-${rng.nextInt(900) + 100}';
                  final student = StudentModel(
                    id: code,
                    code: code,
                    fullName: nameController.text,
                    phone: phoneController.text,
                    parentPhone: parentPhoneController.text,
                    parentPhone2: parentPhone2Controller.text.isNotEmpty ? parentPhone2Controller.text : null,
                    gradeLevel: selectedGradeLevel,
                    groupId: selectedGroupId,
                    createdAt: DateTime.now(),
                  );
                  Navigator.pop(ctx);
                  context.read<DataProvider>().addStudentLocally(student);
                  _showStudentBarcode(context, student);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('برجاء إكمال جميع الحقول المطلوبة (*)'),
                      backgroundColor: AppTheme.warning,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
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

  void _showStudentAnalysis(BuildContext context, DataProvider data, StudentModel student) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final grades = LocalDB.getAllData(LocalDB.gradesBox)
        .where((g) => g['student_code'] == student.code)
        .toList();

    final totalExams = grades.length;
    double avgPercentage = 0;
    double highest = 0;
    double lowest = 100;
    Map<String, double> subjectAverages = {};
    String trend = '';

    if (grades.isNotEmpty) {
      final percentages = grades.map((g) {
        final score = (g['score'] ?? 0).toDouble();
        final max = (g['max_score'] ?? 100).toDouble();
        return max > 0 ? (score / max) * 100 : 0;
      }).toList();

      avgPercentage = percentages.fold(0.0, (a, b) => a + b) / percentages.length;
      highest = percentages.reduce((a, b) => a > b ? a : b);
      lowest = percentages.reduce((a, b) => a < b ? a : b);

      for (final g in grades) {
        final subj = g['subject']?.toString() ?? 'عام';
        final score = (g['score'] ?? 0).toDouble();
        final max = (g['max_score'] ?? 100).toDouble();
        final pct = max > 0 ? (score / max) * 100 : 0;
        subjectAverages.update(subj, (v) => (v + pct) / 2, ifAbsent: () => pct);
      }

      if (percentages.length >= 2) {
        final firstHalf = percentages.sublist(0, percentages.length ~/ 2);
        final secondHalf = percentages.sublist(percentages.length ~/ 2);
        final firstAvg = firstHalf.fold(0.0, (a, b) => a + b) / firstHalf.length;
        final secondAvg = secondHalf.fold(0.0, (a, b) => a + b) / secondHalf.length;
        trend = secondAvg > firstAvg ? 'في تحسن 📈' : secondAvg < firstAvg ? 'في تراجع 📉' : 'مستقر ➡️';
      } else {
        trend = 'لا توجد دراسات كافية لتحليل الاتجاه';
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(student.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(student.fullName, style: TextStyle(color: textPrimary, fontSize: 18))),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text('متوسط الأداء', style: TextStyle(color: textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('${avgPercentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: avgPercentage >= 75 ? AppTheme.success : avgPercentage >= 50 ? AppTheme.warning : AppTheme.danger,
                          fontSize: 36, fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('الاتجاه: $trend', style: TextStyle(color: textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (totalExams > 0) ...[
                  _AnalysisRow(label: 'عدد الامتحانات', value: '$totalExams'),
                  _AnalysisRow(label: 'أعلى درجة', value: '${highest.toStringAsFixed(1)}%', color: AppTheme.success),
                  _AnalysisRow(label: 'أقل درجة', value: '${lowest.toStringAsFixed(1)}%', color: AppTheme.danger),
                ],
                if (subjectAverages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('تحليل المواد:', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...subjectAverages.entries.map((e) => _AnalysisRow(
                    label: e.key,
                    value: '${e.value.toStringAsFixed(1)}%',
                    color: e.value >= 75 ? AppTheme.success : e.value >= 50 ? AppTheme.warning : AppTheme.danger,
                  )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ),
        ],
      ),
    );
  }

  void _showStudentBarcode(BuildContext context, StudentModel student) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(student.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(student.fullName, style: TextStyle(color: textPrimary, fontSize: 18))),
          ],
        ),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CustomPaint(
                  size: const Size(300, 100),
                  painter: _BarcodePainter(student.code),
                ),
              ),
              const SizedBox(height: 16),
              Text(student.code, style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('امسح الباركود لتسجيل الحضور', style: TextStyle(color: textSecondary, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.print, size: 16),
              onPressed: () => _printBarcode(student),
              label: const Text('طباعة'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printBarcode(StudentModel student) async {
    await Printing.layoutPdf(
      onLayout: (format) async {
        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(100, 60, marginAll: 5),
            build: (ctx) => pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: student.code,
                    width: 250,
                    height: 80,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(student.fullName, style: pw.TextStyle(fontSize: 10)),
                  pw.Text(student.code, style: pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          ),
        );
        return pdf.save();
      },
    );
  }
}

class _AnalysisRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _AnalysisRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(color: color ?? textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final String code;
  _BarcodePainter(this.code);

  @override
  void paint(Canvas canvas, Size size) {
    final barcode = Barcode.code128();
    final elements = barcode.make(code, width: size.width, height: size.height, drawText: true);
    for (final elem in elements) {
      if (elem is BarcodeBar) {
        if (elem.black) {
          canvas.drawRect(
            Rect.fromLTWH(elem.left, elem.top, elem.width, elem.height),
            Paint()..color = Colors.black,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StudentCard extends StatefulWidget {
  final StudentModel student;
  final int index;
  final VoidCallback? onAnalyze;
  final VoidCallback? onShowBarcode;
  const _StudentCard({required this.student, required this.index, this.onAnalyze, this.onShowBarcode});

  @override
  State<_StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<_StudentCard> with SingleTickerProviderStateMixin {
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered ? AppTheme.accent.withValues(alpha: 0.3) : borderColor,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      widget.student.initials,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.student.fullName,
                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.student.code,
                        style: TextStyle(
                          color: _isHovered ? AppTheme.accent : textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isHovered)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onAnalyze != null)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: widget.onAnalyze,
                            child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('تحليل', style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (widget.onShowBarcode != null)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: widget.onShowBarcode,
                            child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('باركود', style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_back, size: 16, color: AppTheme.accent),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
