import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/error_utils.dart';
import 'barcode_scanner_screen.dart';
import 'manual_attendance_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحضور'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'اليوم'),
            Tab(text: 'السجل'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
          );
        },
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _TodayTab(),
          _HistoryTab(),
        ],
      ),
    );
  }
}

class _TodayTab extends StatefulWidget {
  @override
  State<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<_TodayTab> {
  List<dynamic> _attendance = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  List<dynamic> get _filteredAttendance {
    if (_filter == 'all') return _attendance;
    return _attendance.where((a) {
      final s = (a['status'] ?? '').toString().trim().toLowerCase();
      return s == _filter;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  Future<void> _loadToday() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final resp = await ApiService().dio.get('/attendance/', queryParameters: {'date': today});
      final data = resp.data;
      _attendance = data is List ? data : [];
    } on DioException catch (e) {
      _error = 'فشل تحميل الحضور: ${getDioErrorMessage(e)}';
    } catch (e) {
      _error = 'حدث خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadToday,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadToday, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_attendance.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'الكل',
                              selected: _filter == 'all',
                              color: AppTheme.primary,
                              onTap: () => setState(() => _filter = 'all'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'حاضر',
                              selected: _filter == 'present',
                              color: AppTheme.success,
                              onTap: () => setState(() => _filter = 'present'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'غائب',
                              selected: _filter == 'absent',
                              color: AppTheme.danger,
                              onTap: () => setState(() => _filter = 'absent'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _filteredAttendance.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fact_check_outlined, size: 64, color: AppTheme.textMuted),
                                  SizedBox(height: 16),
                                  Text('لا يوجد حضور اليوم', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filteredAttendance.length,
                              itemBuilder: (_, i) {
                                final a = _filteredAttendance[i];
                                final status = (a['status'] ?? '').toString().trim().toLowerCase();
                                final isPresent = status == 'present';
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: Icon(
                                      isPresent ? Icons.check_circle : Icons.cancel,
                                      color: isPresent ? AppTheme.success : AppTheme.danger,
                                    ),
                                    title: Text(a['student_name'] ?? a['student']?['full_name'] ?? '—'),
                                    subtitle: Text(a['date'] ?? ''),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isPresent ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.danger.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isPresent ? 'حاضر' : 'غائب',
                                        style: TextStyle(
                                          color: isPresent ? AppTheme.success : AppTheme.danger,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _HistoryTab extends StatefulWidget {
  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  List<dynamic> _attendance = [];
  bool _loading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadByDate();
  }

  Future<void> _loadByDate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final date = _selectedDate.toIso8601String().split('T')[0];
      final resp = await ApiService().dio.get('/attendance/', queryParameters: {'date': date});
      final data = resp.data;
      _attendance = data is List ? data : [];
    } on DioException catch (e) {
      _error = 'فشل تحميل السجل: ${getDioErrorMessage(e)}';
    } catch (e) {
      _error = 'حدث خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadByDate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: InkWell(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateStr, style: const TextStyle(fontSize: 15)),
                  const Icon(Icons.calendar_today, color: AppTheme.accent),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadByDate,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadByDate, child: const Text('إعادة المحاولة')),
                          ],
                        ),
                      )
                    : _attendance.isEmpty
                        ? const Center(
                            child: Text('لا توجد سجلات حضور', style: TextStyle(color: AppTheme.textSecondary)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _attendance.length,
                            itemBuilder: (_, i) {
                              final a = _attendance[i];
                              final status = (a['status'] ?? '').toString().trim().toLowerCase();
                              final isPresent = status == 'present';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(
                                    isPresent ? Icons.check_circle : Icons.cancel,
                                    color: isPresent ? AppTheme.success : AppTheme.danger,
                                  ),
                                  title: Text(a['student_name'] ?? a['student']?['full_name'] ?? '—'),
                                  subtitle: Text(a['date'] ?? ''),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPresent ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.danger.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isPresent ? 'حاضر' : 'غائب',
                                      style: TextStyle(
                                        color: isPresent ? AppTheme.success : AppTheme.danger,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
