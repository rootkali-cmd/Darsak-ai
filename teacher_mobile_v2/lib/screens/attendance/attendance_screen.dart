import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/error_utils.dart';
import '../../core/glass_theme.dart';
import 'barcode_scanner_screen.dart';

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
      backgroundColor: const Color(0xFF0F172A),
      appBar: GlassTheme.glassAppBar(
        'الحضور',
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: GlassTheme.indigo,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(text: 'اليوم'),
            Tab(text: 'السجل'),
          ],
        ),
      ),
      floatingActionButton: GlassTheme.glassFAB(
        () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
          );
        },
        icon: Icons.qr_code_scanner,
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
    if (_filter == 'present') return _attendance.where((a) => a['status'] == 'present').toList();
    if (_filter == 'absent') return _attendance.where((a) => a['status'] == 'absent').toList();
    return _attendance;
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
      color: GlassTheme.indigo,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: GlassTheme.indigo))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: GlassTheme.red),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadToday, style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.indigo), child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_attendance.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            GlassTheme.glassFilterChip('الكل', _filter == 'all', GlassTheme.indigo, () => setState(() => _filter = 'all')),
                            const SizedBox(width: 8),
                            GlassTheme.glassFilterChip('حاضر', _filter == 'present', GlassTheme.green, () => setState(() => _filter = 'present')),
                            const SizedBox(width: 8),
                            GlassTheme.glassFilterChip('غائب', _filter == 'absent', GlassTheme.red, () => setState(() => _filter = 'absent')),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _filteredAttendance.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fact_check_outlined, size: 64, color: Color(0xFF94A3B8)),
                                  SizedBox(height: 16),
                                  Text('لا يوجد حضور اليوم', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filteredAttendance.length,
                              itemBuilder: (_, i) {
                                final a = _filteredAttendance[i];
                                final status = a['status'] ?? '';
                                final isPresent = status == 'present';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: GlassTheme.glassCard,
                                  child: ListTile(
                                    leading: Icon(
                                      isPresent ? Icons.check_circle : Icons.cancel,
                                      color: isPresent ? GlassTheme.green : GlassTheme.red,
                                    ),
                                    title: Text(a['student_name'] ?? a['student']?['full_name'] ?? '—', style: const TextStyle(color: Colors.white)),
                                    subtitle: Text(a['date'] ?? '', style: const TextStyle(color: Color(0xFF94A3B8))),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isPresent ? GlassTheme.green.withValues(alpha: 0.15) : GlassTheme.red.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isPresent ? 'حاضر' : 'غائب',
                                        style: TextStyle(
                                          color: isPresent ? GlassTheme.green : GlassTheme.red,
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
              decoration: GlassTheme.glassCard,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateStr, style: const TextStyle(fontSize: 15, color: Colors.white)),
                  const Icon(Icons.calendar_today, color: GlassTheme.indigo),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadByDate,
            color: GlassTheme.indigo,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: GlassTheme.indigo))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadByDate, style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.indigo), child: const Text('إعادة المحاولة')),
                          ],
                        ),
                      )
                    : _attendance.isEmpty
                        ? const Center(
                            child: Text('لا توجد سجلات حضور', style: TextStyle(color: Color(0xFF94A3B8))),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _attendance.length,
                            itemBuilder: (_, i) {
                              final a = _attendance[i];
                              final status = a['status'] ?? '';
                              final isPresent = status == 'present';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: GlassTheme.glassCard,
                                child: ListTile(
                                  leading: Icon(
                                    isPresent ? Icons.check_circle : Icons.cancel,
                                    color: isPresent ? GlassTheme.green : GlassTheme.red,
                                  ),
                                  title: Text(a['student_name'] ?? a['student']?['full_name'] ?? '—', style: const TextStyle(color: Colors.white)),
                                  subtitle: Text(a['date'] ?? '', style: const TextStyle(color: Color(0xFF94A3B8))),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPresent ? GlassTheme.green.withValues(alpha: 0.15) : GlassTheme.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isPresent ? 'حاضر' : 'غائب',
                                      style: TextStyle(
                                        color: isPresent ? GlassTheme.green : GlassTheme.red,
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
