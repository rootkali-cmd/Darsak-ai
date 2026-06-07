import 'package:flutter/material.dart';
import '../../services/api_service.dart';
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
      backgroundColor: const Color(0xFF000000),
      appBar: GlassTheme.glassAppBar(
        s['full_name'] ?? 'تفاصيل الطالب',
        actions: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.white70), onPressed: _editStudent),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: GlassTheme.indigo,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
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
          decoration: GlassTheme.glassCard,
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: GlassTheme.indigo.withValues(alpha: 0.2),
                child: const Icon(Icons.person, size: 40, color: GlassTheme.indigo),
              ),
              const SizedBox(height: 12),
              Text(s['full_name'] ?? '—', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text(s['code'] ?? '', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _InfoRow(label: 'هاتف ولي الأمر', value: s['parent_phone'] ?? '—'),
        _InfoRow(label: 'المجموعة', value: s['group']?['name'] ?? s['group_id']?.toString() ?? '—'),
        _InfoRow(label: 'الرمز السري', value: s['pin']?.toString() ?? '—'),
      ],
    );
  }

  Widget _buildAttendanceTab() {
    if (_loadingAttendance) {
      return const Center(child: CircularProgressIndicator(color: GlassTheme.indigo));
    }
    if (_attendance.isEmpty) {
      return const Center(
        child: Text('لا توجد سجلات حضور', style: TextStyle(color: Color(0xFF94A3B8))),
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
            decoration: GlassTheme.glassCard,
            child: ListTile(
              leading: Icon(
                isPresent ? Icons.check_circle : Icons.cancel,
                color: isPresent ? GlassTheme.green : GlassTheme.red,
              ),
              title: Text(a['date'] ?? '—', style: const TextStyle(color: Colors.white)),
              subtitle: Text(isPresent ? 'حاضر' : 'غائب', style: const TextStyle(color: Color(0xFF94A3B8))),
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
      return const Center(
        child: Text('لا توجد درجات', style: TextStyle(color: Color(0xFF94A3B8))),
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
            decoration: GlassTheme.glassCard,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: GlassTheme.indigo.withValues(alpha: 0.2),
                child: Text(
                  '${g['score'] ?? 0}',
                  style: const TextStyle(color: GlassTheme.indigo, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(g['subject'] ?? '—', style: const TextStyle(color: Colors.white)),
              subtitle: Text(g['type'] ?? '', style: const TextStyle(color: Color(0xFF94A3B8))),
              trailing: Text(
                '${g['score']} / ${g['max_score']}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
      decoration: GlassTheme.glassCard,
      child: ListTile(
        title: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
      ),
    );
  }
}
