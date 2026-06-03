import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://darsak-backend.fly.dev/api/admin',
    connectTimeout: const Duration(seconds: 30),
  ));

  String _activeFilter = 'all';
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  static const _filters = [
    {'label': 'الكل', 'value': 'all'},
    {'label': 'معلقة', 'value': 'pending'},
    {'label': 'مقبولة', 'value': 'approved'},
    {'label': 'مرفوضة', 'value': 'rejected'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/transactions');
      final list = List<Map<String, dynamic>>.from(res.data);
      if (mounted) {
        setState(() {
          _transactions = list;
          _applyFilter();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _transactions = [];
          _applyFilter();
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _applyFilter() {
    if (_activeFilter == 'all') {
      _filtered = _transactions;
    } else {
      _filtered = _transactions
          .where((t) => t['status'] == _activeFilter)
          .toList();
    }
  }

  Future<void> _approveTransaction(Map<String, dynamic> tx) async {
    try {
      await _dio.put('/transactions/${tx['id']}', data: {'status': 'approved'});
      _fetchTransactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت الموافقة')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشلت العملية'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _rejectTransaction(Map<String, dynamic> tx) async {
    try {
      await _dio.put('/transactions/${tx['id']}', data: {'status': 'rejected'});
      _fetchTransactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الرفض')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشلت العملية'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((filter) {
                final isActive = _activeFilter == filter['value'];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _activeFilter = filter['value'] as String;
                        _applyFilter();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFFD4AF37)
                              : const Color(0xFF2A2A2A),
                        ),
                      ),
                      child: Text(
                        filter['label'] as String,
                        style: TextStyle(
                          color: isActive ? const Color(0xFFD4AF37) : Colors.white54,
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(color: Color(0xFF2A2A2A), height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
              : RefreshIndicator(
                  onRefresh: _fetchTransactions,
                  color: const Color(0xFFD4AF37),
                  child: _filtered.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(
                              child: Text(
                                'لا توجد معاملات',
                                style: TextStyle(color: Colors.white30),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            return _transactionCard(_filtered[index]);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _transactionCard(Map<String, dynamic> tx) {
    final status = tx['status'] as String;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tx['student_name'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                tx['plan_name'] as String,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${tx['amount']} ج.م',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (status == 'approved' && tx['approved_at'] != null) ...[
            const SizedBox(height: 6),
            Text(
              'تمت الموافقة: ${_formatDate(tx['approved_at'] as String)}',
              style: const TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4AF37), Color(0xFFB8941E)],
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () => _approveTransaction(tx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'موافقة',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: TextButton(
                        onPressed: () => _rejectTransaction(tx),
                        child: const Text(
                          'رفض',
                          style: TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'مقبولة';
        break;
      case 'rejected':
        color = Colors.redAccent;
        label = 'مرفوضة';
        break;
      default:
        color = const Color(0xFFD4AF37);
        label = 'معلقة';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
