import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'dashboard/dashboard_screen.dart';
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
    'الدرجات',
    'الحضور',
    'المزيد',
  ];

  static const List<IconData> _icons = [
    Icons.dashboard_rounded,
    Icons.grade_rounded,
    Icons.today_rounded,
    Icons.more_horiz_rounded,
  ];

  static const List<Widget> _screens = [
    DashboardScreen(),
    GradesScreen(),
    AttendanceScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl,
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
          selectedItemColor: AppTheme.accent,
          unselectedItemColor: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54,
          items: List.generate(
            _titles.length,
            (i) => BottomNavigationBarItem(icon: Icon(_icons[i]), label: _titles[i]),
          ),
        ),
      ),
    );
  }
}
