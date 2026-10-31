import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';
import 'ai_generate_screen.dart';
import 'ai_lesson_player_screen.dart';

class AiLessonListScreen extends StatefulWidget {
  const AiLessonListScreen({super.key});

  @override
  State<AiLessonListScreen> createState() => _AiLessonListScreenState();
}

class _AiLessonListScreenState extends State<AiLessonListScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _sessions = [];
  double _balance = 0;
  double _ratePerMinute = 0.42;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _loadError;

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final results = await Future.wait([
        _api.getClassrooms(),
        _api.getWallet(),
      ]);
      final classrooms = results[0];
      final wallet = results[1];
      _sessions = (classrooms['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      _balance = (wallet['balance'] as num?)?.toDouble() ?? 0;
      _ratePerMinute = 0.42;
    } catch (e) {
      if (mounted) setState(() => _loadError = 'فشل تحميل البيانات. تحقق من الإنترنت');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _startNewLesson() async {
    if (_balance < 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('رصيد غير كافٍ. الحد الأدنى 10 ج.م، رصيدك ${_balance.toStringAsFixed(2)} ج.م'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AiGenerateScreen()),
    );
    if (result == true) _load();
  }

  void _resumeSession(Map<String, dynamic> session) {
    final title = session['title'] as String? ?? 'درس AI';
    final status = session['status'] as String? ?? '';
    final classroomUrl = session['classroom_url'] as String? ?? '';

    if (status != 'active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا الدرس منتهي'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    if (classroomUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رابط الفصل غير متاح. حاول إنشاء فصل جديد'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiClassroomWebViewScreen(
          url: classroomUrl,
          title: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفصل الذكي'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off, size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(_loadError!, style: const TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('إعادة المحاولة'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.accent,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildBalanceCard()),
                  SliverToBoxAdapter(child: _buildNewLessonButton()),
                  if (_sessions.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.school_outlined, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                            const SizedBox(height: 12),
                            Text(
                              'لا توجد حصص بعد',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ابدأ فصلاً ذكياً جديداً',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildSessionCard(_sessions[index]),
                          childCount: _sessions.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFFa29bfe)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الرصيد المتاح', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  '${_balance.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('التكلفة', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text(
                '${_ratePerMinute.toStringAsFixed(2)} ج.م/د',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewLessonButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _startNewLesson,
          icon: const Icon(Icons.add, size: 20),
          label: const Text('فصل ذكي جديد', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final title = session['title'] as String? ?? 'درس AI';
    final status = session['status'] as String? ?? '';
    final cost = (session['cost'] as num?)?.toDouble() ?? 0;
    final startedAt = session['started_at'] as String? ?? '';
    final isActive = status == 'active';

    String dateStr = '';
    if (startedAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(startedAt);
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isActive ? () => _resumeSession(session) : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive
                    ? AppTheme.accent.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.accent.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isActive ? Icons.play_arrow_rounded : Icons.check_circle_outline,
                    color: isActive ? AppTheme.accent : Colors.white38,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : Colors.white54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (dateStr.isNotEmpty) ...[
                            Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35))),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppTheme.success.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isActive ? 'نشط' : 'منتهي',
                              style: TextStyle(
                                fontSize: 10,
                                color: isActive ? AppTheme.success : Colors.white38,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (cost > 0)
                  Text(
                    '${cost.toStringAsFixed(2)} ج.م',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.35)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
