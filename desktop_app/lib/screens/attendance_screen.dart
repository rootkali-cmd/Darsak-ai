import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/local_db.dart';
import '../core/api_service.dart';
import '../providers/data_provider.dart';
import '../providers/sync_provider.dart';
import '../models/student.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with TickerProviderStateMixin {
  String _groupId = '';
  String _selectedDay = '';
  DateTime _weekStart = _getWeekStart(DateTime.now());
  final Map<String, String> _records = {};
  final TextEditingController _scannerController = TextEditingController();
  final FocusNode _scannerFocus = FocusNode();
  late AnimationController _listController;
  late Animation<double> _listAnimation;

  static DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - DateTime.saturday));
  }

  String _formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<String> _getLectureDates() {
    if (_groupId.isEmpty) return [];
    final group = context.read<DataProvider>().groups.where((g) => g.id == _groupId).firstOrNull;
    if (group == null) return [];
    final days = group.dayOfWeek.split(' / ');
    final dayMap = {'السبت': DateTime.saturday, 'الأحد': DateTime.sunday, 'الإثنين': DateTime.monday, 'الثلاثاء': DateTime.tuesday, 'الأربعاء': DateTime.wednesday, 'الخميس': DateTime.thursday};
    return days.map((d) {
      final target = dayMap[d];
      if (target == null) return '';
      final diff = target - _weekStart.weekday;
      final date = _weekStart.add(Duration(days: diff < 0 ? diff + 7 : diff));
      return _formatDate(date);
    }).where((d) => d.isNotEmpty).toList();
  }

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
    _scannerController.dispose();
    _scannerFocus.dispose();
    super.dispose();
  }

  void _markAndSync(String studentId, String status, StudentModel student, BuildContext context) {
    if (_selectedDay.isEmpty) {
      _selectedDay = _formatDate(DateTime.now());
    }
    setState(() => _records[studentId] = status);

    final data = {
      'student_id': studentId,
      'group_id': _groupId,
      'lecture_id': '${_groupId}_${_formatDate(_weekStart)}',
      'status': status,
      'date': _selectedDay,
    };

    LocalDB.addToSyncQueue('attendance', data);
    // Sync immediately
    context.read<SyncProvider>().syncNow();
  }

  void _handleBarcodeScan(String code, BuildContext context) {
    final data = context.read<DataProvider>();
    final codeTrimmed = code.trim().toUpperCase();
    final student = data.students.where((s) => s.code.toUpperCase() == codeTrimmed).firstOrNull;

    if (student == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لم يتم العثور على طالب بالكود: $codeTrimmed'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      _scannerController.clear();
      return;
    }

    // Check payment status
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final payment = LocalDB.getData(LocalDB.paymentsBox, '${student.id}_$monthKey');
    final isPaid = payment != null && payment['is_paid'] == true;

    // Check recent attendance
    final today = _formatDate(now);
    final attendanceRecords = LocalDB.getAllData(LocalDB.attendanceBox)
        .where((a) => a['student_id'] == student.id && a['date'] == today)
        .toList();

    // Check pending items from grades box (assignments/exams with low scores)
    final grades = LocalDB.getAllData(LocalDB.gradesBox)
        .where((g) => g['student_code'] == student.code)
        .toList();
    final pendingExams = grades.where((g) {
      final score = (g['score'] ?? 0).toDouble();
      final max = (g['max_score'] ?? 100).toDouble();
      return max > 0 && (score / max) < 0.5;
    }).toList();

    setState(() {
      _groupId = student.groupId ?? '';
      if (attendanceRecords.isNotEmpty) {
        _records[student.id] = attendanceRecords.first['status'] as String;
      }
    });

    _scannerController.clear();
    _scannerFocus.requestFocus();

    // Show student info dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Center(child: Text(student.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(student.fullName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18))),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScanInfoRow(label: 'الكود', value: student.code),
              _ScanInfoRow(label: 'رقم الهاتف', value: student.phone ?? '-'),
              _ScanInfoRow(label: 'المجموعة', value: data.groups.where((g) => g.id == student.groupId).firstOrNull?.name ?? '-'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isPaid ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(isPaid ? Icons.check_circle : Icons.warning, size: 18, color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Text(
                      isPaid ? 'حالة الدفع: مدفوع' : 'حالة الدفع: غير مدفوع',
                      style: TextStyle(color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (attendanceRecords.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, size: 18, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('تم تسجيل حضور اليوم: ${attendanceRecords.first['status'] == 'present' ? 'حاضر' : attendanceRecords.first['status'] == 'absent' ? 'غائب' : 'ملغي'}', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              if (pendingExams.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_late, size: 18, color: Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('لديه ${pendingExams.length} امتحان/تسميع يحتاج تحسين', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              if (attendanceRecords.isEmpty && pendingExams.isEmpty && isPaid)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, size: 18, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Expanded(child: Text('لا توجد مشاكل - كل شيء تمام', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: () {
                _markAndSync(student.id, 'present', student, context);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              child: const Text('تسجيل حضور'),
            ),
          ),
          const SizedBox(width: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final students = data.filterStudents(groupId: _groupId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
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
                      Text(
                        'الحضور والغياب',
                        style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _scannerController,
                              focusNode: _scannerFocus,
                              decoration: InputDecoration(
                                labelText: 'مسح الباركود',
                                hintText: 'امسح باركود الطالب',
                                prefixIcon: const Icon(Icons.qr_code_scanner, size: 20),
                              ),
                              onSubmitted: (value) {
                                if (value.isNotEmpty) _handleBarcodeScan(value, context);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                if (_scannerController.text.isNotEmpty) {
                                  _handleBarcodeScan(_scannerController.text, context);
                                }
                              },
                              tooltip: 'بحث',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _groupId.isEmpty ? null : _groupId,
                              decoration: const InputDecoration(labelText: 'المجموعة'),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('جميع المجموعات')),
                                ...data.groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _groupId = v ?? '';
                                  _weekStart = _AttendanceScreenState._getWeekStart(DateTime.now());
                                });
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    final dates = _getLectureDates();
                                    if (dates.isNotEmpty) setState(() => _selectedDay = dates.first);
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (_groupId.isNotEmpty)
                            ..._getLectureDates().map((d) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: ChoiceChip(
                                  label: Text(d),
                                  selected: _selectedDay == d,
                                  onSelected: (_) => setState(() => _selectedDay = d),
                                  selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                                ),
                              ),
                            )),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 200,
                            child: TextField(
                              decoration: const InputDecoration(labelText: 'الأسبوع'),
                              controller: TextEditingController(text: _formatDate(_weekStart)),
                              readOnly: true,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _weekStart,
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _weekStart = _AttendanceScreenState._getWeekStart(picked);
                                    if (_getLectureDates().contains(_formatDate(picked))) {
                                      _selectedDay = _formatDate(picked);
                                    } else {
                                      _selectedDay = _getLectureDates().firstOrNull ?? _formatDate(picked);
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (data.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (students.isEmpty)
                        Center(
                          child: Text('لا يوجد طلاب', style: TextStyle(color: textMuted)),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            final status = _records[student.id];
                            final now = DateTime.now();
                            final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
                            final payment = LocalDB.getData(LocalDB.paymentsBox, '${student.id}_$monthKey');
                            final isPaid = payment != null && payment['is_paid'] == true;
                            return _AttendanceRow(
                              student: student,
                              status: status,
                              index: index,
                              isPaid: isPaid,
                              onStatusChanged: (s) => setState(() => _records[student.id] = s),
                              onSave: () {
                                if (status != null && _selectedDay.isNotEmpty) {
                                  _markAndSync(student.id, status, student, context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('تم تسجيل الحضور'),
                                      backgroundColor: AppTheme.success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  );
                                }
                              },
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
}

class _AttendanceRow extends StatefulWidget {
  final StudentModel student;
  final String? status;
  final int index;
  final bool isPaid;
  final Function(String) onStatusChanged;
  final VoidCallback onSave;

  const _AttendanceRow({
    required this.student,
    required this.status,
    required this.index,
    required this.isPaid,
    required this.onStatusChanged,
    required this.onSave,
  });

  @override
  State<_AttendanceRow> createState() => _AttendanceRowState();
}

class _AttendanceRowState extends State<_AttendanceRow> with SingleTickerProviderStateMixin {
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
                color: _isHovered ? AppTheme.accent.withValues(alpha: 0.2) : borderColor,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.04),
                        blurRadius: 12,
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      widget.student.initials,
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
                        widget.student.fullName,
                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        widget.student.code,
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.isPaid ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: widget.isPaid ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.isPaid ? Icons.check_circle : Icons.warning, size: 14, color: widget.isPaid ? AppTheme.success : AppTheme.danger),
                      const SizedBox(width: 4),
                      Text(
                        widget.isPaid ? 'مدفوع' : 'غير مدفوع',
                        style: TextStyle(color: widget.isPaid ? AppTheme.success : AppTheme.danger, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusButton(
                  label: 'حاضر',
                  icon: Icons.check,
                  color: AppTheme.success,
                  isActive: widget.status == 'present',
                  onTap: () => widget.onStatusChanged('present'),
                ),
                const SizedBox(width: 8),
                _StatusButton(
                  label: 'غائب',
                  icon: Icons.close,
                  color: AppTheme.danger,
                  isActive: widget.status == 'absent',
                  onTap: () => widget.onStatusChanged('absent'),
                ),
                const SizedBox(width: 8),
                _StatusButton(
                  label: 'ملغي',
                  icon: Icons.remove,
                  color: AppTheme.warning,
                  isActive: widget.status == 'cancelled',
                  onTap: () => widget.onStatusChanged('cancelled'),
                ),
                const SizedBox(width: 12),
                if (widget.status != null)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton(
                      onPressed: widget.onSave,
                      child: const Text('حفظ', style: TextStyle(fontSize: 12)),
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

class _StatusButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_StatusButton> createState() => _StatusButtonState();
}

class _StatusButtonState extends State<_StatusButton> with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _tapController.forward().then((_) => _tapController.reverse());
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, _) => Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isActive ? widget.color.withValues(alpha: 0.1) : surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.isActive ? widget.color : borderColor,
                ),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 14,
                    color: widget.isActive ? widget.color : textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.isActive ? widget.color : textMuted,
                      fontSize: 12,
                      fontWeight: widget.isActive ? FontWeight.bold : FontWeight.normal,
                    ),
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

class _ScanInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _ScanInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
          Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
