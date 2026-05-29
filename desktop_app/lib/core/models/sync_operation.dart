enum SyncOpStatus { pending, syncing, synced, failed }

class SyncOperation {
  final String id;
  final String type;
  final String label;
  SyncOpStatus status;
  final DateTime createdAt;
  DateTime? syncedAt;
  int retryCount;
  String? lastError;
  int latencyMs;

  SyncOperation({
    required this.id,
    required this.type,
    required this.label,
    this.status = SyncOpStatus.pending,
    DateTime? createdAt,
    this.syncedAt,
    this.retryCount = 0,
    this.lastError,
    this.latencyMs = 0,
  }) : createdAt = createdAt ?? DateTime.now();
}
