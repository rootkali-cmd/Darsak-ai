import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../core/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  final VoidCallback? onActivated;

  const SubscriptionScreen({super.key, this.onActivated});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _activating = false;
  String? _error;
  Map<String, dynamic>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscription() async {
    setState(() => _loading = true);
    try {
      final service = context.read<SubscriptionService>();
      final sub = await service.getMySubscription();
      if (mounted) setState(() => _subscription = sub);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _activateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'يرجى إدخال كود التفعيل');
      return;
    }
    setState(() {
      _activating = true;
      _error = null;
    });
    try {
      final service = context.read<SubscriptionService>();
      final sub = await service.activateCode(code);
      if (mounted) {
        setState(() {
          _subscription = sub;
          _activating = false;
          _codeController.clear();
        });
        widget.onActivated?.call();
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ?? 'فشل التفعيل';
      if (mounted) setState(() { _error = msg; _activating = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'حدث خطأ. حاول مرة أخرى'; _activating = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.read<SubscriptionService>();
    final active = service.isSubscriptionActive(_subscription);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الاشتراك'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusCard(theme, active),
                  const SizedBox(height: 16),
                  if (_subscription != null && active)
                    _buildSubscriptionInfo(theme, service)
                  else ...[
                    _buildActivationSection(theme),
                    const SizedBox(height: 24),
                    _buildPlanCards(theme),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard(ThemeData theme, bool active) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle : Icons.cancel,
            color: active ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            size: 32,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                active ? 'الاشتراك نشط' : 'الاشتراك غير نشط',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                active ? 'يمكنك استخدام جميع الميزات' : 'فعّل اشتراكك للاستمرار',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionInfo(ThemeData theme, SubscriptionService service) {
    final plan = service.getPlanName(_subscription);
    final expiry = service.getExpiryDate(_subscription);
    final status = service.getStatus(_subscription);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'معلومات الاشتراك',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          _infoRow('الخطة', plan ?? '-'),
          _infoRow('الحالة', status ?? '-'),
          if (expiry != null) _infoRow('تاريخ الانتهاء', expiry.substring(0, 10)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildActivationSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفعيل كود اشتراك',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    hintText: 'أدخل كود التفعيل',
                    hintStyle: const TextStyle(fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    errorText: _error,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _activating ? null : _activateCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _activating
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('تفعيل'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCards(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'خطط الاشتراك',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildPlanCard(theme, 'شهري', 'شهر', '299 ج', 'تجربة مجانية لمدة 7 أيام')),
            const SizedBox(width: 12),
            Expanded(child: _buildPlanCard(theme, 'سنوي', 'سنة', '1999 ج', 'وفر 50% مقارنة بالشهري')),
          ],
        ),
      ],
    );
  }

  Widget _buildPlanCard(ThemeData theme, String title, String period, String price, String note) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: title == 'سنوي'
              ? const Color(0xFF2563EB).withValues(alpha: 0.4)
              : theme.dividerColor,
        ),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(price, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 22)),
          Text('/$period', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 8),
          Text(note, style: TextStyle(color: Colors.grey[400], fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
