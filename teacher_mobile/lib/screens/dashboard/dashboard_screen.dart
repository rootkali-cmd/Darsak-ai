import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/data_provider.dart';
import '../../providers/sync_provider.dart';
import '../students/students_screen.dart';
import '../attendance/attendance_screen.dart';
import '../grades/grades_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الرئيسية',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Consumer<SyncProvider>(
                                builder: (context, sync, _) {
                                  return Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: sync.isOnline ? AppTheme.success : AppTheme.warning,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        sync.status,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurface2,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.notifications_none, color: AppTheme.darkTextSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AnimationLimiter(
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.3,
                        children: [
                          _StatCard(
                            icon: Icons.people,
                            label: 'الطلاب',
                            color: AppTheme.accent,
                            builder: (data) => data.students.length.toString(),
                            onTap: () => _navigateTo(const StudentsScreen()),
                          ),
                          _StatCard(
                            icon: Icons.group_work,
                            label: 'المجموعات',
                            color: AppTheme.accentLight,
                            builder: (data) => data.groups.length.toString(),
                            onTap: () {},
                          ),
                          _StatCard(
                            icon: Icons.fact_check,
                            label: 'حضور اليوم',
                            color: AppTheme.success,
                            builder: (data) => '--',
                            onTap: () => _navigateTo(const AttendanceScreen()),
                          ),
                          _StatCard(
                            icon: Icons.attach_money,
                            label: 'الإيرادات',
                            color: AppTheme.warning,
                            builder: (data) => '--',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'الإجراءات السريعة',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _QuickAction(
                      icon: Icons.qr_code_scanner,
                      label: 'مسح الباركود',
                      color: AppTheme.accent,
                      onTap: () => _navigateTo(const AttendanceScreen()),
                    ),
                    const SizedBox(height: 10),
                    _QuickAction(
                      icon: Icons.person_add,
                      label: 'إضافة طالب جديد',
                      color: AppTheme.success,
                      onTap: () => _navigateTo(const StudentsScreen()),
                    ),
                    const SizedBox(height: 10),
                    _QuickAction(
                      icon: Icons.add_chart,
                      label: 'إضافة درجة',
                      color: AppTheme.warning,
                      onTap: () => _navigateTo(const GradesScreen()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String Function(DataProvider) builder;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.builder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const Spacer(),
            Consumer<DataProvider>(
              builder: (context, data, _) {
                return Text(
                  builder(data),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 24,
                        color: AppTheme.darkTextPrimary,
                      ),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: AppTheme.darkTextMuted, size: 14),
          ],
        ),
      ),
    );
  }
}
