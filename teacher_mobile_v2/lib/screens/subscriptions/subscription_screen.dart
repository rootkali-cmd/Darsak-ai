import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';
import '../../core/error_utils.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _userData;
  List<dynamic> _plans = [];
  List<dynamic> _notifications = [];
  bool _loading = true;
  String? _error;

  final _codeCtrl = TextEditingController();
  bool _activating = false;

  static const _vodafoneNumber = '01031524947';
  static const _whatsappNumber = '201031524947';

  static const _defaultPlans = [
    {
      'id': '3628fdf5-3a79-43c3-8c04-211f31704e07',
      'name': 'الباقة الأساسية',
      'price_egp': 199,
      'max_students': 100,
      'color': '#6366F1',
      'features': [
        'حتى 100 طالب',
        '5 طلبات ذكاء اصطناعي/شهر',
        'إدارة الدرجات والحضور',
        'الفواتير الأساسية',
        'QR Code المعلم',
        'تخزين فيديو 2GB',
      ],
    },
    {
      'id': '56b99f07-ea35-46ae-9af6-16b17078c9a7',
      'name': 'الباقة المتقدمة',
      'price_egp': 499,
      'max_students': 400,
      'popular': true,
      'color': '#8B5CF6',
      'features': [
        'حتى 400 طالب',
        '30 طلب ذكاء اصطناعي/شهر',
        'إدارة الدرجات والحضور',
        'الفواتير المتقدمة',
        'QR Code المعلم',
        'تصدير التقارير',
        'دعم فني متميز',
        'تخزين فيديو 6GB',
      ],
    },
    {
      'id': '7bc43f3e-d511-4981-ad71-b3c00b637af4',
      'name': 'الباقة المتكاملة',
      'price_egp': 999,
      'max_students': 0,
      'color': '#10B981',
      'features': [
        'طلاب غير محدود',
        'ذكاء اصطناعي غير محدود',
        'جميع المميزات',
        'دعم فني 24/7',
        'تخصيص كامل',
        'تخزين فيديو غير محدود',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService();

      final meResp = await api.dio.get('/auth/me');
      final me = meResp.data is Map ? meResp.data as Map<String, dynamic> : <String, dynamic>{};
      _subscription = me['subscription'] is Map ? Map<String, dynamic>.from(me['subscription']) : null;
      _userData = me;

      final plansResp = await api.dio.get('/subscriptions/plans');
      _plans = plansResp.data is List ? plansResp.data : [];

      try {
        final notifResp = await api.dio.get('/subscriptions/notifications');
        _notifications = notifResp.data is List ? notifResp.data : [];
      } catch (_) {
        _notifications = [];
      }
    } on DioException catch (e) {
      _error = 'فشل التحميل: ${getDioErrorMessage(e)}';
    } catch (e) {
      _error = 'خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  bool get _isActive {
    return _subscription?['is_active'] == true && _subscription?['is_expired'] != true;
  }

  int get _daysLeft => _subscription?['days_remaining'] ?? 0;

  bool get _isTrial => _subscription?['is_trial'] == true;

  bool _isTrialEligible(Map<String, dynamic> plan) {
    if (_subscription != null) return false;
    final name = (plan['name'] ?? '').toString().toLowerCase();
    return name.contains('أساسي') || name.contains('basic');
  }

  String _formatDate(String? d) {
    if (d == null || d.isEmpty) return '—';
    try {
      final dt = DateTime.parse(d);
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return d.substring(0, d.length > 10 ? 10 : d.length);
    }
  }

  // ─── Activation ──────────────────────────────────────────────

  Future<void> _activateCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      _showMsg('أدخل كود التفعيل', AppTheme.warning);
      return;
    }
    setState(() => _activating = true);
    try {
      await ApiService().dio.post('/subscriptions/activate', data: {'code': code});
      _showMsg('تم تفعيل الاشتراك بنجاح', AppTheme.success);
      _codeCtrl.clear();
      _loadData();
    } catch (e) {
      _showMsg('فشل التفعيل: كود غير صالح', AppTheme.danger);
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  // ─── Trial ───────────────────────────────────────────────────

  Future<void> _activateTrial() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiService().dio.post('/subscriptions/activate-trial');
      final data = resp.data is Map ? resp.data as Map<String, dynamic> : <String, dynamic>{};
      final daysRemaining = data['days_remaining'] ?? 30;
      _showMsg('تم تفعيل الفترة التجريبية! متبقي $daysRemaining يوم', AppTheme.success);
      await _loadData();
    } catch (e) {
      _showMsg('فشل تفعيل الفترة التجريبية', AppTheme.danger);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showTrialDialog(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.local_offer_rounded, color: AppTheme.warning, size: 24),
          SizedBox(width: 8),
          Text('تفعيل مجاني', style: TextStyle(fontSize: 18)),
        ]),
        content: const Text(
          'ستحصل على 30 يوم مجاناً. بعد انتهاء الفترة سيتم تحصيل 199 ج.م شهرياً. يمكنك الترقية أو الإلغاء في أي وقت.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _activateTrial();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning, foregroundColor: Colors.white),
            child: const Text('تفعيل'),
          ),
        ],
      ),
    );
  }

  // ─── Payment ─────────────────────────────────────────────────

  void _showPaymentMethodDialog(Map<String, dynamic> plan) {
    final planName = plan['name'] ?? '';
    final planPrice = plan['price_egp'] ?? plan['price'] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('اختر طريقة الدفع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$planName - $planPrice ج.م/شهر', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openWhatsAppWithPlan(planName);
                },
                icon: const Icon(Icons.chat, color: AppTheme.success),
                label: const Text('دعم عبر واتساب', textAlign: TextAlign.left),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showDirectPaymentDialog(plan);
                },
                icon: const Icon(Icons.phone_android, color: AppTheme.accent),
                label: const Text('دفع مباشر (فودافون كاش)', textAlign: TextAlign.left),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDirectPaymentDialog(Map<String, dynamic> plan) {
    final planName = plan['name'] ?? '';
    final planPrice = plan['price_egp'] ?? plan['price'] ?? 0;
    final phoneCtrl = TextEditingController(text: '01000000000');
    File? screenshot;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('دفع عبر فودافون كاش', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Column(children: [
                    const Text('حول إلى رقم فودافون كاش', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: _vodafoneNumber));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم النسخ'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: Text(_vodafoneNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppTheme.primary)),
                    ),
                  ]),
                ),
                const SizedBox(height: 4),
                Text('الباقة: $planName', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text('المبلغ: $planPrice ج.م', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.accent)),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'رقم هاتفك المحول منه', prefixIcon: Icon(Icons.phone, size: 20)),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                const Text('صورة الإيصال', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                    if (file != null) {
                      setDialogState(() => screenshot = File(file.path));
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 100,
                    decoration: BoxDecoration(
                      color: screenshot != null ? AppTheme.success.withValues(alpha: 0.05) : AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: screenshot != null ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.border,
                      ),
                    ),
                    child: screenshot != null
                        ? Stack(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(screenshot!, width: double.infinity, height: 100, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () => setDialogState(() => screenshot = null),
                                child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                              ),
                            ),
                          ])
                        : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.camera_alt, size: 32, color: AppTheme.textMuted),
                            SizedBox(height: 4),
                            Text('اضغط لرفع صورة الإيReceipt', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                          ]),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: AppTheme.danger))),
            ElevatedButton(
              onPressed: () async {
                if (phoneCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل رقم الهاتف')));
                  return;
                }
                if (screenshot == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أرفق صورة الإيصال')));
                  return;
                }
                Navigator.pop(ctx);
                _submitPayment(phoneCtrl.text.trim(), planPrice.toString(), screenshot!);
              },
              child: const Text('إرسال الطلب'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPayment(String phone, String amount, File screenshotFile) async {
    try {
      final formData = FormData.fromMap({
        'phone_number': phone,
        'amount': amount,
        'screenshot': await MultipartFile.fromFile(screenshotFile.path, filename: 'screenshot.${screenshotFile.path.split(".").last}'),
      });
      await ApiService().dio.post('/subscriptions/payment-request', data: formData);
      _showPaymentSuccessDialog();
    } catch (e) {
      _showMsg('فشل الإرسال: $e', AppTheme.danger);
    }
  }

  void _showPaymentSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)), color: AppTheme.success.withValues(alpha: 0.05)),
              child: const Icon(Icons.check_circle, color: AppTheme.success, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('تم الإرسال بنجاح!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('سيتم التحقق من الدفع خلال 10 دقائق', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            const Text('وبحد أقصى ساعتين', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            const Text('لو فيه مشكلة أو تأخير تواصل معانا عبر الواتساب', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _openWhatsApp();
              },
              icon: const Icon(Icons.chat),
              label: const Text('واتساب الدعم'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─── WhatsApp ────────────────────────────────────────────────

  Future<void> _openWhatsApp() async {
    final url = Uri.parse('https://wa.me/$_whatsappNumber?text=${Uri.encodeComponent('مرحباً، أحتاج مساعدة بخصوص الاشتراك في تطبيق درسك AI')}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب'), backgroundColor: AppTheme.danger));
    }
  }

  Future<void> _openWhatsAppWithPlan(String planName) async {
    final msg = Uri.encodeComponent('أريد الاشتراك في $planName');
    final url = Uri.parse('https://wa.me/$_whatsappNumber?text=$msg');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب'), backgroundColor: AppTheme.danger));
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم النسخ'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
  }

  void _showMsg(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  List<Map<String, dynamic>> get _plansToShow {
    if (_plans.isNotEmpty && _plans.every((p) => p['price_egp'] != null || p['price'] != null)) {
      return _plans.map<Map<String, dynamic>>((p) => Map<String, dynamic>.from(p)).toList();
    }
    return _defaultPlans;
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الاشتراكات', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildNotificationsSection(),
                      _buildCurrentSubscriptionCard(),
                      const SizedBox(height: 16),
                      _buildAccountIdSection(),
                      const SizedBox(height: 16),
                      _buildActivateCodeSection(),
                      const SizedBox(height: 24),
                      const Text('الباقات المتاحة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('اختر الباقة المناسبة لك', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(height: 12),
                      ..._plansToShow.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildPlanCard(e.value, e.key),
                          )),
                      const SizedBox(height: 16),
                      _buildPaymentInfoSection(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  // ─── Notifications ───────────────────────────────────────────

  Widget _buildNotificationsSection() {
    if (_notifications.isEmpty) return const SizedBox.shrink();
    return Column(
      children: _notifications.map((n) {
        final isSuccess = n['type'] == 'success';
        final isError = n['type'] == 'error';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (isSuccess ? AppTheme.success : isError ? AppTheme.danger : AppTheme.accent).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (isSuccess ? AppTheme.success : isError ? AppTheme.danger : AppTheme.accent).withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Icon(
              isSuccess ? Icons.check_circle : isError ? Icons.error : Icons.info,
              size: 20,
              color: isSuccess ? AppTheme.success : isError ? AppTheme.danger : AppTheme.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (n['title'] != null) Text(n['title'].toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                if (n['body'] != null) Text(n['body'].toString(), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
            ),
          ]),
        );
      }).toList(),
    );
  }

  // ─── Current Subscription Card ───────────────────────────────

  Widget _buildCurrentSubscriptionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _subscription != null
              ? (_isActive ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.danger.withValues(alpha: 0.3))
              : AppTheme.border.withValues(alpha: 0.15),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.8)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.card_membership, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('الاشتراك الحالي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          if (_subscription != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (_isActive ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_isActive ? Icons.check_circle : Icons.cancel, size: 14, color: _isActive ? AppTheme.success : AppTheme.danger),
                const SizedBox(width: 4),
                Text(
                  _isActive ? 'نشط' : 'منتهي',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isActive ? AppTheme.success : AppTheme.danger),
                ),
              ]),
            ),
        ]),
        const SizedBox(height: 16),
        if (_subscription != null) ...[
          _InfoTile(label: 'الباقة', value: _subscription!['plan_name']?.toString() ?? '—'),
          if (_isTrial)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: const Text('نسخة تجريبية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.warning)),
            ),
          _InfoTile(label: 'تاريخ البدء', value: _formatDate(_subscription!['activated_at']?.toString())),
          _InfoTile(label: 'تاريخ الانتهاء', value: _formatDate(_subscription!['expires_at']?.toString())),
          if (_daysLeft > 0)
            _InfoTile(label: 'الأيام المتبقية', value: '$_daysLeft يوم', valueColor: _daysLeft < 3 ? AppTheme.danger : AppTheme.success),
          _InfoTile(
            label: 'الطلاب',
            value: _subscription!['max_students'] == -1 || _subscription!['max_students'] == 0
                ? 'غير محدود'
                : '${_subscription!['max_students'] ?? '—'}',
          ),
          if (_daysLeft > 0) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('الأيام المتبقية', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text('$_daysLeft يوم', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _daysLeft / 30,
                minHeight: 6,
                backgroundColor: AppTheme.border.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation(_daysLeft < 7 ? AppTheme.danger : AppTheme.accent),
              ),
            ),
          ],
        ] else ...[
          const SizedBox(height: 8),
          const Text('لا يوجد اشتراك نشط. اختر باقة للاشتراك أو استخدم كود تفعيل.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ]),
    );
  }

  // ─── Account ID ──────────────────────────────────────────────

  Widget _buildAccountIdSection() {
    final userId = _userData?['id']?.toString();
    if (userId == null || userId.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.fingerprint, size: 20, color: AppTheme.accent.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          const Text('معرف الحساب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        const Text('استخدم هذا المعرف عند التواصل مع الدعم الفني', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border.withValues(alpha: 0.15)),
              ),
              child: Text(userId, style: const TextStyle(fontSize: 13, fontFamily: 'monospace', letterSpacing: 1), textDirection: TextDirection.ltr),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _copyToClipboard(userId),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.copy, size: 18, color: AppTheme.textSecondary),
            ),
          ),
        ]),
      ]),
    );
  }

  // ─── Activate Code ───────────────────────────────────────────

  Widget _buildActivateCodeSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.vpn_key, size: 20, color: AppTheme.accent.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          const Text('تفعيل كود اشتراك', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _codeCtrl,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 16, letterSpacing: 2, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: 'XXXX-XXXX-XXXX-XXXX',
                hintStyle: TextStyle(letterSpacing: 2),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _activating ? null : _activateCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _activating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('تفعيل', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ]),
    );
  }

  // ─── Plan Card ───────────────────────────────────────────────

  Widget _buildPlanCard(Map<String, dynamic> plan, int index) {
    final name = plan['name'] ?? '';
    final price = plan['price_egp'] ?? plan['price'] ?? 0;
    final features = plan['features'] is List ? plan['features'] as List : <dynamic>[];
    final maxStudents = plan['max_students'];
    final isPopular = plan['popular'] == true;
    final trialEligible = _isTrialEligible(plan);

    final planColors = [
      [const Color(0xFF06B6D4), const Color(0xFF22D3EE)],
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      [const Color(0xFFF43F5E), const Color(0xFFFB7185)],
    ];
    final gradientColors = planColors[index.clamp(0, 2)];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? AppTheme.accent.withValues(alpha: 0.4) : AppTheme.border.withValues(alpha: 0.15),
          width: isPopular ? 1.5 : 1,
        ),
        boxShadow: isPopular ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.08), blurRadius: 20, spreadRadius: 0)] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isPopular)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: const Text('الأكثر طلباً', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (trialEligible)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.warning, AppTheme.warning.withValues(alpha: 0.8)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.local_offer_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('30 يوم مجاناً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
              ),
            Text(name.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$price', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              const Padding(padding: EdgeInsets.only(bottom: 3), child: Text('ج.م/شهر', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
            ]),
            if (maxStudents != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.people, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  maxStudents == 0 || maxStudents == -1 ? 'طلاب غير محدود' : 'حتى $maxStudents طالب',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(Icons.check, size: 16, color: gradientColors[0]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f.toString(), style: const TextStyle(fontSize: 13))),
                  ]),
                )),
            const SizedBox(height: 16),
            if (trialEligible)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showTrialDialog(plan),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: const Text('تفعيل مجاني', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                    borderRadius: BorderRadius.circular(12),
                  ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showPaymentMethodDialog(plan),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.credit_card, size: 18, color: Colors.white),
                            SizedBox(width: 6),
                            Text('اشتراك الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ]),
                        ),
                      ),
                    ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  // ─── Payment Info ────────────────────────────────────────────

  Widget _buildPaymentInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline, size: 20, color: AppTheme.accent),
          const SizedBox(width: 8),
          const Text('طرق الدفع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        const Text('فودافون كاش', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _copyToClipboard(_vodafoneNumber),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.copy, size: 18, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text(_vodafoneNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppTheme.primary)),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        const Text('للمساعدة والتواصل', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openWhatsApp,
            icon: const Icon(Icons.support_agent, size: 20),
            label: const Text('الدعم الفني عبر الواتساب'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.success,
              side: const BorderSide(color: AppTheme.success),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
      ]),
    );
  }
}
