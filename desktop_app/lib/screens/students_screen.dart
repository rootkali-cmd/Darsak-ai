import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:barcode/barcode.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/local_db.dart';
import '../core/subscription_service.dart';
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
  bool _showNoPinOnly = false;
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
    final filteredStudents = _showNoPinOnly ? students.where((s) => !s.hasPin).toList() : students;
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
                          '${filteredStudents.length}',
                          style: TextStyle(color: AppTheme.accent, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_showNoPinOnly)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('بدون PIN', style: TextStyle(color: AppTheme.danger, fontSize: 10)),
                        ),
                    ],
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final canAdd = await _canAddStudent();
                        if (!mounted) return;
                        if (canAdd) _showAddStudentDialog(context, data);
                      },
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
                  const SizedBox(width: 12),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showNoPinOnly = !_showNoPinOnly),
                      icon: Icon(
                        Icons.lock_open,
                        size: 18,
                        color: _showNoPinOnly ? AppTheme.danger : textMuted,
                      ),
                      label: Text(
                        'بدون PIN',
                        style: TextStyle(
                          color: _showNoPinOnly ? AppTheme.danger : textMuted,
                          fontWeight: _showNoPinOnly ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (data.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (filteredStudents.isEmpty)
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
                      Text(_showNoPinOnly ? 'جميع الطلاب لديهم PIN' : 'لا يوجد طلاب', style: TextStyle(color: textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(_showNoPinOnly ? 'كل الطلاب لديهم رمز سري' : 'أضف طالبك الأول للبدء', style: TextStyle(color: textMuted, fontSize: 13)),
                      const SizedBox(height: 20),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final canAdd = await _canAddStudent();
                            if (!mounted) return;
                            if (canAdd) _showAddStudentDialog(context, data);
                          },
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
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    return _StudentCard(
                      student: student,
                      index: index,
                      onAnalyze: () => _showStudentAnalysis(context, data, student),
                      onShowBarcode: () => _showStudentBarcode(context, student),
                      onSetPin: () => _showSetPinDialog(context, student),
                      onDelete: () => _showDeleteStudentDialog(context, data, student),
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

  Future<bool> _canAddStudent() async {
    final sub = SubscriptionService();
    final cached = await sub.getCachedSubscription();
    if (!mounted) return false;
    final data = context.read<DataProvider>();
    final currentCount = data.students.length;
    if (cached == null) return true;
    final limitStr = cached['student_limit']?.toString();
    if (limitStr == null) return true;
    if (limitStr.contains('غير محدود')) return true;
    final limit = int.tryParse(limitStr);
    if (limit != null && currentCount >= limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لقد تجاوزت الحد المسموح به من الطلاب في باقتك'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    return true;
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
                onPressed: () async {
                if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty && parentPhoneController.text.isNotEmpty && selectedGroupId != null) {
                  final rng = math.Random();
                  final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
                  final code = 'ST${List.generate(7, (_) => chars[rng.nextInt(chars.length)]).join()}';
                  final now = DateTime.now();
                  var student = StudentModel(
                    id: code,
                    code: code,
                    fullName: nameController.text,
                    phone: phoneController.text,
                    parentPhone: parentPhoneController.text,
                    parentPhone2: parentPhone2Controller.text.isNotEmpty ? parentPhone2Controller.text : null,
                    gradeLevel: selectedGradeLevel,
                    groupId: selectedGroupId,
                    createdAt: now,
                  );
                  Navigator.pop(ctx);
                  final data = context.read<DataProvider>();
                  // Add locally first (offline-first) — sync queue will push to server later
                  data.addStudentLocally(student);
                  // Also try server immediately; on success, update ID and mark sync queue synced
                  try {
                    final created = await data.api.createStudent(student.toJson());
                    final serverId = created['id']?.toString();
                    if (serverId != null && serverId != code) {
                      data.updateStudentId(code, serverId);
                      student = StudentModel(
                        id: serverId,
                        code: student.code,
                        fullName: student.fullName,
                        phone: student.phone,
                        parentPhone: student.parentPhone,
                        parentPhone2: student.parentPhone2,
                        gradeLevel: student.gradeLevel,
                        groupId: student.groupId,
                        createdAt: now,
                      );
                    }
                    LocalDB.markSyncItemSynced(student.toJson());
                  } catch (_) {
                    // Server unreachable — sync queue handles it later
                  }
                  if (!context.mounted) return;
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

  Future<void> _showSetPinDialog(BuildContext context, StudentModel student) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    // Fetch PIN status first
    String? statusText;
    bool? hasPin;
    try {
      final res = await context.read<DataProvider>().api.getStudentPinStatus(student.id);
      hasPin = res['has_pin'] == true;
      statusText = hasPin == true ? 'الطالب لديه PIN بالفعل' : 'الطالب ليس لديه PIN';
    } catch (_) {
      statusText = 'لا يمكن التحقق من حالة PIN';
    }

    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          title: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(child: Icon(Icons.lock, color: Colors.white, size: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('PIN: ${student.fullName}', style: TextStyle(color: textPrimary, fontSize: 16))),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (statusText != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (hasPin == true ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasPin == true ? Icons.check_circle : Icons.info,
                            size: 14,
                            color: hasPin == true ? AppTheme.success : AppTheme.warning,
                          ),
                          const SizedBox(width: 6),
                          Text(statusText!, style: TextStyle(color: textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    decoration: const InputDecoration(
                      labelText: 'PIN الجديد (6-8 أحرف وأرقام)',
                      hintText: 'مثال: ABC123',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      _UpperCaseTextFormatter(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    decoration: const InputDecoration(
                      labelText: 'تأكيد PIN',
                      hintText: 'أعد كتابة PIN',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      _UpperCaseTextFormatter(),
                    ],
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
                  final pin = pinController.text.trim();
                  final confirm = confirmController.text.trim();
                  if (pin.length < 6 || pin.length > 8) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN يجب أن يكون 6-8 أحرف وأرقام'), backgroundColor: AppTheme.warning));
                    return;
                  }
                  if (pin != confirm) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN غير متطابق'), backgroundColor: AppTheme.warning));
                    return;
                  }
                  setDialogState(() => {});
                  try {
                    final data = context.read<DataProvider>();
                    await data.api.resetStudentPin(student.id, pin);
                    data.updateStudentPinStatus(student.id, true);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('تم تعيين PIN للطالب ${student.fullName}'),
                      backgroundColor: AppTheme.success,
                    ));
                  } catch (e) {
                    final errStr = e.toString();
                    String msg;
                    if (errStr.contains('404')) {
                      msg = 'الطالب غير موجود على الخادم، قم بمزامنة البيانات أولاً';
                    } else if (errStr.contains('422')) {
                      msg = 'PIN غير صالح (6-8 أحرف وأرقام إنجليزية)';
                    } else {
                      msg = 'فشل تعيين PIN';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.danger));
                  }
                },
                child: Text(hasPin == true ? 'إعادة تعيين' : 'تعيين PIN'),
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

  Future<void> _showDeleteStudentDialog(BuildContext context, DataProvider data, StudentModel student) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 24),
            const SizedBox(width: 12),
            Text('حذف الطالب', style: TextStyle(color: textPrimary, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('هل أنت متأكد من حذف الطالب؟', style: TextStyle(color: textSecondary, fontSize: 15)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text(student.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.fullName, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                        Text(student.code, style: TextStyle(color: textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('جميع درجات وسجلات الحضور الخاصة به سيتم حذفها أيضًا.', style: TextStyle(color: AppTheme.danger, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Try to delete from backend first
    String? errorMsg;
    try {
      await data.api.deleteStudent(student.id);
    } catch (e) {
      errorMsg = e.toString().contains('404') ? 'الطالب غير موجود على الخادم' : 'فشل حذف الطالب من الخادم';
    }

    if (!context.mounted) return;

    // Remove locally regardless of backend result
    data.removeStudent(student.id, student.code);

    if (errorMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMsg),
        backgroundColor: AppTheme.warning,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تم حذف الطالب ${student.fullName}'),
        backgroundColor: AppTheme.success,
      ));
    }
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

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class _StudentCard extends StatefulWidget {
  final StudentModel student;
  final int index;
  final VoidCallback? onAnalyze;
  final VoidCallback? onShowBarcode;
  final VoidCallback? onSetPin;
  final VoidCallback? onDelete;
  const _StudentCard({required this.student, required this.index, this.onAnalyze, this.onShowBarcode, this.onSetPin, this.onDelete});

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
                      if (!widget.student.hasPin)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'بدون PIN',
                            style: TextStyle(color: AppTheme.danger, fontSize: 9, fontWeight: FontWeight.w600),
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
                      const SizedBox(width: 6),
                      if (widget.onSetPin != null)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: widget.onSetPin,
                            child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('PIN', style: TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      if (widget.onDelete != null) ...[
                        const SizedBox(width: 6),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: widget.onDelete,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.danger.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('حذف', style: TextStyle(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
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
