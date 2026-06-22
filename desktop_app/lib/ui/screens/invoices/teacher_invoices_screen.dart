import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/data_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'teacher_create_invoice_screen.dart';

class TeacherInvoicesScreen extends StatefulWidget {
  const TeacherInvoicesScreen({super.key});

  @override
  State<TeacherInvoicesScreen> createState() => _TeacherInvoicesScreenState();
}

class _TeacherInvoicesScreenState extends State<TeacherInvoicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _allInvoices = [];
  final Map<String, String> _studentNames = {};

  final _tabs = const [
    Tab(text: 'قيد المراجعة'),
    Tab(text: 'مدفوع'),
    Tab(text: 'مرفوض'),
    Tab(text: 'الكل'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<DataProvider>().api;
      final data = await api.getTeacherInvoices();
      _allInvoices =
          data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();

      for (final inv in _allInvoices) {
        final sid = inv['student_id']?.toString() ?? '';
        if (sid.isNotEmpty && !_studentNames.containsKey(sid)) {
          final name = inv['student_name']?.toString();
          if (name != null && name.isNotEmpty) {
            _studentNames[sid] = name;
          } else {
            try {
              final studentResp = await api.getStudent(sid);
              final studentData = studentResp['data'];
              if (studentData is Map<String, dynamic>) {
                _studentNames[sid] = studentData['full_name']?.toString() ?? 'طالب';
              }
            } catch (_) {
              _studentNames[sid] = 'طالب';
            }
          }
        }
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _filteredInvoices(String status) {
    if (status == 'all') return _allInvoices;
    return _allInvoices.where((inv) {
      final s = inv['status']?.toString().toLowerCase() ?? '';
      return s == status;
    }).toList();
  }

  String _statusArabic(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة';
      case 'approved':
      case 'paid':
        return 'مدفوع';
      case 'rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'approved':
      case 'paid':
        return AppTheme.success;
      case 'rejected':
        return AppTheme.danger;
      default:
        return Colors.grey;
    }
  }

  String _paymentMethodArabic(String? method) {
    switch (method) {
      case 'vodafone_cash':
        return 'فودافون كاش';
      case 'instapay':
        return 'انستاباي';
      case 'bank_transfer':
        return 'تحويل بنكي';
      default:
        return method ?? 'غير محدد';
    }
  }

  Future<void> _approveInvoice(String id) async {
    try {
      await context.read<DataProvider>().api.approveInvoice(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت الموافقة على الفاتورة'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadInvoices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _rejectInvoice(String id) async {
    try {
      await context.read<DataProvider>().api.rejectInvoice(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفض الفاتورة'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadInvoices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary =
        isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Text(
                'الفواتير',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_allInvoices.length}',
                  style: TextStyle(color: AppTheme.accent, fontSize: 12),
                ),
              ),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TeacherCreateInvoiceScreen(),
                      ),
                    );
                    if (result == true) _loadInvoices();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('فاتورة جديدة'),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.accent,
            unselectedLabelColor: textSecondary,
            indicatorColor: AppTheme.accent,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            tabs: _tabs,
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: textSecondary)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadInvoices,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInvoiceList(
                            _filteredInvoices('pending'), isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
                        _buildInvoiceList(
                            _filteredInvoices('paid'), isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
                        _buildInvoiceList(
                            _filteredInvoices('rejected'), isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
                        _buildInvoiceList(
                            _allInvoices, isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildInvoiceList(
    List<Map<String, dynamic>> invoices,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded, size: 64, color: textMuted),
            const SizedBox(height: 12),
            Text('لا توجد فواتير',
                style: TextStyle(fontSize: 16, color: textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: invoices.length,
      itemBuilder: (ctx, i) => _buildInvoiceCard(
        invoices[i], isDark, surfaceColor, borderColor, textPrimary, textSecondary, textMuted,
      ),
    );
  }

  Widget _buildInvoiceCard(
    Map<String, dynamic> invoice,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    final id = invoice['id']?.toString() ?? '';
    final studentId = invoice['student_id']?.toString() ?? '';
    final studentName = _studentNames[studentId] ?? 'طالب';
    final amount = invoice['amount'] ?? 0;
    final method = invoice['payment_method']?.toString() ?? '';
    final status = invoice['status']?.toString() ?? '';
    final screenshotUrl = invoice['screenshot_url']?.toString();
    final createdAt = invoice['created_at']?.toString() ?? '';

    String dateStr = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt);
        dateStr =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {
        dateStr = createdAt;
      }
    }

    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(studentName,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textPrimary)),
                    const SizedBox(height: 2),
                    Text(_paymentMethodArabic(method),
                        style: TextStyle(fontSize: 12, color: textSecondary)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_statusArabic(status),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('$amount ج.م',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary)),
              const Spacer(),
              if (dateStr.isNotEmpty)
                Text(dateStr,
                    style: TextStyle(fontSize: 12, color: textMuted)),
            ],
          ),
          if (screenshotUrl != null && screenshotUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                screenshotUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_rounded, size: 36, color: textMuted),
                      const SizedBox(height: 4),
                      Text('صورة الإيصال',
                          style: TextStyle(fontSize: 12, color: textMuted)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: () => _approveInvoice(id),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('موافقة',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: () => _rejectInvoice(id),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('رفض',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.danger,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
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
}
