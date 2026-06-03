import 'package:flutter/material.dart';
import '../widgets/biometric_lock_widget.dart';
import 'students/students_screen.dart';
import 'codes/codes_screen.dart';
import 'transactions/transactions_screen.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  int _totalStudents = 0;
  int _activeStudents = 0;
  int _pendingPayments = 0;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      // In a real app, these would be separate API calls
      // For now, we load placeholder data
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _totalStudents = 0;
        _activeStudents = 0;
        _pendingPayments = 0;
        _statsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const StudentsScreen(),
      const CodesScreen(),
      const TransactionsScreen(),
      const SettingsScreen(),
    ];

    return BiometricLockWidget(
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          title: const Text(
            'DarsakAI',
            style: TextStyle(
              fontWeight: FontWeight.w300,
              color: Color(0xFFD4AF37),
              letterSpacing: 3,
            ),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            _buildStatsRow(),
            const Divider(color: Color(0xFF2A2A2A), height: 1),
            Expanded(child: screens[_currentIndex]),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            backgroundColor: const Color(0xFF0A0A0A),
            selectedItemColor: const Color(0xFFD4AF37),
            unselectedItemColor: Colors.white38,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'الطلاب'),
              BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'الأكواد'),
              BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'المعاملات'),
              BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'الإعدادات'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: _statsLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                3,
                (_) => _shimmerStat(),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statCard('مجموع الطلاب', _totalStudents.toString(), Icons.group),
                _statCard('النشطين', _activeStudents.toString(), Icons.check_circle_outline),
                _statCard('مدفوعات معلقة', _pendingPayments.toString(), Icons.hourglass_empty),
              ],
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFD4AF37), size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _shimmerStat() {
    return Container(
      height: 60,
      width: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
