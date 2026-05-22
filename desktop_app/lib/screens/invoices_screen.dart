import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/local_db.dart';
import '../providers/data_provider.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> with TickerProviderStateMixin {
  late AnimationController _listController;
  late Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _listAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _listController, curve: Curves.easeOutCubic),
    );
    _listController.forward();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final invoices = LocalDB.getAllData(LocalDB.invoicesBox);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _listAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(_listAnimation),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الفواتير',
                    style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddInvoiceDialog(context, data),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة فاتورة'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (invoices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: textMuted),
                      const SizedBox(height: 16),
                      Text('لا توجد فواتير', style: TextStyle(color: textSecondary, fontSize: 16)),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: invoices.length,
                  itemBuilder: (context, index) {
                    final inv = invoices[index];
                    final amount = (inv['amount'] ?? 0).toDouble();
                    final paid = inv['paid'] == true;
                    return _InvoiceRow(
                      amount: amount,
                      description: inv['description'] ?? '-',
                      paid: paid,
                      paymentDate: inv['payment_date'] ?? '-',
                      index: index,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddInvoiceDialog(BuildContext context, DataProvider data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final amountController = TextEditingController();
    final descController = TextEditingController();
    String? selectedStudentId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        title: Text('إضافة فاتورة جديدة', style: TextStyle(color: textPrimary)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedStudentId,
                decoration: const InputDecoration(labelText: 'الطالب'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('اختر الطالب')),
                  ...data.students.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.fullName} (${s.code})'),
                      )),
                ],
                onChanged: (v) => selectedStudentId = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'المبلغ'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(controller: descController, decoration: const InputDecoration(labelText: 'الوصف')),
            ],
          ),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: () {
              if (selectedStudentId != null && amountController.text.isNotEmpty) {
                final invoiceData = {
                  'student_id': selectedStudentId,
                  'amount': double.tryParse(amountController.text) ?? 0,
                  'description': descController.text,
                  'paid': false,
                  'created_at': DateTime.now().toIso8601String(),
                };
                LocalDB.addToSyncQueue('invoice', invoiceData);
                LocalDB.saveData(LocalDB.invoicesBox, DateTime.now().millisecondsSinceEpoch.toString(), invoiceData);
                Navigator.pop(ctx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('تم إضافة الفاتورة'),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }
            },
            child: const Text('إضافة'),
          ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatefulWidget {
  final double amount;
  final String description;
  final bool paid;
  final String paymentDate;
  final int index;

  const _InvoiceRow({
    required this.amount,
    required this.description,
    required this.paid,
    required this.paymentDate,
    required this.index,
  });

  @override
  State<_InvoiceRow> createState() => _InvoiceRowState();
}

class _InvoiceRowState extends State<_InvoiceRow> with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.01).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    final statusColor = widget.paid ? AppTheme.success : AppTheme.danger;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _hoverController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, _) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered ? statusColor.withValues(alpha: 0.3) : borderColor,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.amount.toStringAsFixed(0)} ج.م',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        widget.description,
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    widget.paid ? 'مدفوع' : 'غير مدفوع',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  widget.paymentDate,
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
