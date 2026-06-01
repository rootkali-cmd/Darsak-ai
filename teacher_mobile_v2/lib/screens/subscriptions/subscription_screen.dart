import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, dynamic>? _currentPlan;
  List<dynamic> _availablePlans = [];
  bool _loading = true;
  String? _error;
  final _codeCtrl = TextEditingController();
  bool _activating = false;

  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService();
      final meResp = await api.dio.get('/auth/me');
      final meData = meResp.data;
      if (meData is Map<String, dynamic>) {
        _currentPlan = meData['subscription'] is Map ? Map<String, dynamic>.from(meData['subscription']) : null;
      }
      final plansResp = await api.dio.get('/subscriptions/plans');
      final plansData = plansResp.data;
      _availablePlans = plansData is List ? plansData : [];
    } on DioException catch (e) {
      _error = 'فشل تحميل البيانات: ${e.response?.statusCode ?? e.message}';
    } catch (e) {
      _error = 'حدث خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _activateCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل كود التفعيل'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    setState(() => _activating = true);
    try {
      await ApiService().dio.post('/subscriptions/activate', data: {'code': code});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تفعيل الاشتراك بنجاح'), backgroundColor: AppTheme.success),
        );
        _codeCtrl.clear();
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التفعيل: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الاشتراك')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadData, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_currentPlan != null) ...[
                        _buildCurrentPlanCard(),
                        const SizedBox(height: 24),
                      ],
                      _buildActivationCard(),
                      const SizedBox(height: 24),
                      const Text('الباقات المتاحة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ..._availablePlans.map((plan) => _buildPlanCard(plan)),
                      const SizedBox(height: 24),
                      _buildPaymentRequestCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCurrentPlanCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.success),
                const SizedBox(width: 8),
                const Text('خطتك الحالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            _PlanInfoRow(label: 'الباقة', value: _currentPlan!['plan_name'] ?? '—'),
            _PlanInfoRow(label: 'الحالة', value: _currentPlan!['status'] ?? '—'),
            _PlanInfoRow(label: 'تاريخ الانتهاء', value: _currentPlan!['end_date'] ?? '—'),
          ],
        ),
      ),
    );
  }

  Widget _buildActivationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تفعيل كود', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(hintText: 'أدخل كود التفعيل'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _activating ? null : _activateCode,
                  child: Text(_activating ? 'جاري...' : 'تفعيل'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
          child: const Icon(Icons.card_membership, color: AppTheme.accent),
        ),
        title: Text(plan['name'] ?? '—'),
        subtitle: Text(plan['description'] ?? ''),
        trailing: Text(
          '${plan['price'] ?? 0} ج.م',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary),
        ),
      ),
    );
  }

  Widget _buildPaymentRequestCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('طلب دفع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('قم بتحويل المبلغ على الرقم التالي وأرسل لقطة الشاشة', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            const Text('01000000000', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone)),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              decoration: const InputDecoration(labelText: 'المبلغ', prefixIcon: Icon(Icons.money)),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('سيتم إضافة رفع لقطة الشاشة قريباً'), backgroundColor: AppTheme.accent),
                  );
                },
                icon: const Icon(Icons.upload),
                label: const Text('رفع لقطة الشاشة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _PlanInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
