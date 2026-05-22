import 'package:flutter/material.dart';
import '../core/theme.dart';

class SyncIndicator extends StatelessWidget {
  final bool isOnline;
  final bool isSyncing;
  final String status;
  final VoidCallback onSync;

  const SyncIndicator({
    super.key,
    required this.isOnline,
    required this.isSyncing,
    required this.status,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isOnline ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isOnline ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSyncing)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accent2,
              ),
            )
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? AppTheme.success : AppTheme.danger,
                boxShadow: [
                  BoxShadow(
                    color: (isOnline ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              color: isOnline ? AppTheme.success : AppTheme.danger,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          if (isOnline && !isSyncing) ...[
            const SizedBox(width: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onSync,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.accent2.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.sync, size: 12, color: AppTheme.accent2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
