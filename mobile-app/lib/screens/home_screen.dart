import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/shimmer_loading.dart';
import 'grades_screen.dart';
import 'attendance_screen.dart';
import 'profile_screen.dart';
import 'ai_chat_screen.dart';
import 'exam_list_screen.dart';
import 'student_qr_screen.dart';
import 'invoices/invoices_screen.dart';
import 'courses/student_courses_screen.dart';
import 'wallet/student_wallet_screen.dart';
import 'ai_classroom/ai_lesson_list_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  Map<String, dynamic>? _walletData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataProvider>().loadAll();
      _checkSubscription();
    });
    _fetchNotifications();
    _fetchWallet();
  }

  void _checkSubscription() {
    final auth = context.read<AuthProvider>();
    // Online students don't need teacher subscription — they use wallet
    if (auth.student?.isOnlineStudent ?? false) return;
    if (auth.subscriptionLoaded && !auth.isSubscriptionActive) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.lock_outline, color: Colors.orange, size: 48),
            title: const Text('اشتراك مطلوب', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text(
              'اشتراك المدرس منتهي. لا يمكن استخدام التطبيق حالياً.\nتواصل مع مدرسك لتجديد الاشتراك.',
              textAlign: TextAlign.center,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.read<AuthProvider>().logout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final notifs = await ApiService().getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _unreadCount = notifs.length;
        });
      }
    } catch (_) {}
  }

  void _fetchWallet() async {
    try {
      final w = await ApiService().getWallet();
      if (mounted) setState(() => _walletData = w);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();
    final student = auth.student;
    final isOnline = student?.isOnlineStudent ?? false;
    final childCount = isOnline ? 4 : 5;
    final safeIndex = _currentIndex.clamp(0, childCount - 1);

    return Scaffold(
      drawer: _buildDrawer(context, auth),
      body: SafeArea(
        child: IndexedStack(
          index: safeIndex,
          children: [
            RefreshIndicator(
              onRefresh: () => data.loadAll(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(student, data, auth),
                    const SizedBox(height: 24),
                    if (data.isLoading && data.grades.isEmpty)
                      const ShimmerList(count: 3)
                    else ...[
                      _buildStatsRow(data, auth),
                      if (_walletData != null) ...[
                        const SizedBox(height: 16),
                        _buildWalletBalanceCard(),
                      ],
                      if (!isOnline) ...[
                        const SizedBox(height: 24),
                        _buildTodayStatus(data),
                      ],
                      const SizedBox(height: 24),
                      _buildRecentGrades(data),
                      const SizedBox(height: 24),
                      _buildQuickSections(),
                    ],
                  ],
                ),
              ),
            ),
            const GradesScreen(),
            if (!isOnline) const AttendanceScreen(),
            const AiLessonListScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(isOnline: isOnline),
    );
  }

  Widget _buildHeader(dynamic student, DataProvider data, AuthProvider auth) {
    final name = student?.fullName ?? 'طالب';
    final code = student?.code ?? '';
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(code, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
          ],
        ),
        const Spacer(),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, size: 28),
              color: AppColors.textSecondary(context),
              onPressed: _showNotificationsSheet,
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.danger,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    '$_unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: AppColors.background(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary(context).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الإشعارات',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_unreadCount > 0)
                    TextButton(
                      onPressed: () async {
                        for (final n in _notifications) {
                          await ApiService().markNotificationRead(n['id']);
                        }
                        _fetchNotifications();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('تحديد الكل مقروء',
                        style: TextStyle(color: AppTheme.accent, fontSize: 13)),
                    ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none, size: 48, color: AppColors.textSecondary(context).withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text('لا توجد إشعارات',
                          style: TextStyle(color: AppColors.textSecondary(context))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      return Dismissible(
                        key: Key(n['id'] ?? i.toString()),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) async {
                          await ApiService().markNotificationRead(n['id']);
                          _fetchNotifications();
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: AppTheme.accent,
                          child: const Icon(Icons.check, color: Colors.white),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.border(context).withValues(alpha: 0.5))),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n['title']?.toString().substring(0, n['title'].toString().length.clamp(0, 2)) ?? '🔔',
                                style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n['title'] ?? '',
                                      style: TextStyle(
                                        color: AppColors.textPrimary(context),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(n['body'] ?? '',
                                      style: TextStyle(
                                        color: AppColors.textSecondary(context),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(DataProvider data, AuthProvider auth) {
    final student = auth.student;
    final isOnline = student?.isOnlineStudent ?? false;
    return Column(
      children: [
        Row(
          children: [
            if (!isOnline) ...[
              Expanded(
                child: StatCard(
                  label: 'الحضور',
                  value: '${data.attendanceRate.toStringAsFixed(0)}%',
                  icon: Icons.check_circle,
                  color: AppTheme.success,
                  valueFontSize: 22,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: StatCard(
                label: 'المعدل',
                value: '${data.averageGrade.toStringAsFixed(1)}%',
                icon: Icons.trending_up,
                color: AppTheme.accent,
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
                label: 'درجات منخفضة',
                value: '${data.lowGradesCount}',
                icon: Icons.assignment_late,
                color: data.lowGradesCount == 0 ? AppTheme.success : AppTheme.warning,
                valueFontSize: 22,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildExamStats(data),
      ],
    );
  }

  Widget _buildWalletBalanceCard() {
    final balance = (_walletData?['balance'] ?? 0).toDouble();
    final deposited = (_walletData?['total_deposited'] ?? 0).toDouble();
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentWalletScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.7)]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رصيد المحفظة', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 2),
              Text('${balance.toStringAsFixed(0)} ج.م', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          )),
          Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.6), size: 16),
        ]),
      ),
    );
  }

  Widget _buildExamStats(DataProvider data) {
    final totalCount = data.totalExamsAndGrades;
    if (totalCount == 0) return const SizedBox.shrink();
    final avgScore = data.averageGrade;
    final best = data.bestScore;
    final worst = data.worstScore;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'الاختبارات والدرجات',
                value: '$totalCount',
                icon: Icons.quiz,
                color: AppTheme.accent,
                valueFontSize: 22,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'متوسط الدرجات',
                value: '${avgScore.toStringAsFixed(1)}%',
                icon: Icons.analytics,
                color: avgScore >= 50 ? AppTheme.success : AppTheme.danger,
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
                label: 'أعلى درجة',
                value: '${best.toStringAsFixed(1)}%',
                icon: Icons.arrow_upward,
                color: AppTheme.success,
                valueFontSize: 22,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'أقل درجة',
                value: '${worst.toStringAsFixed(1)}%',
                icon: Icons.arrow_downward,
                color: worst < 50 ? AppTheme.danger : AppTheme.success,
                valueFontSize: 22,
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
        gradient: AppColors.cardGradient(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: today != null
                  ? today.status == 'present'
                      ? AppTheme.success.withValues(alpha: 0.15)
                      : AppTheme.danger.withValues(alpha: 0.15)
                  : AppColors.textSecondary(context).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              today != null
                  ? today.status == 'present' ? Icons.check_circle : Icons.cancel
                  : Icons.help_outline,
              color: today != null
                  ? today.status == 'present' ? AppTheme.success : AppTheme.danger
                  : AppColors.textSecondary(context),
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
                  style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  today != null
                      ? today.statusLabel
                      : 'لم تسجل بعد',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
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
                    ? AppTheme.success.withValues(alpha: 0.1)
                    : AppTheme.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                today.status == 'present' ? 'حاضر' : 'غائب',
                style: TextStyle(
                  color: today.status == 'present' ? AppTheme.success : AppTheme.danger,
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
    final recent = data.recentResults;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('آخر الدرجات', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GradesScreen())),
              child: const Text('عرض الكل', style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Center(
              child: Text('لا توجد درجات بعد', style: TextStyle(color: AppColors.textSecondary(context))),
            ),
          )
        else
          ...recent.map((g) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: (g['type'] == 'exam' ? AppTheme.accent : AppTheme.success).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        g['type'] == 'exam' ? Icons.quiz : Icons.grade,
                        size: 16,
                        color: g['type'] == 'exam' ? AppTheme.accent : AppTheme.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g['name'] ?? '', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(g['subject'] ?? '', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (g['percentage'] as double) >= 75
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : (g['percentage'] as double) >= 50
                                ? AppTheme.warning.withValues(alpha: 0.1)
                                : AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${(g['score'] as double).toStringAsFixed(0)}/${(g['max_score'] as double).toStringAsFixed(0)}',
                        style: TextStyle(
                          color: (g['percentage'] as double) >= 75
                              ? AppTheme.success
                              : (g['percentage'] as double) >= 50
                                  ? AppTheme.warning
                                  : AppTheme.danger,
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

  Widget _buildQuickSections() {
    final student = context.read<AuthProvider>().student;
    final isOnline = student?.isOnlineStudent ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الأقسام', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (!isOnline) ...[
          _buildSectionCard(
            icon: Icons.qr_code,
            iconColor: AppTheme.accent,
            title: 'كود الحضور',
            subtitle: 'اعرض كود QR الخاص بتسجيل الحضور',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentQrScreen())),
          ),
          const SizedBox(height: 10),
        ],
        _buildSectionCard(
          icon: Icons.quiz_outlined,
          iconColor: AppTheme.success,
          title: 'الاختبارات',
          subtitle: 'شاهد الاختبارات المتاحة وأداءك',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamListScreen())),
        ),
        const SizedBox(height: 10),
        _buildSectionCard(
          icon: Icons.auto_awesome,
          iconColor: const Color(0xFFF59E0B),
          title: 'مساعد AI',
          subtitle: 'اسأل أي سؤال عن دراستك',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('جديد', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
        ),
        const SizedBox(height: 10),
        _buildSectionCard(
          icon: Icons.menu_book,
          iconColor: AppTheme.accent,
          title: 'الكورسات',
          subtitle: 'تصفح الكورسات المتاحة',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentCoursesScreen())),
        ),
        const SizedBox(height: 10),
        _buildSectionCard(
          icon: Icons.account_balance_wallet,
          iconColor: AppTheme.success,
          title: 'المحفظة',
          subtitle: 'إدارة رصيدك وإيداع الأموال',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentWalletScreen())),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 15, fontWeight: FontWeight.bold)),
                      if (trailing != null) ...[const SizedBox(width: 8), trailing],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios, color: AppColors.textSecondary(context), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AuthProvider auth) {
    final isOnline = auth.student?.isOnlineStudent ?? false;
    return Drawer(
      backgroundColor: AppColors.background(context),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: AppColors.headerGradient(context),
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
                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  auth.student?.code ?? '',
                  style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                ),
              ],
            ),
          ),
          _DrawerItem(
            icon: Icons.home,
            label: 'الرئيسية',
            onTap: () => Navigator.pop(context),
          ),
          if (!isOnline) ...[
            _DrawerItem(
              icon: Icons.qr_code,
              label: 'كود الحضور (QR)',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('QR', style: TextStyle(color: AppTheme.accent, fontSize: 10)),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentQrScreen()));
              },
            ),
          ],
          _DrawerItem(
            icon: Icons.assignment,
            label: 'الدرجات',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const GradesScreen()));
            },
          ),
          if (!isOnline) ...[
            _DrawerItem(
              icon: Icons.calendar_month,
              label: 'الحضور',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()));
              },
            ),
          ],
          _DrawerItem(
            icon: Icons.quiz_outlined,
            label: 'الاختبارات',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamListScreen()));
            },
          ),
          _DrawerItem(
            icon: Icons.menu_book,
            label: 'الكورسات',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentCoursesScreen()));
            },
          ),
          _DrawerItem(
            icon: Icons.receipt_long,
            label: 'الفواتير',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesScreen()));
            },
          ),
          _DrawerItem(
            icon: Icons.account_balance_wallet,
            label: 'المحفظة',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentWalletScreen()));
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
          _DrawerItem(
            icon: Icons.auto_awesome,
            label: 'مساعد AI',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('جديد', style: TextStyle(color: AppTheme.accent, fontSize: 10)),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen()));
            },
          ),
          Divider(color: AppColors.border(context), height: 1),
          _DrawerItem(
            icon: Icons.logout,
            label: 'تسجيل الخروج',
            iconColor: AppTheme.danger,
            textColor: AppTheme.danger,
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.dialogBackground(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('تسجيل الخروج', style: TextStyle(color: AppTheme.danger)),
                  content: Text('هل أنت متأكد من تسجيل الخروج؟', style: TextStyle(color: AppColors.textSecondary(context))),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: TextStyle(color: AppColors.textSecondary(context)))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                      onPressed: () {
                        Navigator.pop(ctx);
                        auth.logout();
                      },
                      child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav({required bool isOnline}) {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
      const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'الدرجات'),
      if (!isOnline) const BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'الحضور'),
      const BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'الفصل الذكي'),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'الملف'),
    ];
    final safeIndex = _currentIndex.clamp(0, items.length - 1);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border(context))),
      ),
      child: BottomNavigationBar(
        backgroundColor: AppColors.background(context),
        selectedItemColor: AppTheme.accent,
        unselectedItemColor: AppColors.textSecondary(context),
        currentIndex: safeIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 0 || index == (isOnline ? 2 : 3)) _fetchWallet();
        },
        items: items,
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
      leading: Icon(icon, color: iconColor ?? AppColors.textSecondary(context), size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: textColor ?? AppColors.textPrimary(context),
          fontSize: 14,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
      dense: true,
    );
  }
}
