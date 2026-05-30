import 'package:flutter/material.dart';
import '../groups/groups_screen.dart';
import '../invoices/invoices_screen.dart';
import '../exams/exams_screen.dart';
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
        color: const Color(0xFFdc2626),
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
            color: const Color(0xFF1a1a2e),
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                item.subtitle,
                style: const TextStyle(color: Color(0xFF6b7280), fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_back_ios, size: 16, color: Color(0xFF6b7280)),
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
