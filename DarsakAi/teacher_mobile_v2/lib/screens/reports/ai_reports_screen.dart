import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../../core/glass_theme.dart';
import '../../core/subscription_guard.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!checkPlanFeature(context, PlanFeatures.aiReports)) {
        Navigator.pop(context);
        return;
      }
      _loadReports();
    });
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
    final strengths = student['strengths'] as List<dynamic>? ?? [];
    final weaknesses = student['weaknesses'] as List<dynamic>? ?? [];

    Color barColor;
    if (avgScore > 80) {
      barColor = GlassTheme.green;
    } else if (avgScore >= 50) {
      barColor = const Color(0xFFF59E0B);
    } else {
      barColor = GlassTheme.red;
    }

    return GestureDetector(
      onTap: () => _openStudentDetail(student),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: GlassTheme.glassCard(context),
        child: Column(
          children: [
            Row(
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
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text('${avgScore.toStringAsFixed(1)}%', style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_left, color: GlassTheme.textSecondary(context)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: avgScore / 100,
                backgroundColor: GlassTheme.textSecondary(context).withValues(alpha: 0.2),
                color: barColor,
                minHeight: 6,
              ),
            ),
            if (strengths.isNotEmpty || weaknesses.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (strengths.isNotEmpty) ...[
                    Icon(Icons.check_circle_outline, size: 14, color: GlassTheme.green),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${strengths.length} نقطة قوة',
                        style: TextStyle(color: GlassTheme.green, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (weaknesses.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.warning_amber_outlined, size: 14, color: GlassTheme.red),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${weaknesses.length} نقطة ضعف',
                        style: TextStyle(color: GlassTheme.red, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openStudentDetail(Map<String, dynamic> student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _StudentReportDetailScreen(student: student),
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

class _StudentReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> student;

  const _StudentReportDetailScreen({required this.student});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = student['name'] ?? 'طالب';
    final avgScore = (student['average_score'] ?? 0).toDouble();
    final examsCount = student['exams_count'] ?? 0;
    final exams = student['exams'] as List<dynamic>? ?? [];
    final strengths = student['strengths'] as List<dynamic>? ?? [];
    final weaknesses = student['weaknesses'] as List<dynamic>? ?? [];
    final recommendations = student['recommendations'] as List<dynamic>? ?? [];

    Color scoreColor;
    if (avgScore >= 80) {
      scoreColor = GlassTheme.green;
    } else if (avgScore >= 50) {
      scoreColor = const Color(0xFFF59E0B);
    } else {
      scoreColor = GlassTheme.red;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: GlassTheme.glassAppBar(name),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Score card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: GlassTheme.glassCard(context),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: scoreColor.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(color: scoreColor, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name, style: TextStyle(color: GlassTheme.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('$examsCount اختبار', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 13)),
                const SizedBox(height: 8),
                Text(
                  '${avgScore.toStringAsFixed(1)}%',
                  style: TextStyle(color: scoreColor, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Strengths
          if (strengths.isNotEmpty)
            _buildSection(
              context,
              title: 'نقاط القوة',
              icon: Icons.check_circle,
              color: GlassTheme.green,
              items: strengths.map((s) => s.toString()).toList(),
            ),

          // Weaknesses
          if (weaknesses.isNotEmpty)
            _buildSection(
              context,
              title: 'نقاط الضعف',
              icon: Icons.warning_amber,
              color: GlassTheme.red,
              items: weaknesses.map((w) => w.toString()).toList(),
            ),

          // Recommendations
          if (recommendations.isNotEmpty)
            _buildSection(
              context,
              title: 'توصيات للمعلم',
              icon: Icons.lightbulb,
              color: GlassTheme.indigo,
              items: recommendations.map((r) => r.toString()).toList(),
            ),

          // Per-exam results
          if (exams.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('نتائج الاختبارات', style: TextStyle(color: GlassTheme.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...exams.map((exam) => _buildExamCard(context, exam)),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: GlassTheme.glassCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, size: 6, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildExamCard(BuildContext context, dynamic exam) {
    final score = (exam['score'] ?? 0).toDouble();
    final maxScore = (exam['max_score'] ?? 0).toDouble();
    final pct = (exam['percentage'] ?? 0).toDouble();
    final examStrengths = (exam['strengths'] as List<dynamic>?) ?? [];
    final examWeaknesses = (exam['weaknesses'] as List<dynamic>?) ?? [];

    Color barColor;
    if (pct >= 80) {
      barColor = GlassTheme.green;
    } else if (pct >= 50) {
      barColor = const Color(0xFFF59E0B);
    } else {
      barColor = GlassTheme.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: GlassTheme.glassCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${score.toStringAsFixed(0)} / ${maxScore.toStringAsFixed(0)}', style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 8),
              Text('${pct.toStringAsFixed(1)}%', style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(pct >= 50 ? 'ناجح' : 'راسب', style: TextStyle(color: barColor, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: GlassTheme.textSecondary(context).withValues(alpha: 0.2),
              color: barColor,
              minHeight: 6,
            ),
          ),
          if (examStrengths.isNotEmpty || examWeaknesses.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (examStrengths.isNotEmpty)
              ...examStrengths.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 12, color: GlassTheme.green),
                    const SizedBox(width: 6),
                    Expanded(child: Text(s.toString(), style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 12))),
                  ],
                ),
              )),
            if (examWeaknesses.isNotEmpty)
              ...examWeaknesses.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    const Icon(Icons.close, size: 12, color: GlassTheme.red),
                    const SizedBox(width: 6),
                    Expanded(child: Text(w.toString(), style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 12))),
                  ],
                ),
              )),
          ],
        ],
      ),
    );
  }
}
