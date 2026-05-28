import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/sync_service.dart';

class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();

    String text;
    Color color;
    IconData icon;

    if (sync.isSyncing) {
      text = 'جاري المزامنة...';
      color = const Color(0xFF3B82F6);
      icon = Icons.sync;
    } else if (!sync.isOnline) {
      text = 'غير متصل';
      color = const Color(0xFFF59E0B);
      icon = Icons.cloud_off;
    } else if (sync.failedCount > 0) {
      text = 'خطأ في المزامنة';
      color = const Color(0xFFEF4444);
      icon = Icons.error_outline;
    } else if (sync.pendingCount > 0) {
      text = 'في الانتظار: ${sync.pendingCount}';
      color = const Color(0xFFF59E0B);
      icon = Icons.cloud_upload;
    } else {
      text = 'تمت المزامنة';
      color = const Color(0xFF22C55E);
      icon = Icons.cloud_done;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: color)),
          if (sync.isSyncing) ...[
            const SizedBox(width: 6),
            SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
