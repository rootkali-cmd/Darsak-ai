import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _wallet = {};
  List<dynamic> _transactions = [];
  List<dynamic> _payoutRequests = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ApiService();
      final results = await Future.wait([
        api.dio.get('/wallet'),
        api.dio.get('/wallet/transactions?limit=50'),
        api.dio.get('/wallet/payout-requests?limit=20'),
      ]);
      if (!mounted) return;
      setState(() {
        _wallet = results[0].data is Map ? results[0].data : {};
        _transactions = results[1].data is Map && results[1].data['items'] is List ? results[1].data['items'] : [];
        _payoutRequests = results[2].data is Map && results[2].data['items'] is List ? results[2].data['items'] : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'فشل تحميل بيانات المحفظة'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassTheme.glassAppBar('المحفظة'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: TextStyle(color: GlassTheme.textPrimary(context))),
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
                      _buildBalanceCard(),
                      const SizedBox(height: 16),
                      _buildQuickActions(),
                      const SizedBox(height: 16),
                      if (_payoutRequests.isNotEmpty) ...[
                        Text('طلبات السحب', style: TextStyle(color: GlassTheme.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ..._payoutRequests.map(_buildPayoutItem),
                        const SizedBox(height: 16),
                      ],
                      Text('الحركات', style: TextStyle(color: GlassTheme.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_transactions.isEmpty)
                        Text('لا توجد حركات بعد', style: TextStyle(color: GlassTheme.textSecondary(context)))
                      else
                        ..._transactions.map(_buildTransactionItem),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBalanceCard() {
    final balance = (_wallet['balance'] ?? 0).toDouble();
    final pending = (_wallet['pending_balance'] ?? 0).toDouble();
    final totalWithdrawn = (_wallet['total_withdrawn'] ?? 0).toDouble();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الرصيد المتاح', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text('${balance.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat('قيد الانتظار', '${pending.toStringAsFixed(2)} ج.م'),
              _miniStat('المحصل', '${totalWithdrawn.toStringAsFixed(2)} ج.م'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(child: _actionCard(Icons.account_balance_wallet, 'سحب', const Color(0xFF6366F1), () => _showPayoutDialog())),
      ],
    );
  }

  Widget _actionCard(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [Icon(icon, color: color, size: 28), const SizedBox(height: 6), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600))],
        ),
      ),
    );
  }

  Widget _buildPayoutItem(dynamic item) {
    final status = (item['status'] ?? '').toString();
    final amount = (item['requested_amount'] ?? 0).toDouble();
    final net = (item['net_amount'] ?? 0).toDouble();
    final method = (item['payout_method'] ?? '').toString();
    Color statusColor;
    String statusText;
    switch (status) {
      case 'approved':
      case 'completed':
        statusColor = AppTheme.success;
        statusText = 'مقبول';
        break;
      case 'rejected':
      case 'failed':
        statusColor = AppTheme.danger;
        statusText = 'مرفوض';
        break;
      default:
        statusColor = AppTheme.warning;
        statusText = 'قيد المراجعة';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: GlassTheme.glassCard(context),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${amount.toStringAsFixed(2)} ج.م', style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.w600)),
            Text('صافي: ${net.toStringAsFixed(2)} ج.م — $method', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(dynamic item) {
    final type = (item['transaction_type'] ?? '').toString();
    final amount = (item['amount'] ?? 0).toDouble();
    final desc = (item['description'] ?? '').toString();
    Color color;
    switch (type) {
      case 'credit':
      case 'deposit':
      case 'refund':
        color = AppTheme.success;
        break;
      default:
        color = AppTheme.danger;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: GlassTheme.glassCard(context),
      child: Row(
        children: [
          Icon(type == 'credit' || type == 'deposit' || type == 'refund' ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(desc.isNotEmpty ? desc : type, style: TextStyle(color: GlassTheme.textPrimary(context), fontSize: 13)),
            Text(item['created_at']?.toString().substring(0, 16) ?? '', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 11)),
          ])),
          Text('${type == 'credit' || type == 'deposit' || type == 'refund' ? '+' : '-'}${amount.abs().toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showPayoutDialog() {
    final amountController = TextEditingController();
    final phoneController = TextEditingController();
    String method = 'vodafone_cash';
    final balance = (_wallet['balance'] ?? 0).toDouble();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('طلب سحب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الرصيد المتاح: ${balance.toStringAsFixed(2)} ج.م', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 12)),
              const SizedBox(height: 12),
              TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: method,
                items: const [
                  DropdownMenuItem(value: 'vodafone_cash', child: Text('فودافون كاش')),
                  DropdownMenuItem(value: 'instapay', child: Text('InstaPay')),
                ],
                onChanged: (v) { if (v != null) setDialogState(() => method = v); },
                decoration: const InputDecoration(labelText: 'طريقة السحب', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                final phone = phoneController.text.trim();
                if (amount <= 0 || phone.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await ApiService().dio.post('/wallet/payout-request', data: {'amount': amount, 'payout_method': method, 'payout_phone': phone});
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب السحب'), backgroundColor: AppTheme.success));
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  final msg = e.toString().contains('400') ? 'الرصيد غير كافي' : 'فشل إرسال الطلب';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.danger));
                }
              },
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }
}
