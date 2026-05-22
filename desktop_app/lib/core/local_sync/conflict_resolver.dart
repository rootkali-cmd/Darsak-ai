import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../local_db.dart';

class ConflictResolver {
  static const String conflictLogBox = 'conflict_logs';
  static const Duration priorityThreshold = Duration(seconds: 2);
  static const String accountsDevicePrefix = 'accounts';

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

    if (localTime == null) {
      useRemote = true;
    } else if (remoteTime == null) {
      useRemote = false;
    } else if (remoteTime.isAfter(localTime)) {
      useRemote = true;
    } else if (localTime.isAfter(remoteTime)) {
      useRemote = false;
    } else {
      // Same timestamp – device priority
      // accounts > desktop for payment data
      final isPayment = boxName == LocalDB.paymentsBox;
      if (isPayment && remoteDeviceId.startsWith(accountsDevicePrefix)) {
        useRemote = true;
      } else if (isPayment && localDeviceId.startsWith(accountsDevicePrefix)) {
        useRemote = false;
      } else {
        useRemote = true; // tie-break: newer overwrites
      }
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
      localDeviceId: localDeviceId,
      remoteDeviceId: remoteDeviceId,
    );
  }

  static Future<void> _logConflict({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    required String boxName,
    required String key,
    required String winner,
    required String localDeviceId,
    required String remoteDeviceId,
  }) async {
    try {
      final box = await Hive.openBox<Map>(conflictLogBox);
      await box.add({
        'box': boxName,
        'key': key,
        'winner': winner,
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
