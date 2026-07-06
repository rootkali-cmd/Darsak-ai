import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/update_service.dart';
import '../subscriptions/subscription_screen.dart';

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

  Future<void> _checkForUpdate() async {
    try {
      final update = await UpdateService().checkForUpdate();
      if (!mounted) return;
      if (update != null) {
        _showUpdateDialog(update);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('التطبيق محدث لأحدث إصدار'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر التحقق من التحديثات'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  void _showUpdateDialog(Map<String, dynamic> update) {
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
  }

  int? _daysUntilExpiry(Map<String, dynamic> sub) {
    final expiresAt = sub['expires_at'];
    if (expiresAt == null) return null;
    try {
      final expiry = DateTime.parse(expiresAt.toString());
      return expiry.difference(DateTime.now()).inDays;
    } catch (_) {
      return null;
    }
  }

  bool _isExpired(Map<String, dynamic> sub) {
    final days = _daysUntilExpiry(sub);
    return days != null && days <= 0;
  }

  bool _canUpgrade(String? planName) {
    if (planName == null) return false;
    final lower = planName.toLowerCase();
    return lower.contains('basic') || lower.contains('أساسي') || lower.contains('pro');
  }

  Widget _buildSubscriptionSection(AuthProvider auth) {
    final sub = auth.subscription;

    if (sub == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: GlassTheme.glassCard(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.subscriptions, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Text('الاشتراك', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
            ]),
            const SizedBox(height: 12),
            Text('لا يوجد اشتراك نشط', style: TextStyle(color: GlassTheme.textSecondary(context))),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                },
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: const Text('تفعيل مجاني'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final planName = sub['plan_name']?.toString() ?? sub['name']?.toString() ?? '—';
    final daysRemaining = _daysUntilExpiry(sub);
    final expired = _isExpired(sub);
    final isTrial = (sub['is_trial'] == true || sub['is_trial'] == 'true') ||
        (planName.toLowerCase().contains('trial') || planName.contains('تجريبي'));

    final double progress;
    if (daysRemaining != null && daysRemaining > 0) {
      final totalDays = isTrial ? 30.0 : 30.0;
      progress = (daysRemaining / totalDays).clamp(0.0, 1.0);
    } else {
      progress = 0.0;
    }

    final Color progressColor;
    if (expired) {
      progressColor = GlassTheme.red;
    } else if (daysRemaining != null && daysRemaining <= 3) {
      progressColor = AppTheme.warning;
    } else {
      progressColor = GlassTheme.green;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GlassTheme.glassCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.subscriptions, color: GlassTheme.indigo),
            const SizedBox(width: 8),
            Text('الاشتراك', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        backgroundColor: progressColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                    Text(
                      daysRemaining != null ? '$daysRemaining' : '—',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planName,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expired
                          ? 'منتهي'
                          : isTrial
                              ? 'فترة تجريبية'
                              : 'نشطة',
                      style: TextStyle(
                        fontSize: 13,
                        color: expired ? GlassTheme.red : progressColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (daysRemaining != null && daysRemaining <= 3 && !expired) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'سينتهي اشتراكك خلال $daysRemaining أيام. جدده الآن لتجنب انقطاع الخدمة.',
                    style: TextStyle(fontSize: 12, color: GlassTheme.textMuted(context)),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          if (expired)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('جدد اشتراكك'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassTheme.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else if (_canUpgrade(planName))
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                },
                icon: const Icon(Icons.upgrade, size: 18),
                label: const Text('ترقية الباقة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GlassTheme.indigo,
                  side: const BorderSide(color: GlassTheme.indigo),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: GlassTheme.glassAppBar('الإعدادات'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('المظهر'),
          Container(
            decoration: GlassTheme.glassCard(context),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(themeProvider.isDark ? Icons.dark_mode : Icons.light_mode, color: GlassTheme.indigo),
                  title: Text('الوضع الداكن', style: TextStyle(color: GlassTheme.textPrimary(context))),
                  value: themeProvider.isDark,
                  onChanged: (_) => context.read<ThemeProvider>().toggle(),
                  activeTrackColor: GlassTheme.indigo,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('الإشعارات'),
          Container(
            decoration: GlassTheme.glassCard(context),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications, color: AppTheme.warning),
                  title: Text('تفعيل الإشعارات', style: TextStyle(color: GlassTheme.textPrimary(context))),
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                    activeTrackColor: GlassTheme.indigo,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('الاشتراك'),
          _buildSubscriptionSection(auth),
          const SizedBox(height: 16),
          _buildSectionHeader('اللغة'),
          Container(
            decoration: GlassTheme.glassCard(context),
            child: ListTile(
              leading: const Icon(Icons.language, color: GlassTheme.cyan),
              title: Text('اللغة', style: TextStyle(color: GlassTheme.textPrimary(context))),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('العربية', style: TextStyle(color: GlassTheme.textSecondary(context))),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 14, color: GlassTheme.textSecondary(context)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('حول التطبيق'),
          Container(
            decoration: GlassTheme.glassCard(context),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: GlassTheme.green),
                  title: Text('الإصدار', style: TextStyle(color: GlassTheme.textPrimary(context))),
                  trailing: Text(_version, style: TextStyle(color: GlassTheme.textSecondary(context))),
                ),
                Divider(height: 1, color: GlassTheme.cardBorder(context)),
                ListTile(
                  leading: const Icon(Icons.system_update, color: GlassTheme.indigo),
                  title: Text('التحقق من التحديثات', style: TextStyle(color: GlassTheme.textPrimary(context))),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: GlassTheme.textSecondary(context)),
                  onTap: _checkForUpdate,
                ),
                Divider(height: 1, color: GlassTheme.cardBorder(context)),
                ListTile(
                  leading: const Icon(Icons.code, color: GlassTheme.indigo),
                  title: Text('تطبيق درسك AI', style: TextStyle(color: GlassTheme.textPrimary(context))),
                  subtitle: Text('للمدرسين', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 12)),
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
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: GlassTheme.textSecondary(context),
        ),
      ),
    );
  }
}
