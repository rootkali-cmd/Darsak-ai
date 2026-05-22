import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/shimmer_loading.dart';
import 'grades_screen.dart';
import 'attendance_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();
    final student = auth.student;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => data.loadAll(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(student, data),
                const SizedBox(height: 24),
                if (data.isLoading && data.grades.isEmpty)
                  const ShimmerList(count: 3)
                else ...[
                  _buildStatsRow(data),
                  const SizedBox(height: 24),
                  _buildTodayStatus(data),
                  const SizedBox(height: 24),
                  _buildRecentGrades(data),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader(dynamic student, DataProvider data) {
    final initials = student?.fullName?.isNotEmpty == true ? student.fullName[0] : '?';
    final name = student?.fullName ?? 'طالب';
    final code = student?.code ?? '';
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(color: Color(0xFFF5F5F5), fontSize: 18, fontWeight: FontWeight.bold)),
            Text(code, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: data.isOffline ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                data.isOffline ? 'غير متصل' : 'متصل',
                style: TextStyle(
                  color: data.isOffline ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(DataProvider data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'الحضور',
                value: '${data.attendanceRate.toStringAsFixed(0)}%',
                icon: Icons.check_circle,
                color: const Color(0xFF10B981),
                valueFontSize: 22,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'المعدل',
                value: '${data.averageGrade.toStringAsFixed(1)}%',
                icon: Icons.trending_up,
                color: const Color(0xFF2563EB),
                valueFontSize: 22,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'امتحانات pending',
                value: '${data.pendingExams.length}',
                icon: Icons.assignment_late,
                color: data.pendingExams.isEmpty ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                valueFontSize: 22,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'الشهر الحالي',
                value: data.isPaidThisMonth ? 'مدفوع' : 'غير مدفوع',
                icon: Icons.payment,
                color: data.isPaidThisMonth ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                valueFontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayStatus(DataProvider data) {
    final today = data.todayAttendance;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E1E1E), Color(0xFF141414)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: today != null
                  ? today.status == 'present'
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFEF4444).withValues(alpha: 0.15)
                  : const Color(0xFF9CA3AF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              today != null
                  ? today.status == 'present' ? Icons.check_circle : Icons.cancel
                  : Icons.help_outline,
              color: today != null
                  ? today.status == 'present' ? const Color(0xFF10B981) : const Color(0xFFEF4444)
                  : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حالة اليوم',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  today != null
                      ? today.statusLabel
                      : 'لم تسجل بعد',
                  style: const TextStyle(
                    color: Color(0xFFF5F5F5),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (today != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: today.status == 'present'
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                today.status == 'present' ? 'حاضر' : 'غائب',
                style: TextStyle(
                  color: today.status == 'present' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentGrades(DataProvider data) {
    final recent = data.grades.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('آخر الدرجات', style: TextStyle(color: Color(0xFFF5F5F5), fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GradesScreen())),
              child: const Text('عرض الكل', style: TextStyle(color: Color(0xFF2563EB))),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Center(
              child: Text('لا توجد درجات بعد', style: TextStyle(color: Colors.grey[600])),
            ),
          )
        else
          ...recent.map((g) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.examName, style: const TextStyle(color: Color(0xFFF5F5F5), fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(g.subject, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: g.percentage >= 75
                            ? const Color(0xFF10B981).withValues(alpha: 0.1)
                            : g.percentage >= 50
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                                : const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${g.score.toStringAsFixed(0)}/${g.maxScore.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: g.percentage >= 75
                              ? const Color(0xFF10B981)
                              : g.percentage >= 50
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: BottomNavigationBar(
        backgroundColor: const Color(0xFF0A0A0A),
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: Colors.grey[600],
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(
            icon: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GradesScreen())),
              child: const Icon(Icons.assignment),
            ),
            label: 'الدرجات',
          ),
          BottomNavigationBarItem(
            icon: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
              child: const Icon(Icons.calendar_month),
            ),
            label: 'الحضور',
          ),
          BottomNavigationBarItem(
            icon: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
              child: const Icon(Icons.person),
            ),
            label: 'الملف',
          ),
        ],
      ),
    );
  }
}
