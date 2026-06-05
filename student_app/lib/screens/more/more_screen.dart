import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../login_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import 'developer_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Option(icon: Icons.person, label: 'الملف الشخصي', color: AppTheme.primary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
          _Option(icon: Icons.settings, label: 'الإعدادات', color: AppTheme.textSecondary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          _Option(icon: Icons.bug_report, label: 'المطور', color: AppTheme.warning,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperScreen()))),
          const SizedBox(height: 16),
          _Option(icon: Icons.logout, label: 'تسجيل الخروج', color: AppTheme.danger,
            onTap: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
              }
            }),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Option({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}
