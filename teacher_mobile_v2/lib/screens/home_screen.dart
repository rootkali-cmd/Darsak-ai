import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/glass_theme.dart';
import '../providers/auth_provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'students/students_screen.dart';
import 'attendance/attendance_screen.dart';
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
    'المجموعات',
    'المزيد',
  ];

  static const List<IconData> _icons = [
    Icons.dashboard_rounded,
    Icons.people_rounded,
    Icons.today_rounded,
    Icons.group_rounded,
    Icons.more_horiz_rounded,
  ];

  static const List<bool> _requiresSubscription = [
    false, // الرئيسية
    true,  // الطلاب
    true,  // الحضور
    true,  // المجموعات
    false, // المزيد
  ];

  static const List<Widget> _screens = [
    DashboardScreen(),
    StudentsScreen(),
    AttendanceScreen(),
    GroupsScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  void _dismissBanner() {
    setState(() => _showTrialBanner = false);
  }

  void _notifySubscriptionUpdate() {
    context.read<AuthProvider>().refreshSubscription();
  }

  void _onTabTapped(int index) {
    if (_requiresSubscription[index]) {
      final auth = context.read<AuthProvider>();
      if (!auth.hasSubscription) {
        _showSubscriptionRequiredDialog();
        return;
      }
    }
    setState(() => _currentIndex = index);
  }

  void _showSubscriptionRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          Navigator.of(ctx).pop();
        },
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.lock_outline, color: Colors.orange, size: 48),
          title: const Text('اشتراك مطلوب', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'يجب الاشتراك في باقة أولاً للوصول لهذه الميزة',
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('الذهاب للاشتراكات', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Consumer<AuthProvider>(
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
            onTap: _onTabTapped,
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
                  'جرب الباقة الأساسية مجاناً لمدة 7 أيام',
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
