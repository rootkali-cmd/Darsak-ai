import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/glass_card.dart';
import '../attendance/barcode_scanner_screen.dart';
import '../students/add_edit_student_screen.dart';
import '../grades/add_edit_grade_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<Map<String, dynamic>> _loadStats() async {
    final api = ApiService();
    try {
      final stats = await api.getDashboardStats();
      return stats;
    } catch (e) {
      // Fallback: load individual stats
      final studentsCount = await api.getStudentsCount();
      final groups = await api.getGroups();
      final attendanceStats = await api.getAttendanceStats();
      final invoiceStats = await api.getInvoiceStats();
      return {
        'total_students': studentsCount,
        'total_groups': groups.length,
        'today_attendance': attendanceStats['today_count'] ?? 0,
        'total_revenue': invoiceStats['total_paid'] ?? 0,
      };
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = _loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الرئيسية'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFFdc2626),
        backgroundColor: const Color(0xFF1a1a2e),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _statsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AppLoadingIndicator());
            }
            if (snapshot.hasError) {
              return AppErrorWidget(
                message: 'فشل تحميل الإحصائيات',
                onRetry: _refresh,
              );
            }
            final stats = snapshot.data ?? {};
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'لوحة التحكم',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.people,
                          title: 'الطلاب',
                          value: '${stats['total_students'] ?? 0}',
                          color: const Color(0xFF10b981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.groups,
                          title: 'المجموعات',
                          value: '${stats['total_groups'] ?? 0}',
                          color: const Color(0xFF3b82f6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.fact_check,
                          title: 'الحضور اليوم',
                          value: '${stats['today_attendance'] ?? 0}',
                          color: const Color(0xFFf59e0b),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.payments,
                          title: 'الإيرادات',
                          value: '${stats['total_revenue'] ?? 0} ج.م',
                          color: const Color(0xFF8b5cf6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'الإجراءات السريعة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickAction(
                    icon: Icons.qr_code_scanner,
                    title: 'تسجيل حضور',
                    subtitle: 'مسح الباركود لتسجيل حضور طالب',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                      ).then((_) => _refresh());
                    },
                  ),
                  const SizedBox(height: 8),
                  _QuickAction(
                    icon: Icons.person_add,
                    title: 'إضافة طالب',
                    subtitle: 'تسجيل طالب جديد',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddEditStudentScreen()),
                      ).then((_) => _refresh());
                    },
                  ),
                  const SizedBox(height: 8),
                  _QuickAction(
                    icon: Icons.grade,
                    title: 'إضافة درجة',
                    subtitle: 'إضافة درجة جديدة لطالب',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddEditGradeScreen()),
                      ).then((_) => _refresh());
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6b7280),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFdc2626).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFdc2626)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6b7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_back_ios, size: 16, color: Color(0xFF6b7280)),
        ],
      ),
    );
  }
}
