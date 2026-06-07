import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
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

  static const _appName = 'درسك AI';
  static const _apiUrl = 'https://darsak-backend.fly.dev/api';
  static const _whatsappNumber = '01031524947';
  static const _telegramUser = 'G_M_L_M';
  static const _email = 'support@darsakai.com';

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

  Future<void> _openWhatsApp() async {
    final url = Uri.parse('https://wa.me/20$_whatsappNumber');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح واتساب'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _openTelegram() async {
    final url = Uri.parse('https://t.me/$_telegramUser');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تيليجرام'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _openEmail() async {
    final url = Uri.parse('mailto:$_email');
    try {
      await launchUrl(url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح البريد الإلكتروني'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: GlassTheme.glassAppBar('المطور'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GlassTheme.indigo))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InfoCard(icon: Icons.info_outline, label: 'التطبيق', value: _appName),
                _InfoCard(icon: Icons.system_update, label: 'إصدار التطبيق', value: _appVersion),
                _InfoCard(icon: Icons.link, label: 'API URL', value: _apiUrl),
                _InfoCard(
                  icon: Icons.storage,
                  label: 'حالة قاعدة البيانات',
                  value: _dbStatus,
                  valueColor: _dbStatus == 'متصل' ? GlassTheme.green : GlassTheme.red,
                ),
                const SizedBox(height: 24),
                const Text('التواصل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                _ContactCard(
                  icon: Icons.chat,
                  label: 'واتساب',
                  value: _whatsappNumber,
                  color: const Color(0xFF25D366),
                  onTap: _openWhatsApp,
                ),
                _ContactCard(
                  icon: Icons.send,
                  label: 'تيليجرام',
                  value: '@$_telegramUser',
                  color: const Color(0xFF0088CC),
                  onTap: _openTelegram,
                ),
                _ContactCard(
                  icon: Icons.email,
                  label: 'البريد الإلكتروني',
                  value: _email,
                  color: GlassTheme.indigo,
                  onTap: _openEmail,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _clearCache,
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('مسح الذاكرة المؤقتة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _logoutAllSessions,
                  icon: const Icon(Icons.logout),
                  label: const Text('تسجيل الخروج من جميع الجلسات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: GlassTheme.glassCard,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: GlassTheme.indigo.withValues(alpha: 0.15),
          child: Icon(icon, color: GlassTheme.indigo, size: 22),
        ),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: GlassTheme.glassCard,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(value, style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 14)),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
