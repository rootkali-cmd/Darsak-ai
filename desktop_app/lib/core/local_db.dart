import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class LocalDB {
  static late final String _sharedPath;
  static late final String _backupPath;

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
    await Hive.initFlutter(_sharedPath);
    await Hive.openBox<Map>(studentsBox);
    await Hive.openBox<Map>(groupsBox);
    await Hive.openBox<Map>(attendanceBox);
    await Hive.openBox<Map>(gradesBox);
    await Hive.openBox<Map>(invoicesBox);
    await Hive.openBox<Map>(paymentsBox);
    await Hive.openBox<Map>(syncQueueBox);
    await Hive.openBox<Map>(deadLetterBox);
    await Hive.openBox(syncCursorsBox);
    await Hive.openBox(settingsBox);
  }

  static Box getBox(String boxName) {
    return Hive.box(boxName);
  }

  static const int _maxBackups = 10;
  static const int _backupRetentionDays = 14;

  static Future<void> createBackup() async {
    final backupDir = Directory(_backupPath);
    if (!await backupDir.exists()) await backupDir.create(recursive: true);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final destDir = Directory('$_backupPath/backup_$timestamp');
    await destDir.create(recursive: true);
    final srcDir = Directory(_sharedPath);
    if (await srcDir.exists()) {
      await for (final entity in srcDir.list()) {
        if (entity is File) {
          await entity.copy('${destDir.path}/${entity.uri.pathSegments.last}');
        }
      }
    }
    await _rotateBackups();
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

      // Close all boxes before restore
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

      // Reopen boxes
      await Hive.openBox<Map>(studentsBox);
      await Hive.openBox<Map>(groupsBox);
      await Hive.openBox<Map>(attendanceBox);
      await Hive.openBox<Map>(gradesBox);
      await Hive.openBox<Map>(invoicesBox);
      await Hive.openBox<Map>(paymentsBox);
      await Hive.openBox<Map>(syncQueueBox);
      await Hive.openBox<Map>(deadLetterBox);
      await Hive.openBox(syncCursorsBox);

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
    Hive.box<Map>(boxName).put(key, Map<String, dynamic>.from(data));
  }

  static Map<String, dynamic>? getData(String boxName, String key) {
    final data = Hive.box<Map>(boxName).get(key);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  static List<Map<String, dynamic>> getAllData(String boxName) {
    final box = Hive.box<Map>(boxName);
    return box.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static void deleteData(String boxName, String key) {
    Hive.box<Map>(boxName).delete(key);
  }

  static void clearBox(String boxName) {
    Hive.box<Map>(boxName).clear();
  }

  static void deduplicateBox(String boxName, String field) {
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

  static List<Map<String, dynamic>> getUnsyncedItems() {
    final box = Hive.box<Map>(syncQueueBox);
    return box.values
        .map((e) => Map<String, dynamic>.from(e))
        .where((item) => item['synced'] == false)
        .toList();
  }

  static void markSynced(int index) {
    final box = Hive.box<Map>(syncQueueBox);
    final item = box.getAt(index);
    if (item != null) {
      item['synced'] = true;
      box.putAt(index, item);
      box.flush();
    }
  }

  static void markSyncItemSynced(Map<String, dynamic> targetData) {
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
    final box = Hive.box<Map>(deadLetterBox);
    box.add(Map<String, dynamic>.from({
      ...item,
      'dead_letter_at': DateTime.now().toIso8601String(),
      'error': error ?? 'unknown',
    }));
    box.flush();
  }

  static List<Map<String, dynamic>> getAllDeadLetters() {
    final box = Hive.box<Map>(deadLetterBox);
    return box.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static void removeDeadLetter(Map<String, dynamic> item) {
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
    return Hive.box<Map>(deadLetterBox).length;
  }

  static int get syncQueueLength {
    return Hive.box<Map>(syncQueueBox).length;
  }

  static DateTime? getLastSyncTime() {
    final box = Hive.box(settingsBox);
    final time = box.get('last_sync_time');
    if (time != null) return DateTime.parse(time.toString());
    return null;
  }

  static void setLastSyncTime(DateTime time) {
    Hive.box(settingsBox).put('last_sync_time', time.toIso8601String());
  }
}
