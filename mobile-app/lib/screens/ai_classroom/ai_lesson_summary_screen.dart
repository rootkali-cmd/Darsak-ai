import 'package:flutter/material.dart';
import '../../core/theme.dart';

class AiLessonSummaryScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<Map<String, String>>? messages;
  final Duration? duration;
  final double? cost;
  final String? topic;

  const AiLessonSummaryScreen({
    super.key,
    required this.data,
    this.messages,
    this.duration,
    this.cost,
    this.topic,
  });

  const AiLessonSummaryScreen.withDetails({
    super.key,
    this.messages,
    this.duration,
    this.cost,
    this.topic,
  }) : data = const {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final durationStr = data['duration_formatted'] as String? ?? (duration != null ? '${duration!.inMinutes}:${(duration!.inSeconds % 60).toString().padLeft(2, '0')}' : '00:00');
    final costVal = (data['cost'] as num?)?.toDouble() ?? cost ?? 0;
    final balanceBefore = (data['balance_before'] as num?)?.toDouble() ?? 0;
    final balanceAfter = (data['balance_after'] as num?)?.toDouble() ?? 0;
    final title = data['title'] as String? ?? topic ?? 'درس AI';

    return Scaffold(
      appBar: AppBar(
        title: const Text('انتهى الدرس'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(flex: 1),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            ),
            const SizedBox(height: 16),
            Text('تم إنهاء الدرس بنجاح', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: theme.hintColor)),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  _row('المدة', durationStr, Icons.timer_outlined),
                  const Divider(height: 24),
                  _row('التكلفة', '$costVal ج.م', Icons.monetization_on_outlined),
                  const Divider(height: 24),
                  _row('رصيدك قبل', '$balanceBefore ج.م', Icons.account_balance_wallet_outlined),
                  const Divider(height: 24),
                  _row('رصيدك بعد', '$balanceAfter ج.م', Icons.account_balance_wallet_outlined,
                      valueColor: AppTheme.accent),
                ],
              ),
            ),
            const Spacer(flex: 2),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('العودة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const Spacer(),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: valueColor)),
      ],
    );
  }
}
