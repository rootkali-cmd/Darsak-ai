import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/update_service.dart';
import '../profile/profile_screen.dart';
import '../profile/teacher_code_screen.dart';
import '../settings/settings_screen.dart';
import '../lessons/lessons_screen.dart';
import '../subscriptions/subscription_screen.dart';
import '../exams/exams_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MoreOption(
            icon: Icons.person,
            label: 'الملف الشخصي',
            color: AppTheme.primary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          _MoreOption(
            icon: Icons.settings,
            label: 'الإعدادات',
            color: AppTheme.textSecondary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          _MoreOption(
            icon: Icons.video_library,
            label: 'الدروس',
            color: AppTheme.success,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LessonsScreen())),
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
            color: AppTheme.danger,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamsScreen())),
          ),
          _MoreOption(
            icon: Icons.qr_code,
            label: 'كود المدرس',
            color: AppTheme.accent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherCodeScreen())),
          ),
          _MoreOption(
            icon: Icons.system_update,
            label: 'تحديث',
            color: AppTheme.primary,
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
                  const SnackBar(content: Text('لا توجد تحديثات متاحة'), backgroundColor: AppTheme.accent),
                );
              }
            },
          ),
          _MoreOption(
            icon: Icons.info_outline,
            label: 'عن التطبيق',
            color: AppTheme.textSecondary,
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'درسك AI',
              applicationVersion: '1.0.0',
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(label),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}
