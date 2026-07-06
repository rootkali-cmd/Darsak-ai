import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/glass_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/payments_api_service.dart';
import '../../services/native_file_picker.dart';
import 'package:provider/provider.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _paymentConfig;
  Map<String, dynamic>? _instaPayConfig;
  bool _isYearly = false;
  int _selectedStudentCount = 700;

  static const _defaultPlans = [
    {
      'id': 'basic',
      'name': 'الباقة الأساسية',
      'price_egp': 250,
      'max_students': 100,
      'color': '#06B6D4',
      'features': ['حضور وغياب', 'درجات الطلاب', 'تقارير بسيطة', 'دعم فني'],
    },
    {
      'id': 'pro',
      'name': 'الباقة الاحترافية',
      'price_egp': 600,
      'max_students': 400,
      'color': '#6366F1',
      'popular': true,
      'features': ['حضور وغياب', 'درجات الطلاب', 'تقارير AI', 'دروس مشتركة', 'تحضير اختبارات بالـ AI', 'دعم فني'],
    },
    {
      'id': 'premium',
      'name': 'الباقة المتكاملة',
      'price_egp': 1100,
      'max_students': -1,
      'color': '#10B981',
      'features': ['حضور وغياب', 'درجات الطلاب', 'تقارير AI', 'دروس مشتركة', 'تحضير اختبارات بالـ AI', 'طلاب غير محدود', 'دعم فني أولوية'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final paymentsApi = PaymentsApiService();
      final api = ApiService();

      try {
        final meResp = await api.dio.get('/auth/me');
        final me = meResp.data is Map ? meResp.data as Map<String, dynamic> : <String, dynamic>{};
        _subscription = me['subscription'] is Map ? Map<String, dynamic>.from(me['subscription']) : null;
      } catch (_) {}

      try {
        _paymentConfig = await paymentsApi.getPaymentConfig();
      } catch (_) {}

      try {
        _instaPayConfig = await paymentsApi.getInstaPayConfig();
      } catch (_) {}

      try {
        final plansResp = await api.dio.get('/subscriptions/plans');
        if (plansResp.data is List) {
          _plans = (plansResp.data as List).map<Map<String, dynamic>>((p) => Map<String, dynamic>.from(p)).toList();
        }
      } catch (_) {}
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _plansToShow {
    if (_plans.isNotEmpty && _plans.every((p) => p['price_egp'] != null || p['price'] != null)) {
      return _plans;
    }
    return _defaultPlans;
  }

  int _calculatePremiumPrice() {
    final base = 1100;
    final extra = ((_selectedStudentCount - 700) / 50).floor() * 175;
    return base + extra;
  }

  int _getPlanPrice(Map<String, dynamic> plan) {
    final id = plan['id']?.toString() ?? '';
    if (id == 'premium') {
      final monthly = _calculatePremiumPrice();
      return _isYearly ? monthly * 10 : monthly;
    }
    final base = (plan['price_egp'] ?? plan['price'] ?? 0) as int;
    return _isYearly ? base * 10 : base;
  }

  String _getPriceSuffix() => _isYearly ? 'ج.م/سنه' : 'ج.م/شهر';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: GlassTheme.glassAppBar('الباقات والاشتراكات'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: GlassTheme.textSecondary(context))),
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
                      _buildCurrentStatus(),
                      const SizedBox(height: 20),
                      _buildBillingToggle(),
                      const SizedBox(height: 16),
                      Text('اختر باقتك', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
                      const SizedBox(height: 4),
                      Text('جميع الباقات تشمل الدعم الفني والتحديثات المجانية', style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary(context))),
                      const SizedBox(height: 16),
                      ..._plansToShow.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildPlanCard(e.value, e.key),
                          )),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBillingToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: GlassTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GlassTheme.cardBorder(context)),
      ),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isYearly = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: !_isYearly ? const LinearGradient(colors: [AppTheme.accent, Color(0xFF8B5CF6)]) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (!_isYearly) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                if (!_isYearly) const SizedBox(width: 6),
                Text('شهري', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold,
                  color: !_isYearly ? Colors.white : GlassTheme.textSecondary(context),
                )),
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
                gradient: _isYearly ? const LinearGradient(colors: [AppTheme.accent, Color(0xFF8B5CF6)]) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (_isYearly) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                if (_isYearly) const SizedBox(width: 6),
                Text('سنوي', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold,
                  color: _isYearly ? Colors.white : GlassTheme.textSecondary(context),
                )),
                if (_isYearly) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('وفّر شهرين', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildCurrentStatus() {
    if (_subscription == null) return const SizedBox.shrink();
    final isActive = _subscription!['is_active'] == true && _subscription!['is_expired'] != true;
    final daysLeft = _subscription!['days_remaining'] ?? 0;
    final planName = _subscription!['plan_name']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GlassTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.danger.withValues(alpha: 0.3),
        ),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.card_membership, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('اشتراكك الحالي', style: TextStyle(fontSize: 11, color: GlassTheme.textSecondary(context))),
            const SizedBox(height: 2),
            Text(planName.isNotEmpty ? planName : 'لا يوجد اشتراك', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
          ]),
        ),
        if (isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$daysLeft يوم', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.success)),
          ),
      ]),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, int index) {
    final name = plan['name'] ?? '';
    final price = _getPlanPrice(plan);
    final features = plan['features'] is List ? plan['features'] as List : <dynamic>[];
    final isPopular = plan['popular'] == true;
    final planId = plan['id']?.toString() ?? '';
    final isPremium = planId == 'premium';

    final planColors = [
      [const Color(0xFF6366F1), const Color(0xFF818CF8)],
      [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
      [const Color(0xFF10B981), const Color(0xFF34D399)],
    ];
    final gradientColors = planColors[index.clamp(0, 2)];

    return Container(
      decoration: BoxDecoration(
        color: GlassTheme.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPopular ? AppTheme.accent.withValues(alpha: 0.5) : GlassTheme.cardBorder(context),
          width: isPopular ? 2 : 1,
        ),
        boxShadow: isPopular
            ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.12), blurRadius: 24, spreadRadius: 0)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.star_rounded, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text('الأكثر شعبية', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$price', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
                const SizedBox(width: 4),
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(_getPriceSuffix(), style: TextStyle(fontSize: 14, color: GlassTheme.textSecondary(context)))),
              ]),
              if (isPremium) ...[
                const SizedBox(height: 12),
                _buildStudentSlider(),
              ],
              const SizedBox(height: 16),
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: gradientColors[0].withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.check, size: 14, color: gradientColors[0]),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(f.toString(), style: TextStyle(fontSize: 14, color: GlassTheme.textPrimary(context)))),
                    ]),
                  )),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _showPaymentBottomSheet(plan),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.credit_card_rounded, size: 20, color: Colors.white),
                          SizedBox(width: 8),
                          Text('اشترك الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
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

  void _showPaymentBottomSheet(Map<String, dynamic> plan) {
    final planName = plan['name'] ?? '';
    final planPrice = _getPlanPrice(plan);
    final planId = plan['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PaymentBottomSheet(
        planName: planName,
        planPrice: planPrice,
        planId: planId,
        paymentConfig: _paymentConfig,
        instaPayConfig: _instaPayConfig,
        onSubmit: (method, file, phoneNumber, instapayId) => _submitPayment(planId, planPrice.toDouble(), method, file, phoneNumber, instapayId),
      ),
    );
  }

  Future<void> _submitPayment(String planId, double amount, String method, File? screenshot, String? phoneNumber, String? instapayId) async {
    try {
      final auth = context.read<AuthProvider>();
      final teacherId = auth.user?['id']?.toString() ?? '';

      await PaymentsApiService().submitPaymentRequest(
        teacherId: teacherId,
        planId: planId,
        paymentMethod: method,
        amount: amount,
        screenshotFile: screenshot,
        phoneNumber: phoneNumber,
        instapayId: instapayId,
      );

      if (!mounted) return;
      Navigator.pop(context);
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الإرسال: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.success.withValues(alpha: 0.08),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('تم إرسال طلب الدفع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              ' سيتم تفعيل اشتراكك بعد المراجعة.\nيمكنك التواصل معنا عبر الواتساب لأي استفسار.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary(context), height: 1.6),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('حسناً', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentBottomSheet extends StatefulWidget {
  final String planName;
  final num planPrice;
  final String planId;
  final Map<String, dynamic>? paymentConfig;
  final Map<String, dynamic>? instaPayConfig;
  final Future<void> Function(String method, File? file, String? phoneNumber, String? instapayId) onSubmit;

  const _PaymentBottomSheet({
    required this.planName,
    required this.planPrice,
    required this.planId,
    this.paymentConfig,
    this.instaPayConfig,
    required this.onSubmit,
  });

  @override
  State<_PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<_PaymentBottomSheet> {
  int _selectedMethod = 0;
  File? _screenshot;
  bool _submitting = false;
  final _phoneController = TextEditingController();
  final _instapayIdController = TextEditingController();

  String get _vodafoneNumber => widget.paymentConfig?['vodafone_number']?.toString() ?? '01031524947';
  String? get _barcodeUrl => widget.instaPayConfig?['barcode_url']?.toString();
  String? get _instaPayUsername => widget.instaPayConfig?['username']?.toString();

  @override
  void dispose() {
    _phoneController.dispose();
    _instapayIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.7)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payment_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('اختر طريقة الدفع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${widget.planName} - ${widget.planPrice} ج.م', style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary(context))),
                  ]),
                ),
              ]),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                _buildMethodTile(
                  index: 0,
                  icon: Icons.phone_android_rounded,
                  title: 'فودافون كاش',
                  subtitle: 'الدفع عبر فودافون كاش',
                  color: const Color(0xFFE60023),
                ),
                const SizedBox(height: 10),
                _buildMethodTile(
                  index: 1,
                  icon: Icons.qr_code_rounded,
                  title: 'انستاباي',
                  subtitle: 'الدفع عبر انستاباي',
                  color: const Color(0xFF00C853),
                ),
                const SizedBox(height: 16),
                if (_selectedMethod == 0) _buildVodafoneSection(),
                if (_selectedMethod == 1) _buildInstaPaySection(),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.accent, Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _submitting ? null : _handleSubmit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _submitting
                          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.send_rounded, size: 20, color: Colors.white),
                              SizedBox(width: 8),
                              Text('تأكيد الدفع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTile({required int index, required IconData icon, required String title, required String subtitle, required Color color}) {
    final isSelected = _selectedMethod == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedMethod = index;
        _screenshot = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : GlassTheme.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.4) : GlassTheme.cardBorder(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary(context))),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary(context))),
            ]),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? color : Colors.transparent,
              border: Border.all(color: isSelected ? color : GlassTheme.textSecondary(context), width: 2),
            ),
            child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
          ),
        ]),
      ),
    );
  }

  Widget _buildVodafoneSection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE60023).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE60023).withValues(alpha: 0.15)),
          ),
          child: Column(children: [
            Text('حول المبلغ إلى رقم فودافون كاش', style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary(context))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _vodafoneNumber));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ الرقم'), duration: Duration(seconds: 1)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE60023).withValues(alpha: 0.2)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.copy_rounded, size: 20, color: Color(0xFFE60023)),
                  const SizedBox(width: 10),
                  Text(_vodafoneNumber, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFFE60023))),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Text('المبلغ: ${widget.planPrice} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFE60023))),
          ]),
        ),
        const SizedBox(height: 16),
        Text('رقم الهاتف', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary(context))),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: GlassTheme.glassInput(context, 'أدخل رقم الهاتف', Icons.phone_rounded),
        ),
        const SizedBox(height: 16),
        Text('صورة الإيصال', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary(context))),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickScreenshot,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: _screenshot != null ? AppTheme.success.withValues(alpha: 0.04) : GlassTheme.cardBg(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _screenshot != null ? AppTheme.success.withValues(alpha: 0.3) : GlassTheme.cardBorder(context),
              ),
            ),
            child: _screenshot != null
                ? Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_screenshot!, width: double.infinity, height: 120, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _screenshot = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.camera_alt_rounded, size: 36, color: GlassTheme.textMuted(context)),
                    const SizedBox(height: 8),
                    Text('اضغط لرفع صورة الإيصال', style: TextStyle(fontSize: 13, color: GlassTheme.textMuted(context))),
                  ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildInstaPaySection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_instaPayUsername != null && _instaPayUsername!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.15)),
            ),
            child: Column(children: [
              Text('اسم المستخدم', style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary(context))),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _instaPayUsername!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ اسم المستخدم'), duration: Duration(seconds: 1)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.2)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF00C853)),
                    const SizedBox(width: 8),
                    Text(_instaPayUsername!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00C853))),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        Text('معرف انستاباي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary(context))),
        const SizedBox(height: 8),
        TextField(
          controller: _instapayIdController,
          decoration: GlassTheme.glassInput(context, 'ahmed-mahmoud-1@instapay', Icons.alternate_email),
        ),
        const SizedBox(height: 12),
        Text('رقم الهاتف', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary(context))),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: GlassTheme.glassInput(context, 'أدخل رقم الهاتف', Icons.phone_rounded),
        ),
        const SizedBox(height: 12),
        if (_barcodeUrl != null && _barcodeUrl!.isNotEmpty) ...[
          Text('امسح الباركود للدفع', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary(context))),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GlassTheme.cardBorder(context)),
            ),
            child: Image.network(
              _barcodeUrl!,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.qr_code_rounded, size: 64, color: GlassTheme.textMuted(context)),
                const SizedBox(height: 8),
                Text('تعذر تحميل الباركود', style: TextStyle(fontSize: 13, color: GlassTheme.textMuted(context))),
              ]),
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: GlassTheme.cardBg(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GlassTheme.cardBorder(context)),
            ),
            child: Column(children: [
              Icon(Icons.qr_code_rounded, size: 64, color: GlassTheme.textMuted(context)),
              const SizedBox(height: 12),
              Text('جاري تحميل الباركود...', style: TextStyle(fontSize: 14, color: GlassTheme.textSecondary(context))),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF00C853).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.12)),
          ),
          child: Text('المبلغ: ${widget.planPrice} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF00C853))),
        ),
      ]),
    );
  }

  Future<void> _pickScreenshot() async {
    final path = await NativeFilePicker.pickImage();
    if (path != null) {
      setState(() => _screenshot = File(path));
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedMethod == 0 && _screenshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أرفق صورة الإيصال'), backgroundColor: AppTheme.warning),
      );
      return;
    }
    setState(() => _submitting = true);
    await widget.onSubmit(
      _selectedMethod == 0 ? 'vodafone_cash' : 'instapay',
      _screenshot,
      _phoneController.text.isNotEmpty ? _phoneController.text : null,
      _selectedMethod == 1 && _instapayIdController.text.isNotEmpty ? _instapayIdController.text : null,
    );
    if (mounted) setState(() => _submitting = false);
  }
}
