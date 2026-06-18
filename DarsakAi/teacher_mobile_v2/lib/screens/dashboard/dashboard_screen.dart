import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';
import '../../providers/auth_provider.dart';
import '../attendance/attendance_screen.dart';
import '../students/add_edit_student_screen.dart';
import '../invoices/teacher_create_invoice_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _error;
  static const _cacheKey = 'dashboard_stats_cache';

  @override
  void initState() {
    super.initState();
    // Load cached data immediately
    _loadCache();
    // Fetch fresh data in background
    _fetchStats();
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final data = jsonDecode(cached);
        if (data is Map<String, dynamic>) {
          setState(() {
            _stats = data;
            _loading = false;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchStats() async {
    try {
      final resp = await ApiService().dio.get('/dashboard/stats',
        options: Options(sendTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)),
      );
      final data = resp.data;
      if (data is Map<String, dynamic>) {
        // Cache the result
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(data));
        
        if (mounted) {
          setState(() {
            _stats = data;
            _loading = false;
            _error = null;
          });
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (_stats.isEmpty) {
            _error = 'فشل تحميل الإحصائيات: ${getDioErrorMessage(e)}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (_stats.isEmpty) {
            _error = 'حدث خطأ: $e';
          }
        });
      }
    }
  }

  String _safeStat(String key) {
    final val = _stats[key];
    if (val == null) return '0';
    if (val is num) return val.toInt().toString();
    final str = val.toString();
    if (str.isEmpty || str == 'null') return '0';
    return str;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _stats.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: GlassTheme.indigo));
    }
    if (_error != null && _stats.isEmpty) return _buildError();
    return RefreshIndicator(
      onRefresh: _fetchStats,
      color: GlassTheme.indigo,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildGreeting(),
          const SizedBox(height: 20),
          _buildStatsGrid(),
          const SizedBox(height: 28),
          Text(
            'إجراءات سريعة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: GlassTheme.textPrimary(context),
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final user = context.watch<AuthProvider>().user;
    final name = user?['full_name'] ?? '';
    final greeting = name.isNotEmpty ? 'مرحباً، $name' : 'مرحباً بك';
    final now = DateTime.now();
    final dateStr = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GlassTheme.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GlassTheme.cardBorder(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: GlassTheme.textPrimary(context),
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 13,
                    color: GlassTheme.textSecondary(context),
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GlassTheme.cardBg(context),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.dashboard_rounded, color: GlassTheme.iconPrimary(context), size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.85,
      children: [
        _StatCard(
          icon: Icons.people_rounded,
          label: 'الطلاب',
          count: _safeStat('total_students'),
          subtitle: 'الطلاب المسجلين',
          color: const Color(0xFF3B82F6),
        ),
        _StatCard(
          icon: Icons.groups_rounded,
          label: 'المجموعات',
          count: _safeStat('total_groups'),
          subtitle: 'المجموعات الدراسية',
          color: const Color(0xFF8B5CF6),
        ),
        _StatCard(
          icon: Icons.fact_check_rounded,
          label: 'الحضور',
          count: _safeStat('today_attendance'),
          subtitle: 'حضور اليوم',
          color: const Color(0xFF10B981),
        ),
        _StatCard(
          icon: Icons.receipt_rounded,
          label: 'إيرادات الشهر',
          count: _safeStat('monthly_revenue'),
          subtitle: 'إيرادات هذا الشهر',
          color: const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.how_to_reg,
            label: 'تسجيل حضور',
            color: AppTheme.success,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AttendanceScreen()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.person_add,
            label: 'إضافة طالب',
            color: AppTheme.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditStudentScreen()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.receipt_long,
            label: 'فاتورة',
            color: AppTheme.warning,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeacherCreateInvoiceScreen()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.danger.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.danger),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: GlassTheme.textSecondary(context), fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchStats,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
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
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: GlassTheme.cardBg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GlassTheme.cardBorder(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: GlassTheme.iconPrimary(context), size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: GlassTheme.textPrimary(context),
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String count;
  final String subtitle;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GlassTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlassTheme.cardBorder(context)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              count,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: GlassTheme.textPrimary(context),
                fontFamily: 'Cairo',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: GlassTheme.textPrimary(context),
                fontFamily: 'Cairo',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: GlassTheme.textMuted(context),
                fontFamily: 'Cairo',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
