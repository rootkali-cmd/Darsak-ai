import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('المظهر'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(themeProvider.isDark ? Icons.dark_mode : Icons.light_mode, color: AppTheme.accent),
                  title: const Text('الوضع الداكن'),
                  value: themeProvider.isDark,
                  onChanged: (_) => context.read<ThemeProvider>().toggle(),
                  activeColor: AppTheme.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('الإشعارات'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications, color: AppTheme.warning),
                  title: const Text('تفعيل الإشعارات'),
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                    activeColor: AppTheme.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('اللغة'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language, color: AppTheme.primary),
              title: const Text('اللغة'),
              trailing: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('العربية', style: TextStyle(color: AppTheme.textSecondary)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('حول التطبيق'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppTheme.success),
                  title: const Text('الإصدار'),
                  trailing: Text(_version, style: const TextStyle(color: AppTheme.textSecondary)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code, color: AppTheme.accent),
                  title: const Text('تطبيق درسك AI'),
                  subtitle: const Text('للمدرسين'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
