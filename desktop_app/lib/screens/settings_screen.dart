import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/update_service.dart';
import '../core/sync_service.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';

const List<Map<String, String>> _channels = [
  {'key': 'stable', 'label': 'مستقر', 'labelEn': 'Stable'},
  {'key': 'beta', 'label': 'تجريبي', 'labelEn': 'Beta'},
  {'key': 'dev', 'label': 'تطوير', 'labelEn': 'Dev'},
  {'key': 'nightly', 'label': 'ليلي', 'labelEn': 'Nightly'},
];

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
          _SyncDebugCard(),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'التحديثات',
                        style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Consumer<UpdateService>(
                        builder: (context, update, _) {
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => update.checkForUpdate(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh, size: 14, color: AppTheme.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'تحقق',
                                    style: TextStyle(color: AppTheme.accent, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Consumer<UpdateService>(
                    builder: (context, update, _) {
                      if (update.isChecking) {
                        return Row(
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 12),
                            Text('جارٍ التحقق من التحديثات...', style: TextStyle(color: textSecondary, fontSize: 13)),
                          ],
                        );
                      }

                      if (update.isInstalling) {
                        return Row(
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 12),
                            Text('جاري التثبيت...', style: TextStyle(color: textSecondary, fontSize: 13)),
                          ],
                        );
                      }

                      if (update.isRestartRequired) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                                const SizedBox(width: 6),
                                Text('تم التثبيت', style: TextStyle(color: AppTheme.success, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: ElevatedButton.icon(
                                onPressed: () => update.restartApp(),
                                icon: const Icon(Icons.restart_alt, size: 16),
                                label: const Text('إعادة التشغيل'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      if (update.status == UpdateStatus.available && update.updateInfo != null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.system_update, size: 16, color: AppTheme.success),
                                  const SizedBox(width: 6),
                                  Text(
                                    'تحديث v${update.updateInfo!.version} متوفر',
                                    style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (update.updateInfo!.changelog.isNotEmpty)
                              ...update.updateInfo!.changelog.take(3).map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('• $item', style: TextStyle(color: textMuted, fontSize: 12)),
                              )),
                            const SizedBox(height: 12),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: ElevatedButton.icon(
                                onPressed: () => update.downloadUpdate(),
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text('تحديث الآن'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      if (update.isDownloading) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('جارٍ التحميل... ${update.downloadPercent}',
                              style: TextStyle(color: textSecondary, fontSize: 13)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: update.downloadProgress,
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${update.downloadedSize} / ${update.totalSize}',
                              style: TextStyle(color: textMuted, fontSize: 11),
                            ),
                          ],
                        );
                      }

                      if (update.status == UpdateStatus.readyToInstall) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                                const SizedBox(width: 6),
                                Text('تم التحميل', style: TextStyle(color: AppTheme.success, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: ElevatedButton.icon(
                                onPressed: () => update.installUpdate(),
                                icon: const Icon(Icons.download_done, size: 16),
                                label: const Text('تثبيت التحديث'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      if (update.isError) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(update.errorMessage ?? 'حدث خطأ',
                                style: TextStyle(color: AppTheme.danger, fontSize: 12)),
                            if (update.errorDetail != null)
                              Text(update.errorDetail!,
                                  style: TextStyle(color: textMuted, fontSize: 11)),
                            const SizedBox(height: 8),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: TextButton.icon(
                                onPressed: () => update.retry(),
                                icon: const Icon(Icons.refresh, size: 14),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 16, color: AppTheme.success),
                          const SizedBox(width: 6),
                          Text('التطبيق محدث', style: TextStyle(color: AppTheme.success, fontSize: 13)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Consumer<UpdateService>(
                    builder: (context, update, _) {
                      return Row(
                        children: [
                          Text('قناة التحديثات', style: TextStyle(color: textSecondary, fontSize: 13)),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: update.channel,
                            dropdownColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                            underline: const SizedBox(),
                            style: TextStyle(color: textPrimary, fontSize: 13),
                            items: _channels.map((c) {
                              return DropdownMenuItem(
                                value: c['key'],
                                child: Text(c['label'] ?? c['key']!),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                update.setChannel(value);
                                update.checkForUpdate(force: true);
                              }
                            },
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
                  Text('DarsakAI Desktop v${AppConstants.appVersion}', style: TextStyle(color: textSecondary)),
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

class _SyncDebugCard extends StatefulWidget {
  @override
  State<_SyncDebugCard> createState() => _SyncDebugCardState();
}

class _SyncDebugCardState extends State<_SyncDebugCard> {
  Timer? _timer;

  @override
  void initState() { super.initState(); _timer = Timer.periodic(const Duration(seconds: 2), (_) { if (mounted) setState(() {}); }); }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final ops = sync.recentOps.take(15).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('سجل المزامنة', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            _badge('في الانتظار', sync.pendingCount, Colors.amber, isDark),
            const SizedBox(width: 8),
            _badge('جاري', sync.syncingCount, Colors.blue, isDark),
            const SizedBox(width: 8),
            _badge('فشل', sync.failedCount, Colors.red, isDark),
            const SizedBox(width: 8),
            _badge('تم', ops.where((o) => o.status == SyncOpStatus.synced).length, Colors.green, isDark),
          ]),
          const SizedBox(height: 8),
          Text('آخر مزامنة: ${_fmtTime(sync.lastSyncTime)}', style: TextStyle(fontSize: 12, color: textMuted)),
          Text('الشبكة: ${sync.isOnline ? "متصل" : "غير متصل"} | متوسط الزمن: ${_avgLatency(ops)}ms', style: TextStyle(fontSize: 12, color: textMuted)),
          const SizedBox(height: 8),
          if (ops.isEmpty)
            Text('لا توجد عمليات', style: TextStyle(color: textMuted, fontSize: 13))
          else
            SizedBox(
              height: 250,
              child: ListView.builder(
                itemCount: ops.length,
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
                      Text(op.label, style: TextStyle(fontSize: 12, color: textSecondary)),
                      const Spacer(),
                      Text(
                        op.status == SyncOpStatus.synced ? '${op.latencyMs}ms' :
                        op.status == SyncOpStatus.syncing ? 'جاري...' :
                        op.status == SyncOpStatus.failed ? (op.lastError ?? 'خطأ') :
                        'محاولة ${op.retryCount + 1}',
                        style: TextStyle(fontSize: 10, color: textMuted),
                      ),
                    ]),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }

  Widget _badge(String label, int count, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$count', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87)),
      ]),
    );
  }

  String _fmtTime(DateTime? t) {
    if (t == null) return 'لم تتم بعد';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'منذ ${d.inSeconds}ث';
    if (d.inMinutes < 60) return 'منذ ${d.inMinutes}د';
    return 'منذ ${d.inHours}س';
  }

  int _avgLatency(List<SyncOp> ops) {
    final synced = ops.where((o) => o.status == SyncOpStatus.synced && o.latencyMs > 0).toList();
    if (synced.isEmpty) return 0;
    return synced.fold(0, (s, o) => s + o.latencyMs) ~/ synced.length;
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
