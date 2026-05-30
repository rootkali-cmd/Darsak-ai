import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/invoices_provider.dart';
import '../../providers/students_provider.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/empty_state.dart';
import 'add_edit_invoice_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InvoicesProvider>(context, listen: false).loadInvoices();
      Provider.of<StudentsProvider>(context, listen: false).loadStudents();
    });
  }

  void _showAddInvoice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditInvoiceScreen()),
    );
  }

  void _showEditInvoice(dynamic invoice) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditInvoiceScreen(invoice: invoice)),
    );
  }

  Future<void> _togglePaid(dynamic invoice) async {
    final provider = Provider.of<InvoicesProvider>(context, listen: false);
    final data = {
      ...Map<String, dynamic>.from(invoice as Map),
      'paid': !(invoice['paid'] == true),
    };
    final success = await provider.updateInvoice(invoice['id'] as int, data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'تم التحديث' : (provider.error ?? 'فشل التحديث'))),
      );
    }
  }

  Future<void> _deleteInvoice(dynamic invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
        content: const Text('هل أنت متأكد من حذف هذه الفاتورة؟', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<InvoicesProvider>(context, listen: false);
      final success = await provider.deleteInvoice(invoice['id'] as int);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'تم الحذف بنجاح' : (provider.error ?? 'فشل الحذف'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير'),
      ),
      body: Consumer<InvoicesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const AppLoadingIndicator();
          }
          if (provider.error != null && provider.invoices.isEmpty) {
            return AppErrorWidget(
              message: provider.error!,
              onRetry: () => provider.loadInvoices(),
            );
          }
          if (provider.invoices.isEmpty) {
            return const EmptyState(message: 'لا توجد فواتير', icon: Icons.receipt);
          }
          return RefreshIndicator(
            onRefresh: () => provider.loadInvoices(),
            color: const Color(0xFFdc2626),
            backgroundColor: const Color(0xFF1a1a2e),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: provider.invoices.length,
              itemBuilder: (context, index) {
                final invoice = provider.invoices[index];
                final student = invoice['student'] ?? {};
                final studentName = student['full_name'] ?? student['name'] ?? '—';
                final amount = invoice['amount'] ?? 0;
                final description = invoice['description']?.toString() ?? '';
                final paid = invoice['paid'] == true;

                return Card(
                  color: const Color(0xFF1a1a2e),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => _showEditInvoice(invoice),
                    leading: CircleAvatar(
                      backgroundColor: paid ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                      child: Icon(Icons.receipt, color: paid ? Colors.green : Colors.orange),
                    ),
                    title: Text(
                      studentName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '$description • $amount ج.م',
                      style: const TextStyle(color: Color(0xFF6b7280), fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: paid,
                          onChanged: (_) => _togglePaid(invoice),
                          activeTrackColor: Colors.green,
                          thumbColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) return Colors.green;
                            return Colors.orange;
                          }),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteInvoice(invoice),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddInvoice,
        backgroundColor: const Color(0xFFdc2626),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
