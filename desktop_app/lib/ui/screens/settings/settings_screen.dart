import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/user.dart';
import '../../../core/utils/constants.dart';
import '../../../core/database/database_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const SettingsScreen({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _apiClient = ApiClient();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _changingPassword = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final old = _oldPasswordController.text;
    final newPwd = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (old.isEmpty || newPwd.isEmpty || confirm.isEmpty) {
      _showSnackbar('يرجى ملء جميع الحقول', isError: true);
      return;
    }
    if (newPwd.length < 6) {
      _showSnackbar('كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل', isError: true);
      return;
    }
    if (newPwd != confirm) {
      _showSnackbar('كلمة المرور الجديدة غير متطابقة', isError: true);
      return;
    }

    setState(() => _changingPassword = true);
    try {
      await _apiClient.post('/auth/change-password', data: {
        'old_password': old,
        'new_password': newPwd,
      });
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (!mounted) return;
      _showSnackbar('تم تغيير كلمة المرور بنجاح');
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('فشل تغيير كلمة المرور', isError: true);
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Future<void> _confirmClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'مسح البيانات المحلية',
        message: 'هل أنت متأكد من مسح جميع البيانات المخزنة محلياً؟ لا يمكن التراجع عن هذا الإجراء.',
        confirmLabel: 'مسح',
        isDanger: true,
      ),
    );
    if (confirmed != true) return;
    try {
      final db = DatabaseService.instance;
      for (final table in [
        DbConstants.studentsTable,
        DbConstants.groupsTable,
        DbConstants.attendanceTable,
        DbConstants.gradesTable,
        DbConstants.invoicesTable,
        DbConstants.paymentsTable,
        DbConstants.syncQueueTable,
        DbConstants.deadLetterTable,
        DbConstants.syncCursorsTable,
        DbConstants.settingsTable,
        DbConstants.conflictLogsTable,
      ]) {
        db.db.execute('DELETE FROM $table');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(PrefKeys.cachedUserId);
      await prefs.remove(PrefKeys.cachedUserName);
      await prefs.remove(PrefKeys.cachedUserEmail);
      await prefs.remove(PrefKeys.cachedUserRole);
      await prefs.remove(PrefKeys.cachedUserCode);
      await prefs.remove(PrefKeys.cachedUserIsActive);
      await prefs.remove(PrefKeys.cachedUserCreatedAt);
      await prefs.remove(PrefKeys.subscriptionData);
      if (!mounted) return;
      _showSnackbar('تم مسح البيانات المحلية بنجاح');
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('فشل مسح البيانات', isError: true);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'تسجيل الخروج',
        message: 'هل أنت متأكد من تسجيل الخروج؟',
        confirmLabel: 'تسجيل الخروج',
        isDanger: true,
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    context.read<AuthProvider>().logout();
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = widget.themeMode == ThemeMode.dark;

    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإعدادات',
              style: TextStyle(
                color: textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              title: 'الملف الشخصي',
              icon: Icons.person_outline,
              textPrimary: textPrimary,
              textMuted: textMuted,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileField(label: 'الاسم', value: user?.fullName ?? '-', textMuted: textMuted, textPrimary: textPrimary),
                  const SizedBox(height: 12),
                  _ProfileField(label: 'البريد الإلكتروني', value: user?.email ?? '-', textMuted: textMuted, textPrimary: textPrimary),
                  const SizedBox(height: 12),
                  _ProfileField(label: 'الدور', value: _roleDisplay(user?.role), textMuted: textMuted, textPrimary: textPrimary),
                  const SizedBox(height: 12),
                  _ProfileField(label: 'كود المدرس', value: user?.teacherCode ?? '-', textMuted: textMuted, textPrimary: textPrimary),
                  const SizedBox(height: 16),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: () => _showEditNameDialog(user, textPrimary, surfaceColor, borderColor),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('تعديل الاسم'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildSection(
              title: 'تغيير كلمة المرور',
              icon: Icons.lock_outline,
              textPrimary: textPrimary,
              textMuted: textMuted,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _oldPasswordController,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور القديمة',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureOld ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureOld = !_obscureOld),
                      ),
                    ),
                    obscureText: _obscureOld,
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    obscureText: _obscureNew,
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور الجديدة',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    obscureText: _obscureConfirm,
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 16),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _changingPassword ? null : _changePassword,
                        child: _changingPassword
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('حفظ'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildSection(
              title: 'المظهر',
              icon: Icons.palette_outlined,
              textPrimary: textPrimary,
              textMuted: textMuted,
              child: Row(
                children: [
                  Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: isDark ? AppTheme.warning : AppTheme.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isDark ? 'الوضع الداكن' : 'الوضع الفاتح',
                    style: TextStyle(color: textPrimary, fontSize: 14),
                  ),
                  const Spacer(),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Switch(
                      value: isDark,
                      onChanged: (_) => widget.toggleTheme(),
                      activeThumbColor: AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildSection(
              title: 'حول التطبيق',
              icon: Icons.info_outline,
              textPrimary: textPrimary,
              textMuted: textMuted,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AboutRow(label: 'اسم التطبيق', value: AppConstants.appName, textMuted: textMuted, textPrimary: textPrimary),
                  const SizedBox(height: 10),
                  _AboutRow(label: 'الإصدار', value: 'v${AppConstants.appVersion}', textMuted: textMuted, textPrimary: textPrimary),
                  const SizedBox(height: 10),
                  _AboutRow(label: 'رقم البناء', value: '1', textMuted: textMuted, textPrimary: textPrimary),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildSection(
              title: 'المنطقة الخطرة',
              icon: Icons.warning_amber_rounded,
              textPrimary: textPrimary,
              textMuted: textMuted,
              dangerBorder: true,
              child: Column(
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _confirmClearData,
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        label: const Text('مسح البيانات المحلية'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: const BorderSide(color: AppTheme.danger),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _confirmLogout,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('تسجيل الخروج'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _roleDisplay(String? role) {
    switch (role) {
      case 'admin':
        return 'مدير';
      case 'teacher':
        return 'مدرس';
      case 'assistant':
        return 'مساعد';
      default:
        return role ?? '-';
    }
  }

  Future<void> _showEditNameDialog(
    UserModel? user,
    Color textPrimary,
    Color surfaceColor,
    Color borderColor,
  ) async {
    final controller = TextEditingController(text: user?.fullName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        title: Text('تعديل الاسم', style: TextStyle(color: textPrimary)),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'الاسم الكامل'),
            autofocus: true,
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
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('حفظ'),
            ),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || result == user?.fullName) return;

    try {
      await _apiClient.patch('/auth/profile', data: {'full_name': result});
      await context.read<AuthProvider>().loadUser();
      if (!mounted) return;
      _showSnackbar('تم تحديث الاسم بنجاح');
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('فشل تحديث الاسم', isError: true);
    }
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color textPrimary,
    required Color textMuted,
    bool dangerBorder = false,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: dangerBorder ? AppTheme.danger : AppTheme.accent,
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: dangerBorder ? AppTheme.danger : textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final String value;
  final Color textMuted;
  final Color textPrimary;

  const _ProfileField({
    required this.label,
    required this.value,
    required this.textMuted,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(color: textMuted, fontSize: 14)),
        ),
        Expanded(
          child: Text(value, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textMuted;
  final Color textPrimary;

  const _AboutRow({
    required this.label,
    required this.value,
    required this.textMuted,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: textMuted, fontSize: 14)),
        Text(value, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDanger;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    return AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      title: Row(
        children: [
          Icon(
            isDanger ? Icons.warning_amber_rounded : Icons.info_outline,
            color: isDanger ? AppTheme.danger : AppTheme.accent,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(color: textPrimary, fontSize: 16)),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          fontSize: 14,
        ),
      ),
      actions: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDanger ? AppTheme.danger : AppTheme.accent,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ),
      ],
    );
  }
}
