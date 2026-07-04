import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import 'add_edit_student_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  final dynamic student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<dynamic> _attendance = [];
  List<dynamic> _grades = [];
  bool _loadingAttendance = true;
  bool _loadingGrades = true;
  String _groupName = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadAttendance();
    _loadGrades();
    _loadGroupName();
  }

  Future<void> _loadGroupName() async {
    final groupId = widget.student['group_id']?.toString();
    if (groupId == null || groupId.isEmpty) return;
    try {
      final resp = await ApiService().dio.get('/groups');
      final items = resp.data is Map && resp.data['items'] is List ? resp.data['items'] as List : [];
      for (final g in items) {
        if (g['id']?.toString() == groupId) {
          if (mounted) setState(() => _groupName = g['name']?.toString() ?? '');
          return;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAttendance() async {
    setState(() => _loadingAttendance = true);
    try {
      final resp = await ApiService().dio.get('/students/${widget.student['id']}/attendance/');
      final data = resp.data;
      _attendance = data is List ? data : [];
    } catch (_) {
      _attendance = [];
    }
    if (mounted) setState(() => _loadingAttendance = false);
  }

  Future<void> _loadGrades() async {
    setState(() => _loadingGrades = true);
    try {
      final resp = await ApiService().dio.get('/students/${widget.student['id']}/grades/');
      final data = resp.data;
      _grades = data is List ? data : [];
    } catch (_) {
      _grades = [];
    }
    if (mounted) setState(() => _loadingGrades = false);
  }

  void _editStudent() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditStudentScreen(student: widget.student)),
    );
    if (mounted) setState(() {});
  }

  void _deleteStudent() {
    final studentName = widget.student['full_name'] ?? 'هذا الطالب';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف الطالب', style: TextStyle(color: Colors.white)),
        content: Text(
          'هل أنت متأكد من حذف "$studentName"؟\n\nسيتم حذف جميع بياناته نهائياً:\n• سجل الحضور\n• الدرجات\n• الاختبارات\n• الفواتير\n\nلا يمكن التراجع عن هذا الإجراء.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _performDelete();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.danger)),
    );

    try {
      await ApiService().deleteStudent(widget.student['id'].toString());
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      Navigator.pop(context, true); // Go back with result=true
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الطالب بنجاح', style: TextStyle(color: Colors.white)),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حذف الطالب: ${e.toString()}', style: const TextStyle(color: Colors.white)),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: GlassTheme.glassAppBar(
        s['full_name'] ?? 'تفاصيل الطالب',
        actions: [
          IconButton(icon: Icon(Icons.edit, color: GlassTheme.iconSecondary(context)), onPressed: _editStudent),
          IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.danger), onPressed: _deleteStudent),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: GlassTheme.indigo,
          labelColor: GlassTheme.textPrimary(context),
          unselectedLabelColor: GlassTheme.textSecondary(context),
          tabs: const [
            Tab(text: 'المعلومات'),
            Tab(text: 'الحضور'),
            Tab(text: 'الدرجات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildInfoTab(s),
          _buildAttendanceTab(),
          _buildGradesTab(),
        ],
      ),
    );
  }

  Widget _buildInfoTab(dynamic s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: GlassTheme.glassCard(context),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: GlassTheme.indigo.withValues(alpha: 0.2),
                child: const Icon(Icons.person, size: 40, color: GlassTheme.indigo),
              ),
              const SizedBox(height: 12),
              Text(s['full_name'] ?? '—', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s['code'] ?? '', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 14)),
                  if ((s['code'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: s['code'].toString()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم النسخ'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: GlassTheme.cardBg(context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.copy, size: 14, color: GlassTheme.textSecondary(context)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _InfoRow(label: 'هاتف ولي الأمر', value: s['parent_phone'] ?? '—'),
        _InfoRow(label: 'المجموعة', value: _groupName.isNotEmpty ? _groupName : (widget.student['group_id']?.toString() ?? '—')),
        _InfoRow(label: 'الرمز السري', value: s['pin']?.toString() ?? '—'),
        const SizedBox(height: 24),
        // Delete button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _deleteStudent,
            icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 20),
            label: const Text('حذف الطالب', style: TextStyle(color: AppTheme.danger, fontSize: 15, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.danger, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceTab() {
    if (_loadingAttendance) {
      return const Center(child: CircularProgressIndicator(color: GlassTheme.indigo));
    }
    if (_attendance.isEmpty) {
      return Center(
        child: Text('لا توجد سجلات حضور', style: TextStyle(color: GlassTheme.textSecondary(context))),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAttendance,
      color: GlassTheme.indigo,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _attendance.length,
        itemBuilder: (_, i) {
          final a = _attendance[i];
          final status = a['status'] ?? '';
          final isPresent = status == 'present';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: GlassTheme.glassCard(context),
            child: ListTile(
              leading: Icon(
                isPresent ? Icons.check_circle : Icons.cancel,
                color: isPresent ? GlassTheme.green : GlassTheme.red,
              ),
              title: Text(a['date'] ?? '—', style: TextStyle(color: GlassTheme.textPrimary(context))),
              subtitle: Text(isPresent ? 'حاضر' : 'غائب', style: TextStyle(color: GlassTheme.textSecondary(context))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradesTab() {
    if (_loadingGrades) {
      return const Center(child: CircularProgressIndicator(color: GlassTheme.indigo));
    }
    if (_grades.isEmpty) {
      return Center(
        child: Text('لا توجد درجات', style: TextStyle(color: GlassTheme.textSecondary(context))),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadGrades,
      color: GlassTheme.indigo,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _grades.length,
        itemBuilder: (_, i) {
          final g = _grades[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: GlassTheme.glassCard(context),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: GlassTheme.indigo.withValues(alpha: 0.2),
                child: Text(
                  '${g['score'] ?? 0}',
                  style: const TextStyle(color: GlassTheme.indigo, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(g['subject'] ?? '—', style: TextStyle(color: GlassTheme.textPrimary(context))),
              subtitle: Text(g['type'] ?? '', style: TextStyle(color: GlassTheme.textSecondary(context))),
              trailing: Text(
                '${g['score']} / ${g['max_score']}',
                style: TextStyle(fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: GlassTheme.glassCard(context),
      child: ListTile(
        title: Text(label, style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary(context))),
        trailing: Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: GlassTheme.textPrimary(context))),
      ),
    );
  }
}
