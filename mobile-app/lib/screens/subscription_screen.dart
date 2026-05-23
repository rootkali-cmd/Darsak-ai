import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
          price: 'مجاناً',
          features: ['عرض الدرجات', 'متابعة الحضور', 'الملف الشخصي'],
          isPopular: false,
        ),
        const SizedBox(height: 12),
        _buildPlanCard(
          name: 'الباقة المميزة',
          price: 'اشتراك شهري',
          features: [
            'كل مزايا الأساسية',
            'إشعارات فورية',
            'تقارير أداء أسبوعية',
            'دعم فني متميز',
          ],
          isPopular: true,
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String name,
    required String price,
    required List<String> features,
    required bool isPopular,
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
          Text(price, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
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
