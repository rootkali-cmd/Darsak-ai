import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحضور'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
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
            color: const Color(0xFFdc2626),
            backgroundColor: const Color(0xFF1a1a2e),
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
                  color: const Color(0xFF1a1a2e),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPresent ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                      child: Icon(
                        isPresent ? Icons.check : Icons.close,
                        color: isPresent ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${groupName.isNotEmpty ? '$groupName • ' : ''}${record['date'] ?? provider.today}',
                      style: const TextStyle(color: Color(0xFF6b7280), fontSize: 12),
                    ),
                    trailing: isPresent
                        ? Chip(
                            label: const Text('حاضر', style: TextStyle(fontSize: 12)),
                            backgroundColor: Colors.green.withValues(alpha: 0.2),
                            labelStyle: const TextStyle(color: Colors.green),
                            padding: EdgeInsets.zero,
                          )
                        : ElevatedButton(
                            onPressed: () => _markPresent(record),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFdc2626),
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
        backgroundColor: const Color(0xFFdc2626),
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
    );
  }
}
