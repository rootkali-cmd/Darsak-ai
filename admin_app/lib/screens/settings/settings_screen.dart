import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/auth_provider.dart';
import '../login_screen.dart';
import '../templates/templates_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = '${info.version}+${info.buildNumber}');
      }
    } catch (_) {
      if (mounted) setState(() => _appVersion = '1.0.0');
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'تسجيل الخروج',
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
        content: const Text(
          'هل أنت متأكد من تسجيل الخروج؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'خروج',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        const SizedBox(height: 16),
        // Admin section
        _sectionHeader('المسؤول'),
        _listTile(
          icon: Icons.person_outline,
          title: 'المسؤول',
          subtitle: 'admin@darsakai.com',
          trailing: const Icon(Icons.chevron_left, color: Colors.white24),
        ),

        const SizedBox(height: 24),
        _sectionHeader('الإعدادات'),
        _listTile(
          icon: Icons.description_outlined,
          title: 'القوالب',
          subtitle: 'قوالب الرسائل والإشعارات',
          trailing: const Icon(Icons.chevron_left, color: Colors.white24),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TemplatesScreen()),
            );
          },
        ),

        const SizedBox(height: 24),
        _sectionHeader('حول'),
        _listTile(
          icon: Icons.info_outline,
          title: 'DarsakAI Admin',
          subtitle: _appVersion.isNotEmpty
              ? 'الإصدار $_appVersion'
              : 'جاري التحميل...',
          trailing: const SizedBox.shrink(),
        ),

        const SizedBox(height: 32),
        // Logout button
        SizedBox(
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD4AF37)),
            ),
            child: TextButton(
              onPressed: _logout,
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),
        const Center(
          child: Text(
            '© 2026 DarsakAI',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFD4AF37),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _listTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFD4AF37), size: 22),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
