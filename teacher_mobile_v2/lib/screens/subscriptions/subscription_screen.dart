import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../core/error_utils.dart';
import '../../widgets/celebration_overlay.dart';
import '../../services/notification_service.dart';

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
  bool _showCelebration = false;
  int _studentCount = 0;
  int _selectedStudentCount = 700;
  String? _error;
  bool _isYearly = false;

  final _codeCtrl = TextEditingController();
  bool _activating = false;

  static const _vodafoneNumber = '01031524947';
  static const _whatsappNumber = '201031524947';
  static const _instapayUsername = 'ahmed-mahmoud-1@instapay';
  static const _instapayLink = 'https://ipn.eg/C/Q/ahmed-mahmoud-1/instapay?ISIGN=23052602MEUCIQCpAONEixVTFyg4QY/wVSEMtSOXnHI09UXtf+1a6Cc4ZgIgYMGRcl+a0pjrmoz0d8tAVakB3aAZfkxP3zk7BXO+DUU=';

  static const _defaultPlans = [
    {
      'id': 'basic',
      'name': 'الباقة الأساسية',
      'price_monthly': 350,
      'max_students': 100,
      'max_ai_requests': 5,
      'color': '#06B6D4',
      'features': ['حضور وغياب', 'درجات الطلاب', 'تقارير بسيطة', '5 اختبارات AI شهرياً', '100 تصحيح AI شهرياً', '15GB تخزين', 'دعم فني'],
    },
    {
      'id': 'pro',
      'name': 'الباقة الاحترافية',
      'price_monthly': 750,
      'max_students': 400,
      'max_ai_requests': 10,
      'popular': true,
      'color': '#6366F1',
      'features': ['كل ميزات Basic', 'كورسات مشتركة', '15 اختبار AI شهرياً', '500 تصحيح AI شهرياً', '60GB تخزين', '2 مساعدين', 'تقارير AI', 'دعم فني سريع'],
    },
    {
      'id': 'premium',
      'name': 'الباقة المتكاملة',
      'price_monthly': 1250,
      'max_students': 1000,
      'max_ai_requests': 20,
      'color': '#10B981',
      'features': ['كل ميزات Pro', 'تحضير اختبارات AI', '20 اختبار AI شهرياً', '2000 تصحيح AI شهرياً', '200GB تخزين', '5 مساعدين', 'دعم VIP'],
    },
    {
      'id': 'golden',
      'name': 'الباقة الذهبية',
      'price_monthly': 20000,
      'max_students': 40000,
      'max_ai_requests': 100,
      'color': '#F59E0B',
      'features': ['كل ميزات Premium', '40,000 طالب', '25 مساعد', '25,000 تصحيح AI شهرياً', '2TB تخزين', 'دعم VIP مخصص', 'الدفع عبر إنستاباي فقط'],
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

      try {
        final countResp = await api.dio.get('/students/count');
        if (countResp.data is Map) {
          _studentCount = (countResp.data as Map)['count'] ?? 0;
        }
      } catch (_) {
        _studentCount = 0;
      }

      final plansResp = await api.dio.get('/subscriptions/plans');
      _plans = plansResp.data is List ? plansResp.data : [];

      try {
        final notifResp = await api.dio.get('/subscriptions/notifications');
        _notifications = notifResp.data is List ? notifResp.data : [];
        for (final n in _notifications) {
          if (n is Map && n['type'] == 'success' && n['read'] == false) {
            _showCelebration = true;
            final planName = n['body']?.toString() ?? '';
            NotificationService().showSubscriptionActivated(planName: planName);
            break;
          }
        }
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

  void _onCelebrationComplete() {
    if (!mounted) return;
    setState(() => _showCelebration = false);
    for (final n in _notifications) {
      if (n is Map && n['type'] == 'success') {
        n['read'] = true;
        ApiService().dio.post('/subscriptions/notifications/${n['id']}/read');
      }
    }
  }

  bool get _isActive => _subscription?['is_active'] == true && _subscription?['is_expired'] != true;
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
      return d.length > 10 ? d.substring(0, 10) : d;
    }
  }

  int _getYearlyPrice(int monthlyPrice) => monthlyPrice * 10;

  int _calculatePremiumPrice() {
    final base = 1250;
    final extra = ((_selectedStudentCount - 700) / 50).floor() * 175;
    return base + extra;
  }

  List<Map<String, dynamic>> get _plansToShow {
    if (_plans.isNotEmpty && _plans.every((p) => p['price_monthly'] != null || p['price_yearly'] != null)) {
      return _plans.map<Map<String, dynamic>>((p) => Map<String, dynamic>.from(p)).toList();
    }
    return _defaultPlans;
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
      await _loadData();
      if (mounted) context.read<AuthProvider>().refreshSubscription();
    } catch (e) {
      _showMsg('فشل التفعيل: كود غير صالح', AppTheme.danger);
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  Future<void> _activateTrial() async {
    setState(() => _loading = true);
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final resp = await ApiService().dio.post('/subscriptions/activate-trial');
        final data = resp.data is Map ? resp.data as Map<String, dynamic> : <String, dynamic>{};
        final daysRemaining = data['days_remaining'] ?? 30;
        _showMsg('تم تفعيل الفترة التجريبية! متبقي $daysRemaining يوم', AppTheme.success);
        await _loadData();
        if (mounted) context.read<AuthProvider>().refreshSubscription();
        return;
      } on DioException catch (e) {
        String raw = '';
        if (e.response?.data is Map && e.response?.data['detail'] != null) {
          raw = e.response!.data['detail'].toString();
        }
        String msg = _translateError(raw);
        if (msg.isEmpty) msg = 'فشل تفعيل الفترة التجريبية';
        if (_isTransientError(raw) && attempt < 2) {
          _showMsg('خطأ في الاتصال، جاري إعادة المحاولة...', AppTheme.warning);
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        _showMsg(msg, AppTheme.danger);
        if (mounted) setState(() => _loading = false);
        return;
      } catch (e) {
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        _showMsg('تعذر الاتصال بالخادم. تحقق من اتصال الإنترنت وحاول مرة أخرى.', AppTheme.danger);
        if (mounted) setState(() => _loading = false);
        return;
      }
    }
  }

  bool _isTransientError(String msg) {
    return msg.contains('circuit breaker') || msg.contains('temporarily') || msg.contains('timeout') || msg.contains('Network error') || msg.contains('connection');
  }

  String _translateError(String msg) {
    if (msg.contains('already have an active subscription') || msg.contains('اشتراك نشط')) return 'لديك اشتراك نشط بالفعل';
    if (msg.contains('Basic plan not found')) return 'لم يتم العثور على الباقة الأساسية';
    if (msg.contains('invalid input syntax')) return 'خطأ في البيانات. حاول مرة أخرى';
    if (msg.contains('circuit breaker') || msg.contains('temporarily')) return 'الخدمة غير متاحة مؤقتاً. حاول بعد قليل';
    if (msg.contains('timeout')) return 'انتهت مهلة الاتصال. تحقق من الإنترنت';
    if (msg.contains('Network error')) return 'خطأ في الاتصال بالشبكة';
    if (msg.contains('الفترة التجريبية من قبل')) return 'لقد استخدمت الفترة التجريبية من قبل';
    if (msg.contains('Failed to activate trial')) return 'فشل تفعيل الفترة التجريبية. حاول مرة أخرى';
    return msg;
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
          'ستحصل على 7 أيام مجاناً. بعد انتهاء الفترة يمكنك الاشتراك في أي باقة.',
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

  // ─── Payment Page Navigation ─────────────────────────────────

  void _openPaymentPage(Map<String, dynamic> plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PaymentPage(
          plan: plan,
          isYearly: _isYearly,
          selectedStudentCount: _selectedStudentCount,
          onPaymentSubmitted: () {
            _showPaymentSuccessDialog();
          },
        ),
      ),
    );
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
            Text('سيتم التحقق من الدفع وتفعيل الاشتراك خلال 10 دقائق', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary(context))),
            const SizedBox(height: 4),
            Text('وبحد أقصى ساعتين', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary(context))),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _loadData();
                context.read<AuthProvider>().refreshSubscription();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              child: const Text('حسناً'),
            ),
          ),
        ],
      ),
    );
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

  Future<void> _openWhatsApp() async {
    final url = Uri.parse('https://wa.me/$_whatsappNumber?text=${Uri.encodeComponent('مرحباً، أحتاج مساعدة بخصوص الاشتراك في تطبيق درسك AI')}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب'), backgroundColor: AppTheme.danger));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الاشتراكات', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Stack(
        children: [
          _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: GlassTheme.textSecondary(context))),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
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
                      _buildBillingToggle(),
                      const SizedBox(height: 12),
                      const Text('الباقات المتاحة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('اختر الباقة المناسبة لك', style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary(context))),
                      const SizedBox(height: 12),
                      ..._plansToShow.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildPlanCard(e.value, e.key),
                          )),
                    ],
                  ),
                ),
            if (_showCelebration)
              CelebrationOverlay(onComplete: _onCelebrationComplete),
          ],
        ),
    );
  }

  // ─── Billing Toggle ──────────────────────────────────────────

  Widget _buildBillingToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: GlassTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GlassTheme.cardBorder(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isYearly = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isYearly ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.calendar_month, size: 18, color: !_isYearly ? Colors.white : GlassTheme.textSecondary(context)),
                  const SizedBox(width: 6),
                  Text('شهري', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: !_isYearly ? Colors.white : GlassTheme.textSecondary(context))),
                ]),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isYearly = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isYearly ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.event_repeat, size: 18, color: _isYearly ? Colors.white : GlassTheme.textSecondary(context)),
                  const SizedBox(width: 6),
                  Text('سنوي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _isYearly ? Colors.white : GlassTheme.textSecondary(context))),
                  if (_isYearly) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(8)),
                      child: const Text('خصم شهرين', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ],
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
            Icon(isSuccess ? Icons.check_circle : isError ? Icons.error : Icons.info, size: 20, color: isSuccess ? AppTheme.success : isError ? AppTheme.danger : AppTheme.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (n['title'] != null) Text(n['title'].toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                if (n['body'] != null) Text(n['body'].toString(), style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary(context))),
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
        color: GlassTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _subscription != null
              ? (_isActive ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.danger.withValues(alpha: 0.3))
              : GlassTheme.cardBorder(context),
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
          Expanded(child: Text('الاشتراك الحالي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context)))),
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
                Text(_isActive ? 'نشط' : 'منتهي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isActive ? AppTheme.success : AppTheme.danger)),
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
            value: '$_studentCount / ${_subscription!['max_students']}',
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text('لا يوجد اشتراك نشط. اختر باقة للاشتراك أو استخدم كود تفعيل.', style: TextStyle(color: GlassTheme.textSecondary(context), fontSize: 13)),
        ],
      ]),
    );
  }

  // ─── Account ID ──────────────────────────────────────────────

  Widget _buildAccountIdSection() {
    final userId = _userData?['id']?.toString();
    if (userId == null || userId.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(color: GlassTheme.cardBg(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: GlassTheme.cardBorder(context))),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.fingerprint, size: 20, color: AppTheme.accent.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Text('معرف الحساب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
        ]),
        const SizedBox(height: 4),
        Text('استخدم هذا المعرف عند التواصل مع الدعم الفني', style: TextStyle(fontSize: 11, color: GlassTheme.textSecondary(context))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: GlassTheme.cardBg(context), borderRadius: BorderRadius.circular(10), border: Border.all(color: GlassTheme.cardBorder(context))),
              child: Text(userId, style: const TextStyle(fontSize: 13, fontFamily: 'monospace', letterSpacing: 1), textDirection: TextDirection.ltr),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _copyToClipboard(userId),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: GlassTheme.cardBg(context), borderRadius: BorderRadius.circular(10), border: Border.all(color: GlassTheme.cardBorder(context))),
              child: Icon(Icons.copy, size: 18, color: GlassTheme.textSecondary(context)),
            ),
          ),
        ]),
      ]),
    );
  }

  // ─── Activate Code ───────────────────────────────────────────

  Widget _buildActivateCodeSection() {
    return Container(
      decoration: BoxDecoration(color: GlassTheme.cardBg(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: GlassTheme.cardBorder(context))),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.vpn_key, size: 20, color: AppTheme.accent.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Text('تفعيل كود اشتراك', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _codeCtrl,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 16, letterSpacing: 2, fontFamily: 'monospace'),
              decoration: const InputDecoration(hintText: 'XXXX-XXXX-XXXX-XXXX', hintStyle: TextStyle(letterSpacing: 2)),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _activating ? null : _activateCode,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _activating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('تفعيل', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildStudentSlider() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('عدد الطلاب', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassTheme.textSecondary(context))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$_selectedStudentCount طالب', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.success)),
        ),
      ]),
      const SizedBox(height: 4),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: AppTheme.success,
          inactiveTrackColor: AppTheme.success.withValues(alpha: 0.15),
          thumbColor: AppTheme.success,
          overlayColor: AppTheme.success.withValues(alpha: 0.1),
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        ),
        child: Slider(
          value: _selectedStudentCount.toDouble(),
          min: 700,
          max: 5000,
          divisions: 86,
          onChanged: (v) => setState(() => _selectedStudentCount = v.round()),
        ),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('700', style: TextStyle(fontSize: 11, color: GlassTheme.textMuted(context))),
        Text('5000', style: TextStyle(fontSize: 11, color: GlassTheme.textMuted(context))),
      ]),
    ]);
  }

  // ─── Plan Card ───────────────────────────────────────────────

  Widget _buildPlanCard(Map<String, dynamic> plan, int index) {
    final name = plan['name'] ?? '';
    final planId = plan['id']?.toString() ?? '';
    final isPremium = planId == 'premium';
    final basePrice = (plan['price_monthly'] ?? plan['price_egp'] ?? 0).toInt();
    final yearlyFromDb = (plan['price_yearly'] ?? 0).toInt();
    final monthlyPrice = isPremium ? _calculatePremiumPrice() : basePrice;
    final displayPrice = _isYearly ? (yearlyFromDb > 0 ? yearlyFromDb : _getYearlyPrice(monthlyPrice)) : monthlyPrice;
    final features = plan['features'] is List ? plan['features'] as List : <dynamic>[];
    final maxStudents = plan['max_students'];
    final isPopular = plan['popular'] == true;
    final trialEligible = _isTrialEligible(plan);

    final planColors = [
      [const Color(0xFF06B6D4), const Color(0xFF22D3EE)],
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      [const Color(0xFF10B981), const Color(0xFF34D399)],
    ];
    final gradientColors = planColors[index.clamp(0, 2)];

    return Container(
      decoration: BoxDecoration(
        color: GlassTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? AppTheme.accent.withValues(alpha: 0.4) : GlassTheme.cardBorder(context),
          width: isPopular ? 1.5 : 1,
        ),
        boxShadow: isPopular ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.08), blurRadius: 20)] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isPopular)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors), borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
            child: const Text('الأكثر طلباً', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (trialEligible)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.warning, AppTheme.warning.withValues(alpha: 0.8)]), borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.local_offer_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('7 أيام مجاناً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
              ),
            Text(name.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$displayPrice', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _isYearly ? 'ج.م/سنوياً' : 'ج.م/شهرياً',
                  style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary(context)),
                ),
              ),
            ]),
            if (_isYearly) ...[
              const SizedBox(height: 2),
              Row(children: [
                Text(
                  '$monthlyPrice ج.م/شهر',
                  style: TextStyle(fontSize: 12, color: GlassTheme.textMuted(context), decoration: TextDecoration.lineThrough),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    'وفّر ${monthlyPrice * 12 - _getYearlyPrice(monthlyPrice)} ج.م',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success),
                  ),
                ),
              ]),
            ],
            if (maxStudents != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.people, size: 16, color: GlassTheme.textSecondary(context)),
                const SizedBox(width: 6),
                Text(
                  'حتى $maxStudents طالب',
                  style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary(context)),
                ),
              ]),
            ],
            if (isPremium) ...[
              const SizedBox(height: 12),
              _buildStudentSlider(),
            ],
            const SizedBox(height: 12),
            ...features.map((f) {
              final isInstapayOnly = f.toString().contains('انستاباي');
              final isGolden = planId == 'golden';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(
                    isGolden && isInstapayOnly ? Icons.warning_amber_rounded : Icons.check,
                    size: 16,
                    color: isGolden && isInstapayOnly ? AppTheme.danger : gradientColors[0],
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f.toString(), style: TextStyle(
                    fontSize: 13,
                    color: isGolden && isInstapayOnly ? AppTheme.danger : null,
                    fontWeight: isGolden && isInstapayOnly ? FontWeight.w600 : null,
                  ))),
                ]),
              );
            }),
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
                  decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors), borderRadius: BorderRadius.circular(12)),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openPaymentPage(plan),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.credit_card, size: 18, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            _isYearly ? 'اشتراك سنوي الآن' : 'اشتراك الآن',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
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
        Text(label, style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary(context))),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PAYMENT PAGE
