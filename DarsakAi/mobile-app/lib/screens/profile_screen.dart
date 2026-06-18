import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../providers/theme_provider.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/account_manager.dart';

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
            // Student name and code
            Text(
              student.fullName,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              student.code,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: Personal Info
            _buildSection(
              title: 'المعلومات الشخصية',
              icon: Icons.person_outline,
              children: [
                _InfoRow(label: 'رقم الهاتف', value: student.phone ?? '-'),
                Divider(color: AppColors.border(context), height: 16),
                _InfoRow(label: 'رقم ولي الأمر', value: student.parentPhone ?? '-'),
                Divider(color: AppColors.border(context), height: 16),
                _InfoRow(label: 'المستوى', value: student.gradeLevel ?? '-'),
              ],
            ),
            const SizedBox(height: 12),

            // Section 2: Academic Info
            _buildSection(
              title: 'المعلومات الدراسية',
              icon: Icons.school_outlined,
              children: [
                _InfoRow(
                  label: 'متوسط الدرجات',
                  value: '${data.averageGrade.toStringAsFixed(1)}%',
                ),
                Divider(color: AppColors.border(context), height: 16),
                _InfoRow(
                  label: 'نسبة الحضور',
                  value: '${data.attendanceRate.toStringAsFixed(0)}%',
                ),
                Divider(color: AppColors.border(context), height: 16),
                _InfoRow(label: 'عدد الدرجات', value: '${data.grades.length}'),
              ],
            ),
            const SizedBox(height: 12),

            // Section 3: PIN Change
            _buildSection(
              title: 'الرمز السري',
              icon: Icons.lock_outline,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تغيير الرمز السري',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () => _showPinChangeDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: const Text(
                          'تغيير',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Section: Account Switcher
            _buildAccountsSection(context, auth),
            const SizedBox(height: 12),

            // Theme toggle
            _buildThemeToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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
          Row(
            children: [
              Icon(icon, color: AppTheme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
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
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.bold,
              ),
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

  Widget _buildAccountsSection(BuildContext context, AuthProvider auth) {
    final accounts = auth.accountManager.accounts;
    final activeIndex = auth.accountManager.activeIndex;

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
          Row(
            children: [
              Icon(Icons.swap_horiz, color: AppTheme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'الحسابات',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '${accounts.length}/5',
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showAddAccountDialog(context, auth),
                child: Icon(Icons.add_circle_outline, color: AppTheme.accent, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(accounts.length, (i) {
            final acc = accounts[i];
            final isActive = i == activeIndex;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.accent.withValues(alpha: 0.1) : AppColors.inputFill(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? AppTheme.accent.withValues(alpha: 0.3) : AppColors.border(context),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 18,
                    color: isActive ? AppTheme.accent : AppColors.textSecondary(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          acc.studentName.isNotEmpty ? acc.studentName : acc.studentCode,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          acc.studentCode,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                        ),
                      ],
                    ),
                  ),
                  if (!isActive)
                    GestureDetector(
                      onTap: () async {
                        await auth.switchAccount(i);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('切换', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (accounts.length > 1)
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                      onPressed: () => _confirmRemoveAccount(context, auth, i),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context, AuthProvider auth) {
    final codeController = TextEditingController();
    final pinController = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.dialogBackground(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.person_add_outlined, color: AppTheme.accent, size: 22),
            const SizedBox(width: 8),
            Text('إضافة حساب', style: TextStyle(color: AppColors.textPrimary(context))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'أدخل كود الطالب والرمز السري',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'كود الطالب',
                  hintStyle: TextStyle(color: AppColors.textSecondary(context)),
                  filled: true,
                  fillColor: AppColors.inputFill(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinController,
                textAlign: TextAlign.center,
                obscureText: true,
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'الرمز السري',
                  hintStyle: TextStyle(color: AppColors.textSecondary(context)),
                  filled: true,
                  fillColor: AppColors.inputFill(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: TextStyle(color: AppColors.textSecondary(context))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: loading ? null : () async {
                if (codeController.text.isEmpty || pinController.text.isEmpty) return;
                setState(() => loading = true);
                final success = await auth.addAccount(codeController.text, pinController.text);
                setState(() => loading = false);
                if (ctx.mounted) Navigator.pop(ctx);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت إضافة الحساب بنجاح'), backgroundColor: AppTheme.success),
                  );
                } else if (auth.error != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(auth.error!), backgroundColor: AppTheme.danger),
                  );
                }
              },
              child: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('إضافة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveAccount(BuildContext context, AuthProvider auth, int index) {
    final acc = auth.accountManager.accounts[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.dialogBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الحساب', style: TextStyle(color: AppTheme.danger)),
        content: Text(
          'هل تريد حذف حساب ${acc.studentName.isNotEmpty ? acc.studentName : acc.studentCode}؟',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: TextStyle(color: AppColors.textSecondary(context)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              Navigator.pop(ctx);
              auth.removeAccount(index);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
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
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textPrimary(context)),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(8),
              ],
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
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textPrimary(context)),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(8),
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
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textPrimary(context)),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(8),
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
              final oldPin = oldPinController.text.trim();
              final newPin = newPinController.text.trim();
              final confirmPin = confirmPinController.text.trim();
              if (newPin != confirmPin) {
                Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN غير متطابق'), backgroundColor: AppTheme.danger));
                return;
              }
              if (newPin.length < 6 || newPin.length > 8) {
                Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN يجب أن يكون 6-8 أحرف وأرقام'), backgroundColor: AppTheme.danger));
                return;
              }
              if (oldPin.isEmpty) {
                Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل PIN الحالي'), backgroundColor: AppTheme.danger));
                return;
              }
              try {
                await api.changePin(oldPin, newPin);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير PIN بنجاح'), backgroundColor: AppTheme.success));
              } catch (e) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!context.mounted) return;
                final msg = e.toString().contains('401') ? 'PIN الحالي غير صحيح' : 'فشل تغيير PIN';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.danger));
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
