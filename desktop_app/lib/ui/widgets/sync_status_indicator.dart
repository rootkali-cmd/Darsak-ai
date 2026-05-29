import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/data_provider.dart';
import '../../core/theme/app_theme.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final data = context.watch<DataProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (!sync.isOnline) {
      statusColor = AppTheme.danger;
      statusIcon = Icons.cloud_off;
      statusText = 'غير متصل';
    } else if (sync.isSyncing) {
      statusColor = AppTheme.accent;
      statusIcon = Icons.sync;
      statusText = 'جاري المزامنة...';
    } else if (sync.failedCount > 0) {
      statusColor = AppTheme.warning;
      statusIcon = Icons.error_outline;
      statusText = 'فشل في المزامنة';
    } else if (sync.pendingCount > 0) {
      statusColor = AppTheme.warning;
      statusIcon = Icons.cloud_upload;
      statusText = 'في الانتظار';
    } else {
      statusColor = AppTheme.success;
      statusIcon = Icons.cloud_done;
      statusText = 'متصل';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sync.isSyncing)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  )
                else
                  Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (data.pendingChangesCount > 0 && data.pendingChangesCount < 1000)
            Text(
              'تغييرات معلقة: ${data.pendingChangesCount}',
              style: TextStyle(color: textSecondary, fontSize: 12),
            )
          else if (data.pendingChangesCount >= 1000)
            Text(
              'تغييرات معلقة: ${data.pendingChangesCount} (اضغط مزامنة للتنظيف)',
              style: TextStyle(color: AppTheme.danger, fontSize: 12),
            )
          else
            Text(
              'كل التغييرات متزامنة',
              style: TextStyle(color: AppTheme.success, fontSize: 12),
            ),
          const Spacer(),
          if (sync.isSyncing)
            SizedBox(
              width: 80,
              child: LinearProgressIndicator(
                backgroundColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                minHeight: 3,
              ),
            ),
          if (!sync.isSyncing) ...[
            Icon(Icons.access_time, size: 12, color: textMuted),
            const SizedBox(width: 4),
            Text(
              _lastSyncText(sync.lastSyncTime),
              style: TextStyle(color: textMuted, fontSize: 11),
            ),
          ],
          const SizedBox(width: 12),
          SizedBox(
            height: 32,
            child: ElevatedButton.icon(
              onPressed: sync.isSyncing ? null : () => sync.syncNow(),
              icon: const Icon(Icons.sync, size: 16),
              label: const Text('مزامنة الآن'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _lastSyncText(DateTime? lastSync) {
  if (lastSync == null) return 'لم تتم بعد';
  final diff = DateTime.now().difference(lastSync);
  if (diff.inSeconds < 60) return 'منذ ${diff.inSeconds}ث';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes}د';
  if (diff.inHours < 24) return 'منذ ${diff.inHours}س';
  return 'منذ ${diff.inDays}ي';
}
