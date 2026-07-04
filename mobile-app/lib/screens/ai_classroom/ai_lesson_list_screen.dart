import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';
import 'ai_lesson_player_screen.dart';

class AiLessonListScreen extends StatefulWidget {
  const AiLessonListScreen({super.key});

  @override
  State<AiLessonListScreen> createState() => _AiLessonListScreenState();
}

class _AiLessonListScreenState extends State<AiLessonListScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _lessons = [];
  bool _loading = true;
  double _rate = 0.42;
  double _minBalance = 10.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final config = await _api.getAiClassroomConfig();
      _rate = (config['rate_per_minute'] as num?)?.toDouble() ?? 0.42;
      _minBalance = (config['min_balance'] as num?)?.toDouble() ?? 10.0;
      final sessions = await _api.getAiLessonSessions();
      _lessons = (sessions['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفصل الذكي'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildInfoCard(theme),
                  const SizedBox(height: 16),
                  _buildDemoCard(theme),
                  const SizedBox(height: 24),
                  Text('الجلسات السابقة', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_lessons.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('لا توجد جلسات سابقة', style: TextStyle(color: theme.hintColor)),
                      ),
                    )
                  else
                    ..._lessons.map((s) => _buildSessionCard(theme, s)),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.accent, AppTheme.accent.withAlpha(180)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('التعليم بالذكاء الاصطناعي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text('السعر: $_rate ج.م / دقيقة', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
          Text('الحد الأدنى للرصيد: $_minBalance ج.م', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
          const SizedBox(height: 8),
          Text('يتم خصم التكلفة بعد انتهاء الجلسة على أساس الدقائق الفعلية المستخدمة',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDemoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: AppTheme.accent, size: 24),
              const SizedBox(width: 8),
              Text('درس تجريبي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.titleMedium?.color)),
            ],
          ),
          const SizedBox(height: 8),
          Text('جرب الفصل الذكي الآن', style: TextStyle(color: theme.hintColor, fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startDemo,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('بدء الدرس'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(ThemeData theme, Map<String, dynamic> s) {
    final cost = (s['cost'] as num?)?.toDouble() ?? 0;
    final duration = s['duration_formatted'] as String? ?? '00:00:00';
    final title = s['title'] as String? ?? 'درس AI';
    final status = s['status'] as String? ?? '';
    final isActive = status == 'active';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(isActive ? Icons.play_circle : Icons.check_circle, color: isActive ? Colors.green : theme.hintColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('المدة: $duration  •  التكلفة: $cost ج.م'),
        trailing: Text(status == 'ended' ? 'منتهي' : 'نشط', style: TextStyle(fontSize: 12, color: isActive ? Colors.green : theme.hintColor)),
      ),
    );
  }

  void _startDemo() async {
    final ok = await _checkBalance();
    if (ok && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AiLessonPlayerScreen()));
    }
  }

  Future<bool> _checkBalance() async {
    try {
      final wallet = await _api.getWallet();
      final bal = (wallet['balance'] as num?)?.toDouble() ?? 0;
      if (bal < _minBalance) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('رصيد غير كاف. الحد الأدنى $_minBalance ج.م')));
        }
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }
}
