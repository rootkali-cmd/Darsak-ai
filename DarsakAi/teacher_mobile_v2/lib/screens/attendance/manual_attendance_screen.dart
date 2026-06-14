import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/error_utils.dart';

class ManualAttendanceScreen extends StatefulWidget {
  const ManualAttendanceScreen({super.key});

  @override
  State<ManualAttendanceScreen> createState() => _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState extends State<ManualAttendanceScreen> {
  List<dynamic> _students = [];
  bool _loading = true;
  String? _error;
  final Map<int, bool> _markedStudents = {};

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService().dio.get('/students/');
      final data = resp.data;
      if (data is Map && data.containsKey('data')) {
        _students = data['data'] as List<dynamic>;
      } else if (data is List) {
        _students = data;
      } else {
        _students = [];
      }
    } on DioException catch (e) {
      _error = 'فشل تحميل الطلاب: ${getDioErrorMessage(e)}';
    } catch (e) {
      _error = 'حدث خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markAttendance(int studentId, String status) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      await ApiService().dio.post('/attendance/', data: {
        'student_id': studentId,
        'date': today,
        'status': status,
      });
      setState(() => _markedStudents[studentId] = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الحضور'), backgroundColor: AppTheme.success, duration: Duration(milliseconds: 800)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الحضور يدوياً')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadStudents, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : _students.isEmpty
                  ? const Center(child: Text('لا يوجد طلاب', style: TextStyle(color: AppTheme.textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _students.length,
                      itemBuilder: (_, i) {
                        final s = _students[i];
                        final id = int.tryParse(s['id'].toString()) ?? 0;
                        final marked = _markedStudents[id] ?? false;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(s['full_name'] ?? '—'),
                            subtitle: Text(s['code'] ?? ''),
                            trailing: marked
                                ? const Icon(Icons.check_circle, color: AppTheme.success)
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check_circle_outline, color: AppTheme.success),
                                        onPressed: () => _markAttendance(id, 'present'),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.cancel_outlined, color: AppTheme.danger),
                                        onPressed: () => _markAttendance(id, 'absent'),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
    );
  }
}
