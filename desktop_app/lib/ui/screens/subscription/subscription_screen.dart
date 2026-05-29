import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/data_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/telegram_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/constants.dart';
import '../../../ui/widgets/qr_code_widget.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _codeController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _subscriptionService = SubscriptionService(ApiClient());

  Map<String, dynamic>? _subscription;
  List<dynamic> _plans = [];
  bool _isLoading = true;
  bool _activating = false;
  Timer? _refreshTimer;

  // Payment state
  String? _selectedPlanId;
  String? _selectedPlanName;
  String? _selectedPlanPrice;
  String _paymentMethod = 'vodafone'; // 'vodafone' or 'instapay'
  String? _selectedReceiptFileName;
  final _instaPayIdController = TextEditingController();

  // InstaPay QR code (base64 encoded PNG)
  static const String _instaPayQrBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAMgAAADICAYAAACtWK6uAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH5QYVBiw9+HX3HgAAAAd0SU1FB+UGFQYsPfh1+x4AAAAZdEVYdENvbW1lbnQABGludGVybmFsIENvcHlyaWdodC5QSwcIAAAAAAAAAABQSwMEFAAICAgA+XV6VgAAAAAAAAAAAAAAAAMAAAAaW50ZXJuYWwgc3JjL21haW4ucHkAdGVzdC5weS5iYWNrZW5kLnJvdXRlcjphcGkuZ2V0KCcvJylQYWNrYWdlcyB0ZXN0LnB5LmJhY2tlbmQucm91dGVyOmFwaS5nZXQoJy8nKXJlc3BvbnNlID0geydzdGF0dXMnOiAnb2snLCAnbWVzc2FnZSc6ICdEYXJzYWtBSSBCYWNrZW5kIHJ1bm5pbmcnfW1haW4ucHkuYmFja2VuZC5yb3V0ZXJzOmFwaS5nZXQoJy8nKVJlc3BvbnNlID0geydzdGF0dXMnOiAnb2snLCAnbWVzc2FnZSc6ICdEYXJzYWtBSSBCYWNrZW5kIHJ1bm5pbmcnfXN0YXR1cyA9IHJlc3BvbnNlLnN0YXR1c19jb2RlXG5hc3NlcnQgc3RhdHVzID09IDIwMFxucHJpbnQoJ0JhY2tlbmQgcGluZyBPSyBzdGF0dXM9Jywg';

  static const String _supportWhatsApp = '01031524947';
  static const String _vodafoneCashNumber = '01031524947';

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh counter every minute so remaining days update in real time
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _subscription != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _codeController.dispose();
    _senderPhoneController.dispose();
    _instaPayIdController.dispose();
    super.dispose();
  }

  void _loadData() async {
    final api = context.read<DataProvider>().api;
    final cached = await _subscriptionService.getCachedSubscription();
    if (mounted) {
      setState(() {
        _subscription = cached;
        _isLoading = false;
      });
    }
    try {
      final sub = await api.getMySubscription().timeout(const Duration(seconds: 25));
      if (sub != null) await _subscriptionService.cacheSubscription(sub);
      final plans = await api.getPlans().timeout(const Duration(seconds: 25));
      if (!mounted) return;
      setState(() {
        _subscription = sub ?? cached;
        _plans = plans;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _activateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showSnackbar('يرجى إدخال كود التفعيل', isError: true);
      return;
    }
    setState(() => _activating = true);
    try {
      final api = context.read<DataProvider>().api;
      await api.activateCode(code).timeout(const Duration(seconds: 25));
      _codeController.clear();
      _loadData();
      if (!mounted) return;
      _showSnackbar('تم تفعيل الاشتراك بنجاح');
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('كود التفعيل غير صحيح', isError: true);
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showPaymentDialog(String planId, String planName, String price) {
    setState(() {
      _selectedPlanId = planId;
      _selectedPlanName = planName;
      _selectedPlanPrice = price;
      _paymentMethod = 'vodafone';
      _senderPhoneController.clear();
    });
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('اشتراك $planName', style: const TextStyle(color: AppTheme.darkTextPrimary)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
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
                          style: TextStyle(color: AppTheme.darkTextMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Payment method selector
                  const Text('اختر طريقة الدفع', style: TextStyle(color: AppTheme.darkTextPrimary, fontWeight: FontWeight.bold)),
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

                  // Payment content
                  if (_paymentMethod == 'vodafone') ...[
                    const Text('رقم فودافون كاش', style: TextStyle(color: AppTheme.darkTextSecondary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.copy, size: 18, color: AppTheme.accent),
                          const SizedBox(width: 8),
                          SelectableText(
                            _vodafoneCashNumber,
                            style: const TextStyle(
                              color: AppTheme.darkTextPrimary,
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
                    const Text('صورة التحويل', style: TextStyle(color: AppTheme.darkTextSecondary)),
                    const SizedBox(height: 8),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () async {
                          final result = await FilePicker.pickFiles(
                            type: FileType.image,
                            allowMultiple: false,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            setDialogState(() {
                              _selectedReceiptFileName = result.files.first.name;
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedReceiptFileName != null 
                                  ? AppTheme.success.withOpacity(0.5) 
                                  : AppTheme.darkBorder,
                              width: _selectedReceiptFileName != null ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _selectedReceiptFileName != null ? Icons.check_circle : Icons.upload_file,
                                  size: 40,
                                  color: _selectedReceiptFileName != null 
                                      ? AppTheme.success 
                                      : AppTheme.darkTextMuted.withOpacity(0.5),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedReceiptFileName ?? 'اضغط لرفع صورة التحويل',
                                  style: TextStyle(
                                    color: _selectedReceiptFileName != null 
                                        ? AppTheme.success 
                                        : AppTheme.darkTextMuted,
                                    fontSize: 13,
                                    fontWeight: _selectedReceiptFileName != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // InstaPay QR
                    const Text('امسح QR Code بالكاميرا', style: TextStyle(color: AppTheme.darkTextSecondary)),
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
                            const QrCodeWidget(
                              data: 'ahmed-mahmoud-1@instapay',
                              size: 180,
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
                            const Text(
                              'ahmed-mahmoud-1@instapay',
                              style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
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
                    const Text('صورة التحويل', style: TextStyle(color: AppTheme.darkTextSecondary)),
                    const SizedBox(height: 8),
                    _buildReceiptUpload(setDialogState),
                  ],

                  const SizedBox(height: 16),
                  // Support
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
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
                  _showSnackbar('يرجى إدخال رقم المحول', isError: true);
                  return;
                }
                if (_paymentMethod == 'instapay' && _instaPayIdController.text.trim().isEmpty) {
                  _showSnackbar('يرجى إدخال معرف إنستا باي', isError: true);
                  return;
                }
                if (_selectedReceiptFileName == null) {
                  _showSnackbar('يرجى رفع صورة التحويل', isError: true);
                  return;
                }
                Navigator.pop(ctx);
                _showAdminActivationDialog();
              },
              child: const Text('إرسال للتفعيل'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminActivationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('تفعيل الاشتراك', style: TextStyle(color: AppTheme.darkTextPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الباقة: $_selectedPlanName', style: const TextStyle(color: AppTheme.darkTextSecondary)),
            Text('السعر: $_selectedPlanPrice ج.م', style: const TextStyle(color: AppTheme.darkTextSecondary)),
            Text('الطريقة: ${_paymentMethod == 'vodafone' ? 'فودافون كاش' : 'إنستا باي'}', style: const TextStyle(color: AppTheme.darkTextSecondary)),
            if (_paymentMethod == 'vodafone')
              Text('من رقم: ${_senderPhoneController.text}', style: const TextStyle(color: AppTheme.darkTextSecondary))
            else
              Text('من معرف: ${_instaPayIdController.text}', style: const TextStyle(color: AppTheme.darkTextSecondary)),
            Text('صورة التحويل: ${_selectedReceiptFileName ?? '---'}', style: const TextStyle(color: AppTheme.darkTextSecondary)),
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
              await TelegramService.sendPaymentNotification(
                planName: _selectedPlanName ?? '---',
                planPrice: _selectedPlanPrice ?? '---',
                paymentMethod: _paymentMethod == 'vodafone' ? 'فودافون كاش' : 'إنستا باي',
                senderInfo: senderInfo,
                receiptFileName: _selectedReceiptFileName,
              );
              if (!mounted) return;
              Navigator.pop(ctx);
              _showSnackbar('تم إرسال طلب التفعيل');
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptUpload(void Function(void Function()) setDialogState) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final result = await FilePicker.pickFiles(
            type: FileType.image,
            allowMultiple: false,
          );
          if (result != null && result.files.isNotEmpty) {
            setDialogState(() {
              _selectedReceiptFileName = result.files.first.name;
            });
          }
        },
        child: Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.darkSurface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedReceiptFileName != null 
                  ? AppTheme.success.withOpacity(0.5) 
                  : AppTheme.darkBorder,
              width: _selectedReceiptFileName != null ? 2 : 1,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _selectedReceiptFileName != null ? Icons.check_circle : Icons.upload_file,
                  size: 40,
                  color: _selectedReceiptFileName != null 
                      ? AppTheme.success 
                      : AppTheme.darkTextMuted.withOpacity(0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedReceiptFileName ?? 'اضغط لرفع صورة التحويل',
                  style: TextStyle(
                    color: _selectedReceiptFileName != null 
                        ? AppTheme.success 
                        : AppTheme.darkTextMuted,
                    fontSize: 13,
                    fontWeight: _selectedReceiptFileName != null ? FontWeight.w600 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الاشتراكات', style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            if (_subscription != null) ...[
              _buildSubscriptionCard(
                isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary,
                textMuted: textMuted, surfaceColor: surfaceColor, borderColor: borderColor,
              ),
              const SizedBox(height: 20),
            ],

            _buildActivateSection(
              isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary,
              textMuted: textMuted, surfaceColor: surfaceColor, borderColor: borderColor,
            ),
            const SizedBox(height: 20),

            _buildPlansSection(
              isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary,
              textMuted: textMuted, surfaceColor: surfaceColor, borderColor: borderColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard({
    required bool isDark, required Color textPrimary, required Color textSecondary,
    required Color textMuted, required Color surfaceColor, required Color borderColor,
  }) {
    final isActive = _subscriptionService.isSubscriptionActive(_subscription);
    final remainingDays = _subscriptionService.getRemainingDays(_subscription);
    final planName = _subscription?['plan_name']?.toString() ?? 'الباقة الحالية';
    final expiryDate = _subscription?['expires_at']?.toString() ?? '--';

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppTheme.success.withOpacity(0.3) : AppTheme.danger.withOpacity(0.3),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.card_membership, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(planName, style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.success.withOpacity(0.15) : AppTheme.danger.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isActive ? 'نشط' : 'منتهي',
                          style: TextStyle(color: isActive ? AppTheme.success : AppTheme.danger, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoRow('تاريخ الانتهاء', expiryDate, textMuted, textPrimary),
            const SizedBox(height: 12),
            _buildInfoRow('الأيام المتبقية', '$remainingDays يوم', textMuted, isActive ? AppTheme.success : AppTheme.danger, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color labelColor, Color valueColor, {bool isBold = false}) {
    return Row(
      children: [
        SizedBox(width: 140, child: Text(label, style: TextStyle(color: labelColor, fontSize: 14))),
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal)),
      ],
    );
  }

  Widget _buildActivateSection({
    required bool isDark, required Color textPrimary, required Color textSecondary,
    required Color textMuted, required Color surfaceColor, required Color borderColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.vpn_key, size: 20, color: AppTheme.accent),
                const SizedBox(width: 10),
                Text('تفعيل كود', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'كود التفعيل',
                      hintText: 'XXXX-XXXX-XXXX-XXXX',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, letterSpacing: 2),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _activating ? null : _activateCode,
                    child: _activating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('تفعيل', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlansSection({
    required bool isDark, required Color textPrimary, required Color textSecondary,
    required Color textMuted, required Color surfaceColor, required Color borderColor,
  }) {
    // Use default plans if API plans are empty or incomplete
    final plansToShow = _plans.isNotEmpty && _plans.every((p) => p['price'] != null && p['price'].toString().isNotEmpty) 
        ? _plans 
        : _defaultPlans;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الباقات المتاحة', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (plansToShow.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('لا توجد باقات متاحة', style: TextStyle(color: textMuted))))
        else
          ...plansToShow.map((plan) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildPlanCard(plan: plan, textPrimary: textPrimary, textSecondary: textSecondary,
                    textMuted: textMuted, surfaceColor: surfaceColor, borderColor: borderColor),
              )),
      ],
    );
  }

  Widget _buildPlanCard({
    required dynamic plan, required Color textPrimary, required Color textSecondary,
    required Color textMuted, required Color surfaceColor, required Color borderColor,
  }) {
    final name = plan['name']?.toString() ?? 'باقة';
    final price = plan['price']?.toString() ?? '--';
    final features = plan['features'] ?? [];
    final isPopular = plan['popular'] == true;
    final studentLimit = plan['student_limit']?.toString() ?? '--';
    final duration = plan['duration']?.toString() ?? '--';

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isPopular ? AppTheme.accent.withOpacity(0.5) : Colors.transparent),
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      if (isPopular)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                          child: const Text('الأكثر طلباً', style: TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('$price ج.م / $duration', style: TextStyle(color: AppTheme.accent, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (features is List)
                    ...features.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                            const SizedBox(width: 8),
                            Text(f.toString(), style: TextStyle(color: textSecondary, fontSize: 13)),
                          ]),
                        )),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Container(
              width: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text('الحد الأقصى', style: TextStyle(color: textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('$studentLimit طالب', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('المدة', style: TextStyle(color: textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(duration, style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showPaymentDialog(name, name, price),
                      child: const Text('اشتراك'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _defaultPlans {
    return [
      {
        'name': 'Basic',
        'price': '200',
        'duration': 'شهر',
        'student_limit': '50',
        'popular': false,
        'features': ['إدارة الطلاب', 'تسجيل الحضور', 'المجموعات', 'تقارير أساسية'],
      },
      {
        'name': 'Pro',
        'price': '600',
        'duration': 'شهر',
        'student_limit': '150',
        'popular': true,
        'features': ['كل مزايا Basic', 'تحليل الأداء', 'الفواتير', 'QR Code', 'تقارير متقدمة'],
      },
      {
        'name': 'Enterprise',
        'price': '1100',
        'duration': 'شهر',
        'student_limit': '300',
        'popular': false,
        'features': ['كل المزايا', '300 طالب', 'دعم فني مميز', 'تصدير البيانات', 'امتيازات حصرية'],
      },
    ];
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.title, required this.icon, required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent.withOpacity(0.15) : AppTheme.darkSurface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.accent : AppTheme.darkBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: isSelected ? AppTheme.accent : AppTheme.darkTextMuted),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppTheme.accent : AppTheme.darkTextMuted,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}