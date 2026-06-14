import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/invoice.dart';
import '../../../core/models/student.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> with TickerProviderStateMixin {
  late AnimationController _listController;
  late Animation<double> _listAnimation;
  List<InvoiceModel> _invoices = [];
  List<StudentModel> _students = [];
  String _selectedStudentId = '';
  bool _isLoading = true;

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
    _loadData();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  void _loadData() async {
    final data = context.read<DataProvider>();
    // 1. Show local data IMMEDIATELY
    _students = data.students;
    if (_students.isNotEmpty && _selectedStudentId.isEmpty) {
      _selectedStudentId = _students.first.id;
    }
    if (_students.isNotEmpty) {
      setState(() => _isLoading = false);
    } else {
      setState(() => _isLoading = true);
    }

    // 2. Background API call
    try {
      final raw = await data.api.getInvoices(
        studentId: _selectedStudentId.isNotEmpty ? _selectedStudentId : null,
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _invoices = raw.map((j) => InvoiceModel.fromJson(j as Map<String, dynamic>)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final sync = context.watch<SyncProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    final totalAmount = _invoices.fold<double>(0, (sum, inv) => sum + inv.amount);
    final totalPaid = _invoices.where((inv) => inv.paid).fold<double>(0, (sum, inv) => sum + inv.amount);
    final totalUnpaid = totalAmount - totalPaid;

    return Scaffold(
      body: Column(
        children: [
          if (data.isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.15),
                border: Border(bottom: BorderSide(color: AppTheme.warning.withValues(alpha: 0.3))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 16, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  Text(
                    'وضع عدم الاتصال',
                    style: TextStyle(color: AppTheme.warning, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (sync.isSyncing) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warning),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
                          Row(
                            children: [
                              Text(
                                'الفواتير',
                                style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_invoices.length}',
                                  style: TextStyle(color: AppTheme.accent, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddInvoiceDialog(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('إضافة فاتورة'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 320,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedStudentId.isNotEmpty ? _selectedStudentId : null,
                          decoration: const InputDecoration(
                            labelText: 'تصفية حسب الطالب',
                            prefixIcon: Icon(Icons.filter_list, size: 20),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('جميع الطلاب')),
                            ..._students.map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.fullName),
                            )),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedStudentId = v ?? '');
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _summaryChip('الإجمالي', '${totalAmount.toStringAsFixed(0)} ج.م', AppTheme.accent, isDark),
                          const SizedBox(width: 12),
                          _summaryChip('المدفوع', '${totalPaid.toStringAsFixed(0)} ج.م', AppTheme.success, isDark),
                          const SizedBox(width: 12),
                          _summaryChip('غير المدفوع', '${totalUnpaid.toStringAsFixed(0)} ج.م', AppTheme.danger, isDark),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (_invoices.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(60),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 56, color: textMuted),
                              const SizedBox(height: 16),
                              Text('لا توجد فواتير', style: TextStyle(color: textSecondary, fontSize: 16)),
                              const SizedBox(height: 8),
                              Text('أضف فاتورة جديدة للبدء', style: TextStyle(color: textMuted, fontSize: 13)),
                            ],
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _invoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _invoices[index];
                            final student = _students.where((s) => s.id == invoice.studentId).firstOrNull;
                            return _InvoiceRow(
                              invoice: invoice,
                              studentName: student?.fullName ?? '—',
                              onTap: () => _togglePaid(invoice),
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

  Widget _summaryChip(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePaid(InvoiceModel invoice) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final newStatus = !invoice.paid;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        title: Row(
          children: [
            Icon(
              newStatus ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: newStatus ? AppTheme.success : AppTheme.warning,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              newStatus ? 'تأكيد الدفع' : 'إلغاء الدفع',
              style: TextStyle(color: textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                newStatus
                    ? 'هل أنت متأكد من تأكيد دفع هذه الفاتورة؟'
                    : 'هل أنت متأكد من إلغاء دفع هذه الفاتورة؟',
                style: TextStyle(color: textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt, size: 20, color: AppTheme.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.description ?? 'فاتورة',
                            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${invoice.amount.toStringAsFixed(0)} ج.م',
                            style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: newStatus ? AppTheme.success : AppTheme.warning,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                newStatus ? 'تأكيد الدفع' : 'إلغاء الدفع',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<DataProvider>().api.toggleInvoicePaid(
          invoice.id,
          newStatus,
          paymentDate: newStatus ? DateTime.now().toIso8601String() : null,
        ).timeout(const Duration(seconds: 8));
        _loadData();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'تم تأكيد الدفع' : 'تم إلغاء الدفع'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddInvoiceDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final amountController = TextEditingController();
    final descController = TextEditingController();
    final paymentDateController = TextEditingController();
    String? selectedStudentId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
                  initialValue: selectedStudentId,
                  decoration: const InputDecoration(
                    labelText: 'اختر الطالب *',
                    prefixIcon: Icon(Icons.person, size: 20),
                  ),
                  items: _students.map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.fullName),
                  )).toList(),
                  onChanged: (v) {
                    setDialogState(() => selectedStudentId = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ *',
                    prefixIcon: Icon(Icons.monetization_on_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'الوصف',
                    prefixIcon: Icon(Icons.description_outlined, size: 20),
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: paymentDateController,
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الدفع (اختياري)',
                    prefixIcon: Icon(Icons.calendar_today, size: 20),
                    hintText: 'YYYY-MM-DD',
                  ),
                ),
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
                onPressed: selectedStudentId != null && amountController.text.isNotEmpty
                    ? () async {
                        Navigator.pop(ctx);
                        try {
                          await context.read<DataProvider>().api.createInvoice({
                            'student_id': selectedStudentId,
                            'amount': double.tryParse(amountController.text) ?? 0,
                            'description': descController.text,
                            'paid': false,
                            if (paymentDateController.text.isNotEmpty)
                              'payment_date': paymentDateController.text,
                          }).timeout(const Duration(seconds: 8));
                          _loadData();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إضافة الفاتورة'),
                              backgroundColor: AppTheme.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          setState(() => _isLoading = false);
                        }
                      }
                    : null,
                child: const Text('إضافة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatefulWidget {
  final InvoiceModel invoice;
  final String studentName;
  final VoidCallback onTap;

  const _InvoiceRow({
    required this.invoice,
    required this.studentName,
    required this.onTap,
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
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    final isPaid = widget.invoice.paid;
    final statusColor = isPaid ? AppTheme.success : AppTheme.danger;

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
      child: GestureDetector(
        onTap: widget.onTap,
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
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPaid ? Icons.check_circle : Icons.pending,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.studentName,
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.invoice.amount.toStringAsFixed(0)} ج.م',
                              style: TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (widget.invoice.description != null && widget.invoice.description!.isNotEmpty)
                          Text(
                            widget.invoice.description!,
                            style: TextStyle(color: textMuted, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      isPaid ? 'مدفوع' : 'غير مدفوع',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (widget.invoice.paymentDate != null) ...[
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'تاريخ الدفع',
                          style: TextStyle(color: textMuted, fontSize: 9),
                        ),
                        Text(
                          widget.invoice.paymentDate!.length >= 10
                              ? widget.invoice.paymentDate!.substring(0, 10)
                              : widget.invoice.paymentDate!,
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
