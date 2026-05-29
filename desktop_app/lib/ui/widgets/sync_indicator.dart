import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sync_provider.dart';

class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();

    Color color;
    IconData icon;
    String tooltip;
    bool spinning;

    if (!sync.isOnline) {
      color = const Color(0xFFEF4444);
      icon = Icons.cloud_off;
      tooltip = 'غير متصل بالإنترنت';
      spinning = false;
    } else if (sync.isSyncing) {
      color = const Color(0xFF2563EB);
      icon = Icons.sync;
      tooltip = 'جاري المزامنة...';
      spinning = true;
    } else if (sync.failedCount > 0) {
      color = const Color(0xFFF59E0B);
      icon = Icons.access_time;
      tooltip = 'فشلت المزامنة لـ ${sync.failedCount} عناصر';
      spinning = false;
    } else if (sync.pendingCount > 0) {
      color = const Color(0xFFF59E0B);
      icon = Icons.access_time;
      tooltip = 'في الانتظار: ${sync.pendingCount}';
      spinning = false;
    } else {
      color = const Color(0xFF10B981);
      icon = Icons.check_circle;
      tooltip = 'تمت المزامنة';
      spinning = false;
    }

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => sync.syncNow(),
        child: spinning
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Icon(icon, color: color, size: 20),
      ),
    );
  }
}
