import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
  List<dynamic> _supportLinks = [];
  bool _loadingLinks = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSupportLinks());
  }

  Future<void> _loadSupportLinks() async {
    final teacherId = context.read<AuthProvider>().student?.teacherId;
    if (teacherId == null || teacherId.isEmpty) return;
    setState(() => _loadingLinks = true);
    try {
      final links = await ApiService().getTeacherSupportLinks(teacherId);
      if (mounted) setState(() => _supportLinks = links);
    } catch (_) {}
    if (mounted) setState(() => _loadingLinks = false);
  }

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
                if (!student.isOnlineStudent) ...[
                  Divider(color: AppColors.border(context), height: 16),
                  _InfoRow(
                    label: 'نسبة الحضور',
                    value: '${data.attendanceRate.toStringAsFixed(0)}%',
                  ),
                ],
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

            // Theme toggle
            _buildThemeToggle(),
            const SizedBox(height: 12),

            // Support Links
            if (_loadingLinks)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_supportLinks.isNotEmpty) ...[
              _buildSupportLinksSection(),
              const SizedBox(height: 12),
            ],
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

  Widget _buildSupportLinksSection() {
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
              Icon(Icons.support_agent, color: AppTheme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'التواصل مع المدرس',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _supportLinks.map((link) {
              final platform = (link['platform'] ?? '').toString().toLowerCase();
              final url = (link['url'] ?? '').toString();
              final label = (link['label'] ?? link['platform'] ?? '').toString();
              final icon = _getPlatformIcon(platform);
              final color = _getPlatformColor(platform);
              return SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => _openSupportLink(url),
                  icon: Icon(icon, color: Colors.white, size: 18),
                  label: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform) {
      case 'whatsapp':
        return Icons.chat;
      case 'telegram':
        return Icons.telegram;
      case 'instagram':
        return Icons.camera_alt;
      case 'facebook':
        return Icons.facebook;
      case 'youtube':
        return Icons.play_circle_fill;
      case 'tiktok':
        return Icons.music_note;
      default:
        return Icons.link;
    }
  }

  Color _getPlatformColor(String platform) {
    switch (platform) {
      case 'whatsapp':
        return const Color(0xFF25D366);
      case 'telegram':
        return const Color(0xFF26A5E4);
      case 'instagram':
        return const Color(0xFFE4405F);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'youtube':
        return const Color(0xFFFF0000);
      case 'tiktok':
        return const Color(0xFF000000);
      default:
        return AppTheme.accent;
    }
  }

  Future<void> _openSupportLink(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن فتح الرابط'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
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
