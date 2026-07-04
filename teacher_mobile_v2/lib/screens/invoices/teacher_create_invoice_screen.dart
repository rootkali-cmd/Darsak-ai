import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class TeacherCreateInvoiceScreen extends StatefulWidget {
  const TeacherCreateInvoiceScreen({super.key});

  @override
  State<TeacherCreateInvoiceScreen> createState() => _TeacherCreateInvoiceScreenState();
}

class _TeacherCreateInvoiceScreenState extends State<TeacherCreateInvoiceScreen> {
  final _amountController = TextEditingController();
  final _searchCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMsg;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filtered = [];
  String? _selectedStudentId;
  bool _hasSearched = false;
  String _paymentMethod = 'vodafone_cash';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final res = await ApiService().dio.get('/students/', queryParameters: {
        'limit': 200,
        'registration_type': 'center',
      }).timeout(const Duration(seconds: 20));

      final body = res.data;
      List raw = [];
      if (body is List) {
        raw = body;
      } else if (body is Map) {
        raw = (body['data'] as List?) ?? (body['items'] as List?) ?? [];
      }

      if (!mounted) return;
      if (raw.isEmpty) {
        setState(() { _errorMsg = 'لا يوجد طلاب في السنتر'; _isLoading = false; });
        return;
      }

      setState(() {
        _students = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _filtered = [];
        _hasSearched = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      String msg = 'فشل تحميل الطلاب';
      if (e is DioException) {
        final detail = e.response?.data is Map ? (e.response!.data as Map)['detail'] : null;
        if (detail != null) msg = detail.toString();
      }
      setState(() { _errorMsg = msg; _isLoading = false; });
    }
  }

  void _onSearch(String q) {
    if (q.trim().length < 2) {
      setState(() { _filtered = []; _hasSearched = false; });
      return;
    }
    final lq = q.toLowerCase();
    setState(() {
      _hasSearched = true;
      _filtered = _students.where((s) {
        return (s['full_name'] ?? '').toString().toLowerCase().contains(lq) ||
               (s['code'] ?? '').toString().toLowerCase().contains(lq);
      }).take(15).toList();
    });
  }

  Future<void> _submit() async {
    if (_selectedStudentId == null) {
      _snack('اختر طالباً', false);
      return;
    }
    final amt = double.tryParse(_amountController.text.trim());
    if (amt == null || amt <= 0) {
      _snack('أدخل مبلغاً صحيحاً', false);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ApiService().dio.post('/invoices/teacher-create', data: {
        'student_id': _selectedStudentId,
        'amount': amt,
        'payment_method': _paymentMethod,
      });
      if (!mounted) return;
      _snack('تم إنشاء الفاتورة بنجاح', true);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      if (!mounted) return;
      String msg = 'حدث خطأ';
      if (e is DioException && e.response?.data is Map) {
        msg = (e.response!.data as Map)['detail']?.toString() ?? msg;
      }
      _snack(msg, false);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, textAlign: TextAlign.right, textDirection: TextDirection.rtl), backgroundColor: ok ? Colors.green : Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? Colors.black : Colors.white;
    final card = dark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final border = dark ? Colors.white12 : Colors.black12;
    final text = dark ? Colors.white : Colors.black87;
    final sub = dark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text('إنشاء فاتورة', style: TextStyle(fontWeight: FontWeight.bold, color: text)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: dark ? Colors.white : Colors.black))
          : _errorMsg != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                        const SizedBox(height: 16),
                        Text(_errorMsg!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[400], fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(backgroundColor: dark ? Colors.white : Colors.black, foregroundColor: dark ? Colors.black : Colors.white),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Student
                      Text('اختر الطالب', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text)),
                      const SizedBox(height: 8),
                      // Search
                      TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearch,
                        style: TextStyle(color: text),
                        decoration: InputDecoration(
                          hintText: 'ابحث بالاسم أو الكود...',
                          hintStyle: TextStyle(color: sub, fontSize: 14),
                          prefixIcon: Icon(Icons.search, color: sub),
                          filled: true,
                          fillColor: card,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // List
                      if (!_hasSearched)
                        Container(
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            Icon(Icons.search, color: sub, size: 20),
                            const SizedBox(width: 8),
                            Text('ابدأ بكتابة اسم الطالب أو الكود...', style: TextStyle(color: sub, fontSize: 14)),
                          ]),
                        )
                      else
                        Container(
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: _filtered.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(children: [
                                  Icon(Icons.person_off, color: sub, size: 20),
                                  const SizedBox(width: 8),
                                  Text('لا يوجد نتائج', style: TextStyle(color: sub, fontSize: 14)),
                                ]),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) => Divider(height: 1, color: border),
                                itemBuilder: (ctx, i) {
                                  final s = _filtered[i];
                                  final id = s['id']?.toString() ?? '';
                                  final sel = _selectedStudentId == id;
                                  return ListTile(
                                    selected: sel,
                                    selectedTileColor: dark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                    leading: CircleAvatar(
                                      backgroundColor: sel ? (dark ? Colors.white : Colors.black) : sub.withValues(alpha: 0.2),
                                      child: Text(
                                        (s['full_name'] ?? '?')[0].toString(),
                                        style: TextStyle(color: sel ? (dark ? Colors.black : Colors.white) : text),
                                      ),
                                    ),
                                    title: Text(s['full_name'] ?? 'طالب', style: TextStyle(fontWeight: FontWeight.w600, color: text)),
                                    subtitle: Text(s['code'] ?? '-', style: TextStyle(fontSize: 12, color: sub)),
                                    trailing: sel ? Icon(Icons.check_circle, color: dark ? Colors.white : Colors.black) : null,
                                    onTap: () => setState(() => _selectedStudentId = id),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 24),

                      // Payment
                      Text('طريقة الدفع', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text)),
                      const SizedBox(height: 12),
                      ...[
                        ('vodafone_cash', 'فودافون كاش', Icons.phone_android, const Color(0xFFE60023)),
                        ('instapay', 'انستاباي', Icons.qr_code_2, const Color(0xFF00C853)),
                        ('cash', 'نقدي', Icons.money, Colors.green),
                      ].map((m) {
                        final sel = _paymentMethod == m.$1;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: () => setState(() => _paymentMethod = m.$1),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: sel ? m.$4.withValues(alpha: 0.1) : card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: sel ? m.$4 : border, width: sel ? 1.5 : 1),
                              ),
                              child: Row(children: [
                                Icon(m.$3, color: sel ? m.$4 : sub, size: 22),
                                const SizedBox(width: 12),
                                Text(m.$2, style: TextStyle(color: sel ? m.$4 : text, fontWeight: FontWeight.bold, fontSize: 15)),
                                const Spacer(),
                                Icon(sel ? Icons.check_circle : Icons.circle_outlined, color: sel ? m.$4 : sub, size: 20),
                              ]),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),

                      // Amount
                      Text('المبلغ (ج.م)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: text, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixIcon: Icon(Icons.money, color: sub),
                          suffixText: 'ج.م',
                          suffixStyle: TextStyle(color: sub),
                          filled: true,
                          fillColor: card,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: dark ? Colors.white : Colors.black,
                            foregroundColor: dark ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isSubmitting
                              ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: dark ? Colors.black : Colors.white, strokeWidth: 2))
                              : const Text('إنشاء الفاتورة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
