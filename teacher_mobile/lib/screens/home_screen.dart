import 'dart:async';
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

  final List<Widget> _screens = const [
    DashboardScreen(),
    StudentsScreen(),
    AttendanceScreen(),
    GradesScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final updateService = UpdateService();
    final update = await updateService.checkForUpdate();
    if (update == null || !mounted) return;

    final remindActive = await updateService.isRemindLaterActive();
    if (remindActive) return;

    _showUpdateDialog(update, updateService);
  }

  void _showUpdateDialog(Map<String, dynamic> update, UpdateService service) {
    final version = update['latest_version'] ?? '';
    final changelog = update['changelog'] ?? '';
    final currentVersion = update['current_version'] ?? '';
    double downloadProgress = 0;
    bool downloading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('تحديث متوفر'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الإصدار الحالي: $currentVersion'),
                  const SizedBox(height: 4),
                  Text('الإصدار الجديد: $version',
                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                  if (changelog.toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('التغييرات:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(changelog.toString(), style: const TextStyle(fontSize: 12)),
                  ],
                  if (downloading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: downloadProgress > 0 ? downloadProgress : null),
                    const SizedBox(height: 8),
                    Text('جاري التحميل... ${(downloadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
              actions: downloading
                  ? [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء'),
                      ),
                    ]
                  : [
                      TextButton(
                        onPressed: () {
                          service.setRemindLater();
                          Navigator.pop(ctx);
                        },
                        child: const Text('تذكير لاحقاً'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          setDialogState(() => downloading = true);
                          try {
                            await service.downloadAndInstall(
                              version: version.toString(),
                              onProgress: (p) {
                                setDialogState(() => downloadProgress = p);
                              },
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setDialogState(() {
                              downloading = false;
                              downloadProgress = 0;
                            });
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('فشل التحميل: $e'),
                                  backgroundColor: AppTheme.danger,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                        child: const Text('تحديث الآن'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'الطلاب'),
          BottomNavigationBarItem(icon: Icon(Icons.fact_check_outlined), activeIcon: Icon(Icons.fact_check), label: 'الحضور'),
          BottomNavigationBarItem(icon: Icon(Icons.grade_outlined), activeIcon: Icon(Icons.grade), label: 'الدرجات'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_outlined), activeIcon: Icon(Icons.menu), label: 'المزيد'),
        ],
      ),
    );
  }
}
