import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/subscription_service.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/sidebar.dart';
import '../widgets/sync_indicator.dart';
import '../widgets/stat_card.dart';
import '../widgets/quick_action.dart';
import '../widgets/subscription_overlay.dart';
import 'students_screen.dart';
import 'groups_screen.dart';
import 'attendance_screen.dart';
import 'grades_screen.dart';
import 'invoices_screen.dart';
import 'settings_screen.dart';
import 'qr_screen.dart';
import 'subscription_screen.dart';

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
  late VoidCallback _goToGroups;
  late VoidCallback _goToAttendance;
  late VoidCallback _goToGrades;

  final _subscriptionService = SubscriptionService();
  bool _subscriptionExpired = false;

  @override
  void initState() {
    super.initState();
    _goToStudents = () => setState(() => _selectedIndex = 1);
    _goToGroups = () => setState(() => _selectedIndex = 2);
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
      _checkSubscription();
    });
  }

  Future<void> _checkSubscription() async {
    final sub = await _subscriptionService.getMySubscription();
    if (sub != null) {
      await _subscriptionService.cacheSubscription(sub);
    }
    final cached = sub ?? await _subscriptionService.getCachedSubscription();
    final expired = !_subscriptionService.isSubscriptionActive(cached);
    if (!mounted) return;
    setState(() {
      _subscriptionExpired = expired;
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sync = context.watch<SyncProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              Sidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: (i) {
                  setState(() => _selectedIndex = i);
                  _slideController.reset();
                  _slideController.forward();
                },
                userName: auth.user?.fullName ?? 'مدرس',
                onLogout: () => auth.logout(),
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
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sync.isOnline ? AppTheme.success : AppTheme.danger,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            sync.isOnline ? 'متصل' : 'غير متصل',
                            style: TextStyle(
                              color: sync.isOnline ? AppTheme.success : AppTheme.danger,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '/',
                            style: TextStyle(color: borderColor, fontSize: 13),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _getPageTitle(),
                            style: TextStyle(color: textMuted, fontSize: 13),
                          ),
                          const Spacer(),
                          SyncIndicator(
                            isOnline: sync.isOnline,
                            isSyncing: sync.isSyncing,
                            status: sync.status,
                            onSync: () => context.read<SyncProvider>().syncNow(),
                          ),
                          const SizedBox(width: 8),
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
          if (_subscriptionExpired && _selectedIndex != 7)
            SubscriptionOverlay(
              onRefresh: _checkSubscription,
              onActivate: () {
                setState(() => _selectedIndex = 7);
              },
            ),
        ],
      ),
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
      case 6: return 'QR Code';
      case 7: return 'الاشتراكات';
      case 8: return 'الإعدادات';
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
        return const QrScreen(key: ValueKey('qr'));
      case 7:
        return const SubscriptionScreen(key: ValueKey('subscription'));
      case 8:
        return const SettingsScreen(key: ValueKey('settings'));
      default:
        return _buildHome(key: const ValueKey('home'));
    }
  }

  Widget _buildHome({Key? key}) {
    final data = context.watch<DataProvider>();
    final students = data.students;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

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
                    const SizedBox(height: 16),
                    Text(
                      'لوحة التحكم',
                      style: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'نظرة شاملة على أداء طلابك مع تحليلات ذكية',
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
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${students.length} طالب',
                      style: TextStyle(color: AppTheme.accent, fontSize: 11),
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
                  StatCard(label: 'إجمالي الطلاب', value: students.length.toString(), icon: Icons.people, color: AppTheme.accent),
                  StatCard(label: 'المجموعات', value: data.groups.length.toString(), icon: Icons.groups, color: AppTheme.accentLight),
                  StatCard(label: 'الدرجات', value: '-', icon: Icons.grade, color: AppTheme.success),
                  StatCard(label: 'الفواتير', value: '-', icon: Icons.receipt, color: AppTheme.warning),
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
                  QuickAction(label: 'إضافة طالب', icon: Icons.person_add, color: AppTheme.accent, onTap: _goToStudents),
                  QuickAction(label: 'إنشاء مجموعة', icon: Icons.group_add, color: AppTheme.accentLight, onTap: _goToGroups),
                  QuickAction(label: 'تسجيل حضور', icon: Icons.check_circle, color: AppTheme.success, onTap: _goToAttendance),
                  QuickAction(label: 'رفع درجات', icon: Icons.upload_file, color: AppTheme.warning, onTap: _goToGrades),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
