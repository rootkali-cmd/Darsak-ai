import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateService updateService;
  final VoidCallback onDismiss;

  const UpdateDialog({
    super.key,
    required this.updateService,
    required this.onDismiss,
  });

  void _handleDownload() {
    updateService.downloadUpdate();
  }

  void _handleInstall() {
    updateService.installUpdate();
  }

  void _handleRestart() {
    updateService.restartApp();
  }

  void _handleIgnore() {
    updateService.ignoreVersion();
    onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return ListenableBuilder(
      listenable: updateService,
      builder: (context, _) {
        final info = updateService.updateInfo;
        final status = updateService.status;

        if (status == UpdateStatus.upToDate || info == null) {
          return AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 48, color: AppTheme.success),
                const SizedBox(height: 16),
                Text(
                  'التطبيق محدث',
                  style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'لديك أحدث إصدار',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: onDismiss,
                child: const Text('حسناً'),
              ),
            ],
          );
        }

        if (status == UpdateStatus.checking) {
          return AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
                const SizedBox(width: 16),
                Text('جارٍ التحقق من التحديثات...', style: TextStyle(color: textSecondary)),
              ],
            ),
          );
        }

        if (status == UpdateStatus.downloading) {
          return AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.downloading, size: 48, color: AppTheme.accent),
                const SizedBox(height: 16),
                Text('جاري التحميل...', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: updateService.downloadProgress,
                    minHeight: 8,
                    backgroundColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(updateService.downloadProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'يمكنك متابعة العمل أثناء التحميل',
                  style: TextStyle(color: textMuted(context), fontSize: 11),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: onDismiss,
                child: const Text('تصغير'),
              ),
            ],
          );
        }

        if (status == UpdateStatus.readyToInstall) {
          return AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_done, size: 48, color: AppTheme.success),
                const SizedBox(height: 16),
                Text('تم التحميل', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('التحديث جاهز للتثبيت', style: TextStyle(color: textSecondary, fontSize: 13)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: onDismiss,
                child: const Text('تثبيت لاحقاً'),
              ),
              ElevatedButton.icon(
                onPressed: _handleInstall,
                icon: const Icon(Icons.download_done, size: 16),
                label: const Text('تثبيت'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        }

        if (status == UpdateStatus.installing) {
          return AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 3)),
                const SizedBox(height: 16),
                Text('جاري التثبيت...', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('سيتم إغلاق التطبيق تلقائياً', style: TextStyle(color: textSecondary, fontSize: 13)),
              ],
            ),
          );
        }

        if (status == UpdateStatus.restartRequired) {
          return AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.restart_alt, size: 48, color: AppTheme.success),
                const SizedBox(height: 16),
                Text('تم التحديث بنجاح', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('يرجى إعادة تشغيل التطبيق', style: TextStyle(color: textSecondary, fontSize: 13)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: onDismiss,
                child: const Text('لاحقاً'),
              ),
              ElevatedButton.icon(
                onPressed: _handleRestart,
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('إعادة التشغيل'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        }

        if (status == UpdateStatus.error) {
          return AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
                const SizedBox(height: 16),
                Text(
                  updateService.errorMessage ?? 'حدث خطأ أثناء التحديث',
                  style: TextStyle(color: textPrimary, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: onDismiss,
                child: const Text('إغلاق'),
              ),
              TextButton(
                onPressed: () => updateService.retry(),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          );
        }

        return _buildAvailableDialog(context, info, isDark, textPrimary, textSecondary);
      },
    );
  }

  Widget _buildAvailableDialog(
    BuildContext context,
    UpdateInfo info,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isMandatory = info.mandatory;

    return AlertDialog(
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isMandatory ? AppTheme.danger : AppTheme.success).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.system_update,
                  color: isMandatory ? AppTheme.danger : AppTheme.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تحديث متوفر v${info.version}',
                      style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (info.sizeMb != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'الحجم: ${info.sizeMb} ميگابايت',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              if (isMandatory)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'إجباري',
                    style: TextStyle(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (info.changelog.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'التغييرات الجديدة:',
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 10),
            ...info.changelog.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: AppTheme.accent, fontSize: 13)),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!isMandatory)
          TextButton(
            onPressed: _handleIgnore,
            child: Text('تجاهل', style: TextStyle(color: textSecondary)),
          ),
        if (!isMandatory)
          TextButton(
            onPressed: onDismiss,
            child: const Text('لاحقاً'),
          ),
        ElevatedButton.icon(
          onPressed: _handleDownload,
          icon: const Icon(Icons.download, size: 16),
          label: const Text('تحديث الآن'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isMandatory ? AppTheme.danger : AppTheme.accent,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  static Color textMuted(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
  }
}
