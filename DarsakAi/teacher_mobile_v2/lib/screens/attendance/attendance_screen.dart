import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../core/error_utils.dart';
import '../../core/glass_theme.dart';
import '../../core/subscription_guard.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: GlassTheme.glassAppBar(
        'الحضور',
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: GlassTheme.indigo,
          labelColor: GlassTheme.textPrimary(context),
          unselectedLabelColor: GlassTheme.textSecondary(context),
          tabs: const [
            Tab(text: 'اليوم'),
            Tab(text: 'السجل'),
          ],
        ),
      ),
      floatingActionButton: GlassTheme.glassFAB(
        () async {
          if (!checkSubscription(context)) return;
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
          );
          // Reload attendance after returning from scanner
          if (mounted) setState(() {});
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
  static const _cacheKey = 'attendance_today_cache';

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
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final resp = await ApiService().dio.get('/attendance/', queryParameters: {'date': today});
      final data = resp.data;
      if (data is List) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(data));
        if (mounted) setState(() { _attendance = data; _loading = false; });
      }
    } catch (_) {
      // Try loading from cache
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_cacheKey);
        if (cached != null) {
          final data = jsonDecode(cached);
          if (data is List && mounted) setState(() { _attendance = data; _loading = false; });
          return;
        }
      } catch (_) {}
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getStudentName(dynamic a) {
    // Try multiple possible fields for student name
    if (a['student_name'] != null && a['student_name'].toString().isNotEmpty) {
      return a['student_name'].toString();
    }
    if (a['student'] != null && a['student'] is Map) {
      final student = a['student'] as Map;
      if (student['full_name'] != null) return student['full_name'].toString();
      if (student['name'] != null) return student['name'].toString();
    }
    if (a['full_name'] != null && a['full_name'].toString().isNotEmpty) {
      return a['full_name'].toString();
    }
    if (a['name'] != null && a['name'].toString().isNotEmpty) {
      return a['name'].toString();
    }
    // Show code if name not available
    if (a['student_code'] != null) return 'كود: ${a['student_code']}';
    if (a['code'] != null) return 'كود: ${a['code']}';
    if (a['student_id'] != null) return 'ID: ${a['student_id'].toString().substring(0, 8)}';
    return 'غير معروف';
  }

  String _getStudentCode(dynamic a) {
    if (a['student_code'] != null) return a['student_code'].toString();
    if (a['code'] != null) return a['code'].toString();
    if (a['student'] != null && a['student'] is Map) {
      final student = a['student'] as Map;
      if (student['code'] != null) return student['code'].toString();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadToday,
      color: GlassTheme.indigo,
      child: _loading && _attendance.isEmpty
          ? const Center(child: CircularProgressIndicator(color: GlassTheme.indigo))
          : Column(
                  children: [
                    // Stats summary
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: GlassTheme.glassCard(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat('الكل', '${_attendance.length}', GlassTheme.indigo),
                          _buildStat('حاضر', '${_attendance.where((a) => a['status'] == 'present').length}', GlassTheme.green),
                          _buildStat('غائب', '${_attendance.where((a) => a['status'] == 'absent').length}', GlassTheme.red),
                        ],
                      ),
                    ),
                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          GlassTheme.glassFilterChip(context, 'الكل', _filter == 'all', GlassTheme.indigo, () => setState(() => _filter = 'all')),
                          const SizedBox(width: 8),
                          GlassTheme.glassFilterChip(context, 'حاضر', _filter == 'present', GlassTheme.green, () => setState(() => _filter = 'present')),
                          const SizedBox(width: 8),
                          GlassTheme.glassFilterChip(context, 'غائب', _filter == 'absent', GlassTheme.red, () => setState(() => _filter = 'absent')),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _filteredAttendance.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fact_check_outlined, size: 64, color: GlassTheme.textSecondary(context)),
                                  const SizedBox(height: 16),
                                  Text('لا يوجد حضور اليوم', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 16)),
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
                                final studentName = _getStudentName(a);
                                final studentCode = _getStudentCode(a);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: GlassTheme.glassCard(context),
                                  child: ListTile(
                                    leading: Icon(
                                      isPresent ? Icons.check_circle : Icons.cancel,
                                      color: isPresent ? GlassTheme.green : GlassTheme.red,
                                    ),
                                    title: Text(studentName, style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.w600)),
                                    subtitle: studentCode.isNotEmpty 
                                      ? Text(studentCode, style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 12))
                                      : null,
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

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 12)),
      ],
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

  @override
  void initState() {
    super.initState();
    _loadAllHistory();
  }

  Future<void> _loadAllHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService().dio.get('/attendance/');
      final data = resp.data;
      _attendance = data is List ? data : [];
    } on DioException catch (e) {
      _error = 'فشل تحميل السجل: ${getDioErrorMessage(e)}';
    } catch (e) {
      _error = 'حدث خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  String _getStudentName(dynamic a) {
    if (a['student_name'] != null && a['student_name'].toString().isNotEmpty) {
      return a['student_name'].toString();
    }
    if (a['student'] != null && a['student'] is Map) {
      final student = a['student'] as Map;
      if (student['full_name'] != null) return student['full_name'].toString();
      if (student['name'] != null) return student['name'].toString();
    }
    if (a['full_name'] != null && a['full_name'].toString().isNotEmpty) {
      return a['full_name'].toString();
    }
    if (a['student_code'] != null) return 'كود: ${a['student_code']}';
    if (a['student_id'] != null) return 'ID: ${a['student_id'].toString().substring(0, 8)}';
    return 'غير معروف';
  }

  String _getStudentCode(dynamic a) {
    if (a['student_code'] != null) return a['student_code'].toString();
    if (a['code'] != null) return a['code'].toString();
    if (a['student'] != null && a['student'] is Map) {
      final student = a['student'] as Map;
      if (student['code'] != null) return student['code'].toString();
    }
    return '';
  }

  Map<String, List<dynamic>> _groupByDate() {
    final map = <String, List<dynamic>>{};
    for (final a in _attendance) {
      final d = a['date'] ?? 'غير محدد';
      map.putIfAbsent(d, () => []).add(a);
    }
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in sortedKeys) k: map[k]!};
  }

  String _formatDateArabic(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return dateStr;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final months = [
        '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      return '$day ${months[month]} $year';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAllHistory,
      color: GlassTheme.indigo,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: GlassTheme.indigo))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: GlassTheme.textMuted(context))),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadAllHistory, style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.indigo), child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : _attendance.isEmpty
                  ? Center(
                      child: Text('لا توجد سجلات حضور', style: TextStyle(color: GlassTheme.textSecondary(context))),
                    )
                  : _buildGroupedList(),
    );
  }

  Widget _buildGroupedList() {
    final grouped = _groupByDate();
    final sections = <Widget>[];
    for (final entry in grouped.entries) {
      final dateLabel = _formatDateArabic(entry.key);
      final records = entry.value;
      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: GlassTheme.indigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: GlassTheme.indigo),
                const SizedBox(width: 8),
                Text(dateLabel, style: TextStyle(color: GlassTheme.indigo, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 8),
                Text('(${records.length})', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 12)),
              ],
            ),
          ),
        ),
      );
      for (final a in records) {
        final status = a['status'] ?? '';
        final isPresent = status == 'present';
        final studentName = _getStudentName(a);
        final studentCode = _getStudentCode(a);
        sections.add(
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: GlassTheme.glassCard(context),
            child: ListTile(
              leading: Icon(
                isPresent ? Icons.check_circle : Icons.cancel,
                color: isPresent ? GlassTheme.green : GlassTheme.red,
              ),
              title: Text(studentName, style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.w600)),
              subtitle: studentCode.isNotEmpty
                  ? Text(studentCode, style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 12))
                  : null,
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
          ),
        );
      }
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: sections,
    );
  }
}
