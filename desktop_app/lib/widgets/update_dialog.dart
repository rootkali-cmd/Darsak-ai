import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/update_service.dart';

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UpdateDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Consumer<UpdateService>(
      builder: (context, update, _) {
        if (update.status == UpdateStatus.upToDate || update.updateInfo == null) {
          return AlertDialog(
            backgroundColor: surfaceColor,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 48, color: AppTheme.success),
                const SizedBox(height: 16),
                Text('التطبيق محدث', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('حسناً')),
            ],
          );
        }

        if (update.isChecking) {
          return AlertDialog(
            backgroundColor: surfaceColor,
            content: Row(
              children: [
                SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 16),
                Text('جارٍ التحقق من التحديثات...', style: TextStyle(color: textSecondary)),
              ],
            ),
          );
        }

        final info = update.updateInfo!;

        if (update.isDownloading) {
          return AlertDialog(
            backgroundColor: surfaceColor,
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
                    value: update.downloadProgress,
                    minHeight: 8,
                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${update.downloadPercent} - ${update.downloadedSize} / ${update.totalSize}',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                if (update.downloadSpeed.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(update.downloadSpeed, style: TextStyle(color: textSecondary, fontSize: 12)),
                ],
              ],
            ),
          );
        }

        if (update.status == UpdateStatus.readyToInstall) {
          return AlertDialog(
            backgroundColor: surfaceColor,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_done, size: 48, color: AppTheme.success),
                const SizedBox(height: 16),
                Text('تم التحميل', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('التحديث جاهز للتثبيت', style: TextStyle(color: textSecondary)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('تثبيت لاحقاً'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  update.installUpdate();
                },
                icon: const Icon(Icons.download_done, size: 16),
                label: const Text('تثبيت الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        }

        if (update.status == UpdateStatus.error) {
          return AlertDialog(
            backgroundColor: surfaceColor,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
                const SizedBox(height: 16),
                Text(update.errorMessage ?? 'حدث خطأ', style: TextStyle(color: textPrimary, fontSize: 16)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق')),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  update.retry();
                },
                child: const Text('إعادة المحاولة'),
              ),
            ],
          );
        }

        return AlertDialog(
          backgroundColor: surfaceColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.system_update, color: AppTheme.success, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تحديث متوفر v${info.version}',
                          style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (info.sizeMb != null)
                          Text(
                            'الحجم: ~${info.sizeMb} MB',
                            style: TextStyle(color: textSecondary, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  if (info.mandatory)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('إجباري', style: TextStyle(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              if (info.changelog.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('التغييرات:', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                ...info.changelog.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: AppTheme.accent, fontSize: 13)),
                      Expanded(child: Text(item, style: TextStyle(color: textSecondary, fontSize: 13))),
                    ],
                  ),
                )),
              ],
            ],
          ),
          actions: [
            if (!info.mandatory)
              TextButton(
                onPressed: () {
                  update.ignoreVersion();
                  Navigator.of(context).pop();
                },
                child: Text('تخطي هذا الإصدار', style: TextStyle(color: textSecondary)),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('لاحقاً'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                update.downloadUpdate();
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('تحديث الآن'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}
