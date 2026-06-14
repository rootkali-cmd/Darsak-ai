import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../services/update_service.dart';
import '../profile/profile_screen.dart';
import '../profile/teacher_code_screen.dart';
import '../settings/settings_screen.dart';
import '../subscriptions/subscription_screen.dart';
import '../exams/exams_screen.dart';
import '../reports/ai_reports_screen.dart';
import '../invoices/teacher_invoices_screen.dart';
import 'developer_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String _version = '...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = '${info.version}+${info.buildNumber}');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: GlassTheme.glassAppBar('المزيد'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MoreOption(
            icon: Icons.person,
            label: 'الملف الشخصي',
            color: GlassTheme.indigo,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          _MoreOption(
            icon: Icons.settings,
            label: 'الإعدادات',
            color: const Color(0xFF94A3B8),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          _MoreOption(
            icon: Icons.video_library,
            label: 'الدروس',
            color: const Color(0xFF94A3B8),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('قريباً إن شاء الله'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          _MoreOption(
            icon: Icons.card_membership,
            label: 'الاشتراكات',
            color: AppTheme.warning,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
          ),
          _MoreOption(
            icon: Icons.quiz,
            label: 'الاختبارات',
            color: GlassTheme.red,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamsScreen())),
          ),
          _MoreOption(
            icon: Icons.bar_chart,
            label: 'التقارير',
            color: GlassTheme.indigo,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiReportsScreen())),
          ),
          _MoreOption(
            icon: Icons.receipt_long_rounded,
            label: 'الفواتير',
            color: AppTheme.warning,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherInvoicesScreen())),
          ),
          _MoreOption(
            icon: Icons.qr_code,
            label: 'كود المدرس',
            color: GlassTheme.cyan,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherCodeScreen())),
          ),
          _MoreOption(
            icon: Icons.system_update,
            label: 'تحديث',
            color: GlassTheme.indigo,
            onTap: () async {
              final update = await UpdateService().checkForUpdate();
              if (!context.mounted) return;
              if (update != null) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('تحديث متاح'),
                    content: Text('الإصدار ${update['latest_version']} متاح الآن. هل تريد التحديث؟'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          UpdateService().setRemindLater();
                        },
                        child: const Text('لاحقاً'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await UpdateService().downloadAndInstall(
                              version: update['latest_version'] ?? '0.0.0',
                              onProgress: (_) {},
                            );
                          } catch (_) {}
                        },
                        child: const Text('تحديث'),
                      ),
                    ],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لا توجد تحديثات متاحة'), backgroundColor: GlassTheme.indigo),
                );
              }
            },
          ),
          _MoreOption(
            icon: Icons.developer_mode,
            label: 'المطور',
            color: const Color(0xFF94A3B8),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperScreen())),
          ),
          _MoreOption(
            icon: Icons.info_outline,
            label: 'عن التطبيق',
            color: const Color(0xFF94A3B8),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'درسك AI',
              applicationVersion: _version,
              applicationLegalese: '© 2025 DarsakAI',
              children: [
                const Text('التطبيق الذكي لإدارة التدريس'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MoreOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: GlassTheme.glassCard(context),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(label, style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: GlassTheme.iconSecondary(context)),
      ),
    );
  }
}
