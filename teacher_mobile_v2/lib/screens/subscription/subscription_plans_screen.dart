import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/glass_theme.dart';
import '../../services/api_service.dart';
import '../../services/payments_api_service.dart';
import '../../services/native_file_picker.dart';
import 'dart:io';

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
  bool _isYearly = false;
  int _premiumStudents = 1000;

  static const _premiumTiers = [
    {'students': 1000, 'monthly': 1250, 'yearly': 11500, 'assistants': 5, 'storage': '200GB', 'grading': '2,000'},
    {'students': 2500, 'monthly': 2500, 'yearly': 24000, 'assistants': 10, 'storage': '500GB', 'grading': '5,000'},
    {'students': 5000, 'monthly': 4200, 'yearly': 42000, 'assistants': 15, 'storage': '1TB', 'grading': '10,000'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ApiService();
      try {
        final meResp = await api.dio.get('/auth/me');
        final me = meResp.data is Map ? meResp.data as Map<String, dynamic> : <String, dynamic>{};
        _subscription = me['subscription'] is Map ? Map<String, dynamic>.from(me['subscription']) : null;
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

  Map<String, dynamic>? get _currentPlan => _subscription?['plan'] is Map ? Map<String, dynamic>.from(_subscription!['plan']) : null;
  String get _currentPlanName => _currentPlan?['name'] ?? '';

  Map<String, dynamic>? _findPlan(String planId) {
    try {
      return _plans.firstWhere((p) => (p['id'] ?? '').toString().toLowerCase() == planId.toLowerCase());
    } catch (_) {
      return null;
    }
  }
  int get _daysRemaining {
    final exp = _subscription?['expires_at'];
    if (exp == null) return 0;
    try {
      final d = DateTime.parse(exp.toString());
      return d.difference(DateTime.now()).inDays;
    } catch (_) { return 0; }
  }

  int get _premiumPrice => _isYearly
      ? (_premiumTiers.firstWhere((t) => t['students'] == _premiumStudents, orElse: () => _premiumTiers[0])['yearly'] as int)
      : (_premiumTiers.firstWhere((t) => t['students'] == _premiumStudents, orElse: () => _premiumTiers[0])['monthly'] as int);

  Map<String, dynamic> get _currentPremiumTier => _premiumTiers.firstWhere((t) => t['students'] == _premiumStudents, orElse: () => _premiumTiers[0]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassTheme.glassAppBar('الباقات والاشتراكات'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GlassTheme.indigo))
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: GlassTheme.textPrimary(context))),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadData, child: const Text('إعادة المحاولة')),
                ]))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildBillingToggle(),
                      const SizedBox(height: 16),
                      if (_currentPlanName.isNotEmpty) ...[
                        _buildCurrentSubscription(),
                        const SizedBox(height: 20),
                      ],
                      _buildPlanCardDynamic(_findPlan('basic'), color: const Color(0xFF06B6D4)),
                      const SizedBox(height: 12),
                      _buildPlanCardDynamic(_findPlan('pro'), color: GlassTheme.indigo, popular: true),
                      const SizedBox(height: 12),
                      _buildPremiumCard(),
                      const SizedBox(height: 12),
                      _buildGoldenCard(),
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
        color: GlassTheme.textSecondary(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => setState(() => _isYearly = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: !_isYearly ? GlassTheme.indigo : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text('شهري', style: GoogleFonts.cairo(
              color: !_isYearly ? Colors.white : GlassTheme.textSecondary(context),
              fontWeight: FontWeight.w700,
            ))),
          ),
        )),
        Expanded(child: GestureDetector(
          onTap: () => setState(() => _isYearly = true),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _isYearly ? GlassTheme.indigo : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('سنوي', style: GoogleFonts.cairo(
                color: _isYearly ? Colors.white : GlassTheme.textSecondary(context),
                fontWeight: FontWeight.w700,
              )),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                child: const Text('وفّر شهرين', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ])),
          ),
        )),
      ]),
    );
  }

  Widget _buildCurrentSubscription() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: GlassTheme.glassCard(context),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الباقة الحالية: $_currentPlanName', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 2),
          Text(_daysRemaining > 0 ? 'متبقي $_daysRemaining يوم' : 'منتهية', style: GoogleFonts.cairo(
            fontSize: 12, color: _daysRemaining > 0 ? Colors.green : Colors.red,
          )),
        ])),
      ]),
    );
  }

  Widget _buildPlanCardDynamic(Map<String, dynamic>? plan, {required Color color, bool popular = false}) {
    final planId = plan?['id']?.toString().toLowerCase() ?? '';
    final name = plan?['name_ar']?.toString() ?? plan?['name']?.toString() ?? '';
    final monthly = (plan?['price_monthly'] ?? 0).toInt();
    final yearly = (plan?['price_yearly'] ?? 0).toInt();
    final students = plan?['max_students'] ?? 0;
    final assistants = plan?['max_assistants'] ?? 0;
    final aiRequests = plan?['max_ai_requests'] ?? 0;
    final storage = plan?['storage_limit_gb'] ?? 0;

    List<String> features = [];
    final fj = plan?['features_json'];
    if (fj is List) features = fj.map((f) => f.toString()).toList();

    final nameEn = plan?['name']?.toString() ?? '';
    final effectiveYearly = yearly > 0 ? yearly : monthly * 10;
    final price = _isYearly ? effectiveYearly : monthly;
    final isCurrent = nameEn.isNotEmpty && _currentPlanName.toLowerCase().contains(nameEn.toLowerCase());

    final extras = <String, String>{
      if (assistants > 0) 'مساعدين': '$assistants',
      if (aiRequests > 0) 'امتحانات AI/شهر': '$aiRequests',
      if (storage > 0) 'تخزين': storage >= 1024 ? '${(storage / 1024).toStringAsFixed(1)}TB' : '${storage}GB',
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: GlassTheme.textPrimary(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: popular ? color : GlassTheme.textSecondary(context).withValues(alpha: 0.2), width: popular ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (popular) Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
          child: const Center(child: Text('الأكثر شعبية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
        ),
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          if (students > 0) ...[
            const SizedBox(height: 4),
            Text('$students طالب كحد أقصى', style: GoogleFonts.cairo(fontSize: 12, color: GlassTheme.textSecondary(context))),
          ],
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (_isYearly && monthly > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 8),
                child: Text('${monthly * 12}', style: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.red.shade300, decoration: TextDecoration.lineThrough)),
              ),
            Text('$price', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 28, color: GlassTheme.textPrimary(context))),
            const SizedBox(width: 4),
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('ج.م/${_isYearly ? 'سنة' : 'شهر'}', style: GoogleFonts.cairo(fontSize: 12, color: GlassTheme.textSecondary(context)))),
          ]),
          if (_isYearly && monthly > 0 && effectiveYearly > 0) ...[
            const SizedBox(height: 4),
            Text('وفر ${(monthly * 12) - effectiveYearly} ج.م سنوياً', style: GoogleFonts.cairo(fontSize: 11, color: Colors.green)),
          ],
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...extras.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(Icons.check_circle, color: color, size: 16),
                const SizedBox(width: 8),
                Text('${e.key}: ${e.value}', style: GoogleFonts.cairo(fontSize: 12, color: GlassTheme.textPrimary(context))),
              ]),
            )),
          ],
          if (features.isNotEmpty) ...[
            const Divider(height: 20),
            ...features.take(4).map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(Icons.check, color: Colors.green, size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(f, style: GoogleFonts.cairo(fontSize: 12, color: GlassTheme.textPrimary(context)))),
              ]),
            )),
            if (features.length > 4) TextButton(
              onPressed: () {},
              child: Text('+${features.length - 4} ميزة إضافية', style: GoogleFonts.cairo(fontSize: 12, color: color)),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: isCurrent ? null : () => _showPaymentBottomSheet(planId.isNotEmpty ? planId : name, price),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isCurrent ? 'الباقة الحالية' : 'اشترك الآن', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          )),
        ])),
      ]),
    );
  }

  Widget _buildPremiumCard() {
    final tier = _currentPremiumTier;
    final price = _premiumPrice;
    final sliderIndex = _premiumTiers.indexWhere((t) => t['students'] == _premiumStudents);
    final premiumPlan = _findPlan('premium');
    final premiumName = premiumPlan?['name_ar']?.toString() ?? premiumPlan?['name']?.toString() ?? 'المميزة (Premium)';
    final isCurrent = premiumPlan != null
        ? _currentPlanName.toLowerCase().contains((premiumPlan['name'] ?? '').toString().toLowerCase())
        : _currentPlanName.toLowerCase().contains('premium');
    final apiStorage = premiumPlan?['storage_limit_gb'];
    final storageDisplay = apiStorage != null
        ? (apiStorage >= 1024 ? '${(apiStorage / 1024).toStringAsFixed(1)}TB' : '${apiStorage}GB')
        : tier['storage'];
    final apiAssistants = premiumPlan?['max_assistants'] ?? tier['assistants'];
    final apiGrading = premiumPlan?['max_ai_grading']?.toString() ?? tier['grading']?.toString() ?? '2,000';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [GlassTheme.indigo, GlassTheme.indigo.withValues(alpha: 0.8)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.diamond, color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            Text(premiumName, style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
          ]),
          const SizedBox(height: 4),
          Text('نظام السعر المرن — اختر عدد الطلاب', style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$price', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 28, color: Colors.white)),
            const SizedBox(width: 4),
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('ج.م/${_isYearly ? 'سنة' : 'شهر'}', style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70))),
          ]),
          const SizedBox(height: 16),
          Text('عدد الطلاب: $_premiumStudents', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: Colors.white)),
          Slider(
            value: sliderIndex.toDouble(),
            min: 0,
            max: (_premiumTiers.length - 1).toDouble(),
            divisions: _premiumTiers.length - 1,
            activeColor: Colors.amber,
            inactiveColor: Colors.white24,
            onChanged: (v) {
              setState(() => _premiumStudents = _premiumTiers[v.round()]['students'] as int);
            },
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: _premiumTiers.map((t) =>
            Text('${t['students']}', style: GoogleFonts.cairo(fontSize: 10, color: Colors.white70))
          ).toList()),
          const SizedBox(height: 16),
          _buildPremiumFeature('المساعدين', '$apiAssistants'),
          _buildPremiumFeature('امتحانات AI/شهر', '20'),
          _buildPremiumFeature('تصحيح AI/شهر', '$apiGrading ورقة'),
          _buildPremiumFeature('التخزين', '$storageDisplay'),
          _buildPremiumFeature('الدعم الفني', 'VIP'),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: isCurrent ? null : () => _showPaymentBottomSheet('Premium', price),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isCurrent ? 'الباقة الحالية' : 'اشترك الآن', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          )),
        ])),
      ]),
    );
  }

  Widget _buildPremiumFeature(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        const Icon(Icons.check_circle, color: Colors.amber, size: 16),
        const SizedBox(width: 8),
        Text('$label: ', style: GoogleFonts.cairo(fontSize: 13, color: Colors.white70)),
        Text(value, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    );
  }

  Widget _buildGoldenCard() {
    final goldenPlan = _findPlan('golden');
    final isCurrent = goldenPlan != null
        ? _currentPlanName.toLowerCase().contains((goldenPlan['name'] ?? '').toString().toLowerCase())
        : _currentPlanName.toLowerCase().contains('golden');
    final goldenName = goldenPlan?['name_ar']?.toString() ?? goldenPlan?['name']?.toString() ?? 'الباقة الذهبية (Golden)';
    final gMonthly = (goldenPlan?['price_monthly'] ?? (goldenPlan?['price_egp'] ?? 20000)).toInt();
    final gYearly = (goldenPlan?['price_yearly'] ?? gMonthly * 10).toInt();
    final price = _isYearly ? gYearly : gMonthly;
    final gStudents = goldenPlan?['max_students'] ?? 40000;
    final gAssistants = goldenPlan?['max_assistants'] ?? 25;
    final gStorage = goldenPlan?['storage_limit_gb'];
    final storageDisplay = gStorage != null
        ? (gStorage >= 1024 ? '${(gStorage / 1024).toStringAsFixed(1)}TB' : '${gStorage}GB')
        : '2TB';
    final gGrading = goldenPlan?['max_ai_grading']?.toString() ?? '25,000';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.workspace_premium, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(goldenName, style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
          ]),
          const SizedBox(height: 4),
          Text('للسنترات الكبيرة — الدفع عبر إنستاباي فقط', style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (_isYearly && gMonthly > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 8),
                child: Text('${gMonthly * 12}', style: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white70, decoration: TextDecoration.lineThrough)),
              ),
            Text('$price', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 28, color: Colors.white)),
            const SizedBox(width: 4),
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('ج.م/${_isYearly ? 'سنة' : 'شهر'}', style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70))),
          ]),
          if (_isYearly && gMonthly > 0 && gYearly > 0) ...[
            const SizedBox(height: 4),
            Text('وفر ${(gMonthly * 12) - gYearly} ج.م سنوياً', style: GoogleFonts.cairo(fontSize: 11, color: Colors.white)),
          ],
          const SizedBox(height: 16),
          _buildGoldenFeature('الطلاب', '$gStudents'),
          _buildGoldenFeature('المساعدين', '$gAssistants'),
          _buildGoldenFeature('امتحانات AI/شهر', '20'),
          _buildGoldenFeature('تصحيح AI/شهر', '$gGrading ورقة'),
          _buildGoldenFeature('التخزين', storageDisplay),
          _buildGoldenFeature('الدعم الفني', 'VIP مخصص'),
          _buildGoldenFeature('طريقة الدفع', 'إنستاباي فقط'),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: isCurrent ? null : () => _showPaymentBottomSheet('Golden', price),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFB8860B),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isCurrent ? 'الباقة الحالية' : 'اشترك الآن', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          )),
        ])),
      ]),
    );
  }

  Widget _buildGoldenFeature(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text('$label: ', style: GoogleFonts.cairo(fontSize: 13, color: Colors.white70)),
        Text(value, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    );
  }

  void _showPaymentBottomSheet(String planName, int amount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PaymentBottomSheet(
        planName: planName,
        amount: amount,
        billingPeriod: _isYearly ? 'yearly' : 'monthly',
        maxStudents: planName == 'Premium' ? _premiumStudents : null,
      ),
    );
  }
}