// ═══════════════════════════════════════════════════════════════

class _PaymentPage extends StatefulWidget {
  final Map<String, dynamic> plan;
  final bool isYearly;
  final int selectedStudentCount;
  final VoidCallback onPaymentSubmitted;

  const _PaymentPage({required this.plan, required this.isYearly, required this.selectedStudentCount, required this.onPaymentSubmitted});

  @override
  State<_PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<_PaymentPage> {
  String _selectedMethod = '';
  File? _screenshot;
  final _phoneCtrl = TextEditingController();
  final _instapayIdCtrl = TextEditingController();
  bool _submitting = false;

  static const _vodafoneNumber = '01031524947';
  static const _instapayUsername = 'ahmed-mahmoud-1@instapay';
  static const _instapayLink = 'https://ipn.eg/C/Q/ahmed-mahmoud-1/instapay?ISIGN=23052602MEUCIQCpAONEixVTFyg4QY/wVSEMtSOXnHI09UXtf+1a6Cc4ZgIgYMGRcl+a0pjrmoz0d8tAVakB3aAZfkxP3zk7BXO+DUU=';

  int get _price {
    final monthly = (widget.plan['price_monthly'] ?? widget.plan['price_egp'] ?? 0).toInt();
    final yearlyFromDb = (widget.plan['price_yearly'] ?? 0).toInt();
    if (widget.isYearly) {
      return yearlyFromDb > 0 ? yearlyFromDb : monthly * 10;
    }
    return monthly;
  }

  String get _planName => widget.plan['name'] ?? '';
  String get _periodLabel => widget.isYearly ? 'سنوياً' : 'شهرياً';

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _instapayIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedMethod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر طريقة الدفع')));
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل رقم هاتفك')));
      return;
    }
    if (_screenshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أرفق صورة الإيصال')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final formData = FormData.fromMap({
        'plan_id': widget.plan['id'] ?? '',
        'payment_method': _selectedMethod,
        'amount': _price,
        'phone_number': _phoneCtrl.text.trim(),
        'instapay_id': _instapayIdCtrl.text.trim(),
        'billing_period': widget.isYearly ? 'yearly' : 'monthly',
        if (widget.selectedStudentCount > 0) 'max_students': widget.selectedStudentCount,
        'screenshot': await MultipartFile.fromFile(_screenshot!.path, filename: 'screenshot.${_screenshot!.path.split(".").last}'),
      });
      await ApiService().dio.post('/payments/request', data: formData);
      if (mounted) {
        Navigator.pop(context);
        widget.onPaymentSubmitted();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الإرسال: $e'), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إتمام الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Plan Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.accent.withValues(alpha: 0.1), AppTheme.accent.withValues(alpha: 0.05)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.card_membership, color: AppTheme.accent, size: 24),
                const SizedBox(width: 10),
                Text(_planName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$_price', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('ج.م/$_periodLabel', style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary(context)))),
              ]),
            ]),
          ),
          const SizedBox(height: 24),

          // Payment Method Selection
          const Text('اختر طريقة الدفع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (widget.plan['id'] == 'golden') ...[
            _buildMethodCard('instapay', 'انستاباي فقط', Icons.qr_code_rounded, const Color(0xFF00C853)),
          ] else ...[
            _buildMethodCard('vodafone_cash', 'فودافون كاش', Icons.phone_android, const Color(0xFFE60023)),
            const SizedBox(height: 8),
            _buildMethodCard('instapay', 'انستاباي', Icons.qr_code_rounded, const Color(0xFF00C853)),
            const SizedBox(height: 8),
            _buildMethodCard('cash', 'نقدي', Icons.payments_outlined, AppTheme.accent),
          ],
          const SizedBox(height: 24),

          // Payment Details
          if (_selectedMethod.isNotEmpty) ...[
            Text('تفاصيل الدفع - ${_selectedMethod == 'vodafone_cash' ? 'فودافون كاش' : _selectedMethod == 'instapay' ? 'انستاباي' : 'نقدي'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_selectedMethod == 'vodafone_cash') _buildVodafoneSection(),
            if (_selectedMethod == 'instapay') _buildInstaPaySection(),
            if (_selectedMethod == 'cash') _buildCashSection(),
            const SizedBox(height: 16),

            // Phone Number
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم هاتفك', prefixIcon: Icon(Icons.phone, size: 20)),
            ),
            if (_selectedMethod == 'instapay') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _instapayIdCtrl,
                decoration: const InputDecoration(labelText: 'معرف انستاباي الذي حولت منه (اختياري)', prefixIcon: Icon(Icons.person, size: 20)),
              ),
            ],
            const SizedBox(height: 16),

            // Screenshot Upload
            Text('صورة الإيصال', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary(context))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (file != null) setState(() => _screenshot = File(file.path));
              },
              child: Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  color: _screenshot != null ? AppTheme.success.withValues(alpha: 0.05) : GlassTheme.cardBg(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _screenshot != null ? AppTheme.success.withValues(alpha: 0.4) : GlassTheme.cardBorder(context),
                    width: _screenshot != null ? 2 : 1.5,
                  ),
                ),
                child: _screenshot != null
                    ? Stack(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(_screenshot!, width: double.infinity, height: 140, fit: BoxFit.cover)),
                        Positioned(
                          top: 8, right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _screenshot = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
                              child: const Icon(Icons.close, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8, left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(8)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.check_circle, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text('تم الإرفاق', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            ]),
                          ),
                        ),
                      ])
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.cloud_upload_outlined, size: 32, color: AppTheme.accent),
                        ),
                        const SizedBox(height: 10),
                        Text('اضغط هنا لرفع صورة الإيصال', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary(context))),
                        const SizedBox(height: 4),
                        Text('PNG, JPG أو WEBP (حد أقصى 5MB)', style: TextStyle(fontSize: 11, color: GlassTheme.textMuted(context))),
                      ]),
              ),
            ),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _submitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('إرسال طلب الدفع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),

            // Support
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final url = Uri.parse('https://wa.me/201031524947?text=${Uri.encodeComponent('أحتاج مساعدة بالاشتراك - $_planName')}');
                  try { await launchUrl(url, mode: LaunchMode.externalApplication); } catch (_) {}
                },
                icon: const Icon(Icons.support_agent, size: 18),
                label: const Text('الدعم الفني عبر الواتساب'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMethodCard(String method, String label, IconData icon, Color color) {
    final isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : GlassTheme.cardBg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : GlassTheme.cardBorder(context), width: isSelected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isSelected ? color : GlassTheme.textPrimary(context))),
          const Spacer(),
          if (isSelected) Icon(Icons.check_circle, color: color, size: 22),
        ]),
      ),
    );
  }

  Widget _buildVodafoneSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE60023).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE60023).withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('خطوات الدفع:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        _buildStep(1, 'افتح تطبيق فودافون كاش'),
        _buildStep(2, 'اختر "تحويل للمحفضة"'),
        _buildStep(3, 'أدخل المبلغ: $_price ج.م'),
        _buildStep(4, 'أدخل الرقم التالي:'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            Clipboard.setData(const ClipboardData(text: _vodafoneNumber));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرقم'), duration: Duration(seconds: 1)));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE60023).withValues(alpha: 0.2))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.copy, size: 18, color: Color(0xFFE60023)),
              const SizedBox(width: 8),
              Text(_vodafoneNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFFE60023))),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        _buildStep(5, 'ارفق صورة الإيصال أدناه'),
      ]),
    );
  }

  Widget _buildInstaPaySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00C853).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('خطوات الدفع:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        _buildStep(1, 'افتح تطبيق البنك وانستاباي'),
        _buildStep(2, 'اختر "إرسال للمعرف"'),
        _buildStep(3, 'امسح الباركود أو أدخل المعرف'),
        _buildStep(4, 'أدخل المبلغ: $_price ج.م'),
        const SizedBox(height: 12),
        const Text('باركود الدفع:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: QrImageView(
              data: _instapayLink,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(color: Color(0xFF00C853)),
              dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF00C853)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: () {
              Clipboard.setData(const ClipboardData(text: _instapayUsername));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ المعرف'), duration: Duration(seconds: 1)));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF00C853).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.copy, size: 16, color: Color(0xFF00C853)),
                const SizedBox(width: 6),
                Text(_instapayUsername, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF00C853))),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildStep(5, 'ارفق صورة الإيصال أدناه'),
      ]),
    );
  }

  Widget _buildCashSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('الدفع النقدي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        _buildStep(1, 'تواصل معنا عبر الواتساب لتحديد موعد التسليم'),
        _buildStep(2, 'ادفع المبلغ $_price ج.م نقداً'),
        _buildStep(3, 'سيتم تفعيل اشتراكك فوراً'),
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton.icon(
            onPressed: () async {
              final url = Uri.parse('https://wa.me/201031524947?text=${Uri.encodeComponent('أريد الدفع نقداً - $_planName - $_price ج.م')}');
              try { await launchUrl(url, mode: LaunchMode.externalApplication); } catch (_) {}
            },
            icon: const Icon(Icons.chat, size: 18),
            label: const Text('تواصل عبر الواتساب'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Center(child: Text('$num', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accent))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}
