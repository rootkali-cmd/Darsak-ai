import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../core/app_theme.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/empty_state.dart';
import 'barcode_scanner_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AttendanceProvider>(context, listen: false).loadAttendance();
    });
  }

  Future<void> _markPresent(dynamic record) async {
    final studentId = record['student_id'] ?? record['student']?['id'];
    if (studentId == null) return;

    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final result = await provider.markAttendance(studentId, status: 'present');
    if (mounted) {
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل الحضور')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'فشل التسجيل')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحضور'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              final provider = Provider.of<AttendanceProvider>(context, listen: false);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
              ).then((_) {
                if (mounted) provider.loadAttendance();
              });
            },
          ),
        ],
      ),
      body: Consumer<AttendanceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const AppLoadingIndicator();
          }
          if (provider.error != null && provider.attendance.isEmpty) {
            return AppErrorWidget(
              message: provider.error!,
              onRetry: () => provider.loadAttendance(),
            );
          }
          if (provider.attendance.isEmpty) {
            return EmptyState(
              message: 'لا يوجد سجل حضور لهذا اليوم',
              icon: Icons.fact_check,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                      ).then((_) => provider.loadAttendance());
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('مسح الباركود'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => provider.loadAttendance(),
            color: AppTheme.accent,
            backgroundColor: colorScheme.surface,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: provider.attendance.length,
              itemBuilder: (context, index) {
                final record = provider.attendance[index];
                final student = record['student'] ?? {};
                final name = student['full_name'] ?? student['name'] ?? '—';
                final status = record['status']?.toString() ?? 'absent';
                final isPresent = status == 'present';
                final groupName = student['group']?['name']?.toString() ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPresent
                          ? AppTheme.success.withValues(alpha: 0.2)
                          : AppTheme.danger.withValues(alpha: 0.2),
                      child: Icon(
                        isPresent ? Icons.check : Icons.close,
                        color: isPresent ? AppTheme.success : AppTheme.danger,
                      ),
                    ),
                    title: Text(name, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${groupName.isNotEmpty ? '$groupName • ' : ''}${record['date'] ?? provider.today}',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
                        fontSize: 12,
                      ),
                    ),
                    trailing: isPresent
                        ? Chip(
                            label: const Text('حاضر', style: TextStyle(fontSize: 12)),
                            backgroundColor: AppTheme.success.withValues(alpha: 0.2),
                            labelStyle: const TextStyle(color: AppTheme.success),
                            padding: EdgeInsets.zero,
                          )
                        : ElevatedButton(
                            onPressed: () => _markPresent(record),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: const Size(60, 32),
                            ),
                            child: const Text('تسجيل', style: TextStyle(fontSize: 12)),
                          ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final provider = Provider.of<AttendanceProvider>(context, listen: false);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
          ).then((_) {
            if (mounted) provider.loadAttendance();
          });
        },
        child: const Icon(Icons.qr_code_scanner),
      ),
    );
  }
}
