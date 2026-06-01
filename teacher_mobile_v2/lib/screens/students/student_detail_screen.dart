import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadAttendance();
    _loadGrades();
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

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    return Scaffold(
      appBar: AppBar(
        title: Text(s['full_name'] ?? 'تفاصيل الطالب'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _editStudent),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
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
        _InfoRow(label: 'الاسم الكامل', value: s['full_name'] ?? '—'),
        _InfoRow(label: 'الكود', value: s['code'] ?? '—'),
        _InfoRow(label: 'هاتف ولي الأمر', value: s['parent_phone'] ?? '—'),
        _InfoRow(label: 'المجموعة', value: s['group']?['name'] ?? s['group_id']?.toString() ?? '—'),
        _InfoRow(label: 'الرمز السري', value: s['pin']?.toString() ?? '—'),
      ],
    );
  }

  Widget _buildAttendanceTab() {
    if (_loadingAttendance) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_attendance.isEmpty) {
      return const Center(
        child: Text('لا توجد سجلات حضور', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _attendance.length,
        itemBuilder: (_, i) {
          final a = _attendance[i];
          final status = a['status'] ?? '';
          final isPresent = status == 'present';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                isPresent ? Icons.check_circle : Icons.cancel,
                color: isPresent ? AppTheme.success : AppTheme.danger,
              ),
              title: Text(a['date'] ?? '—'),
              subtitle: Text(isPresent ? 'حاضر' : 'غائب'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradesTab() {
    if (_loadingGrades) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_grades.isEmpty) {
      return const Center(
        child: Text('لا توجد درجات', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadGrades,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _grades.length,
        itemBuilder: (_, i) {
          final g = _grades[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Text(
                  '${g['score'] ?? 0}',
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(g['subject'] ?? '—'),
              subtitle: Text(g['type'] ?? ''),
              trailing: Text(
                '${g['score']} / ${g['max_score']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }
}