class _PaymentBottomSheet extends StatefulWidget {
  final String planName;
  final int amount;
  final String billingPeriod;
  final int? maxStudents;
  const _PaymentBottomSheet({required this.planName, required this.amount, required this.billingPeriod, this.maxStudents});

  @override
  State<_PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<_PaymentBottomSheet> {
  String _method = 'vodafone_cash';
  final _phoneCtrl = TextEditingController();
  String? _screenshotPath;
  bool _submitting = false;

  bool get _isGolden => widget.planName == 'Golden';

  @override
  void initState() {
    super.initState();
    if (_isGolden) _method = 'instapay';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: GlassTheme.background(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('اشتراك ${widget.planName}', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 4),
          Text('${widget.amount} ج.م', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 24, color: GlassTheme.indigo)),
        ])),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('طريقة الدفع', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_isGolden)
            _methodTile('instapay', 'إنستاباي (مدى فقط)', Icons.account_balance)
          else
            Row(children: [
              _methodTile('vodafone_cash', 'فودافون كاش', Icons.phone_android),
              const SizedBox(width: 8),
              _methodTile('instapay', 'إنستاباي', Icons.account_balance),
            ]),
          const SizedBox(height: 16),
          TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(
            labelText: 'رقم الهاتف', prefixIcon: const Icon(Icons.phone),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          )),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final file = await NativeFilePicker.pickImage();
              if (file != null) setState(() => _screenshotPath = file.path);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _screenshotPath != null ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _screenshotPath != null ? Colors.green.shade300 : Colors.grey.shade300),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_screenshotPath != null ? Icons.check_circle : Icons.camera_alt, color: _screenshotPath != null ? Colors.green : Colors.grey),
                const SizedBox(width: 8),
                Text(_screenshotPath != null ? 'تم اختيار الصورة ✓' : 'رفع صورة الإثبات', style: TextStyle(color: _screenshotPath != null ? Colors.green : Colors.grey)),
              ]),
            ),
          ),
        ])),
        const Spacer(),
        Padding(padding: const EdgeInsets.all(20), child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: _submitting ? const CircularProgressIndicator(color: Colors.white) : Text('إرسال طلب الدفع', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        )),
      ]),
    );
  }

  Widget _methodTile(String value, String label, IconData icon) {
    final selected = _method == value;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _method = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? GlassTheme.indigo.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? GlassTheme.indigo : Colors.grey.shade300),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: selected ? GlassTheme.indigo : Colors.grey),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? GlassTheme.indigo : Colors.grey)),
        ]),
      ),
    ));
  }

  Future<void> _submit() async {
    if (_phoneCtrl.text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final api = ApiService();
      if (_screenshotPath != null) {
        final file = File(_screenshotPath!);
        final bytes = await file.readAsBytes();
        final fileName = _screenshotPath!.split('/').last;
        final formData = FormData.fromMap({
          'plan_name': widget.planName,
          'amount': widget.amount,
          'phone_number': _phoneCtrl.text,
          'payment_method': _method,
          'billing_period': widget.billingPeriod,
          if (widget.maxStudents != null) 'max_students': widget.maxStudents,
          'screenshot': MultipartFile.fromBytes(bytes, filename: fileName),
        });
        await api.dio.post('/payments/request', data: formData);
      } else {
        await api.dio.post('/payments/request', data: {
          'plan_name': widget.planName,
          'amount': widget.amount,
          'phone_number': _phoneCtrl.text,
          'payment_method': _method,
          'billing_period': widget.billingPeriod,
          if (widget.maxStudents != null) 'max_students': widget.maxStudents,
        });
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب الدفع — في انتظار المراجعة'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _submitting = false);
  }
}
