import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../../core/glass_theme.dart';
import '../../services/reports_api_service.dart';
import '../../services/api_service.dart';

class AiReportsScreen extends StatefulWidget {
  const AiReportsScreen({super.key});

  @override
  State<AiReportsScreen> createState() => _AiReportsScreenState();
}

class _AiReportsScreenState extends State<AiReportsScreen> {
  final ReportsApiService _reportsApi = ReportsApiService();
  final ApiService _api = ApiService();

  List<dynamic> _students = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  String? _error;

  String? _selectedSubject;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  final List<String> _subjects = ['الرياضيات', 'الفيزياء', 'الكيمياء', 'الأحياء', 'اللغة العربية', 'اللغة الإنجليزية'];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final me = await _api.getMe();
      final teacherId = me['id'] ?? me['data']?['id'] ?? '';

      final dateFromStr = _dateFrom != null
          ? intl.DateFormat('yyyy-MM-dd').format(_dateFrom!)
          : null;
      final dateToStr = _dateTo != null
          ? intl.DateFormat('yyyy-MM-dd').format(_dateTo!)
          : null;

      final result = await _reportsApi.getStudentReports(
        teacherId,
        subject: _selectedSubject,
        dateFrom: dateFromStr,
        dateTo: dateToStr,
      );

      if (!mounted) return;
      setState(() {
        _students = result['students'] ?? [];
        _summary = result['summary'] ?? {};
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'حدث خطأ أثناء تحميل البيانات';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_dateFrom ?? DateTime.now()) : (_dateTo ?? DateTime.now()),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
      _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: GlassTheme.glassAppBar('التقارير الذكية'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: GlassTheme.red),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: GlassTheme.textPrimary(context))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReports,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 16),
                      _buildFilters(),
                      const SizedBox(height: 16),
                      _buildStudentsList(),
                      const SizedBox(height: 16),
                      _buildAnalysisSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCards() {
    final totalStudents = _summary['total_students'] ?? 0;
    final avgScore = _summary['average_score'] ?? 0;
    final passRate = _summary['pass_rate'] ?? 0;

    return Row(
      children: [
        Expanded(child: _buildSummaryCard('عدد الطلاب', '$totalStudents', Icons.people, GlassTheme.indigo)),
        const SizedBox(width: 8),
        Expanded(child: _buildSummaryCard('متوسط الدرجات', '${avgScore.toStringAsFixed(1)}%', Icons.trending_up, GlassTheme.cyan)),
        const SizedBox(width: 8),
        Expanded(child: _buildSummaryCard('نسبة النجاح', '${passRate.toStringAsFixed(1)}%', Icons.check_circle, GlassTheme.green)),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: GlassTheme.glassCard(context),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: GlassTheme.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GlassTheme.glassCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('التصفية', style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedSubject,
            decoration: InputDecoration(
              labelText: 'المادة',
              labelStyle: TextStyle(color: GlassTheme.textSecondary(context)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: GlassTheme.cardBg(context),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('الكل')),
              ..._subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
            ],
            onChanged: (val) {
              setState(() => _selectedSubject = val);
              _loadReports();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isFrom: true),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_dateFrom != null
                      ? intl.DateFormat('yyyy-MM-dd').format(_dateFrom!)
                      : 'من تاريخ'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isFrom: false),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_dateTo != null
                      ? intl.DateFormat('yyyy-MM-dd').format(_dateTo!)
                      : 'إلى تاريخ'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    if (_students.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: GlassTheme.glassCard(context),
        child: Center(
          child: Text('لا توجد بيانات طلاب', style: TextStyle(color: GlassTheme.textSecondary(context))),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('أداء الطلاب', style: TextStyle(color: GlassTheme.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._students.map((s) => _buildStudentCard(s)),
      ],
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final name = student['name'] ?? 'طالب';
    final avgScore = (student['average_score'] ?? 0).toDouble();
    final examsCount = student['exams_count'] ?? 0;

    Color barColor;
    if (avgScore > 80) {
      barColor = GlassTheme.green;
    } else if (avgScore >= 50) {
      barColor = const Color(0xFFF59E0B);
    } else {
      barColor = GlassTheme.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: GlassTheme.glassCard(context),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: barColor.withValues(alpha: 0.15),
            child: Icon(Icons.person, color: barColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text('$examsCount اختبار', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 11)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: avgScore / 100,
                    backgroundColor: GlassTheme.textSecondary(context).withValues(alpha: 0.2),
                    color: barColor,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${avgScore.toStringAsFixed(1)}%', style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildAnalysisSection() {
    final analysis = _summary['analysis'] ?? 'لا توجد بيانات كافية للتحليل.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: GlassTheme.glassCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: GlassTheme.indigo, size: 22),
              const SizedBox(width: 8),
              Text('تحليل AI', style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            analysis,
            style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}
