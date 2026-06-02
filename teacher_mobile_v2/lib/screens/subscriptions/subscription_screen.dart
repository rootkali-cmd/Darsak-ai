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
  Map<String, dynamic>? _currentSub;
  List<dynamic> _plans = [];
  bool _loading = true;
  String? _error;

  final _codeCtrl = TextEditingController();
  bool _activating = false;

  final _phoneCtrl = TextEditingController(text: '01000000000');
  final _amountCtrl = TextEditingController();
  File? _screenshot;
  bool _uploading = false;

  static const _trialPlanNames = ['basic', 'أساسي', 'باقة أساسية'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ApiService();
      final meResp = await api.dio.get('/auth/me');
      final me = meResp.data is Map ? meResp.data as Map<String, dynamic> : <String, dynamic>{};
      _currentSub = me['subscription'] is Map ? Map<String, dynamic>.from(me['subscription']) : null;

      final plansResp = await api.dio.get('/subscriptions/plans');
      _plans = plansResp.data is List ? plansResp.data : [];
    } on DioException catch (e) {
      _error = 'فشل التحميل: ${getDioErrorMessage(e)}';
    } catch (e) {
      _error = 'خطأ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  bool _isBasicPlan(Map<String, dynamic> plan) {
    final name = (plan['name'] ?? '').toString().toLowerCase();
    return _trialPlanNames.any((t) => name.contains(t.toLowerCase()));
  }

  bool _isTrialEligible(Map<String, dynamic> plan) {
    return _currentSub == null && _isBasicPlan(plan);
  }

  Future<void> _activateTrial() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiService().dio.post('/subscriptions/activate-trial');
      final data = resp.data is Map ? resp.data as Map<String, dynamic> : <String, dynamic>{};
      final daysRemaining = data['days_remaining'] ?? 30;
      _showMsg('تم تفعيل الفترة التجريبية بنجاح! متبقي $daysRemaining يوم', AppTheme.success);
      await _loadData();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showMsg('فشل تفعيل الفترة التجريبية. حاول لاحقاً', AppTheme.danger);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showTrialDialog(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
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

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;

    final ext = file.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      _showMsg('يرجى اختيار صورة فقط (JPG, PNG, WEBP)', AppTheme.warning);
      return;
    }

    final size = await File(file.path).length();
    if (size > 10 * 1024 * 1024) {
      _showMsg('حجم الصورة كبير جداً (الحد الأقصى 10MB)', AppTheme.warning);
      return;
    }

    setState(() => _screenshot = File(file.path));
  }

  Future<void> _submitPayment() async {
    final phone = _phoneCtrl.text.trim();
    final amount = _amountCtrl.text.trim();
    if (phone.isEmpty || amount.isEmpty) {
      _showMsg('أدخل رقم الهاتف والمبلغ', AppTheme.warning);
      return;
    }
    if (_screenshot == null) {
      _showMsg('يرجى إرفاق لقطة شاشة للتحويل', AppTheme.warning);
      return;
    }

    setState(() => _uploading = true);
    try {
      final formData = FormData.fromMap({
        'phone_number': phone,
        'amount': amount,
        'screenshot': await MultipartFile.fromFile(_screenshot!.path, filename: 'screenshot.${_screenshot!.path.split(".").last}'),
      });
      await ApiService().dio.post('/subscriptions/payment-request', data: formData);
      _showMsg('تم إرسال طلب الدفع بنجاح. سنتواصل معك قريباً', AppTheme.success);
      _screenshot = null;
      _amountCtrl.clear();
    } catch (e) {
      _showMsg('فشل الإرسال: $e', AppTheme.danger);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showMsg(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الاشتراك')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!), const SizedBox(height: 12),
                  ElevatedButton(onPressed: _loadData, child: const Text('إعادة المحاولة')),
                ]))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    if (_currentSub != null) ...[_buildCurrentPlan(), const SizedBox(height: 24)],
                    _buildActivationCard(),
                    const SizedBox(height: 24),
                    const Text('الباقات المتاحة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._plans.map((p) => _buildPlanCard(p)),
                    const SizedBox(height: 32),
                    _buildPaymentForm(),
                    const SizedBox(height: 24),
                    _buildPaymentInfo(),
                  ]),
                ),
    );
  }

  Widget _buildCurrentPlan() {
    return Card(
      color: AppTheme.success.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.check_circle, color: AppTheme.success, size: 28),
            const SizedBox(width: 10),
            const Text('باقتك الحالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          _InfoRow(label: 'الباقة', value: _currentSub!['plan_name']?.toString() ?? _currentSub!['name']?.toString() ?? '—'),
          _InfoRow(label: 'الحالة', value: 'نشطة', color: AppTheme.success),
          if (_currentSub!['expires_at'] != null)
            _InfoRow(label: 'تنتهي في', value: _currentSub!['expires_at'].toString().substring(0, 10)),
          if (_currentSub!['max_students'] != null)
            _InfoRow(label: 'الطلاب', value: _currentSub!['max_students'].toString()),
        ]),
      ),
    );
  }

  Widget _buildActivationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('تفعيل كود اشتراك', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _codeCtrl, decoration: const InputDecoration(hintText: 'XXXX-XXXX-XXXX'))),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _activating ? null : _activateCode, child: Text(_activating ? 'جاري...' : 'تفعيل')),
          ]),
        ]),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final name = plan['name'] ?? '';
    final price = plan['price_egp'] ?? plan['price'] ?? 0;
    final features = plan['features_json'] is List ? plan['features_json'] as List : <dynamic>[];
    final students = plan['max_students'];
    final aiReq = plan['max_ai_requests'];
    final isTrialEligible = _isTrialEligible(plan);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (isTrialEligible)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.warning, AppTheme.warning.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_offer_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('30 يوم مجاناً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(name.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accent)),
            Text('$price ج.م', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          if (students != null) Text('👥 ${students == -1 ? 'غير محدود' : '$students طالب'}'),
          if (aiReq != null) Text('🤖 $aiReq طلبات AI/شهر'),
          if (features.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(children: [
                    const Icon(Icons.check, size: 16, color: AppTheme.success),
                    const SizedBox(width: 4),
                    Expanded(child: Text(f.toString(), style: const TextStyle(fontSize: 13))),
                  ]),
                )),
          ],
          if (isTrialEligible) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showTrialDialog(plan),
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: const Text('تفعيل مجاني'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.payment, color: AppTheme.accent),
            SizedBox(width: 8),
            Text('طلب اشتراك جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          const Text('حوّل المبلغ على فودافون كاش وأرفق لقطة الشاشة', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(const ClipboardData(text: '01000000000'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم نسخ رقم فودافون كاش'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.copy, size: 20, color: AppTheme.accent),
                SizedBox(width: 8),
                Text('01000000000', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppTheme.accent)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'رقم هاتفك', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone)),
            const SizedBox(width: 8),
            SizedBox(width: 130, child: TextField(controller: _amountCtrl, decoration: const InputDecoration(labelText: 'المبلغ (ج.م)', prefixIcon: Icon(Icons.money)), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 12),
          if (_screenshot != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(children: [
                Image.file(_screenshot!, height: 200, width: double.infinity, fit: BoxFit.cover),
                Positioned(top: 8, right: 8, child: GestureDetector(
                    onTap: () => setState(() => _screenshot = null),
                    child: const CircleAvatar(radius: 14, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 18, color: Colors.white)),
                  )),
              ]),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickScreenshot,
                icon: const Icon(Icons.camera_alt),
                label: Text(_screenshot != null ? 'تغيير الصورة' : 'رفع لقطة الشاشة'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accent, side: const BorderSide(color: AppTheme.accent)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploading ? null : _submitPayment,
              icon: _uploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
              label: Text(_uploading ? 'جاري الإرسال...' : 'إرسال الطلب'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.info_outline, color: AppTheme.accent),
            SizedBox(width: 8),
            Text('معلومات الدفع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          const Text('فودافون كاش', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(const ClipboardData(text: '01000000000'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم نسخ رقم فودافون كاش'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.copy, size: 18, color: AppTheme.primary),
                SizedBox(width: 10),
                Text('01000000000', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo', letterSpacing: 2, color: AppTheme.primary)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          const Text('إنستاباي', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
            ),
            child: const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.qr_code_2, size: 48, color: AppTheme.textMuted),
                SizedBox(height: 8),
                Text('QR إنستاباي قريباً', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openWhatsApp,
              icon: const Icon(Icons.support_agent),
              label: const Text('للتواصل مع الدعم الفني'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.success,
                side: const BorderSide(color: AppTheme.success),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    const phone = '201000000000';
    const message = 'مرحباً، أحتاج مساعدة بخصوص الاشتراك في تطبيق درسك AI';
    final url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب'), backgroundColor: AppTheme.danger),
      );
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _InfoRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
