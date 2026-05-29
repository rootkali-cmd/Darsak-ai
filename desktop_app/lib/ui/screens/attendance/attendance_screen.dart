import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/student.dart';
import '../../../core/models/group.dart';

final class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

final class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  String _groupId = '';
  final Map<String, String> _records = {};
  bool _isSaving = false;
  bool _isLoadingExisting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingAttendance());
  }

  String get _dateString => '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  Future<void> _loadExistingAttendance() async {
    final data = context.read<DataProvider>();
    if (_groupId.isEmpty) return;
    setState(() => _isLoadingExisting = true);
    try {
      final records = await data.api.getAttendance(groupId: _groupId, date: _dateString);
      final map = <String, String>{};
      for (final r in records) {
        if (r is Map) {
          final sid = r['student_id']?.toString();
          final status = r['status']?.toString();
          if (sid != null && status != null) {
            map[sid] = status;
          }
        }
      }
      if (mounted) setState(() => _records.addAll(map));
    } catch (_) {}
    if (mounted) setState(() => _isLoadingExisting = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'اختر التاريخ',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _loadExistingAttendance();
    }
  }

  Future<void> _saveAttendance() async {
    final data = context.read<DataProvider>();
    final sync = context.read<SyncProvider>();
    if (_groupId.isEmpty) {
      _showMessage('يرجى اختيار مجموعة', AppTheme.warning);
      return;
    }
    if (_records.isEmpty) {
      _showMessage('لا توجد سجلات لحفظها', AppTheme.warning);
      return;
    }

    setState(() => _isSaving = true);
    int saved = 0;
    int failed = 0;

    final batch = _records.entries.map((e) => {
      'student_id': e.key,
      'group_id': _groupId,
      'status': e.value,
      'date': _dateString,
    }).toList();

    for (final payload in batch) {
      try {
        await data.api.markAttendance(payload);
        saved++;
      } catch (_) {
        failed++;
      }
    }

    setState(() => _isSaving = false);

    if (failed > 0 && saved == 0) {
      _showMessage('فشل حفظ الحضور. تمت الإضافة لقائمة الانتظار.', AppTheme.danger);
    } else if (failed > 0) {
      _showMessage('تم حفظ $saved سجل. $failed سجل في قائمة الانتظار.', AppTheme.warning);
    } else {
      _showMessage('تم حفظ الحضور بنجاح', AppTheme.success);
    }

    sync.syncNow();
  }

  void _markAll(String status) {
    final students = _getFilteredStudents();
    setState(() {
      for (final s in students) {
        _records[s.id] = status;
      }
    });
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  List<StudentModel> _getFilteredStudents() {
    final data = context.read<DataProvider>();
    return data.filterStudents(groupId: _groupId);
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final students = _getFilteredStudents();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    final presentCount = students.where((s) => _records[s.id] == 'present').length;
    final absentCount = students.where((s) => _records[s.id] == 'absent').length;
    final cancelledCount = students.where((s) => _records[s.id] == 'cancelled').length;
    final markedCount = presentCount + absentCount + cancelledCount;

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
                        Text(
                          'تسجيل الحضور',
                          style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDatePicker(textPrimary, textSecondary, surfaceColor, borderColor),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildGroupFilter(data.groups, borderColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildStatsBar(presentCount, absentCount, cancelledCount, markedCount, students.length, textPrimary, textSecondary, textMuted, surfaceColor, borderColor),
                        const SizedBox(height: 16),
                        _buildBulkActions(textPrimary, textSecondary, surfaceColor, borderColor),
                        const SizedBox(height: 20),
                        if (_isLoadingExisting || data.isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (students.isEmpty)
                          _buildEmptyState(textSecondary, textMuted, surfaceColor, borderColor)
                        else
                          ...students.map((s) => _buildStudentRow(s, textPrimary, textSecondary, textMuted, surfaceColor, borderColor, isDark)),
                      ],
                    ),
                  ),
                ),
                _buildSaveButton(surfaceColor, borderColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(Color textPrimary, Color textSecondary, Color surfaceColor, Color borderColor) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: AppTheme.accent),
              const SizedBox(width: 12),
              Text(
                _dateString,
                style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Icon(Icons.arrow_drop_down, color: textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupFilter(List<GroupModel> groups, Color borderColor) {
    return DropdownButtonFormField<String>(
      initialValue: _groupId.isEmpty ? null : _groupId,
      decoration: InputDecoration(
        labelText: 'المجموعة',
        prefixIcon: Icon(Icons.group, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
      ),
      items: [
        DropdownMenuItem(value: null, child: Text('كل المجموعات')),
        ...groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))),
      ],
      onChanged: (v) {
        setState(() {
          _groupId = v ?? '';
          _records.clear();
        });
        if (v != null && v.isNotEmpty) {
          _loadExistingAttendance();
        }
      },
    );
  }

  Widget _buildStatsBar(int present, int absent, int cancelled, int marked, int total, Color textPrimary, Color textSecondary, Color textMuted, Color surfaceColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          _StatItem(label: 'الإجمالي', value: '$total', color: textPrimary),
          Container(width: 1, height: 30, color: borderColor),
          _StatItem(label: 'حاضر', value: '$present', color: AppTheme.success),
          Container(width: 1, height: 30, color: borderColor),
          _StatItem(label: 'غائب', value: '$absent', color: AppTheme.danger),
          Container(width: 1, height: 30, color: borderColor),
          _StatItem(label: 'ملغي', value: '$cancelled', color: AppTheme.warning),
          const Spacer(),
          Text(
            'تم تسجيل $marked من $total',
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActions(Color textPrimary, Color textSecondary, Color surfaceColor, Color borderColor) {
    return Row(
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _markAll('present'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                  const SizedBox(width: 6),
                  Text('تحديد الكل كحاضر', style: TextStyle(color: AppTheme.success, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _markAll('absent'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel, size: 16, color: AppTheme.danger),
                  const SizedBox(width: 6),
                  Text('تحديد الكل كغائب', style: TextStyle(color: AppTheme.danger, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _markAll('cancelled'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.remove_circle, size: 16, color: AppTheme.warning),
                  const SizedBox(width: 6),
                  Text('تحديد الكل كملغي', style: TextStyle(color: AppTheme.warning, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ],
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
          Icon(Icons.people_outline, size: 48, color: textMuted),
          const SizedBox(height: 16),
          Text('لا يوجد طلاب', style: TextStyle(color: textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text('اختر مجموعة لعرض الطلاب', style: TextStyle(color: textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStudentRow(StudentModel student, Color textPrimary, Color textSecondary, Color textMuted, Color surfaceColor, Color borderColor, bool isDark) {
    final status = _records[student.id];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                student.initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  student.code,
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          _StatusChip(
            label: 'حاضر',
            icon: Icons.check,
            color: AppTheme.success,
            isActive: status == 'present',
            onTap: () => setState(() => _records[student.id] = 'present'),
          ),
          const SizedBox(width: 8),
          _StatusChip(
            label: 'غائب',
            icon: Icons.close,
            color: AppTheme.danger,
            isActive: status == 'absent',
            onTap: () => setState(() => _records[student.id] = 'absent'),
          ),
          const SizedBox(width: 8),
          _StatusChip(
            label: 'ملغي',
            icon: Icons.remove,
            color: AppTheme.warning,
            isActive: status == 'cancelled',
            onTap: () => setState(() => _records[student.id] = 'cancelled'),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(Color surfaceColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          if (_isSaving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (_isSaving) const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAttendance,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 18),
              label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ الحضور'),
            ),
          ),
        ],
      ),
    );
  }
}

final class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

final class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.1) : surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? color : borderColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isActive ? color : textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? color : textMuted,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
