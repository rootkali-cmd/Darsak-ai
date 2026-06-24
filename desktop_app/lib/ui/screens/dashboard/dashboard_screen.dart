import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_provider.dart';
import '../../widgets/sidebar.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/quick_action.dart';
import '../../widgets/glass_notification_overlay.dart';
import '../students/students_screen.dart';
import '../groups/groups_screen.dart';
import '../attendance/attendance_screen.dart';
import '../grades/grades_screen.dart';
import '../invoices/invoices_screen.dart';
import '../exams/exam_list_screen.dart';
import '../qr/qr_screen.dart';
import '../subscription/subscription_screen.dart';
import '../settings/settings_screen.dart';
import '../reports/ai_reports_screen.dart';
import '../profile/profile_screen.dart';
import '../contacts/teacher_contacts_screen.dart';
import '../assistants/assistants_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const DashboardScreen({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  late VoidCallback _goToStudents;
  late VoidCallback _goToAttendance;
  late VoidCallback _goToGrades;

  // Dashboard API data
  Map<String, dynamic>? _dashboardStats;
  bool _dashboardLoading = false;
  String? _dashboardError;

  @override
  void initState() {
    super.initState();
    _goToStudents = () => setState(() => _selectedIndex = 1);
    _goToAttendance = () => setState(() => _selectedIndex = 3);
    _goToGrades = () => setState(() => _selectedIndex = 4);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _slideController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataProvider>().loadData();
      _fetchDashboardStats();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardStats() async {
    if (_dashboardLoading) return;
    setState(() { _dashboardLoading = true; _dashboardError = null; });
    try {
      final api = context.read<AuthProvider>().client;
      final apiService = ApiService(api);
      final stats = await apiService.get('/dashboard/stats');
      setState(() { _dashboardStats = stats; _dashboardLoading = false; });
    } catch (e) {
      setState(() { _dashboardError = 'فشل تحميل الإحصائيات'; _dashboardLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Stack(
      children: [
        Scaffold(
      body: Row(
        children: [
          Sidebar(
            currentIndex: _selectedIndex,
            onItemSelected: (i) {
              setState(() => _selectedIndex = i);
              _slideController.reset();
              _slideController.forward();
            },
            onLogout: () => auth.logout(),
            user: auth.user,
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _getPageTitle(),
                        style: TextStyle(color: textMuted, fontSize: 14),
                      ),
                      const SizedBox(width: 12),
                      if (_selectedIndex == 0)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: _fetchDashboardStats,
                            child: Tooltip(
                              message: 'تحديث',
                              child: Icon(
                                Icons.refresh,
                                size: 16,
                                color: textMuted,
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: IconButton(
                          onPressed: widget.toggleTheme,
                          icon: Icon(
                            widget.themeMode == ThemeMode.dark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            size: 20,
                          ),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _buildPage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    const GlassNotificationOverlay(),
  ],
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0: return 'لوحة التحكم';
      case 1: return 'الطلاب';
      case 2: return 'المجموعات';
      case 3: return 'الحضور';
      case 4: return 'الدرجات';
      case 5: return 'الفواتير';
      case 6: return 'الامتحانات';
      case 7: return 'QR';
      case 8: return 'الإعدادات';
      case 9: return 'الاشتراك';
      case 10: return 'التقارير';
      case 11: return 'المساعدين';
      case 12: return 'الملف الشخصي';
      case 13: return 'جهات الاتصال';
      default: return 'لوحة التحكم';
    }
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildHome(key: const ValueKey('home'));
      case 1:
        return const StudentsScreen(key: ValueKey('students'));
      case 2:
        return const GroupsScreen(key: ValueKey('groups'));
      case 3:
        return const AttendanceScreen(key: ValueKey('attendance'));
      case 4:
        return const GradesScreen(key: ValueKey('grades'));
      case 5:
        return const InvoicesScreen(key: ValueKey('invoices'));
      case 6:
        return const ExamListScreen(key: ValueKey('exams'));
      case 7:
        return const QrScreen(key: ValueKey('qr'));
      case 8:
        return SettingsScreen(
          key: const ValueKey('settings'),
          toggleTheme: widget.toggleTheme,
          themeMode: widget.themeMode,
        );
      case 9:
        return const SubscriptionScreen(key: ValueKey('subscription'));
      case 10:
        return const AiReportsScreen(key: ValueKey('reports'));
      case 11:
        return const AssistantsScreen(key: ValueKey('assistants'));
      case 12:
        return const ProfileScreen(key: ValueKey('profile'));
      case 13:
        return const TeacherContactsScreen(key: ValueKey('contacts'));
      default:
        return _buildHome(key: const ValueKey('home'));
    }
  }

  String _planLabel(String? plan) {
    switch (plan?.toLowerCase()) {
      case 'basic': return 'Basic';
      case 'pro': return 'Pro';
      case 'premium': return 'Premium';
      default: return 'مجاني';
    }
  }

  Color _planColor(String? plan) {
    switch (plan?.toLowerCase()) {
      case 'pro': return AppTheme.accent;
      case 'premium': return AppTheme.warning;
      default: return AppTheme.success;
    }
  }

  Widget _buildHome({Key? key}) {
    final data = context.watch<DataProvider>();
    final auth = context.watch<AuthProvider>();
    final students = data.students;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final todayAttendance = _dashboardStats?['today_attendance'] ?? '-';
    final totalRevenue = _dashboardStats?['total_revenue'] ?? '-';
    final totalStudents = _dashboardStats?['total_students'] ?? students.length;
    final totalGroups = _dashboardStats?['total_groups'] ?? data.groups.length;
    final planName = auth.subscriptionData?['plan']?.toString();
    final planLabel = _planLabel(planName);
    final planColor = _planColor(planName);

    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(24),
      child: FadeTransition(
        opacity: _slideAnimation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(_slideAnimation),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.08),
                      isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.waving_hand, size: 14, color: AppTheme.accent),
                              const SizedBox(width: 6),
                              Text(
                                'مرحباً بك',
                                style: TextStyle(color: AppTheme.accent, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (auth.subscriptionLoaded)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: planColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: planColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.workspace_premium, size: 14, color: planColor),
                                const SizedBox(width: 4),
                                Text(
                                  planLabel,
                                  style: TextStyle(color: planColor, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لوحة التحكم',
                      style: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'نظرة شاملة على أداء طلابك',
                      style: TextStyle(color: textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'إحصائيات سريعة',
                    style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_dashboardLoading)
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                    ),
                  if (_dashboardError != null)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _fetchDashboardStats,
                        child: Text('إعادة المحاولة', style: TextStyle(color: AppTheme.danger, fontSize: 12)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.6,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StatCard(
                    title: 'عدد الطلاب',
                    value: totalStudents.toString(),
                    icon: Icons.people,
                    color: AppTheme.accent,
                  ),
                  StatCard(
                    title: 'عدد المجموعات',
                    value: totalGroups.toString(),
                    icon: Icons.groups,
                    color: AppTheme.accentLight,
                  ),
                  StatCard(
                    title: 'الحضور اليوم',
                    value: todayAttendance.toString(),
                    icon: Icons.check_circle,
                    color: AppTheme.success,
                  ),
                  StatCard(
                    title: 'الإيرادات',
                    value: _dashboardStats != null ? '$totalRevenue ج.م' : '-',
                    icon: Icons.account_balance,
                    color: AppTheme.warning,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'إجراءات سريعة',
                style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  QuickAction(
                    title: 'إضافة طالب',
                    icon: Icons.person_add,
                    color: AppTheme.accent,
                    onTap: _goToStudents,
                  ),
                  QuickAction(
                    title: 'تسجيل حضور',
                    icon: Icons.check_circle,
                    color: AppTheme.success,
                    onTap: _goToAttendance,
                  ),
                  QuickAction(
                    title: 'إضافة درجة',
                    icon: Icons.upload_file,
                    color: AppTheme.warning,
                    onTap: _goToGrades,
                  ),
                  QuickAction(
                    title: 'إنشاء فاتورة',
                    icon: Icons.receipt,
                    color: AppTheme.accentLight,
                    onTap: () => setState(() => _selectedIndex = 5),
                  ),
                  QuickAction(
                    title: 'التقارير',
                    icon: Icons.analytics,
                    color: AppTheme.accentDark,
                    onTap: () => setState(() => _selectedIndex = 10),
                  ),
                  QuickAction(
                    title: 'الامتحانات',
                    icon: Icons.quiz,
                    color: AppTheme.danger,
                    onTap: () => setState(() => _selectedIndex = 6),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      );
    }
  }
