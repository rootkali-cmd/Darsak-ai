import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../groups/groups_screen.dart';
import '../invoices/invoices_screen.dart';
import '../exams/exams_screen.dart';
import '../sessions/sessions_screen.dart';
import '../settings/settings_screen.dart';
import '../profile/profile_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _MenuItem(
        icon: Icons.groups,
        title: 'المجموعات',
        subtitle: 'إدارة مجموعات الطلاب',
        color: const Color(0xFF3b82f6),
        onTap: (ctx) => _navigate(ctx, const GroupsScreen()),
      ),
      _MenuItem(
        icon: Icons.event_repeat,
        title: 'المحاضرات المتكررة',
        subtitle: 'ربط مجموعات بمحاضرة واحدة',
        color: const Color(0xFFec4899),
        onTap: (ctx) => _navigate(ctx, const SessionsScreen()),
      ),
      _MenuItem(
        icon: Icons.receipt,
        title: 'الفواتير',
        subtitle: 'إدارة الفواتير والمدفوعات',
        color: const Color(0xFF10b981),
        onTap: (ctx) => _navigate(ctx, const InvoicesScreen()),
      ),
      _MenuItem(
        icon: Icons.quiz,
        title: 'الاختبارات',
        subtitle: 'إدارة الاختبارات',
        color: const Color(0xFFf59e0b),
        onTap: (ctx) => _navigate(ctx, const ExamsScreen()),
      ),
      _MenuItem(
        icon: Icons.settings,
        title: 'الإعدادات',
        subtitle: 'إعدادات التطبيق',
        color: const Color(0xFF8b5cf6),
        onTap: (ctx) => _navigate(ctx, const SettingsScreen()),
      ),
      _MenuItem(
        icon: Icons.person,
        title: 'الملف الشخصي',
        subtitle: 'بيانات الحساب',
        color: AppTheme.accent,
        onTap: (ctx) => _navigate(ctx, const ProfileScreen()),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('المزيد'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              onTap: () => item.onTap(context),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color),
              ),
              title: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                item.subtitle,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_back_ios, size: 16),
            ),
          );
        },
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final void Function(BuildContext) onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
