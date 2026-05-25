import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/shimmer_loading.dart';
import 'grades_screen.dart';
import 'attendance_screen.dart';
import 'profile_screen.dart';
import 'subscription_screen.dart';
import 'exam_list_screen.dart';

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

    final expiryDays = auth.subscriptionData != null
        ? _parseRemainingDays(auth.subscriptionData!)
        : 0;
    final showExpiryBanner = auth.isAuthenticated && !auth.isSubscriptionActive;

    return Scaffold(
      drawer: _buildDrawer(context, auth),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => data.loadAll(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showExpiryBanner) ...[
                  _buildExpiryBanner(),
                  const SizedBox(height: 12),
                ],
                _buildHeader(student, data, auth),
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

  Widget _buildHeader(dynamic student, DataProvider data, AuthProvider auth) {
    final initials = student?.fullName?.isNotEmpty == true ? student.fullName[0] : '?';
    final name = student?.fullName ?? 'طالب';
    final code = student?.code ?? '';
    return Row(
      children: [
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => Scaffold.of(ctx).openDrawer(),
            child: Container(
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
        if (!auth.isSubscriptionActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'اشتراك منتهي',
              style: TextStyle(color: AppTheme.danger, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          )
        else
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

  Widget _buildDrawer(BuildContext context, AuthProvider auth) {
    return Drawer(
      backgroundColor: const Color(0xFF0A0A0A),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF0A0A0A)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: const Center(child: Icon(Icons.school, color: Colors.white, size: 30)),
                ),
                const SizedBox(height: 12),
                Text(
                  auth.student?.fullName ?? 'طالب',
                  style: const TextStyle(color: Color(0xFFF5F5F5), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  auth.student?.code ?? '',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          _DrawerItem(
            icon: Icons.home,
            label: 'الرئيسية',
            onTap: () => Navigator.pop(context),
          ),
          _DrawerItem(
            icon: Icons.assignment,
            label: 'الدرجات',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const GradesScreen()));
            },
          ),
          _DrawerItem(
            icon: Icons.calendar_month,
            label: 'الحضور',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()));
            },
          ),
          _DrawerItem(
            icon: Icons.quiz_outlined,
            label: 'الاختبارات',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamListScreen()));
            },
          ),
          _DrawerItem(
            icon: Icons.person,
            label: 'الملف الشخصي',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          _DrawerItem(
            icon: Icons.card_membership,
            label: 'الاشتراك',
            trailing: !auth.isSubscriptionActive
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('منتهي', style: TextStyle(color: AppTheme.danger, fontSize: 10)),
                  )
                : null,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
            },
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          _DrawerItem(
            icon: Icons.logout,
            label: 'تسجيل الخروج',
            iconColor: AppTheme.danger,
            textColor: AppTheme.danger,
            onTap: () {
              Navigator.pop(context);
              auth.logout();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'اشتراكك منتهٍ. فعّل اشتراكك الآن للاستمرار.',
                style: TextStyle(color: AppTheme.danger, fontSize: 12),
              ),
            ),
            const Icon(Icons.arrow_back_ios, color: AppTheme.danger, size: 14),
          ],
        ),
      ),
    );
  }

  int _parseRemainingDays(Map<String, dynamic> subData) {
    final expiresAt = subData['expires_at'] as String?;
    if (expiresAt == null) return 0;
    final expiry = DateTime.tryParse(expiresAt);
    if (expiry == null) return 0;
    return expiry.difference(DateTime.now()).inDays;
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

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.grey[500], size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: textColor ?? const Color(0xFFF5F5F5),
          fontSize: 14,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
      dense: true,
    );
  }
}
