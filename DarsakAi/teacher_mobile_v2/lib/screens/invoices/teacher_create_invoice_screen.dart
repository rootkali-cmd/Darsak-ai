import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../services/api_service.dart';

class TeacherCreateInvoiceScreen extends StatefulWidget {
  const TeacherCreateInvoiceScreen({super.key});

  @override
  State<TeacherCreateInvoiceScreen> createState() => _TeacherCreateInvoiceScreenState();
}

class _TeacherCreateInvoiceScreenState extends State<TeacherCreateInvoiceScreen> {
  final _amountController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLookingUp = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _foundStudent;
  String? _selectedStudentId;
  String _paymentMethod = 'vodafone_cash';

  @override
  void dispose() {
    _amountController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _lookupStudent() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل كود الطالب'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    setState(() { _isLookingUp = true; _foundStudent = null; _selectedStudentId = null; });
    try {
      final resp = await ApiService().dio.get('/students/', queryParameters: {'search': code});
      final data = resp.data;
      List<dynamic> students = [];
      if (data is Map && data['data'] is List) {
        students = data['data'];
      } else if (data is List) {
        students = data;
      }
      final match = students.cast<Map<String, dynamic>?>().firstWhere(
        (s) => (s?['code'] ?? '').toString().trim() == code,
        orElse: () => null,
      );
      if (mounted) {
        setState(() {
          _foundStudent = match;
          _selectedStudentId = match?['id']?.toString();
          _isLookingUp = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLookingUp = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ابحث عن الطالب أولاً'), backgroundColor: AppTheme.danger),
      );
      return;
    }
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل المبلغ'), backgroundColor: AppTheme.danger),
      );
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المبلغ غير صحيح'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService().dio.post('/invoices/teacher-create', data: {
        'student_id': _selectedStudentId,
        'amount': amount,
        'payment_method': _paymentMethod,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء الفاتورة بنجاح'), backgroundColor: AppTheme.success),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('إنشاء فاتورة', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('كود الطالب', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
            const SizedBox(height: 8),
            _buildCodeSearch(),
            const SizedBox(height: 8),
            if (_foundStudent != null) _buildStudentInfo(),
            const SizedBox(height: 24),
            Text('طريقة الدفع', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
            const SizedBox(height: 12),
            _buildPaymentMethods(),
            const SizedBox(height: 24),
            Text('المبلغ (ج.م)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
            const SizedBox(height: 8),
            _buildAmountInput(),
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeSearch() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _codeController,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: TextStyle(color: GlassTheme.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
            decoration: InputDecoration(
              hintText: 'مثال: STU001',
              hintStyle: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 14),
              prefixIcon: Icon(Icons.person_search, color: GlassTheme.textSecondary(context)),
              filled: true,
              fillColor: GlassTheme.cardBg(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: GlassTheme.cardBorder(context))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.accent)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isLookingUp ? null : _lookupStudent,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLookingUp
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.search, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentInfo() {
    final name = _foundStudent!['full_name'] ?? 'طالب';
    final code = _foundStudent!['code'] ?? '-';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppTheme.success, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: GlassTheme.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(code, style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 13, letterSpacing: 1)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() { _foundStudent = null; _selectedStudentId = null; _codeController.clear(); }),
            child: Text('تغيير', style: TextStyle(color: AppTheme.accent, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    final methods = [
      ('vodafone_cash', 'فودافون كاش', Icons.phone_android, const Color(0xFFE60023)),
      ('instapay', 'انستاباي', Icons.qr_code_2, const Color(0xFF00C853)),
      ('cash', 'نقدي', Icons.money, Colors.green),
    ];
    return Column(
      children: methods.map((m) {
        final isSelected = _paymentMethod == m.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => setState(() => _paymentMethod = m.$1),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? m.$4.withValues(alpha: 0.08) : GlassTheme.cardBg(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? m.$4 : GlassTheme.cardBorder(context),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(m.$3, color: isSelected ? m.$4 : GlassTheme.iconSecondary(context), size: 22),
                  const SizedBox(width: 12),
                  Text(m.$2, style: TextStyle(
                    color: isSelected ? m.$4 : GlassTheme.textPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  )),
                  const Spacer(),
                  if (isSelected)
                    Icon(Icons.check_circle, color: m.$4, size: 20)
                  else
                    Icon(Icons.circle_outlined, color: GlassTheme.iconSecondary(context), size: 20),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAmountInput() {
    return TextField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      style: TextStyle(color: GlassTheme.textPrimary(context), fontSize: 16),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: TextStyle(color: GlassTheme.textSecondary(context)),
        prefixIcon: Icon(Icons.monetization_on_outlined, color: GlassTheme.textSecondary(context)),
        suffixText: 'ج.م',
        suffixStyle: TextStyle(color: GlassTheme.textSecondary(context)),
        filled: true,
        fillColor: GlassTheme.cardBg(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: GlassTheme.cardBorder(context))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accent)),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSubmitting
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('إنشاء الفاتورة', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
