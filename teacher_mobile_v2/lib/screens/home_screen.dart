import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/glass_theme.dart';
import '../providers/auth_provider.dart';
import '../services/update_service.dart';
import 'dashboard/dashboard_screen.dart';
import 'students/students_screen.dart';
import 'attendance/attendance_screen.dart';
import 'grades/grades_screen.dart';
import 'groups/groups_screen.dart';
import 'more/more_screen.dart';
import 'subscriptions/subscription_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _showTrialBanner = true;

  static const List<String> _titles = [
    'الرئيسية',
    'الطلاب',
    'الحضور',
    'الدرجات',
    'المجموعات',
    'المزيد',
  ];

  static const List<IconData> _icons = [
    Icons.dashboard_rounded,
    Icons.people_rounded,
    Icons.today_rounded,
    Icons.grade_rounded,
    Icons.group_rounded,
    Icons.more_horiz_rounded,
  ];

  static const List<Widget> _screens = [
    DashboardScreen(),
    StudentsScreen(),
    AttendanceScreen(),
    GradesScreen(),
    GroupsScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), _checkForUpdates);
  }

  Future<void> _checkForUpdates() async {
    if (!mounted) return;
    try {
      final update = await UpdateService().checkForUpdate();
      if (!mounted) return;
      if (update != null) {
        _showUpdateDialog(update);
      }
    } catch (_) {}
  }

  void _showUpdateDialog(Map<String, dynamic> update) {
    double progress = 0;
    bool downloading = false;
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(error != null ? 'خطأ' : (downloading ? 'جاري التحميل...' : 'تحديث متاح')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Text(error!, style: const TextStyle(color: AppTheme.danger))
              else if (downloading)
                Column(children: [
                  LinearProgressIndicator(value: progress > 0 ? progress : null),
                  const SizedBox(height: 8),
                  Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 14)),
                ])
              else
                Text('الإصدار ${update['latest_version']} متاح الآن.\nهل تريد التحديث الآن؟', textAlign: TextAlign.center),
            ],
          ),
          actions: downloading
              ? [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                ]
              : [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      UpdateService().setRemindLater();
                    },
                    child: const Text('لاحقاً'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      setDialogState(() => downloading = true);
                      try {
                        await UpdateService().downloadAndInstall(
                          version: update['latest_version'] ?? '0.0.0',
                          onProgress: (p) => setDialogState(() => progress = p),
                        );
                        Navigator.pop(ctx);
                      } catch (e) {
                        setDialogState(() {
                          downloading = false;
                          error = 'فشل التحميل. جرب مرة أخرى من الموقع';
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                    child: const Text('تحديث الآن'),
                  ),
                ],
        ),
      ),
    );
  }

  void _dismissBanner() {
    setState(() => _showTrialBanner = false);
  }

  void _notifySubscriptionUpdate() {
    context.read<AuthProvider>().refreshSubscription();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(_titles[_currentIndex], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                if (_showTrialBanner && auth.isAuthenticated && !auth.hasSubscription)
                  _buildTrialBanner(),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111111) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: GlassTheme.indigo,
            unselectedItemColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            items: List.generate(
              _titles.length,
              (i) => BottomNavigationBarItem(
                icon: Icon(_icons[i]),
                label: _titles[i],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrialBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.warning.withValues(alpha: 0.15), AppTheme.warning.withValues(alpha: 0.08)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border(bottom: BorderSide(color: AppTheme.warning.withValues(alpha: 0.3))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_rounded, color: AppTheme.warning, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'جرب الباقة الأساسية مجاناً لمدة 30 يوم',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary(context)),
                ),
              ),
              GestureDetector(
                onTap: _dismissBanner,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: GlassTheme.cardBg(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.close, size: 16, color: GlassTheme.textSecondary(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
                if (result == true) {
                  _notifySubscriptionUpdate();
                }
              },
              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
              label: const Text('تفعيل مجاني', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
