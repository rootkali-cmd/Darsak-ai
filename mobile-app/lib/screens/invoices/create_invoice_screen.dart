import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../core/theme.dart';
import '../../services/invoices_api_service.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final InvoicesApiService _api = InvoicesApiService();
  final _amountController = TextEditingController();
  final _picker = ImagePicker();

  List<dynamic> _lessons = [];
  bool _isLoadingLessons = true;
  bool _isSubmitting = false;
  String? _selectedLessonId;
  double? _selectedLessonPrice;
  String _paymentMethod = 'vodafone_cash';
  File? _screenshotFile;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadLessons() async {
    try {
      final lessons = await _api.getTeacherLessons();
      if (!mounted) return;
      setState(() {
        _lessons = lessons;
        _isLoadingLessons = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingLessons = false);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.dialogBackground(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.accent),
                title: Text('الكاميرا', style: TextStyle(color: AppColors.textPrimary(context))),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.accent),
                title: Text('المعرض', style: TextStyle(color: AppColors.textPrimary(context))),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() => _screenshotFile = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (_selectedLessonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر الدرس'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل المبلغ'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المبلغ غير صحيح'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final invoice = await _api.createInvoice(
        lessonId: _selectedLessonId!,
        amount: amount,
        paymentMethod: _paymentMethod,
      );

      if (!mounted) return;

      if (_screenshotFile != null && invoice['id'] != null) {
        final bytes = await _screenshotFile!.readAsBytes();
        final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        await _api.uploadPaymentProof(
          invoiceId: invoice['id'].toString(),
          screenshotUrl: base64Str,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء الفاتورة بنجاح'), backgroundColor: AppTheme.success),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة جديدة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('اختر الدرس'),
            const SizedBox(height: 8),
            _buildLessonDropdown(),
            const SizedBox(height: 24),
            _buildSectionTitle('طريقة الدفع'),
            const SizedBox(height: 12),
            _buildPaymentMethods(),
            const SizedBox(height: 24),
            _buildSectionTitle('المبلغ (ج.م)'),
            const SizedBox(height: 8),
            _buildAmountInput(),
            const SizedBox(height: 24),
            _buildSectionTitle('إثبات الدفع (اختياري)'),
            const SizedBox(height: 8),
            _buildScreenshotUpload(),
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.textPrimary(context),
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildLessonDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: _isLoadingLessons
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedLessonId,
                hint: Text(
                  'اختر الدرس',
                  style: TextStyle(color: AppColors.textSecondary(context)),
                ),
                dropdownColor: AppColors.surfaceElevated(context),
                items: _lessons.map<DropdownMenuItem<String>>((lesson) {
                  final id = lesson['id'].toString();
                  final title = lesson['title'] ?? lesson['name'] ?? 'درس';
                  final price = (lesson['price'] ?? 0).toDouble();
                  return DropdownMenuItem(
                    value: id,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14)),
                        if (price > 0)
                          Text(
                            '${price.toStringAsFixed(0)} ج.م',
                            style: TextStyle(color: AppTheme.accent, fontSize: 12),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLessonId = value;
                    final lesson = _lessons.firstWhere(
                      (l) => l['id'].toString() == value,
                      orElse: () => {},
                    );
                    final price = (lesson['price'] ?? 0).toDouble();
                    _selectedLessonPrice = price > 0 ? price : null;
                    if (_selectedLessonPrice != null) {
                      _amountController.text = _selectedLessonPrice!.toStringAsFixed(0);
                    }
                  });
                },
              ),
            ),
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      children: [
        _buildPaymentOption(
          value: 'vodafone_cash',
          label: 'فودافون كاش',
          icon: Icons.phone_android,
          child: _paymentMethod == 'vodafone_cash'
              ? Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone, color: AppTheme.success, size: 20),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('أرسل المبلغ إلى:', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(
                            '01031524947',
                            style: TextStyle(color: AppTheme.success, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        _buildPaymentOption(
          value: 'instapay',
          label: 'انستاباي',
          icon: Icons.qr_code_2,
          child: _paymentMethod == 'instapay'
              ? Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigher(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Center(
                    child: BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: 'INSTAPAY-DARSAK-01031524947',
                      width: 200,
                      height: 100,
                      drawText: true,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        _buildPaymentOption(
          value: 'bank_transfer',
          label: 'تحويل بنكي',
          icon: Icons.account_balance,
          child: _paymentMethod == 'bank_transfer'
              ? Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigher(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBankInfoRow('البنك', 'البنك الأهلي المصري'),
                      const SizedBox(height: 6),
                      _buildBankInfoRow('اسم الحساب', 'Darsak AI'),
                      const SizedBox(height: 6),
                      _buildBankInfoRow('رقم الحساب', '1234567890123456'),
                      const SizedBox(height: 6),
                      _buildBankInfoRow('IBAN', 'EGXX XXXX XXXX XXXX XXXX XXXX XXXX'),
                    ],
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildBankInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
        Text(value, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildPaymentOption({
    required String value,
    required String label,
    required IconData icon,
    Widget? child,
  }) {
    final isSelected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.08)
              : AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppColors.border(context),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isSelected ? AppTheme.accent : AppColors.textSecondary(context), size: 22),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppTheme.accent : AppColors.textPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(Icons.check_circle, color: AppTheme.accent, size: 20)
                else
                  Icon(Icons.circle_outlined, color: AppColors.textSecondary(context), size: 20),
              ],
            ),
            if (child != null) child,
          ],
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    return TextField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: TextStyle(color: AppColors.textSecondary(context)),
        prefixIcon: Icon(Icons.monetization_on_outlined, color: AppColors.textSecondary(context)),
        suffixText: 'ج.م',
        suffixStyle: TextStyle(color: AppColors.textSecondary(context)),
        filled: true,
        fillColor: AppColors.surfaceElevated(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accent),
        ),
      ),
    );
  }

  Widget _buildScreenshotUpload() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _screenshotFile != null ? AppTheme.success : AppColors.border(context),
                style: _screenshotFile == null ? BorderStyle.solid : BorderStyle.solid,
              ),
            ),
            child: _screenshotFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_screenshotFile!, fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _screenshotFile = null),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 40, color: AppColors.textSecondary(context)),
                      const SizedBox(height: 8),
                      Text(
                        'اضغط لرفع صورة إثبات الدفع',
                        style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
                      ),
                    ],
                  ),
          ),
        ),
      ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'إرسال الفاتورة',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
