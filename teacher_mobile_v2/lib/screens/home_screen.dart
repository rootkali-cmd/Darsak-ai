import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/update_service.dart';
import 'dashboard/dashboard_screen.dart';
import 'students/students_screen.dart';
import 'attendance/attendance_screen.dart';
import 'grades/grades_screen.dart';
import 'more/more_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const List<String> _titles = [
    'الرئيسية',
    'الطلاب',
    'الحضور',
    'الدرجات',
    'المزيد',
  ];

  static const List<IconData> _icons = [
    Icons.dashboard_rounded,
    Icons.people_rounded,
    Icons.today_rounded,
    Icons.grade_rounded,
    Icons.more_horiz_rounded,
  ];

  static const List<Widget> _screens = [
    DashboardScreen(),
    StudentsScreen(),
    AttendanceScreen(),
    GradesScreen(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl,
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.accent.withValues(alpha: 0.12),
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: List.generate(
            _titles.length,
            (i) => NavigationDestination(
              icon: Icon(_icons[i], color: AppTheme.textMuted),
              selectedIcon: Icon(_icons[i], color: AppTheme.accent),
              label: _titles[i],
            ),
          ),
        ),
      ),
    );
  }
}

