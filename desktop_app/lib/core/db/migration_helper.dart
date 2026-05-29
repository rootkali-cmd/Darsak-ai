import 'package:hive_flutter/hive_flutter.dart';
import 'database_service.dart';
import '../local_db.dart';

class MigrationResult {
  final bool success;
  final String? error;
  final Map<String, int> itemsMigrated;
  final int durationMs;

  MigrationResult({
    required this.success,
    this.error,
    required this.itemsMigrated,
    required this.durationMs,
  });
}

class MigrationHelper {
  static const int _targetSchemaVersion = 1;
  static const String _migrationLockKey = 'migration_lock';

  static bool isMigrated() {
    final version = DatabaseService.instance.getSchemaVersion();
    return version != null && version >= _targetSchemaVersion;
  }

  static bool isMigrationLocked() {
    final lock = DatabaseService.instance.getSetting(_migrationLockKey);
    return lock == '1';
  }

  static Future<MigrationResult> runMigration() async {
    final start = DateTime.now();
    final itemsMigrated = <String, int>{};

    try {
      if (isMigrated()) {
        return MigrationResult(
          success: true,
          itemsMigrated: itemsMigrated,
          durationMs: DateTime.now().difference(start).inMilliseconds,
        );
      }

      DatabaseService.instance.setSetting(_migrationLockKey, '1');

      final backupName = await LocalDB.createBackup();
      if (backupName == null) {
        throw Exception('فشل إنشاء نسخة احتياطية قبل الترحيل');
      }

      final boxes = [
        ('students', LocalDB.studentsBox),
        ('groups', LocalDB.groupsBox),
        ('attendance', LocalDB.attendanceBox),
        ('grades', LocalDB.gradesBox),
        ('invoices', LocalDB.invoicesBox),
        ('payments', LocalDB.paymentsBox),
      ];

      for (final (tableName, boxName) in boxes) {
        final count = _migrateBox(tableName, boxName);
        itemsMigrated[tableName] = count;
      }

      _migrateSyncQueue();
      _migrateDeadLetters();
      _migrateCursors();
      _migrateSettings();

      DatabaseService.instance.setSchemaVersion(_targetSchemaVersion);
      DatabaseService.instance.setSetting(_migrationLockKey, '0');

      final preMigrationBackup = DatabaseService.instance.getSetting('pre_migration_backup');
      if (preMigrationBackup == null) {
        DatabaseService.instance.setSetting('pre_migration_backup', backupName);
      }

      return MigrationResult(
        success: true,
        itemsMigrated: itemsMigrated,
        durationMs: DateTime.now().difference(start).inMilliseconds,
      );
    } catch (e) {
      await rollback();
      return MigrationResult(
        success: false,
        error: e.toString(),
        itemsMigrated: itemsMigrated,
        durationMs: DateTime.now().difference(start).inMilliseconds,
      );
    }
  }

  static int _migrateBox(String tableName, String hiveBoxName) {
    if (!Hive.isBoxOpen(hiveBoxName)) return 0;
    final box = Hive.box<Map>(hiveBoxName);
    final entries = box.toMap();
    if (entries.isEmpty) return 0;

    int count = 0;
    for (final entry in entries.entries) {
      final key = entry.key.toString();
      final data = Map<String, dynamic>.from(entry.value as Map);
      try {
        DatabaseService.instance.saveGenericData(tableName, key, data);
        count++;
      } catch (_) {}
    }
    return count;
  }

  static void _migrateSyncQueue() {
    final boxName = LocalDB.syncQueueBox;
    if (!Hive.isBoxOpen(boxName)) return;
    final box = Hive.box<Map>(boxName);
    if (box.length == 0) return;

    for (int i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      if (item == null) continue;
      try {
        final data = Map<String, dynamic>.from(item['data'] as Map? ?? {});
        final opId = item['operation_id']?.toString();
        DatabaseService.instance.addToSyncQueue(
          item['type']?.toString() ?? 'unknown',
          data,
          operationId: opId,
        );
        if (item['synced'] == true) {
          if (opId != null) {
            DatabaseService.instance.markSyncedByOpId(opId);
          }
        }
      } catch (_) {}
    }
  }

  static void _migrateDeadLetters() {
    final boxName = LocalDB.deadLetterBox;
    if (!Hive.isBoxOpen(boxName)) return;
    final box = Hive.box<Map>(boxName);
    if (box.length == 0) return;

    for (int i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      if (item == null) continue;
      try {
        DatabaseService.instance.addToDeadLetter(
          Map<String, dynamic>.from(item),
          error: item['error']?.toString(),
        );
      } catch (_) {}
    }
  }

  static void _migrateCursors() {
    final boxName = LocalDB.syncCursorsBox;
    if (!Hive.isBoxOpen(boxName)) return;
    final box = Hive.box(boxName);
    if (box.length == 0) return;

    for (final key in box.keys) {
      final val = box.get(key)?.toString();
      if (val != null) {
        DatabaseService.instance.saveCursor(key.toString(), val);
      }
    }
  }

  static void _migrateSettings() {
    final boxName = LocalDB.settingsBox;
    if (!Hive.isBoxOpen(boxName)) return;
    final box = Hive.box(boxName);

    if (box.containsKey('last_sync_time')) {
      final val = box.get('last_sync_time')?.toString();
      if (val != null) {
        DatabaseService.instance.setSetting('last_sync_time', val);
      }
    }
  }

  static Future<bool> verifyMigration() async {
    try {
      final tables = ['students', 'groups_tbl', 'attendance', 'grades', 'invoices', 'payments', 'sync_queue', 'dead_letter', 'sync_cursors', 'settings'];
      for (final t in tables) {
        final result = DatabaseService.instance.db.select('SELECT COUNT(*) AS cnt FROM $t');
        if (result.isEmpty) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> rollback() async {
    final backupName = DatabaseService.instance.getSetting('pre_migration_backup');
    if (backupName != null) {
      await LocalDB.restoreFromBackup(backupName);
    }
    DatabaseService.instance.db.execute('DELETE FROM settings WHERE key=?', ['schema_version']);
    DatabaseService.instance.setSetting(_migrationLockKey, '0');
  }
}
