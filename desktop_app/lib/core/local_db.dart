import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'db/database_service.dart';
import 'db/migration_helper.dart';

class LocalDB {
  static late final String _sharedPath;
  static late final String _backupPath;
  static bool _migrated = false;

  static const String studentsBox = 'students';
  static const String groupsBox = 'groups';
  static const String attendanceBox = 'attendance';
  static const String gradesBox = 'grades';
  static const String invoicesBox = 'invoices';
  static const String paymentsBox = 'payments';
  static const String syncQueueBox = 'sync_queue';
  static const String deadLetterBox = 'dead_letter';
  static const String syncCursorsBox = 'sync_cursors';
  static const String settingsBox = 'settings';

  static Future<void> init() async {
    final appDir = await getApplicationSupportDirectory();
    _sharedPath = '${appDir.path}/darsak_db';
    _backupPath = '${appDir.path}/darsak_db_backups';
    final dbDir = Directory(_sharedPath);
    if (!await dbDir.exists()) await dbDir.create(recursive: true);

    // Initialize SQLite database
    final dbPath = '$_sharedPath/darsak.db';
    await DatabaseService.instance.init(dbPath);

    // Open Hive boxes for migration source
    await Hive.initFlutter(_sharedPath);

    final alreadyMigrated = MigrationHelper.isMigrated();
    final isLocked = MigrationHelper.isMigrationLocked();

    if (alreadyMigrated) {
      _migrated = true;
    } else {
      // Open Hive boxes for migration source / fallback
      for (final boxName in [studentsBox, groupsBox, attendanceBox, gradesBox, invoicesBox, paymentsBox, syncQueueBox, deadLetterBox, syncCursorsBox, settingsBox]) {
        if (!Hive.isBoxOpen(boxName)) {
          await Hive.openBox<Map>(boxName).catchError((_) => null);
        }
      }
      // If migration was interrupted (lock stuck), retry
      if (isLocked) {
        DatabaseService.instance.setSetting('migration_retry', '1');
      }
      final result = await MigrationHelper.runMigration();
      if (result.success) {
        _migrated = true;
      }
    }
  }

  static Box getBox(String boxName) {
    return Hive.box(boxName);
  }

  static const int _maxBackups = 10;
  static const int _backupRetentionDays = 14;

  static Future<String?> createBackup() async {
    try {
      final backupDir = Directory(_backupPath);
      if (!await backupDir.exists()) await backupDir.create(recursive: true);
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final destDir = Directory('$_backupPath/backup_$timestamp');
      await destDir.create(recursive: true);

      // Copy Hive files
      final srcDir = Directory(_sharedPath);
      if (await srcDir.exists()) {
        await for (final entity in srcDir.list()) {
          if (entity is File && !entity.path.endsWith('.db-wal') && !entity.path.endsWith('.db-shm')) {
            await entity.copy('${destDir.path}/${entity.uri.pathSegments.last}');
          }
        }
      }
      await _rotateBackups();
      return 'backup_$timestamp';
    } catch (_) {
      return null;
    }
  }

  static Future<void> _rotateBackups() async {
    try {
      final backupDir = Directory(_backupPath);
      if (!await backupDir.exists()) return;

      final entries = await backupDir.list().toList();
      final backupDirs = <Directory>[];
      for (final e in entries) {
        if (e is Directory && e.path.startsWith('$_backupPath/backup_')) {
          backupDirs.add(e);
        }
      }

      backupDirs.sort((a, b) => b.path.compareTo(a.path));

      if (backupDirs.length > _maxBackups) {
        for (int i = _maxBackups; i < backupDirs.length; i++) {
          await backupDirs[i].delete(recursive: true);
        }
      }

      final cutoff = DateTime.now().subtract(Duration(days: _backupRetentionDays));
      for (final dir in backupDirs) {
        final name = dir.path.split('_').last;
        final ts = DateTime.tryParse(name.replaceAll('-', ':'));
        if (ts != null && ts.isBefore(cutoff)) {
          await dir.delete(recursive: true);
        }
      }
    } catch (_) {}
  }

  static Future<bool> restoreFromBackup(String backupName) async {
    try {
      final srcDir = Directory('$_backupPath/$backupName');
      if (!await srcDir.exists()) return false;

      final destDir = Directory(_sharedPath);
      if (!await destDir.exists()) await destDir.create(recursive: true);

      // Close all boxes
      for (final boxName in [studentsBox, groupsBox, attendanceBox, gradesBox, invoicesBox, paymentsBox, syncQueueBox, deadLetterBox, syncCursorsBox]) {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).close();
        }
      }

