import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../attendance/attendance_screen.dart';
import '../students/add_edit_student_screen.dart';
import '../lessons/lesson_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService().dio.get('/dashboard/stats');
      final data = resp.data;
      _stats = data is Map<String, dynamic> ? data : {};
    } on DioException catch (e) {
      _error = 'فشل تحميل الإحصائيات: ${e.response?.statusCode ?? e.message}';
    } catch (e) {
      _error = 'حدث خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة التحكم')),
      body: RefreshIndicator(
        onRefresh: _fetchStats,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.3,
                        children: [
                          _StatCard(
                            icon: Icons.people,
                            label: 'عدد الطلاب',
                            count: '${_stats['students_count'] ?? 0}',
                            color: AppTheme.primary,
                          ),
                          _StatCard(
                            icon: Icons.groups,
                            label: 'عدد المجموعات',
                            count: '${_stats['groups_count'] ?? 0}',
                            color: AppTheme.accent,
                          ),
                          _StatCard(
                            icon: Icons.fact_check,
                            label: 'حضور اليوم',
                            count: '${_stats['today_attendance'] ?? 0}',
                            color: AppTheme.success,
                          ),
                          _StatCard(
                            icon: Icons.receipt,
                            label: 'فواتير معلقة',
                            count: '${_stats['pending_invoices'] ?? 0}',
                            color: AppTheme.warning,
                          ),
                          _StatCard(
                            icon: Icons.quiz,
                            label: 'اختبارات نشطة',
                            count: '${_stats['active_exams'] ?? 0}',
                            color: AppTheme.danger,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'إجراءات سريعة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.how_to_reg,
                              label: 'تسجيل حضور',
                              color: AppTheme.success,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.person_add,
                              label: 'إضافة طالب',
                              color: AppTheme.primary,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AddEditStudentScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.play_circle_fill,
                              label: 'إضافة درس',
                              color: AppTheme.accent,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LessonDetailScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.upload_file,
                              label: 'رفع فيديو',
                              color: AppTheme.danger,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LessonDetailScreen()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchStats, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String count;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
