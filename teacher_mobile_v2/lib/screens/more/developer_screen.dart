import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  String _appVersion = '...';
  String _dbStatus = '...';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _appVersion = 'غير متاح';
    }

    try {
      await ApiService().dio.get('/dashboard/stats');
      _dbStatus = 'متصل';
    } on DioException {
      _dbStatus = 'غير متصل';
    } catch (_) {
      _dbStatus = 'غير متصل';
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_data');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم مسح الذاكرة المؤقتة'), backgroundColor: AppTheme.success),
      );
    }
  }

  Future<void> _logoutAllSessions() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من جميع الجلسات؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService().dio.post('/auth/logout-all');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المطور')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InfoCard(
                  icon: Icons.info_outline,
                  label: 'إصدار التطبيق',
                  value: _appVersion,
                ),
                _InfoCard(
                  icon: Icons.link,
                  label: 'API URL',
                  value: 'https://darsak-backend.fly.dev/api',
                ),
                _InfoCard(
                  icon: Icons.storage,
                  label: 'حالة قاعدة البيانات',
                  value: _dbStatus,
                  valueColor: _dbStatus == 'متصل' ? AppTheme.success : AppTheme.danger,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _clearCache,
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('مسح الذاكرة المؤقتة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _logoutAllSessions,
                  icon: const Icon(Icons.logout),
                  label: const Text('تسجيل الخروج من جميع الجلسات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
        title: Text(label),
        trailing: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
