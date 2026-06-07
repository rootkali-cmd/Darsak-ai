import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../providers/theme_provider.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();
    final student = auth.student;

    if (student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('الملف الشخصي')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.accent),
            onPressed: _showVersionInfo,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.danger),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Center(
                child: Text(
                  student.initials,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(student.fullName, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 20, fontWeight: FontWeight.bold)),
            Text(student.code, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14)),
            const SizedBox(height: 24),
            _buildThemeToggle(),
            const SizedBox(height: 16),
            _buildInfoCard(student, data),
            const SizedBox(height: 16),
            _buildPinChangeSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    final themeNotifier = context.watch<ThemeNotifier>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(
            themeNotifier.isDark ? Icons.dark_mode : Icons.light_mode,
            color: AppTheme.accent,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              themeNotifier.isDark ? 'الوضع الداكن' : 'الوضع الفاتح',
              style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold),
            ),
          ),
          Switch(
            value: !themeNotifier.isDark,
            onChanged: (_) => themeNotifier.toggleTheme(),
            activeColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(dynamic student, DataProvider data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          _InfoRow(label: 'رقم الهاتف', value: student.phone ?? '-'),
          Divider(color: AppColors.border(context), height: 16),
          _InfoRow(label: 'رقم ولي الأمر', value: student.parentPhone ?? '-'),
          Divider(color: AppColors.border(context), height: 16),
          _InfoRow(label: 'المستوى', value: student.gradeLevel ?? '-'),
          Divider(color: AppColors.border(context), height: 16),
          _InfoRow(label: 'حالة الدفع', value: data.isPaidThisMonth ? 'مدفوع' : 'غير مدفوع',
              valueColor: data.isPaidThisMonth ? AppTheme.success : AppTheme.danger),
          Divider(color: AppColors.border(context), height: 16),
          _InfoRow(label: 'متوسط الدرجات', value: '${data.averageGrade.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildPinChangeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تغيير PIN', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showPinChangeDialog(context),
              icon: const Icon(Icons.lock_reset, size: 18),
              label: const Text('تغيير الرقم السري'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPinChangeDialog(BuildContext context) {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final api = ApiService();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.dialogBackground(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border(context)),
        ),
        title: Text('تغيير PIN', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPinController,
              obscureText: true,
              style: TextStyle(color: AppColors.textPrimary(context)),
              decoration: InputDecoration(
                labelText: 'PIN الحالي',
                labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                filled: true,
                fillColor: AppColors.inputFill(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPinController,
              obscureText: true,
              style: TextStyle(color: AppColors.textPrimary(context)),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
              decoration: InputDecoration(
                labelText: 'PIN الجديد (6-8 أحرف وأرقام)',
                labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                filled: true,
                fillColor: AppColors.inputFill(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPinController,
              obscureText: true,
              style: TextStyle(color: AppColors.textPrimary(context)),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
              decoration: InputDecoration(
                labelText: 'تأكيد PIN الجديد',
                labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                filled: true,
                fillColor: AppColors.inputFill(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPin = newPinController.text.trim();
              final confirmPin = confirmPinController.text.trim();
              if (newPin != confirmPin) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN غير متطابق'), backgroundColor: AppTheme.danger));
                return;
              }
              if (newPin.length < 6 || newPin.length > 8) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN يجب أن يكون 6-8 أحرف وأرقام'), backgroundColor: AppTheme.danger));
                return;
              }
              try {
                await api.changePin(oldPinController.text.trim(), newPin);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير PIN بنجاح'), backgroundColor: AppTheme.success));
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(e.toString().contains('401') ? 'PIN الحالي غير صحيح' : 'فشل تغيير PIN'),
                  backgroundColor: AppTheme.danger,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('تغيير'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.dialogBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border(context))),
        title: Text('تسجيل الخروج', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Text('هل أنت متأكد من تسجيل الخروج؟', style: TextStyle(color: AppColors.textSecondary(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }

  void _showVersionInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.dialogBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('معلومات التطبيق', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('الاسم', 'DarsakAI'),
            const SizedBox(height: 8),
            _buildInfoRow('الإصدار', AppConstants.appVersion),
            const SizedBox(height: 8),
            _buildInfoRow('المنصة', 'Android'),
            const SizedBox(height: 8),
            _buildInfoRow('النظام', 'Android 6.0+'),
            const SizedBox(height: 8),
            _buildInfoRow('المطور', 'DarsakAI Team'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
        Text(value, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
        Text(value, style: TextStyle(color: valueColor ?? AppColors.textPrimary(context), fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
