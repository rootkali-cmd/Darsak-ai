import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '1.2.1';
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadNotificationSetting();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = packageInfo.version;
        });
      }
    } catch (e) {
      // fallback already set
    }
  }

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (mounted) {
      setState(() {
        _notificationsEnabled = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'المظهر',
            style: TextStyle(
              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return ListTile(
                      leading: Icon(
                        themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: colorScheme.onSurface,
                      ),
                      title: Text(
                        themeProvider.isDarkMode ? 'الوضع الداكن' : 'الوضع الفاتح',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                      trailing: Switch(
                        value: themeProvider.isDarkMode,
                        onChanged: (v) => themeProvider.toggleTheme(),
                        activeColor: AppTheme.accent,
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.notifications,
                    color: colorScheme.onSurface,
                  ),
                  title: Text(
                    'الإشعارات',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                    activeColor: AppTheme.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'حول التطبيق',
            style: TextStyle(
              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info, color: colorScheme.onSurface),
                  title: Text('الإصدار', style: TextStyle(color: colorScheme.onSurface)),
                  trailing: Text(
                    _version,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.language, color: colorScheme.onSurface),
                  title: Text('اللغة', style: TextStyle(color: colorScheme.onSurface)),
                  trailing: Text(
                    'العربية',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.danger),
              title: const Text(
                'تسجيل الخروج',
                style: TextStyle(color: AppTheme.danger),
              ),
              onTap: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                await auth.logout();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
