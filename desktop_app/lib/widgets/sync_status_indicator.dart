import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/sync_service.dart';
import '../providers/data_provider.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final networkOk = sync.isOnline;
    final pending = sync.pendingCount;
    final syncing = sync.syncingCount;
    final failed = sync.failedCount;
    final lastSync = sync.lastSyncTime;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    IconData icon;
    String tooltip;

    if (!networkOk) {
      statusColor = Colors.orange;
      icon = Icons.cloud_off;
      tooltip = 'غير متصل بالإنترنت';
    } else if (failed > 0) {
      statusColor = Colors.red;
      icon = Icons.error_outline;
      tooltip = '$failed عملية فاشلة';
    } else if (syncing > 0) {
      statusColor = Colors.blue;
      icon = Icons.sync;
      tooltip = 'جاري التحديث...';
    } else if (pending > 0) {
      statusColor = Colors.amber.shade700;
      icon = Icons.cloud_upload;
      tooltip = '$pending عملية في الانتظار';
    } else {
      statusColor = Colors.green;
      icon = Icons.cloud_done;
      tooltip = 'متصل';
    }

    String timeSince = '';
    if (lastSync != null) {
      final diff = DateTime.now().difference(lastSync);
      if (diff.inSeconds < 60) timeSince = 'منذ ${diff.inSeconds}ث';
      else if (diff.inMinutes < 60) timeSince = 'منذ ${diff.inMinutes}د';
      else timeSince = 'منذ ${diff.inHours}س';
    }

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => _showDetails(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: statusColor),
              if (syncing > 0) ...[
                const SizedBox(width: 4),
                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(statusColor))),
              ],
              if (pending > 0) ...[
                const SizedBox(width: 4),
                Text('$pending', style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87)),
              ],
              if (failed > 0) ...[
                const SizedBox(width: 4),
                Text('$failed!', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
              ],
              if (timeSince.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(timeSince, style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black54)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog(context: context, builder: (_) => _SyncDetailsDialog());
  }
}

class _SyncDetailsDialog extends StatefulWidget {
  @override
  State<_SyncDetailsDialog> createState() => _SyncDetailsDialogState();
}

class _SyncDetailsDialogState extends State<_SyncDetailsDialog> {
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final data = context.watch<DataProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ops = sync.recentOps;
    final pending = sync.pendingCount;
    final failed = sync.failedCount;
    final synced = ops.where((o) => o.status == SyncOpStatus.synced).length;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Icon(sync.isOnline ? Icons.cloud_done : Icons.cloud_off,
             color: sync.isOnline ? Colors.green : Colors.orange, size: 20),
        const SizedBox(width: 8),
        const Text('حالة المزامنة', style: TextStyle(fontSize: 16)),
      ]),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _stat('معلق', pending, Colors.amber.shade700),
              _stat('قيد التنفيذ', sync.syncingCount, Colors.blue),
              _stat('تم', synced, Colors.green),
              _stat('فشل', failed, Colors.red),
            ]),
            const SizedBox(height: 12),
            Text('آخر مزامنة: ${_fmtTime(sync.lastSyncTime)}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
            Text('الجلسة: ${sync.isOnline ? "متصل" : "غير متصل"}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
            Text('التعديلات المحلية: ${data.pendingChangesCount}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
            const SizedBox(height: 12),
            if (ops.isEmpty)
              Text('لا توجد عمليات', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13))
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: ops.length > 20 ? 20 : ops.length,
                  itemBuilder: (_, i) {
                    final op = ops[i];
                    final icon = op.status == SyncOpStatus.synced ? Icons.check_circle :
                                op.status == SyncOpStatus.failed ? Icons.error :
                                op.status == SyncOpStatus.syncing ? Icons.sync : Icons.hourglass_empty;
                    final color = op.status == SyncOpStatus.synced ? Colors.green :
                                  op.status == SyncOpStatus.failed ? Colors.red :
                                  op.status == SyncOpStatus.syncing ? Colors.blue : Colors.amber;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Icon(icon, size: 14, color: color),
                        const SizedBox(width: 6),
                        Expanded(child: Text(op.label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87))),
                        Text(op.status == SyncOpStatus.synced ? '${op.latencyMs}ms' :
                             op.status == SyncOpStatus.failed ? op.lastError ?? '' :
                             '${op.retryCount}x', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
                      ]),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ElevatedButton(
          onPressed: () { sync.syncNow(); _refresh(); },
          child: const Text('مزامنة الآن'),
        ),
      ],
    );
  }

  Widget _stat(String label, int count, Color color) {
    return Expanded(child: Column(children: [
      Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
    ]));
  }

  String _fmtTime(DateTime? t) {
    if (t == null) return 'لم تتم بعد';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'منذ ${d.inSeconds} ثانية';
    if (d.inMinutes < 60) return 'منذ ${d.inMinutes} دقيقة';
    return 'منذ ${d.inHours} ساعة';
  }
}
