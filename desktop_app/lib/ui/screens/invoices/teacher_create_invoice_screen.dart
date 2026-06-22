import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/data_provider.dart';
import '../../../core/theme/app_theme.dart';

class TeacherCreateInvoiceScreen extends StatefulWidget {
  const TeacherCreateInvoiceScreen({super.key});

  @override
  State<TeacherCreateInvoiceScreen> createState() =>
      _TeacherCreateInvoiceScreenState();
}

class _TeacherCreateInvoiceScreenState extends State<TeacherCreateInvoiceScreen> {
  final _amountController = TextEditingController();
  bool _isLoadingStudents = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  String? _selectedStudentId;
  String _paymentMethod = 'vodafone_cash';
  final _searchController = TextEditingController();
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final resp = await context
          .read<DataProvider>()
          .api
          .getStudents(search: '')
          .timeout(const Duration(seconds: 15));
      _students =
          resp.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
      _filteredStudents = List.from(_students);
    } catch (e) {
      debugPrint('Load students error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل الطلاب: $e'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  void _onSearchChanged() {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text.trim().toLowerCase();
      if (query.isEmpty) {
        _filteredStudents = List.from(_students);
      } else {
        _filteredStudents = _students.where((s) {
          final name = (s['full_name'] ?? '').toString().toLowerCase();
          final code = (s['code'] ?? '').toString().toLowerCase();
          return name.contains(query) || code.contains(query);
        }).toList();
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _submit() async {
    if (_selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر الطالب'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل المبلغ'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المبلغ غير صحيح'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await context.read<DataProvider>().api.teacherCreateInvoice({
        'student_id': _selectedStudentId,
        'amount': amount,
        'payment_method': _paymentMethod,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء الفاتورة بنجاح'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_forward, color: textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Text(
                  'إنشاء فاتورة',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: SizedBox(
                  width: 600,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('اختر الطالب', textPrimary),
                      const SizedBox(height: 10),
                      _buildStudentDropdown(surfaceColor, borderColor, textPrimary, textSecondary),
                      const SizedBox(height: 28),
                      _buildSectionTitle('طريقة الدفع', textPrimary),
                      const SizedBox(height: 12),
                      _buildPaymentMethods(surfaceColor, borderColor, textPrimary, textSecondary),
                      const SizedBox(height: 28),
                      _buildSectionTitle('المبلغ (ج.م)', textPrimary),
                      const SizedBox(height: 10),
                      _buildAmountInput(surfaceColor, borderColor, textPrimary, textSecondary),
                      const SizedBox(height: 36),
                      _buildSubmitButton(),
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

  Widget _buildSectionTitle(String title, Color textPrimary) {
    return Text(
      title,
      style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
    );
  }

  Widget _buildStudentDropdown(
      Color surfaceColor, Color borderColor, Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'ابحث بالاسم أو الكود...',
            hintStyle: TextStyle(color: textSecondary, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: textSecondary),
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accent),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: _isLoadingStudents
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : _filteredStudents.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 18, color: AppTheme.danger),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('لا يوجد طلاب',
                                style:
                                    TextStyle(color: AppTheme.danger, fontSize: 14)),
                          ),
                          TextButton(
                            onPressed: _loadStudents,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedStudentId,
                        hint: Text('اختر الطالب',
                            style: TextStyle(color: textSecondary)),
                        dropdownColor: surfaceColor,
                        items: _filteredStudents
                            .map<DropdownMenuItem<String>>((student) {
                          return DropdownMenuItem(
                            value: student['id'].toString(),
                            child: Text(
                              '${student['full_name'] ?? 'طالب'} (${student['code'] ?? '-'})',
                              style: TextStyle(
                                  color: textPrimary, fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedStudentId = value),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethods(
      Color surfaceColor, Color borderColor, Color textPrimary, Color textSecondary) {
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
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _paymentMethod = m.$1),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? m.$4.withValues(alpha: 0.08)
                      : surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? m.$4 : borderColor,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(m.$3,
                        color: isSelected ? m.$4 : textSecondary, size: 22),
                    const SizedBox(width: 12),
                    Text(m.$2,
                        style: TextStyle(
                          color: isSelected ? m.$4 : textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        )),
                    const Spacer(),
                    if (isSelected)
                      Icon(Icons.check_circle, color: m.$4, size: 20)
                    else
                      Icon(Icons.circle_outlined,
                          color: textSecondary, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAmountInput(
      Color surfaceColor, Color borderColor, Color textPrimary, Color textSecondary) {
    return TextField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      style: TextStyle(color: textPrimary, fontSize: 16),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: TextStyle(color: textSecondary),
        prefixIcon: Icon(Icons.monetization_on_outlined, color: textSecondary),
        suffixText: 'ج.م',
        suffixStyle: TextStyle(color: textSecondary),
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.accent)),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child:
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('إنشاء الفاتورة',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
      ),
    );
  }
}