      await for (final entity in srcDir.list()) {
        if (entity is File) {
          await entity.copy('${destDir.path}/${entity.uri.pathSegments.last}');
        }
      }

      await Hive.openBox<Map>(studentsBox).catchError((_) => null);
      await Hive.openBox<Map>(groupsBox).catchError((_) => null);
      await Hive.openBox<Map>(attendanceBox).catchError((_) => null);
      await Hive.openBox<Map>(gradesBox).catchError((_) => null);
      await Hive.openBox<Map>(invoicesBox).catchError((_) => null);
      await Hive.openBox<Map>(paymentsBox).catchError((_) => null);
      await Hive.openBox<Map>(syncQueueBox).catchError((_) => null);
      await Hive.openBox<Map>(deadLetterBox).catchError((_) => null);
      await Hive.openBox(syncCursorsBox).catchError((_) => null);

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> listBackups() async {
    try {
      final backupDir = Directory(_backupPath);
      if (!await backupDir.exists()) return [];
      final entries = await backupDir.list().toList();
      final names = <String>[];
      for (final e in entries) {
        if (e is Directory && e.path.contains('backup_')) {
          names.add(e.path.split('/').last);
        }
      }
      names.sort((a, b) => b.compareTo(a));
      return names;
    } catch (_) {
      return [];
    }
  }

  static void saveData(String boxName, String key, Map<String, dynamic> data) {
    if (_migrated) {
      DatabaseService.instance.saveGenericData(boxName, key, data);
    } else {
      Hive.box<Map>(boxName).put(key, Map<String, dynamic>.from(data));
    }
  }

  static Map<String, dynamic>? getData(String boxName, String key) {
    if (_migrated) {
      return DatabaseService.instance.getGenericData(boxName, key);
    }
    final data = Hive.box<Map>(boxName).get(key);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  static List<Map<String, dynamic>> getAllData(String boxName) {
    if (_migrated) {
      return DatabaseService.instance.getAllGenericData(boxName);
    }
    final box = Hive.box<Map>(boxName);
    return box.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static void deleteData(String boxName, String key) {
    if (_migrated) {
      DatabaseService.instance.deleteGenericData(boxName, key);
    } else {
      Hive.box<Map>(boxName).delete(key);
    }
  }

  static void clearBox(String boxName) {
    if (_migrated) {
      final db = DatabaseService.instance.db;
      final table = _boxToTable(boxName);
      if (table != null) db.execute('DELETE FROM $table');
    } else {
      Hive.box<Map>(boxName).clear();
    }
  }

  static void deduplicateBox(String boxName, String field) {
    // SQLite tables have UNIQUE constraints; deduplication is automatic
    if (_migrated) return;
    final box = Hive.box<Map>(boxName);
    final seen = <String>{};
    final toRemove = <dynamic>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data == null) continue;
      final val = data[field]?.toString() ?? '';
      if (val.isEmpty) continue;
      if (seen.contains(val)) {
        toRemove.add(key);
      } else {
        seen.add(val);
      }
    }
    for (final key in toRemove) {
      box.delete(key);
    }
  }

  static void addToSyncQueue(String type, Map<String, dynamic> data, {String? operationId}) {
    if (_migrated) {
      DatabaseService.instance.addToSyncQueue(type, data, operationId: operationId);
    } else {
      final box = Hive.box<Map>(syncQueueBox);
      box.add(Map<String, dynamic>.from({
        'type': type,
        'data': data,
        'operation_id': operationId ?? const Uuid().v4(),
        'timestamp': DateTime.now().toIso8601String(),
        'synced': false,
        'retry_count': 0,
      }));
      box.flush();
    }
  }

  static List<Map<String, dynamic>> getUnsyncedItems() {
    if (_migrated) {
      return DatabaseService.instance.getUnsyncedItems();
    }
    final box = Hive.box<Map>(syncQueueBox);
    return box.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((item) => item['synced'] == false)
        .toList();
  }

  static void markSynced(int index) {
    if (_migrated) return;
    final box = Hive.box<Map>(syncQueueBox);
    final item = box.getAt(index);
    if (item != null) {
      item['synced'] = true;
      box.putAt(index, item);
      box.flush();
    }
  }

