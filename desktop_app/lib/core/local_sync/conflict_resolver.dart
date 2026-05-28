import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../local_db.dart';

class ConflictResolver {
  static const String conflictLogBox = 'conflict_logs';
  static const Duration priorityThreshold = Duration(seconds: 2);
  static const String accountsDevicePrefix = 'accounts';

  static const Set<String> serverAuthoritativeTables = {'invoices', 'payments'};
  static const Set<String> fieldMergeTables = {'students', 'groups'};
  static const Set<String> immutableFields = {'id', 'code', 'created_at', 'teacher_id'};

  static Future<void> resolve({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    required String boxName,
    required String key,
    required String localDeviceId,
    required String remoteDeviceId,
    String? localTimestamp,
    String? remoteTimestamp,
  }) async {
    if (remoteTimestamp == null && localTimestamp == null) return;

    final localTime = _parseTimestamp(localTimestamp);
    final remoteTime = _parseTimestamp(remoteTimestamp);
    if (localTime == null && remoteTime == null) return;

    bool useRemote = false;
    String resolver = '';

    if (serverAuthoritativeTables.contains(boxName)) {
      useRemote = true;
      resolver = 'server_authoritative';
    } else if (fieldMergeTables.contains(boxName)) {
      final merged = _fieldMerge(localData, remoteData, localTime, remoteTime);
      if (merged != null) {
        LocalDB.saveData(boxName, key, merged);
        return;
      }
      useRemote = true;
      resolver = 'field_merge_fallback';
    } else {
      resolver = _lastWriterWins(localTime, remoteTime, localDeviceId, remoteDeviceId, boxName);
      useRemote = resolver == 'remote_wins';
    }

    if (useRemote) {
      LocalDB.saveData(boxName, key, remoteData);
    }

    await _logConflict(
      localData: localData,
      remoteData: remoteData,
      boxName: boxName,
      key: key,
      winner: useRemote ? 'remote' : 'local',
      resolver: resolver,
      localDeviceId: localDeviceId,
      remoteDeviceId: remoteDeviceId,
    );
  }

  static Map<String, dynamic>? _fieldMerge(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
    DateTime? localTime,
    DateTime? remoteTime,
  ) {
    final merged = <String, dynamic>{};
    final allKeys = <String>{...local.keys, ...remote.keys};
    final conflicts = <Map<String, dynamic>>[];

    for (final key in allKeys) {
      final lv = local[key];
      final rv = remote[key];

      if (lv == null && rv == null) continue;
      if (lv == null) { merged[key] = rv; continue; }
      if (rv == null) { merged[key] = lv; continue; }
      if (lv == rv) { merged[key] = lv; continue; }

      if (immutableFields.contains(key)) {
        merged[key] = rv;
        continue;
      }

      if (localTime != null && remoteTime != null) {
        if (localTime.isAfter(remoteTime)) {
          merged[key] = lv;
        } else {
          merged[key] = rv;
        }
      } else {
        merged[key] = rv;
      }

      conflicts.add({
        'field': key,
        'local': lv,
        'remote': rv,
        'resolved_to': merged[key],
      });
    }

    return conflicts.isEmpty ? null : merged;
  }

  static String _lastWriterWins(
    DateTime? localTime,
    DateTime? remoteTime,
    String localDeviceId,
    String remoteDeviceId,
    String boxName,
  ) {
    if (localTime == null) return 'remote_wins';
    if (remoteTime == null) return 'local_wins';

    if (remoteTime.isAfter(localTime)) {
      return 'remote_wins';
    } else if (localTime.isAfter(remoteTime)) {
      return 'local_wins';
    } else {
      final isPayment = boxName == LocalDB.paymentsBox;
      if (isPayment && remoteDeviceId.startsWith(accountsDevicePrefix)) {
        return 'remote_wins';
      } else if (isPayment && localDeviceId.startsWith(accountsDevicePrefix)) {
        return 'local_wins';
      }
      return 'remote_wins';
    }
  }

  static Future<void> _logConflict({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    required String boxName,
    required String key,
    required String winner,
    required String resolver,
    required String localDeviceId,
    required String remoteDeviceId,
  }) async {
    try {
      final box = await Hive.openBox<Map>(conflictLogBox);
      await box.add({
        'box': boxName,
        'key': key,
        'winner': winner,
        'resolver': resolver,
        'local_device': localDeviceId,
        'remote_device': remoteDeviceId,
        'local_data': localData,
        'remote_data': remoteData,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  static DateTime? _parseTimestamp(String? ts) {
    if (ts == null) return null;
    return DateTime.tryParse(ts);
  }

  static Future<List<Map<String, dynamic>>> getConflictLogs() async {
    try {
      final box = await Hive.openBox<Map>(conflictLogBox);
      return box.values.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }
}
