import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

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
    await Hive.openBox(settingsBox);
  }

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

  static void addToSyncQueue(String type, Map<String, dynamic> data) {
    final box = Hive.box<Map>(syncQueueBox);
    box.add(Map<String, dynamic>.from({
      'type': type,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': false,
    }));
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
    }
  }

  /// Mark a specific item in the sync queue as synced (by matching data content)
  static void markSyncItemSynced(Map<String, dynamic> targetData) {
    final box = Hive.box<Map>(syncQueueBox);
    for (int i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      if (item != null && item['synced'] == false) {
        final itemData = item['data'] as Map?;
        if (itemData != null) {
          final targetId = targetData['id']?.toString();
          final targetCode = targetData['code']?.toString();
          final itemId = itemData['id']?.toString();
          final itemCode = itemData['code']?.toString();
          if ((targetId != null && targetId == itemId) ||
              (targetCode != null && targetCode == itemCode && targetCode == itemCode)) {
            item['synced'] = true;
            box.putAt(i, item);
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
