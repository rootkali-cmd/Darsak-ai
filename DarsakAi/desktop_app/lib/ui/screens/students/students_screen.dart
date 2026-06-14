import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/student.dart';
import '../../../core/models/group.dart';
import 'student_profile_screen.dart';

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

  String _getGroupName(String? groupId, List<GroupModel> groups) {
    if (groupId == null || groupId.isEmpty) return '—';
    final group = groups.where((g) => g.id == groupId).firstOrNull;
    return group?.name ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final sync = context.watch<SyncProvider>();
    final students = data.filterStudents(search: _search, groupId: _groupId);
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
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              initialValue: _groupId.isEmpty ? null : _groupId,
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
                              Text(
                                _search.isNotEmpty || _groupId.isNotEmpty
                                    ? 'لا توجد نتائج للبحث'
                                    : 'أضف طالبك الأول للبدء',
                                style: TextStyle(color: textMuted, fontSize: 13),
                              ),
                              if (_search.isEmpty && _groupId.isEmpty) ...[
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
                            childAspectRatio: 2.8,
                          ),
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            return Dismissible(
                              key: Key(student.id),
                              direction: DismissDirection.horizontal,
                              confirmDismiss: (_) => _confirmDeleteStudent(context, data, student),
                              background: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.danger,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 24),
                                child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                              ),
                              secondaryBackground: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.danger,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                              ),
                              child: _StudentCard(
                                student: student,
                                groupName: _getGroupName(student.groupId, data.groups),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StudentProfileScreen(
                                        student: student,
                                        groupName: _getGroupName(student.groupId, data.groups),
                                      ),
                                    ),
                                  );
                                },
                                onAnalyze: () => _showStudentAnalysis(context, student, data.groups),
                                onDelete: () => _confirmDeleteStudent(context, data, student),
                              ),
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
                      labelText: 'الاسم الكامل *',
                      hintText: 'الاسم الثلاثي',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      hintText: '01xxxxxxxxx',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: parentPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'رقم ولي الأمر',
                      hintText: '01xxxxxxxxx',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: parentPhone2Controller,
                    decoration: const InputDecoration(
                      labelText: 'رقم ولي الأمر الآخر',
                      hintText: 'اختياري',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGradeLevel,
                    decoration: const InputDecoration(labelText: 'المرحلة الدراسية'),
                    items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setDialogState(() {
                      selectedGradeLevel = v;
                      selectedGroupId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGroupId,
                    decoration: const InputDecoration(labelText: 'المجموعة'),
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
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('الاسم الكامل مطلوب'),
                        backgroundColor: AppTheme.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  if (selectedGroupId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى اختيار مجموعة'),
                        backgroundColor: AppTheme.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  final rng = math.Random();
                  final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
                  final code = 'ST${List.generate(7, (_) => chars[rng.nextInt(chars.length)]).join()}';
                  final student = StudentModel(
                    id: code,
                    code: code,
                    fullName: nameController.text.trim(),
                    phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                    parentPhone: parentPhoneController.text.trim().isNotEmpty ? parentPhoneController.text.trim() : null,
                    parentPhone2: parentPhone2Controller.text.trim().isNotEmpty ? parentPhone2Controller.text.trim() : null,
                    gradeLevel: selectedGradeLevel,
                    groupId: selectedGroupId,
                    createdAt: DateTime.now(),
                  );
                  Navigator.pop(ctx);
                  context.read<DataProvider>().addStudentLocally(student);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تمت الإضافة'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('إضافة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteStudent(BuildContext context, DataProvider data, StudentModel student) async {
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
              Text('سيتم حذف جميع بيانات الطالب.', style: TextStyle(color: AppTheme.danger, fontSize: 12)),
            ],
          ),
        ),
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
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      data.removeStudent(student.id, student.code);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف ${student.fullName}'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    return confirmed ?? false;
  }

  void _showStudentAnalysis(BuildContext context, StudentModel student, List<GroupModel> groups) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final groupName = _getGroupName(student.groupId, groups);

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
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accent.withValues(alpha: 0.08), AppTheme.accentLight.withValues(alpha: 0.04)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.auto_awesome, size: 32, color: AppTheme.accent),
                    const SizedBox(height: 8),
                    Text('التحليل الذكي', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('تحليل أداء الطالب باستخدام الذكاء الاصطناعي', style: TextStyle(color: textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _infoRow('الكود', student.code, textPrimary, textSecondary),
              _infoRow('المجموعة', groupName, textPrimary, textSecondary),
              _infoRow('الهاتف', student.phone ?? '—', textPrimary, textSecondary),
              _infoRow('ولي الأمر', student.parentPhone ?? '—', textPrimary, textSecondary),
              _infoRow('المرحلة', student.gradeLevel ?? '—', textPrimary, textSecondary),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (student.isPaid ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(student.isPaid ? Icons.check_circle : Icons.cancel, size: 14, color: student.isPaid ? AppTheme.success : AppTheme.danger),
                          const SizedBox(width: 6),
                          Text(student.isPaid ? 'مدفوع' : 'غير مدفوع', style: TextStyle(color: student.isPaid ? AppTheme.success : AppTheme.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (student.hasPin ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(student.hasPin ? Icons.lock : Icons.lock_open, size: 14, color: student.hasPin ? AppTheme.success : AppTheme.warning),
                          const SizedBox(width: 6),
                          Text(student.hasPin ? 'لديه PIN' : 'بدون PIN', style: TextStyle(color: student.hasPin ? AppTheme.success : AppTheme.warning, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
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
            child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StudentCard extends StatefulWidget {
  final StudentModel student;
  final String groupName;
  final VoidCallback? onTap;
  final VoidCallback? onAnalyze;
  final VoidCallback? onDelete;

  const _StudentCard({
    required this.student,
    required this.groupName,
    this.onTap,
    this.onAnalyze,
    this.onDelete,
  });

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
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.translucent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  // Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        widget.student.initials,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name + badges
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.student.fullName,
                                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _Badge(
                              text: widget.student.isPaid ? 'مدفوع' : 'غير مدفوع',
                              color: widget.student.isPaid ? AppTheme.success : AppTheme.danger,
                            ),
                            if (!widget.student.hasPin) ...[
                              const SizedBox(width: 4),
                              _Badge(text: 'بدون PIN', color: AppTheme.warning),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Code + group only (no phone to save space)
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.student.code,
                                style: TextStyle(
                                  color: _isHovered ? AppTheme.accent : textMuted,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.people, size: 11, color: textMuted),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                widget.groupName,
                                style: TextStyle(color: textMuted, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Hover actions — icon only, compact
                  if (_isHovered)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onAnalyze != null)
                          _IconBtn(
                            icon: Icons.auto_awesome,
                            color: AppTheme.accent,
                            tooltip: 'تحليل',
                            onTap: widget.onAnalyze!,
                          ),
                        if (widget.onDelete != null)
                          _IconBtn(
                            icon: Icons.delete,
                            color: AppTheme.danger,
                            tooltip: 'حذف',
                            onTap: widget.onDelete!,
                          ),
                        if (widget.onTap != null)
                          _IconBtn(
                            icon: Icons.arrow_back,
                            color: AppTheme.accent,
                            tooltip: 'فتح الملف',
                            onTap: widget.onTap!,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Compact helper widgets ──

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
