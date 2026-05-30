import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/students_provider.dart';

import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';
import '../../services/api_service.dart';
import 'add_edit_student_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  final dynamic student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<dynamic>> _attendanceFuture;
  late Future<List<dynamic>> _gradesFuture;
  late Future<List<dynamic>> _invoicesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final api = ApiService();
    final studentId = widget.student['id'] as int;
    _attendanceFuture = api.getStudentAttendance(studentId);
    _gradesFuture = api.getStudentGrades(studentId);
    _invoicesFuture = api.dio.get('/students/$studentId/invoices').then((r) => r.data as List<dynamic>);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _editStudent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditStudentScreen(student: widget.student),
      ),
    );
  }

  Future<void> _deleteStudent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل أنت متأكد من حذف هذا الطالب؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<StudentsProvider>(context, listen: false);
      final success = await provider.deleteStudent(widget.student['id'] as int);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الطالب بنجاح')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(provider.error ?? 'فشل الحذف')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final name = student['full_name'] ?? student['name'] ?? 'بدون اسم';
    final phone = student['phone']?.toString() ?? '';
    final parentPhone = student['parent_phone']?.toString() ?? '';
    final gradeLevel = student['grade_level']?.toString() ?? '';
    final pin = student['pin']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _editStudent,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteStudent,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFdc2626),
          labelColor: const Color(0xFFdc2626),
          unselectedLabelColor: const Color(0xFF6b7280),
          tabs: const [
            Tab(text: 'معلومات'),
            Tab(text: 'الحضور'),
            Tab(text: 'الدرجات'),
            Tab(text: 'الفواتير'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(name, phone, parentPhone, gradeLevel, pin),
          _buildAttendanceTab(),
          _buildGradesTab(),
          _buildInvoicesTab(),
        ],
      ),
    );
  }

  Widget _buildInfoTab(String name, String phone, String parentPhone, String gradeLevel, String pin) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFFdc2626).withValues(alpha: 0.2),
            child: const Icon(Icons.person, size: 50, color: Color(0xFFdc2626)),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _InfoTile(label: 'الاسم', value: name),
          _InfoTile(label: 'رقم الهاتف', value: phone.isEmpty ? '—' : phone),
          _InfoTile(label: 'رقم ولي الأمر', value: parentPhone.isEmpty ? '—' : parentPhone),
          _InfoTile(label: 'الصف الدراسي', value: gradeLevel.isEmpty ? '—' : gradeLevel),
          _InfoTile(label: 'الرقم السري', value: pin.isEmpty ? '—' : pin),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    return FutureBuilder<List<dynamic>>(
      future: _attendanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingIndicator();
        }
        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return const EmptyState(message: 'لا يوجد سجل حضور', icon: Icons.fact_check);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final item = data[index];
            final date = item['date']?.toString() ?? '';
            final status = item['status']?.toString() ?? 'absent';
            final isPresent = status == 'present';
            return Card(
              color: const Color(0xFF1a1a2e),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  isPresent ? Icons.check_circle : Icons.cancel,
                  color: isPresent ? Colors.green : Colors.red,
                ),
                title: Text(date, style: const TextStyle(color: Colors.white)),
                trailing: Text(
                  isPresent ? 'حاضر' : 'غائب',
                  style: TextStyle(color: isPresent ? Colors.green : Colors.red),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGradesTab() {
    return FutureBuilder<List<dynamic>>(
      future: _gradesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingIndicator();
        }
        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return const EmptyState(message: 'لا توجد درجات', icon: Icons.grade);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final item = data[index];
            final exam = item['exam_name']?.toString() ?? item['exam']?.toString() ?? '—';
            final subject = item['subject']?.toString() ?? '';
            final score = item['score'] ?? 0;
            final maxScore = item['max_score'] ?? 0;
            return Card(
              color: const Color(0xFF1a1a2e),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('$exam ${subject.isNotEmpty ? '($subject)' : ''}', style: const TextStyle(color: Colors.white)),
                trailing: Text(
                  '$score / $maxScore',
                  style: const TextStyle(color: Color(0xFFdc2626), fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInvoicesTab() {
    return FutureBuilder<List<dynamic>>(
      future: _invoicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingIndicator();
        }
        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return const EmptyState(message: 'لا توجد فواتير', icon: Icons.receipt);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final item = data[index];
            final amount = item['amount'] ?? 0;
            final description = item['description']?.toString() ?? '';
            final paid = item['paid'] == true;
            return Card(
              color: const Color(0xFF1a1a2e),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(description, style: const TextStyle(color: Colors.white)),
                trailing: Text(
                  '$amount ج.م',
                  style: TextStyle(
                    color: paid ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  paid ? 'مدفوع' : 'غير مدفوع',
                  style: TextStyle(color: paid ? Colors.green : Colors.orange, fontSize: 12),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1a1a2e),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(label, style: const TextStyle(color: Color(0xFF6b7280), fontSize: 12)),
        trailing: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