  static void markSyncItemSynced(Map<String, dynamic> targetData) {
    if (_migrated) {
      DatabaseService.instance.markSyncedByData(targetData);
      return;
    }
    final box = Hive.box<Map>(syncQueueBox);
    for (int i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      if (item != null && item['synced'] == false) {
        final itemData = item['data'] as Map?;
        if (itemData != null) {
          final targetId = targetData['id']?.toString();
          final targetCode = targetData['code']?.toString();
          final targetOpId = targetData['operation_id']?.toString();
          final itemOpId = item['operation_id']?.toString();
          final itemId = itemData['id']?.toString();
          final itemCode = itemData['code']?.toString();
          if ((targetOpId != null && targetOpId == itemOpId) ||
              (targetId != null && targetId == itemId) ||
              (targetCode != null && targetCode == itemCode)) {
            item['synced'] = true;
            box.putAt(i, item);
            box.flush();
            break;
          }
        }
      }
    }
  }

  static void clearSyncedItems() {
    if (_migrated) {
      DatabaseService.instance.clearSyncedItems();
      return;
    }
    final box = Hive.box<Map>(syncQueueBox);
    final keysToRemove = <int>[];
    for (int i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      if (item != null && item['synced'] == true) {
        keysToRemove.add(i);
      }
    }
    for (final key in keysToRemove.reversed) {
      box.deleteAt(key);
    }
    box.flush();
  }

  static void addToDeadLetter(Map<String, dynamic> item, {String? error}) {
    if (_migrated) {
      DatabaseService.instance.addToDeadLetter(item, error: error);
      return;
    }
    final box = Hive.box<Map>(deadLetterBox);
    box.add(Map<String, dynamic>.from({
      ...item,
      'dead_letter_at': DateTime.now().toIso8601String(),
      'error': error ?? 'unknown',
    }));
    box.flush();
  }

  static List<Map<String, dynamic>> getAllDeadLetters() {
    if (_migrated) {
      return DatabaseService.instance.getAllDeadLetters();
    }
    final box = Hive.box<Map>(deadLetterBox);
    return box.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static void removeDeadLetter(Map<String, dynamic> item) {
    if (_migrated) {
      final opId = item['operation_id']?.toString();
      if (opId != null) {
        DatabaseService.instance.removeDeadLetter(opId);
      }
      return;
    }
    final box = Hive.box<Map>(deadLetterBox);
    final opId = item['operation_id']?.toString();
    for (int i = 0; i < box.length; i++) {
      final existing = box.getAt(i);
      if (existing != null) {
        final existingOpId = existing['operation_id']?.toString();
        if (opId != null && opId == existingOpId) {
          box.deleteAt(i);
          box.flush();
          return;
        }
      }
    }
  }

  static void recoverDeadLetters() {
    if (_migrated) {
      DatabaseService.instance.recoverDeadLetters();
      return;
    }
    final deadItems = getAllDeadLetters();
    for (final item in deadItems) {
      addToSyncQueue(
        item['type'] as String? ?? 'unknown',
        Map<String, dynamic>.from(item['data'] as Map? ?? {}),
        operationId: item['operation_id']?.toString(),
      );
    }
    if (deadItems.isNotEmpty) {
      Hive.box<Map>(deadLetterBox).clear();
    }
  }

  static int get deadLetterCount {
    if (_migrated) return DatabaseService.instance.deadLetterCount;
    return Hive.box<Map>(deadLetterBox).length;
  }

  static int get syncQueueLength {
    if (_migrated) return DatabaseService.instance.syncQueueLength;
    return Hive.box<Map>(syncQueueBox).length;
  }

  static DateTime? getLastSyncTime() {
    if (_migrated) return DatabaseService.instance.getLastSyncTime();
    final box = Hive.box(settingsBox);
    final time = box.get('last_sync_time');
    if (time != null) return DateTime.parse(time.toString());
    return null;
  }

  static void setLastSyncTime(DateTime time) {
    if (_migrated) {
      DatabaseService.instance.setLastSyncTime(time);
    } else {
      Hive.box(settingsBox).put('last_sync_time', time.toIso8601String());
    }
  }

  static String? _boxToTable(String boxName) {
    switch (boxName) {
      case 'students': return 'students';
      case 'groups': return 'groups_tbl';
      case 'attendance': return 'attendance';
      case 'grades': return 'grades';
      case 'invoices': return 'invoices';
      case 'payments': return 'payments';
      case 'sync_queue': return 'sync_queue';
      case 'dead_letter': return 'dead_letter';
      case 'sync_cursors': return 'sync_cursors';
      case 'settings': return 'settings';
      default: return null;
    }
  }
}
