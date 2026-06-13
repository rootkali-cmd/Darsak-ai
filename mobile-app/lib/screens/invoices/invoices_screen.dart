import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/invoices_api_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/shimmer_loading.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final InvoicesApiService _api = InvoicesApiService();
  List<dynamic> _invoices = [];
  bool _isLoading = true;
  String _currentTab = 'all';

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await _api.getMyInvoices();
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredInvoices {
    if (_currentTab == 'all') return _invoices;
    return _invoices.where((inv) {
      final status = (inv['status'] ?? '').toString();
      return status == _currentTab;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvoices,
          ),
        ],
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: ShimmerList(),
            )
          : Column(
              children: [
                _buildTabs(),
                Expanded(
                  child: _filteredInvoices.isEmpty
                      ? EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: _currentTab == 'all'
                              ? 'لا توجد فواتير بعد'
                              : 'لا توجد فواتير في هذا القسم',
                        )
                      : RefreshIndicator(
                          onRefresh: _loadInvoices,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                            itemCount: _filteredInvoices.length,
                            itemBuilder: (_, i) => _buildInvoiceCard(_filteredInvoices[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabs() {
    final tabs = [
      ('all', 'الكل'),
      ('pending', 'قيد المراجعة'),
      ('paid', 'مدفوع'),
      ('rejected', 'مرفوض'),
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: tabs.map((tab) {
          final isActive = _currentTab == tab.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentTab = tab.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tab.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isActive ? Colors.white : AppColors.textSecondary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final lessonName = invoice['lesson_name'] ?? invoice['lesson']?['title'] ?? '';
    final amount = (invoice['amount'] ?? 0).toDouble();
    final paymentMethod = _paymentMethodLabel(invoice['payment_method'] ?? '');
    final status = (invoice['status'] ?? 'pending').toString();
    final createdAt = invoice['created_at'];

    final statusInfo = _statusInfo(status);

    String dateStr = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt.toString());
        dateStr = DateFormat('yyyy-MM-dd', 'ar').format(dt);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusInfo.$1.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.receipt_long, color: statusInfo.$1, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lessonName.isNotEmpty ? lessonName : 'فاتورة',
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      paymentMethod,
                      style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusInfo.$1.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusInfo.$1.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusInfo.$2,
                  style: TextStyle(
                    color: statusInfo.$1,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.monetization_on_outlined, size: 16, color: AppColors.textSecondary(context)),
              const SizedBox(width: 6),
              Text(
                '${amount.toStringAsFixed(0)} ج.م',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (dateStr.isNotEmpty) ...[
                Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary(context)),
                const SizedBox(width: 4),
                Text(dateStr, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'vodafone_cash':
        return 'فودافون كاش';
      case 'instapay':
        return 'انستاباي';
      case 'bank_transfer':
        return 'تحويل بنكي';
      default:
        return method;
    }
  }

  (Color, String) _statusInfo(String status) {
    switch (status) {
      case 'paid':
        return (AppTheme.success, 'مدفوع');
      case 'rejected':
        return (AppTheme.danger, 'مرفوض');
      case 'pending':
      default:
        return (AppTheme.warning, 'قيد المراجعة');
    }
  }
}
