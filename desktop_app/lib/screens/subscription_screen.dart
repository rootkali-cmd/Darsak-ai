import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _subscriptionService = SubscriptionService();
  Map<String, dynamic>? _subscription;
  List<dynamic> _plans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final sub = await _subscriptionService.getMySubscription();
    if (sub != null) {
      await _subscriptionService.cacheSubscription(sub);
    }
    final cached = await _subscriptionService.getCachedSubscription();
    final plans = await _subscriptionService.getPlans();
    if (!mounted) return;
    setState(() {
      _subscription = sub ?? cached;
      _plans = plans;
      _isLoading = false;
    });
  }

  void _showActivateDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        title: Text('تفعيل كود الاشتراك', style: TextStyle(color: textPrimary)),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: codeController,
            decoration: const InputDecoration(
              labelText: 'كود التفعيل',
              hintText: 'XXXX-XXXX-XXXX-XXXX',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, letterSpacing: 2),
          ),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: () async {
                final code = codeController.text.trim();
                if (code.isEmpty) return;
                try {
                  await _subscriptionService.activateCode(code);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  await _loadData();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تفعيل الاشتراك بنجاح'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (_) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('فشل التفعيل: تأكد من صحة الكود'),
                      backgroundColor: AppTheme.danger,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('تفعيل'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الاشتراكات',
              style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (_subscription != null)
              _buildCurrentSubscription(isDark, textPrimary, textSecondary, textMuted)
            else
              _buildPlans(isDark, textPrimary, textSecondary, textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSubscription(bool isDark, Color textPrimary, Color textSecondary, Color textMuted) {
    final isActive = _subscriptionService.isSubscriptionActive(_subscription);
    final remainingDays = _subscriptionService.getRemainingDays(_subscription);
    final planName = _subscription?['plan_name']?.toString() ?? 'الباقة الحالية';
    final expiryDate = _subscription?['expires_at']?.toString() ?? '--';
    final studentLimit = _subscription?['student_limit']?.toString() ?? '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
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
                          Text(
                            planName,
                            style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppTheme.success.withValues(alpha: 0.15)
                                  : AppTheme.danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isActive ? 'نشط' : remainingDays <= 0 ? 'منتهي' : 'غير مشترك',
                              style: TextStyle(
                                color: isActive ? AppTheme.success : AppTheme.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
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
                _buildInfoRow('الأيام المتبقية', '$remainingDays يوم', textMuted, textPrimary,
                    valueColor: isActive ? AppTheme.success : AppTheme.danger),
                const SizedBox(height: 12),
                _buildInfoRow('الحد الأقصى للطلاب', studentLimit, textMuted, textPrimary),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showActivateDialog,
                    icon: const Icon(Icons.vpn_key, size: 18),
                    label: const Text('تفعيل كود'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('تحديث'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, Color textMuted, Color textPrimary, {Color? valueColor}) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: TextStyle(color: textMuted, fontSize: 14)),
        ),
        Text(
          value,
          style: TextStyle(color: valueColor ?? textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPlans(bool isDark, Color textPrimary, Color textSecondary, Color textMuted) {
    final plansToShow = _plans.isNotEmpty ? _plans : _defaultPlans;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('الباقات المتاحة', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ElevatedButton.icon(
                onPressed: _showActivateDialog,
                icon: const Icon(Icons.vpn_key, size: 18),
                label: const Text('تفعيل كود'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (plansToShow.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text('لا توجد باقات متاحة حالياً', style: TextStyle(color: textMuted)),
            ),
          )
        else
          ...plansToShow.map((plan) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildPlanCard(plan, isDark, textPrimary, textSecondary, textMuted),
              )),
      ],
    );
  }

  Widget _buildPlanCard(dynamic plan, bool isDark, Color textPrimary, Color textSecondary, Color textMuted) {
    final name = plan['name']?.toString() ?? 'باقة';
    final price = plan['price']?.toString() ?? '--';
    final features = plan['features'] ?? [];
    final isPopular = plan['popular'] == true;
    final studentLimit = plan['student_limit']?.toString() ?? '--';
    final duration = plan['duration']?.toString() ?? '--';

    final surfaceColor = isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPopular ? AppTheme.accent.withValues(alpha: 0.5) : Colors.transparent,
          ),
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
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('الأكثر طلباً',
                              style: TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('$price ر.س / $duration', style: TextStyle(color: AppTheme.accent, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (features is List)
                    ...features.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                              const SizedBox(width: 8),
                              Text(f.toString(), style: TextStyle(color: textSecondary, fontSize: 13)),
                            ],
                          ),
                        )),
                ],
              ),
            ),
            Container(
              width: 180,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text('الحد الأقصى', style: TextStyle(color: textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('$studentLimit طالب', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text('المدة', style: TextStyle(color: textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(duration, style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
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
        'name': 'الباقة الأساسية',
        'price': '99',
        'duration': 'شهرياً',
        'student_limit': '30',
        'popular': false,
        'features': ['إدارة الطلاب', 'تسجيل الحضور', 'إنشاء المجموعات', 'تقارير أساسية'],
      },
      {
        'name': 'الباقة المتقدمة',
        'price': '199',
        'duration': 'شهرياً',
        'student_limit': '100',
        'popular': true,
        'features': ['كل مزايا الأساسية', 'تحليل الأداء', 'الفواتير', 'QR Code', 'تقارير متقدمة'],
      },
      {
        'name': 'الباقة الاحترافية',
        'price': '399',
        'duration': 'شهرياً',
        'student_limit': 'غير محدود',
        'popular': false,
        'features': ['كل مزايا المتقدمة', 'عدد غير محدود من الطلاب', 'دعم فني مميز', 'تصدير البيانات', 'امتيازات حصرية'],
      },
    ];
  }
}
