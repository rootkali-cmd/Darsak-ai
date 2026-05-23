import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Text(
            'الإعدادات',
            style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المعلومات الشخصية',
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(label: 'الاسم', value: user?.fullName ?? '-', textMuted: textMuted, textPrimary: textPrimary),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'البريد الإلكتروني', value: user?.email ?? '-', textMuted: textMuted, textPrimary: textPrimary),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'كود المدرس', value: user?.teacherCode ?? '-', textMuted: textMuted, textPrimary: textPrimary),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'الدور', value: user?.role ?? '-', textMuted: textMuted, textPrimary: textPrimary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المزامنة',
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Consumer<SyncProvider>(
                    builder: (context, sync, _) {
                      return Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sync.isOnline ? AppTheme.success : AppTheme.danger,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            sync.isOnline ? 'متصل' : 'غير متصل',
                            style: TextStyle(
                              color: sync.isOnline ? AppTheme.success : AppTheme.danger,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: ElevatedButton(
                              onPressed: sync.isOnline ? () => sync.syncNow() : null,
                              child: const Text('مزامنة الآن'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حول التطبيق',
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text('DarsakAI Desktop v1.0.0', style: TextStyle(color: textSecondary)),
                  Text('تطبيق سطح المكتب لإدارة الفصول والطلاب', style: TextStyle(color: textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textMuted;
  final Color textPrimary;

  const _InfoRow({
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
          child: Text(label, style: TextStyle(color: textMuted)),
        ),
        Text(value, style: TextStyle(color: textPrimary)),
      ],
    );
  }
}
