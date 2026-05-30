import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/subscription_service.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _codeController = TextEditingController();
  final _subService = SubscriptionService();
  bool _activating = false;
  bool _refreshing = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _activateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _activating = true);
    try {
      await _subService.activateCode(code);
      if (!mounted) return;
      await context.read<AuthProvider>().refreshSubscription();
      if (!mounted) return;
      if (context.read<AuthProvider>().isSubscriptionActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تفعيل الاشتراك بنجاح'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رمز التفعيل غير صالح أو منتهي الصلاحية'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().contains('404') ? 'رمز التفعيل غير صالح' : 'فشل تفعيل الاشتراك'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await context.read<AuthProvider>().refreshSubscription();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final subData = auth.subscriptionData;
    final isActive = auth.isSubscriptionActive;
    final remainingDays = subData != null ? _parseRemainingDays(subData) : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الاشتراك'),
        leading: isActive
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (subData != null) _buildCurrentPlan(subData, remainingDays),
            if (subData != null) const SizedBox(height: 24),
            if (!isActive) ...[
              _buildActivationSection(),
              const SizedBox(height: 24),
              _buildPlansSection(),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _refreshing ? null : _refresh,
                icon: _refreshing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('التحقق من حالة الاشتراك'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  side: const BorderSide(color: AppTheme.accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlan(Map<String, dynamic> subData, int remainingDays) {
    final planName = _getPlanName(subData);
    final status = subData['status'] as String? ?? 'غير معروف';
    final isActive = status == 'active';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF141414)])
            : const LinearGradient(colors: [Color(0xFF3D1A1A), Color(0xFF141414)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? AppTheme.accent.withValues(alpha: 0.3) : AppTheme.danger.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.danger.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.verified : Icons.error_outline,
              color: isActive ? AppTheme.success : AppTheme.danger,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            planName,
            style: const TextStyle(
              color: Color(0xFFF5F5F5),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.success.withValues(alpha: 0.1)
                  : AppTheme.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isActive ? 'نشط' : 'منتهي',
              style: TextStyle(
                color: isActive ? AppTheme.success : AppTheme.danger,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isActive && remainingDays >= 0) ...[
            const SizedBox(height: 12),
            Text(
              '$remainingDays يوم متبقي',
              style: TextStyle(
                color: remainingDays < 7 ? AppTheme.warning : Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _getExpiryText(subData),
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActivationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key, color: AppTheme.accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'تفعيل باشتراك',
                style: TextStyle(color: Color(0xFFF5F5F5), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'أدخل رمز التفعيل المكون من 16 رقم (XXXX-XXXX-XXXX-XXXX)',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF5F5F5),
              fontSize: 18,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              hintText: 'XXXX-XXXX-XXXX-XXXX',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: const Color(0xFF0A0A0A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accent),
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _activateCode(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _activating ? null : _activateCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _activating
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('تفعيل', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الباقات المتاحة',
          style: TextStyle(color: Color(0xFFF5F5F5), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildPlanCard(
          name: 'الباقة الأساسية',
          price: '199 ج.م/شهر',
          students: '50 طالب',
          features: ['حتى 50 طالب', '100 طلب ذكاء اصطناعي/شهر', 'إدارة الدرجات والحضور', 'الفواتير', 'QR Code المعلم'],
          isPopular: false,
          color: 0xFF00f3ff,
          onSubscribe: () => _showPaymentDialog('الباقة الأساسية', 199, '3628fdf5-3a79-43c3-8c04-211f31704e07'),
        ),
        const SizedBox(height: 12),
        _buildPlanCard(
          name: 'الباقة المتقدمة',
          price: '499 ج.م/شهر',
          students: '500 طالب',
          features: ['حتى 500 طالب', '500 طلب ذكاء اصطناعي/شهر', 'إدارة الدرجات والحضور', 'الفواتير المتقدمة', 'تصدير التقارير', 'دعم فني متميز'],
          isPopular: true,
          color: 0xFFccff00,
          onSubscribe: () => _showPaymentDialog('الباقة المتقدمة', 499, '56b99f07-ea35-46ae-9af6-16b17078c9a7'),
        ),
        const SizedBox(height: 12),
        _buildPlanCard(
          name: 'الباقة الغير محدودة',
          price: '999 ج.م/شهر',
          students: 'غير محدود',
          features: ['طلاب غير محدود', '2000 طلب ذكاء اصطناعي/شهر', 'جميع المميزات', 'دعم فني متميز', 'أولوية في التحديثات'],
          isPopular: false,
          color: 0xFFff003c,
          onSubscribe: () => _showPaymentDialog('الباقة الغير محدودة', 999, '7bc43f3e-d511-4981-ad71-b3c00b637af4'),
        ),
        const SizedBox(height: 16),
        _buildPaymentInfo(),
      ],
    );
  }

  void _showPaymentDialog(String planName, int amount, String planId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('اختر طريقة الدفع',
                  style: TextStyle(color: Color(0xFFF5F5F5), fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('$planName - $amount ج.م',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openWhatsApp(planName);
                    },
                    icon: const Icon(Icons.message, color: Colors.white),
                    label: const Text('دعم عبر واتساب', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showVodafoneDialog(planName, amount, planId);
                    },
                    icon: const Icon(Icons.phone_android, color: Colors.white),
                    label: const Text('دفع عبر فودافون كاش', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openWhatsApp(String planName) {
    final msg = Uri.encodeComponent('أريد الاشتراك في $planName');
    launchUrl(Uri.parse('https://wa.me/201031524947?text=$msg'), mode: LaunchMode.externalApplication);
  }

  void _showVodafoneDialog(String planName, int amount, String planId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String phoneNumber = '';
        String? screenshotB64;
        bool sending = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => Padding(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('دفع عبر فودافون كاش',
                  style: TextStyle(color: Color(0xFFF5F5F5), fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('حول إلى رقم فودافون كاش',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      const Text('201031524947',
                        style: TextStyle(color: AppTheme.accent, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'رقم هاتفك المحول منه',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    hintText: '10XXXXXXXX',
                    prefixText: '+20 ',
                    prefixStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF0A0A0A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  onChanged: (v) => setDialogState(() => phoneNumber = v.replaceAll(RegExp(r'[^0-9]'), '')),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text('المبلغ: ', style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(width: 8),
                      Text('$amount ج.م',
                        style: const TextStyle(color: Color(0xFFF5F5F5), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await _pickImage();
                      if (result != null) {
                        setDialogState(() => screenshotB64 = result);
                      }
                    },
                    icon: Icon(screenshotB64 != null ? Icons.check_circle : Icons.camera_alt, color: screenshotB64 != null ? AppTheme.success : Colors.grey),
                    label: Text(screenshotB64 != null ? 'تم اختيار الصورة' : 'إرفاق صورة الإيصال',
                      style: TextStyle(color: screenshotB64 != null ? AppTheme.success : Colors.grey),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: screenshotB64 != null ? AppTheme.success : Colors.grey[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: phoneNumber.length >= 10 && !sending
                        ? () async {
                            setDialogState(() => sending = true);
                            try {
                              await _subService.sendPaymentRequest(planId, phoneNumber, amount, screenshotB64);
                              Navigator.pop(ctx);
                              _showSuccess('تم إرسال طلب الاشتراك',
                                'سيتم مراجعة طلبك من الإدارة والرد عليك في أقرب وقت.');
                            } catch (e) {
                              setDialogState(() => sending = false);
                              _showError('فشل الإرسال', e.toString());
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: sending
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('إرسال طلب الاشتراك', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  void _showSuccess(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.check_circle, color: AppTheme.success),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Color(0xFFF5F5F5))),
        ]),
        content: Text(message, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
        ],
      ),
    );
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.error, color: AppTheme.danger),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Color(0xFFF5F5F5))),
        ]),
        content: Text(message, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.accentLight, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'يمكنك الاشتراك أيضاً عبر الموقع: darsakai.com',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String name,
    required String price,
    required String students,
    required List<String> features,
    required bool isPopular,
    required int color,
    required VoidCallback onSubscribe,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isPopular
            ? const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF141414)])
            : const LinearGradient(colors: [Color(0xFF1E1E1E), Color(0xFF141414)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? AppTheme.accent.withValues(alpha: 0.5) : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(color: Color(0xFFF5F5F5), fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'الأكثر طلباً',
                    style: TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(price, style: const TextStyle(color: Color(0xFF00f3ff), fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(students, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 12),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                    const SizedBox(width: 8),
                    Text(f, style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(color),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('اشتراك الآن', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  String _getPlanName(Map<String, dynamic> subData) {
    if (subData['plan'] is Map) {
      return (subData['plan'] as Map)['name'] as String? ?? 'الباقة الحالية';
    }
    return subData['plan_name'] as String? ?? 'الباقة الحالية';
  }

  int _parseRemainingDays(Map<String, dynamic> subData) {
    final expiresAt = subData['expires_at'] as String?;
    if (expiresAt == null) return 0;
    final expiry = DateTime.tryParse(expiresAt);
    if (expiry == null) return 0;
    return expiry.difference(DateTime.now()).inDays;
  }

  String _getExpiryText(Map<String, dynamic> subData) {
    final expiresAt = subData['expires_at'] as String?;
    if (expiresAt == null) return '';
    final expiry = DateTime.tryParse(expiresAt);
    if (expiry == null) return '';
    return 'تاريخ الانتهاء: ${expiry.day}/${expiry.month}/${expiry.year}';
  }
}
