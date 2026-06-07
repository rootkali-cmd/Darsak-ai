import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';
import 'add_edit_invoice_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<dynamic> _invoices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService().dio.get('/invoices/');
      final data = resp.data;
      _invoices = data is List ? data : [];
    } on DioException catch (e) {
      _error = 'فشل تحميل الفواتير: ${getDioErrorMessage(e)}';
    } catch (e) {
      _error = 'حدث خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _addInvoice() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditInvoiceScreen()),
    );
    _loadInvoices();
  }

  double get _totalAmount {
    return _invoices.fold(0.0, (sum, inv) => sum + ((inv['amount'] as num?)?.toDouble() ?? 0.0));
  }

  double get _paidAmount {
    return _invoices.where((inv) => inv['status'] == 'paid').fold(0.0, (sum, inv) => sum + ((inv['amount'] as num?)?.toDouble() ?? 0.0));
  }

  double get _unpaidAmount {
    return _invoices.where((inv) => inv['status'] != 'paid').fold(0.0, (sum, inv) => sum + ((inv['amount'] as num?)?.toDouble() ?? 0.0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: GlassTheme.glassAppBar('الفواتير'),
      floatingActionButton: GlassTheme.glassFAB(_addInvoice),
      body: RefreshIndicator(
        onRefresh: _loadInvoices,
        color: GlassTheme.indigo,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: GlassTheme.indigo))
            : _error != null
                ? _buildError()
                : _invoices.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFF94A3B8)),
                            SizedBox(height: 16),
                            Text('لا توجد فواتير', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          Row(
                            children: [
                              _StatChip(label: 'الإجمالي', amount: _totalAmount, color: GlassTheme.indigo),
                              const SizedBox(width: 8),
                              _StatChip(label: 'المدفوع', amount: _paidAmount, color: GlassTheme.green),
                              const SizedBox(width: 8),
                              _StatChip(label: 'غير المدفوع', amount: _unpaidAmount, color: GlassTheme.red),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._invoices.map((inv) {
                            final status = inv['status'] ?? '';
                            final isPaid = status == 'paid';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: GlassTheme.glassCard,
                              child: ListTile(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => AddEditInvoiceScreen(invoice: inv)),
                                  );
                                  _loadInvoices();
                                },
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: isPaid ? GlassTheme.green.withValues(alpha: 0.15) : GlassTheme.red.withValues(alpha: 0.15),
                                  child: Icon(
                                    isPaid ? Icons.check_circle : Icons.pending,
                                    color: isPaid ? GlassTheme.green : GlassTheme.red,
                                    size: 22,
                                  ),
                                ),
                                title: Text(inv['student_name'] ?? inv['student']?['full_name'] ?? '—', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                subtitle: Text(inv['description'] ?? '', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${inv['amount'] ?? 0} ج.م',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isPaid ? GlassTheme.green.withValues(alpha: 0.15) : GlassTheme.red.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isPaid ? 'مدفوع' : 'غير مدفوع',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isPaid ? GlassTheme.green : GlassTheme.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: GlassTheme.red),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadInvoices, style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.indigo), child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _StatChip({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: GlassTheme.glassCardColored(color),
        child: Column(
          children: [
            Text(
              '$amount',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}
