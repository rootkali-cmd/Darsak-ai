import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/student.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/database_service.dart';
import '../../../providers/data_provider.dart';

/// Compact student profile with inline stats and clean tab layout.
class StudentProfileScreen extends StatefulWidget {
  final StudentModel student;
  final String groupName;

  const StudentProfileScreen({
    super.key,
    required this.student,
    required this.groupName,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _pinController = TextEditingController();
  bool _isResettingPin = false;

  int _presentCount = 0;
  int _absentCount = 0;
  int _lateCount = 0;
  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStudentData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _loadStudentData() {
    final db = DatabaseService.instance;
    final allAttendance = db.getAllAttendance();
    _attendance = allAttendance.where((a) => a['student_id'] == widget.student.id).toList();
    _presentCount = _attendance.where((a) => a['status'] == 'present').length;
    _absentCount = _attendance.where((a) => a['status'] == 'absent').length;
    _lateCount = _attendance.where((a) => a['status'] == 'late').length;

    _grades = db.getAllGrades().where((g) => g['student_id'] == widget.student.id).toList();
    _invoices = db.getAllInvoices().where((i) => i['student_id'] == widget.student.id).toList();
    setState(() {});
  }

  Future<void> _resetPin() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty || pin.length < 4) {
      _showSnackbar('PIN يجب أن يكون 4 أرقام على الأقل', isError: true);
      return;
    }
    setState(() => _isResettingPin = true);
    try {
      final data = context.read<DataProvider>();
      final ok = await data.resetStudentPin(widget.student.id, pin);
      _pinController.clear();
      if (!mounted) return;
      _showSnackbar(ok ? 'تم إنشاء PIN بنجاح' : 'تم الحفظ. سيتم المزامنة تلقائياً عند الاتصال', isWarning: !ok);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('تم الحفظ محلياً. سيتم المزامنة لاحقاً.', isWarning: true);
    } finally {
      if (mounted) setState(() => _isResettingPin = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false, bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.danger : isWarning ? AppTheme.warning : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPinDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.student.hasPin ? 'تغيير PIN' : 'إنشاء PIN'),
        content: TextField(
          controller: _pinController,
          decoration: const InputDecoration(labelText: 'PIN جديد', hintText: '****'),
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _isResettingPin ? null : () { Navigator.pop(ctx); _resetPin(); },
            child: _isResettingPin
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    final totalDays = _presentCount + _absentCount + _lateCount;
    final attendanceRate = totalDays > 0 ? (_presentCount / totalDays * 100).round() : 0;

    return Scaffold(
      body: Column(
        children: [
          // ── Compact Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                // Back
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, size: 18, color: AppTheme.accent),
                        const SizedBox(width: 6),
                        Text('عودة', style: TextStyle(color: AppTheme.accent, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Avatar (compact 40x40)
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
                // Name + details (single column, compact)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.student.fullName,
                        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.student.code}  ·  ${widget.groupName}',
                        style: TextStyle(color: textMuted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // PIN button (small, icon-only when space is tight)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _showPinDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.student.hasPin
                            ? AppTheme.success.withValues(alpha: 0.12)
                            : AppTheme.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.student.hasPin ? Icons.lock : Icons.lock_open,
                            size: 12,
                            color: widget.student.hasPin ? AppTheme.success : AppTheme.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.student.hasPin ? 'PIN' : 'بدون',
                            style: TextStyle(
                              color: widget.student.hasPin ? AppTheme.success : AppTheme.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
          // ── Inline Stats Row ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _StatPill(
                  label: 'حضور',
                  value: '$attendanceRate%',
                  color: attendanceRate >= 80 ? AppTheme.success : attendanceRate >= 50 ? AppTheme.warning : AppTheme.danger,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: 'درجات',
                  value: '${_grades.length}',
                  color: AppTheme.accent,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: 'فواتير',
                  value: '${_invoices.length}',
                  color: AppTheme.accentLight,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: 'حالة',
                  value: widget.student.isPaid ? 'مدفوع' : 'غير مدفوع',
                  color: widget.student.isPaid ? AppTheme.success : AppTheme.danger,
                ),
              ],
            ),
          ),
          // ── Tab Bar ──
          TabBar(
            controller: _tabController,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: const [
              Tab(text: 'الحضور'),
              Tab(text: 'الدرجات'),
              Tab(text: 'الفواتير'),
              Tab(text: 'معلومات'),
            ],
            labelColor: AppTheme.accent,
            unselectedLabelColor: textMuted,
            indicatorColor: AppTheme.accent,
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
          ),
          Divider(height: 1, color: borderColor),
          // ── Tab Content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAttendanceTab(textPrimary, textMuted),
                _buildGradesTab(textPrimary, textMuted),
                _buildInvoicesTab(textPrimary, textMuted),
                _buildInfoTab(textPrimary, textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab builders ──

  Widget _buildAttendanceTab(Color textPrimary, Color textMuted) {
    if (_attendance.isEmpty) {
      return _EmptyState(icon: Icons.event_available, message: 'لا يوجد سجل حضور');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _attendance.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final record = _attendance[i];
        final status = record['status']?.toString() ?? '';
        final statusColor = status == 'present' ? AppTheme.success : status == 'absent' ? AppTheme.danger : AppTheme.warning;
        final statusText = status == 'present' ? 'حاضر' : status == 'absent' ? 'غائب' : 'متأخر';
        return _ListRow(
          leading: Icon(
            status == 'present' ? Icons.check_circle : status == 'absent' ? Icons.cancel : Icons.access_time,
            size: 18,
            color: statusColor,
          ),
          title: statusText,
          subtitle: record['date']?.toString() ?? '--',
          titleColor: textPrimary,
          subtitleColor: textMuted,
        );
      },
    );
  }

  Widget _buildGradesTab(Color textPrimary, Color textMuted) {
    if (_grades.isEmpty) {
      return _EmptyState(icon: Icons.grade, message: 'لا يوجد درجات مسجلة');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _grades.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final grade = _grades[i];
        final score = (grade['score'] ?? 0).toDouble();
        final maxScore = (grade['max_score'] ?? 100).toDouble();
        final percentage = maxScore > 0 ? (score / maxScore * 100).round() : 0;
        final gradeColor = percentage >= 85 ? AppTheme.success : percentage >= 60 ? AppTheme.warning : AppTheme.danger;
        return _ListRow(
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: gradeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text('$percentage%', style: TextStyle(color: gradeColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          title: grade['exam_name']?.toString() ?? 'امتحان',
          subtitle: '${score.toStringAsFixed(0)} / ${maxScore.toStringAsFixed(0)}  ${grade['subject']?.toString() ?? ''}',
          titleColor: textPrimary,
          subtitleColor: textMuted,
        );
      },
    );
  }

  Widget _buildInvoicesTab(Color textPrimary, Color textMuted) {
    if (_invoices.isEmpty) {
      return _EmptyState(icon: Icons.receipt, message: 'لا يوجد فواتير');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final invoice = _invoices[i];
        final isPaid = invoice['paid'] == true || invoice['paid'] == 1;
        return _ListRow(
          leading: Icon(isPaid ? Icons.check_circle : Icons.pending, size: 18, color: isPaid ? AppTheme.success : AppTheme.warning),
          title: '${invoice['amount']?.toString() ?? '--'} ج.م',
          subtitle: invoice['description']?.toString() ?? '',
          titleColor: textPrimary,
          subtitleColor: textMuted,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isPaid ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(isPaid ? 'مدفوع' : 'معلق', style: TextStyle(color: isPaid ? AppTheme.success : AppTheme.warning, fontSize: 11)),
          ),
        );
      },
    );
  }

  Widget _buildInfoTab(Color textPrimary, Color textMuted) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(title: 'المعلومات الأساسية', rows: [
          _InfoLine(label: 'الاسم', value: widget.student.fullName),
          _InfoLine(label: 'الكود', value: widget.student.code),
          _InfoLine(label: 'المجموعة', value: widget.groupName),
          if (widget.student.gradeLevel != null)
            _InfoLine(label: 'المرحلة', value: widget.student.gradeLevel!),
        ]),
        const SizedBox(height: 10),
        _InfoCard(title: 'الاتصال', rows: [
          if (widget.student.phone != null)
            _InfoLine(label: 'الهاتف', value: widget.student.phone!),
          if (widget.student.parentPhone != null)
            _InfoLine(label: 'ولي الأمر', value: widget.student.parentPhone!),
          if (widget.student.parentPhone2 != null)
            _InfoLine(label: 'ولي الأمر ٢', value: widget.student.parentPhone2!),
        ]),
        const SizedBox(height: 10),
        _InfoCard(title: 'الحالة', rows: [
          _InfoLine(label: 'الاشتراك', value: widget.student.isPaid ? 'مدفوع' : 'غير مدفوع'),
          _InfoLine(label: 'PIN', value: widget.student.hasPin ? 'مفعل' : 'غير مفعل'),
        ]),
      ],
    );
  }
}

// ── Compact Widgets ──

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final textMuted = Theme.of(context).brightness == Brightness.dark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;
  final Widget? trailing;
  const _ListRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w500)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 11)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.darkTextPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppTheme.darkTextMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppTheme.darkTextPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
