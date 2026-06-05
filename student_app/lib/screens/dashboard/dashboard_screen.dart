import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/error_utils.dart';

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
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ApiService();
      final res = await api.dio.get('/dashboard/stats');
      _stats = res.data is Map ? Map<String, dynamic>.from(res.data) : {};
    } on DioException catch (e) {
      _error = getDioErrorMessage(e);
    } catch (e) {
      _error = 'خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off, size: 48, color: AppTheme.textMuted),
        const SizedBox(height: 12),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _loadStats, child: const Text('إعادة المحاولة')),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('مرحباً بك في DarsakAI Student', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('تابع درجاتك وحضورك', style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 20),
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
          children: [
            _StatCard(label: 'الدرجات', value: '${_stats['total_grades'] ?? 0}', icon: Icons.grade, color: AppTheme.accent),
            _StatCard(label: 'الحضور', value: '${_stats['total_attendance'] ?? 0}', icon: Icons.today, color: AppTheme.success),
            _StatCard(label: 'الاختبارات', value: '${_stats['active_exams'] ?? 0}', icon: Icons.quiz, color: AppTheme.warning),
            _StatCard(label: 'الدروس', value: '${_stats['total_lessons'] ?? 0}', icon: Icons.play_circle, color: AppTheme.danger),
          ],
        ),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ]),
      ),
    );
  }
}
