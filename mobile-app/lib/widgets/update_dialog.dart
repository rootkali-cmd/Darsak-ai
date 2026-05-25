import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/update_service.dart';

class AndroidUpdateDialog extends StatelessWidget {
  final AndroidUpdateInfo info;

  const AndroidUpdateDialog({super.key, required this.info});

  static Future<bool?> show(BuildContext context, AndroidUpdateInfo info) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !info.mandatory,
      builder: (_) => AndroidUpdateDialog(info: info),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.system_update, color: Colors.green, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تحديث متوفر v${info.version}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (info.sizeMb != null)
                      Text(
                        'الحجم: ~${info.sizeMb} MB',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (info.mandatory)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('إجباري', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (info.changelog.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('التغييرات:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            ...info.changelog.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: Colors.blue[400], fontSize: 13)),
                  Expanded(child: Text(item, style: TextStyle(color: Colors.grey[300], fontSize: 13))),
                ],
              ),
            )),
          ],
        ],
      ),
      actions: [
        if (!info.mandatory)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('لاحقاً', style: TextStyle(color: Colors.grey[400])),
          ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          icon: const Icon(Icons.download, size: 16),
          label: const Text('تحديث'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
