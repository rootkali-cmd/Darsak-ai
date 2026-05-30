import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/invoice.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final List<InvoiceModel> _invoices = [];

  void _showAddInvoiceDialog() {
    final amountController = TextEditingController();
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'إضافة فاتورة',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'المبلغ'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'الوصف'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  final invoice = InvoiceModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    studentId: '',
                    amount: amount,
                    description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                    paid: false,
                    createdAt: DateTime.now(),
                  );
                  setState(() => _invoices.insert(0, invoice));
                  Navigator.pop(context);
                },
                child: const Text('حفظ'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('الفواتير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddInvoiceDialog,
          ),
        ],
      ),
      body: _invoices.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.darkTextMuted),
                  const SizedBox(height: 16),
                  Text(
                    'لا يوجد فواتير',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _invoices.length,
              itemBuilder: (context, index) {
                final invoice = _invoices[index];
                return _InvoiceCard(
                  invoice: invoice,
                  onTogglePaid: () => setState(() {
                    final idx = _invoices.indexOf(invoice);
                    _invoices[idx] = InvoiceModel(
                      id: invoice.id,
                      studentId: invoice.studentId,
                      amount: invoice.amount,
                      description: invoice.description,
                      paid: !invoice.paid,
                      paymentDate: !invoice.paid ? DateTime.now().toIso8601String() : null,
                      signature: invoice.signature,
                      createdAt: invoice.createdAt,
                    );
                  }),
                );
              },
            ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final VoidCallback onTogglePaid;

  const _InvoiceCard({required this.invoice, required this.onTogglePaid});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: invoice.paid
                  ? AppTheme.success.withValues(alpha: 0.15)
                  : AppTheme.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                invoice.paid ? Icons.check_circle : Icons.pending,
                color: invoice.paid ? AppTheme.success : AppTheme.danger,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${invoice.amount.toStringAsFixed(0)} ج.م',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  invoice.description ?? 'فاتورة',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch(
            value: invoice.paid,
            onChanged: (_) => onTogglePaid(),
            activeColor: AppTheme.success,
          ),
        ],
      ),
    );
  }
}
