import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/reports_api_service.dart';
import '../../../core/api/api_client.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/api/subscription_guard.dart';

class AiReportsScreen extends StatefulWidget {
  const AiReportsScreen({super.key});

  @override
  State<AiReportsScreen> createState() => _AiReportsScreenState();
}

class _AiReportsScreenState extends State<AiReportsScreen> {
  ReportsApiService? _reportsApi;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => checkSubscription(context));
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final teacherId = auth.user?.id ?? '';
      if (teacherId.isEmpty) {
        if (!mounted) return;
        setState(() { _error = 'لم يتم العثور على حساب المدرس'; _isLoading = false; });
        return;
      }
      _reportsApi ??= ReportsApiService(auth.client);

      final dateFromStr = _dateFrom != null ? intl.DateFormat('yyyy-MM-dd').format(_dateFrom!) : null;
      final dateToStr = _dateTo != null ? intl.DateFormat('yyyy-MM-dd').format(_dateTo!) : null;

      final result = await _reportsApi!.getStudentReports(
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
      final msg = e.toString();
      setState(() {
        _error = msg.contains('401') || msg.contains('403')
            ? 'ليس لديك صلاحية لعرض التقارير'
            : msg.contains('500')
                ? 'خطأ في الخادم، حاول مرة أخرى'
                : msg.contains('timeout')
                    ? 'انتهت مهلة الاتصال'
                    : msg.contains('Connection refused') || msg.contains('SocketException')
                        ? 'لا يمكن الاتصال بالخادم'
                        : 'حدث خطأ أثناء تحميل البيانات';
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
        if (isFrom) _dateFrom = picked;
        else _dateTo = picked;
      });
      _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: textPrimary)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadReports, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : ListView(
                  children: [
                    Text('التقارير الذكية', style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _buildSummaryCards(textPrimary, textSecondary),
                    const SizedBox(height: 16),
                    _buildFilters(textPrimary, textSecondary),
                    const SizedBox(height: 16),
                    _buildStudentsList(textPrimary, textSecondary),
                    const SizedBox(height: 16),
                    _buildAnalysisSection(textPrimary, textSecondary),
                  ],
                ),
    );
  }

  Widget _buildSummaryCards(Color textPrimary, Color textSecondary) {
    final totalStudents = _summary['total_students'] ?? 0;
    final avgScore = (_summary['average_score'] ?? 0).toDouble();
    final passRate = (_summary['pass_rate'] ?? 0).toDouble();
    return Row(
      children: [
        Expanded(child: _summaryCard('عدد الطلاب', '$totalStudents', Icons.people, AppTheme.accent, textPrimary, textSecondary)),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard('متوسط الدرجات', '${avgScore.toStringAsFixed(1)}%', Icons.trending_up, AppTheme.accentLight, textPrimary, textSecondary)),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard('نسبة النجاح', '${passRate.toStringAsFixed(1)}%', Icons.check_circle, AppTheme.success, textPrimary, textSecondary)),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color, Color textPrimary, Color textSecondary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildFilters(Color textPrimary, Color textSecondary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('التصفية', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedSubject,
            decoration: InputDecoration(
              labelText: 'المادة',
              labelStyle: TextStyle(color: textSecondary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  label: Text(_dateFrom != null ? intl.DateFormat('yyyy-MM-dd').format(_dateFrom!) : 'من تاريخ'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isFrom: false),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_dateTo != null ? intl.DateFormat('yyyy-MM-dd').format(_dateTo!) : 'إلى تاريخ'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList(Color textPrimary, Color textSecondary) {
    if (_students.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
      final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
        child: Center(child: Text('لا توجد بيانات طلاب', style: TextStyle(color: textSecondary))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('أداء الطلاب', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._students.map((s) => _buildStudentCard(s, textPrimary, textSecondary)),
      ],
    );
  }

  Widget _buildStudentCard(dynamic student, Color textPrimary, Color textSecondary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final name = student['name'] ?? 'طالب';
    final avgScore = (student['average_score'] ?? 0).toDouble();
    final examsCount = student['exams_count'] ?? 0;

    Color barColor;
    if (avgScore > 80) barColor = AppTheme.success;
    else if (avgScore >= 50) barColor = AppTheme.warning;
    else barColor = AppTheme.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: barColor.withValues(alpha: 0.15), child: Icon(Icons.person, color: barColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text('$examsCount اختبار', style: TextStyle(color: textSecondary, fontSize: 11)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: avgScore / 100,
                    backgroundColor: textSecondary.withValues(alpha: 0.2),
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

  Widget _buildAnalysisSection(Color textPrimary, Color textSecondary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final analysis = _summary['analysis'] ?? 'لا توجد بيانات كافية للتحليل.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 22),
              const SizedBox(width: 8),
              Text('تحليل AI', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(analysis, style: TextStyle(color: textSecondary, fontSize: 13, height: 1.6)),
        ],
      ),
    );
  }
}
