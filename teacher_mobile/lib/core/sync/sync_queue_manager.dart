import 'package:uuid/uuid.dart';
import '../database/database_service.dart';

final class SyncQueueManager {
  final DatabaseService _db;

  SyncQueueManager(this._db);

  void enqueue(String type, Map<String, dynamic> data, {String? operationId}) {
    _db.addToSyncQueue(type, data, operationId: operationId ?? const Uuid().v4());
  }

  List<Map<String, dynamic>> getUnsynced() => _db.getUnsyncedItems();

  void markSynced(Map<String, dynamic> targetData) => _db.markSyncedByData(targetData);

  void clearSynced() => _db.clearSyncedItems();

  int get pendingCount => _db.unsyncedCount;

  void moveToDeadLetter(Map<String, dynamic> item, {required String error}) {
    _db.addToDeadLetter(item, error: error);
  }

  List<Map<String, dynamic>> getDeadLetters() => _db.getAllDeadLetters();

  void recoverDeadLetters() => _db.recoverDeadLetters();

  void removeDeadLetter(Map<String, dynamic> item) {
    final opId = item['operation_id']?.toString();
    if (opId != null) _db.removeDeadLetter(opId);
  }

  int get deadLetterCount => _db.deadLetterCount;

  void clearOldQueue({int maxItems = 1000}) {
    _db.clearSyncedItems();
    final total = _db.syncQueueLength;
    if (total > maxItems) {
      _db.trimSyncQueue(total - maxItems);
    }
  }

  void clearAllQueue() {
    _db.clearAllSyncQueue();
  }
}
