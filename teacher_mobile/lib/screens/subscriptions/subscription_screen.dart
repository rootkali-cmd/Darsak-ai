import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../services/telegram_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _codeController = TextEditingController();

  // Payment dialog state
  String _paymentMethod = 'vodafone';
  final _senderPhoneController = TextEditingController();
  final _instaPayIdController = TextEditingController();
  File? _selectedReceipt;

  static const String _vodafoneCashNumber = '01031524947';
  static const String _instaPayId = 'ahmed-mahmoud-1@instapay';
  static const String _supportWhatsApp = '201031524947';

  @override
  void dispose() {
    _codeController.dispose();
    _senderPhoneController.dispose();
    _instaPayIdController.dispose();
    super.dispose();
  }

  void _showPaymentDialog(String planName, String price) {
    setState(() {
      _paymentMethod = 'vodafone';
      _senderPhoneController.clear();
      _instaPayIdController.clear();
      _selectedReceipt = null;
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('اشتراك $planName'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$price ج.م',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'سعر الباقة',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'اختر طريقة الدفع',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PaymentMethodCard(
                          title: 'فودافون كاش',
                          icon: Icons.phone_android,
                          isSelected: _paymentMethod == 'vodafone',
                          onTap: () => setDialogState(() => _paymentMethod = 'vodafone'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PaymentMethodCard(
                          title: 'إنستا باي',
                          icon: Icons.qr_code,
                          isSelected: _paymentMethod == 'instapay',
                          onTap: () => setDialogState(() => _paymentMethod = 'instapay'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_paymentMethod == 'vodafone') ...[
                    Text(
                      'رقم فودافون كاش',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.copy, size: 18, color: AppTheme.accent),
                          const SizedBox(width: 8),
                          SelectableText(
                            _vodafoneCashNumber,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _senderPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'رقم المحول منه *',
                        hintText: '01xxxxxxxxx',
                        prefixIcon: Icon(Icons.phone, size: 20),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'صورة التحويل',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildReceiptUpload(setDialogState),
                  ] else ...[
                    Text(
                      'امسح QR Code بالكاميرا',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'QR Code',
                              style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6B2D82),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'INSTA PAY',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _instaPayId,
                              style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _instaPayIdController,
                      decoration: const InputDecoration(
                        labelText: 'معرف إنستا باي الخاص بك *',
                        hintText: 'username@instapay',
                        prefixIcon: Icon(Icons.account_circle, size: 20),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'صورة التحويل',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildReceiptUpload(setDialogState),
                  ],
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final url = Uri.parse('https://wa.me/$_supportWhatsApp');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Row(
                      children: [
                        Icon(Icons.support_agent, size: 16, color: AppTheme.accent),
                        const SizedBox(width: 8),
                        Text(
                          'للدعم عبر واتساب: $_supportWhatsApp',
                          style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.open_in_new, size: 12, color: AppTheme.accent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: AppTheme.danger)),
            ),
            ElevatedButton(
              onPressed: () {
                if (_paymentMethod == 'vodafone' && _senderPhoneController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال رقم المحول')),
                  );
                  return;
                }
                if (_paymentMethod == 'instapay' && _instaPayIdController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال معرف إنستا باي')),
                  );
                  return;
                }
                if (_selectedReceipt == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى رفع صورة التحويل')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _showAdminActivationDialog(planName, price);
              },
              child: const Text('إرسال للتفعيل'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminActivationDialog(String planName, String price) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تفعيل الاشتراك'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الباقة: $planName'),
            Text('السعر: $price ج.م'),
            Text('الطريقة: ${_paymentMethod == 'vodafone' ? 'فودافون كاش' : 'إنستا باي'}'),
            if (_paymentMethod == 'vodafone')
              Text('من رقم: ${_senderPhoneController.text}')
            else
              Text('من معرف: ${_instaPayIdController.text}'),
            Text('صورة التحويل: ${_selectedReceipt != null ? 'تم الرفع' : '---'}'),
            const SizedBox(height: 16),
            const Text(
              'سيتم إرسال إشعار للمشرف للتفعيل.',
              style: TextStyle(color: AppTheme.warning, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final senderInfo = _paymentMethod == 'vodafone'
                  ? 'فودافون كاش - ${_senderPhoneController.text}'
                  : 'إنستا باي - ${_instaPayIdController.text}';
              final method = _paymentMethod == 'vodafone' ? 'فودافون كاش' : 'إنستا باي';
              final receiptName = _selectedReceipt?.path.split('/').last;
              Navigator.pop(ctx);
              if (!mounted) return;
              await TelegramService.sendPaymentNotification(
                planName: planName,
                planPrice: price,
                paymentMethod: method,
                senderInfo: senderInfo,
                receiptFileName: receiptName,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إرسال طلب التفعيل')),
              );
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptUpload(void Function(void Function()) setDialogState) {
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final result = await picker.pickImage(source: ImageSource.gallery);
        if (result != null) {
          setDialogState(() {
            _selectedReceipt = File(result.path);
          });
        }
      },
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedReceipt != null
                ? AppTheme.success.withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.outline,
            width: _selectedReceipt != null ? 2 : 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedReceipt != null ? Icons.check_circle : Icons.upload_file,
                size: 40,
                color: _selectedReceipt != null
                    ? AppTheme.success
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedReceipt != null ? 'تم اختيار الصورة' : 'اضغط لرفع صورة التحويل',
                style: TextStyle(
                  color: _selectedReceipt != null
                      ? AppTheme.success
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: _selectedReceipt != null ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('الاشتراكات')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'كود التفعيل',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'أدخل كود التفعيل للحصول على اشتراكك',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            decoration: const InputDecoration(
                              hintText: 'XXXX-XXXX-XXXX',
                              hintStyle: TextStyle(color: AppTheme.textMuted),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('تفعيل'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اختر الخطة المناسبة لك',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildPlanCard(
              context: context,
              name: 'Basic',
              price: '200',
              students: '50 طالب',
              features: const [
                'إدارة الطلاب',
                'تسجيل الحضور',
                'المجموعات',
                'تقارير أساسية',
              ],
              isPopular: false,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildPlanCard(
              context: context,
              name: 'Pro',
              price: '600',
              students: '150 طالب',
              features: const [
                'كل مزايا Basic',
                'تحليل الأداء',
                'الفواتير',
                'QR Code',
                'تقارير متقدمة',
              ],
              isPopular: true,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildPlanCard(
              context: context,
              name: 'Enterprise',
              price: '1100',
              students: '300 طالب',
              features: const [
                'كل المزايا',
                '300 طالب',
                'دعم فني مميز',
                'تصدير البيانات',
                'امتيازات حصرية',
              ],
              isPopular: false,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required String name,
    required String price,
    required String students,
    required List<String> features,
    required bool isPopular,
    required bool isDark,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPopular
            ? const BorderSide(color: AppTheme.accent, width: 2)
            : BorderSide.none,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      students,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'ج.م/شهر',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(f, style: const TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showPaymentDialog(name, price),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('اشتراك', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
          if (isPopular)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'الأكثر طلباً',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accent : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? AppTheme.accent
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.accent
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
