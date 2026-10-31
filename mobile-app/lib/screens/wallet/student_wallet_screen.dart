import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../core/theme.dart';
import '../../core/api_service.dart';

class StudentWalletScreen extends StatefulWidget {
  const StudentWalletScreen({super.key});

  @override
  State<StudentWalletScreen> createState() => _StudentWalletScreenState();
}

class _StudentWalletScreenState extends State<StudentWalletScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic> _wallet = {};
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  bool _isDepositing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getWallet(),
        _api.getWalletTransactions(limit: 30),
      ]);
      if (!mounted) return;
      setState(() {
        _wallet = (results[0] is Map<String, dynamic>) ? results[0] as Map<String, dynamic> : <String, dynamic>{};
        _transactions = (results[1] is List) ? results[1] as List : [];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحفظة'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(),
                    const SizedBox(height: 24),
                    _buildDepositButton(),
                    const SizedBox(height: 24),
                    Text('سجل المعاملات', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_transactions.isEmpty)
                      _buildEmptyTransactions()
                    else
                      ..._transactions.map((t) => _buildTransactionCard(t)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    final balance = (_wallet['balance'] ?? 0).toDouble();
    final deposited = (_wallet['total_deposited'] ?? 0).toDouble();
    final spent = (_wallet['total_spent'] ?? 0).toDouble();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Text('رصيد المحفظة', style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${balance.toStringAsFixed(0)} ج.م',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMiniStat('إيداع', deposited, Icons.arrow_downward),
              const SizedBox(width: 24),
              _buildMiniStat('مصروف', spent, Icons.arrow_upward),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, double value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white60, size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            Text('${value.toStringAsFixed(0)} ج.م', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildDepositButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isDepositing ? null : _showDepositDialog,
        icon: _isDepositing
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add, color: Colors.white),
        label: Text(_isDepositing ? 'جاري الإيداع...' : 'إيداع رصيد', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.success,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showDepositDialog() async {
    final amountCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String method = 'vodafone_cash';
    File? screenshotFile;

    final config = await _api.getPaymentConfig();
    final vodafoneNumber = config['vodafone_cash_number'] ?? '';
    final instapayUser = config['instapay_username'] ?? '';

    if (!mounted) { amountCtrl.dispose(); phoneCtrl.dispose(); return; }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: AppColors.background(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary(context).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('إيداع رصيد', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('طريقة الدفع', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMethodChip('فودافون كاش', 'vodafone_cash', method, (v) => setSheetState(() => method = v)),
                    const SizedBox(width: 8),
                    _buildMethodChip('انستاباي', 'instapay', method, (v) => setSheetState(() => method = v)),
                  ],
                ),
                if (method == 'vodafone_cash' && vodafoneNumber.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone, color: AppTheme.accent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('أرسل على: $vodafoneNumber', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13))),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          color: AppTheme.accent,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: vodafoneNumber));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ')));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                if (method == 'instapay' && instapayUser.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance, color: AppTheme.accent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('انستاباي: $instapayUser', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13))),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          color: AppTheme.accent,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: instapayUser));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ')));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                    labelText: 'المبلغ (ج.م)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (amountCtrl.text.isNotEmpty && (double.tryParse(amountCtrl.text) ?? 0) > 0) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (_) {
                      final amt = double.tryParse(amountCtrl.text) ?? 0;
                      final tax = (amt * 1.5 / 100);
                      final total = amt + tax;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('المبلغ', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
                              Text('${amt.toStringAsFixed(2)} ج.م', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13, fontWeight: FontWeight.bold)),
                            ]),
                            const SizedBox(height: 4),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('ضريبة الخدمة (1.5%)', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
                              Text('${tax.toStringAsFixed(2)} ج.م', style: TextStyle(color: AppTheme.warning, fontSize: 13)),
                            ]),
                            const Divider(height: 16),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('المبلغ المطلوب تحويله', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14, fontWeight: FontWeight.bold)),
                              Text('${total.toStringAsFixed(2)} ج.م', style: TextStyle(color: AppTheme.accent, fontSize: 16, fontWeight: FontWeight.bold)),
                            ]),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم المرسل',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 80);
                    if (picked != null) setSheetState(() => screenshotFile = File(picked.path));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: screenshotFile != null ? AppTheme.success : AppTheme.danger,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: screenshotFile != null
                        ? Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(screenshotFile!, width: 60, height: 60, fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('صورة التحويل', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
                                    Text('تم اختيار الصورة ✓', style: TextStyle(color: AppTheme.success, fontSize: 12)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () => setSheetState(() => screenshotFile = null),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Icon(Icons.camera_alt_outlined, color: AppTheme.danger),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('صورة التحويل *', style: TextStyle(color: AppTheme.danger, fontSize: 13, fontWeight: FontWeight.bold)),
                                    Text('إلزامي — التقط صورة للتحويل', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text);
                      final phone = phoneCtrl.text.trim();
                      if (amount == null || amount <= 0 || phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل البيانات')));
                        return;
                      }
                      if (screenshotFile == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف صورة التحويل'), backgroundColor: AppTheme.danger));
                        return;
                      }
                      Navigator.pop(ctx);
                      amountCtrl.dispose();
                      phoneCtrl.dispose();
                      setState(() => _isDepositing = true);
                      try {
                        await _api.depositRequestWithScreenshot(
                          amount: amount, senderPhone: phone, method: method,
                          filePath: screenshotFile!.path,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب الإيداع — في انتظار الموافقة'), backgroundColor: AppTheme.success));
                          _loadData();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إرسال طلب الإيداع، حاول مرة أخرى'), backgroundColor: AppTheme.danger));
                        }
                      } finally {
                        if (mounted) setState(() => _isDepositing = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('إرسال طلب الإيداع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodChip(String label, String value, String current, ValueChanged<String> onTap) {
    final isActive = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.accent : AppColors.surfaceElevated(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isActive ? AppTheme.accent : AppColors.border(context)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(
            color: isActive ? Colors.white : AppColors.textSecondary(context),
            fontWeight: FontWeight.bold, fontSize: 13,
          )),
        ),
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textSecondary(context).withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text('لا توجد معاملات بعد', style: TextStyle(color: AppColors.textSecondary(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final type = (tx['type'] ?? '').toString();
    final amount = (tx['amount'] ?? 0).toDouble();
    final note = (tx['note'] ?? '').toString();
    final createdAt = tx['created_at'];
    final isDeposit = type == 'deposit' || type == 'topup';

    String dateStr = '';
    if (createdAt != null) {
      try {
        dateStr = DateFormat('yyyy-MM-dd HH:mm', 'ar').format(DateTime.parse(createdAt.toString()));
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (isDeposit ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isDeposit ? AppTheme.success : AppTheme.danger,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.isNotEmpty ? note : (isDeposit ? 'إيداع' : 'خصم'),
                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (dateStr.isNotEmpty)
                  Text(dateStr, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11)),
              ],
            ),
          ),
          Text(
            '${isDeposit ? '+' : '-'}${amount.toStringAsFixed(0)} ج.م',
            style: TextStyle(
              color: isDeposit ? AppTheme.success : AppTheme.danger,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
