import 'dart:convert';
import '../database/database_service.dart';
import '../models/student.dart';
import '../models/group.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

final class ConflictResolver {
  static const Set<String> serverAuthoritative = {'invoices', 'payments'};
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

    if (serverAuthoritative.contains(boxName)) {
      useRemote = true;
      resolver = 'server_authoritative';
      _saveData(boxName, key, remoteData);
    } else if (fieldMergeTables.contains(boxName)) {
      final merged = _fieldMerge(localData, remoteData, localTime, remoteTime);
      if (merged != null) {
        _saveData(boxName, key, merged);
        resolver = 'field_merge';
        useRemote = false;
      } else {
        useRemote = true;
        resolver = 'field_merge_fallback';
        _saveData(boxName, key, remoteData);
      }
    } else {
      resolver = _lastWriterWins(localTime, remoteTime, localDeviceId, remoteDeviceId, boxName);
      useRemote = resolver == 'remote_wins';
      if (useRemote) {
        _saveData(boxName, key, remoteData);
      }
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
    bool hasConflict = false;

    for (final key in allKeys) {
      final lv = local[key];
      final rv = remote[key];

      if (lv == null && rv == null) continue;
      if (lv == null) {
        merged[key] = rv;
        continue;
      }
      if (rv == null) {
        merged[key] = lv;
        continue;
      }
      if (lv == rv) {
        merged[key] = lv;
        continue;
      }

      if (immutableFields.contains(key)) {
        merged[key] = rv;
        continue;
      }

      hasConflict = true;
      if (localTime != null && remoteTime != null) {
        merged[key] = localTime.isAfter(remoteTime) ? lv : rv;
      } else {
        merged[key] = rv;
      }
    }

    return hasConflict ? merged : null;
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
    if (remoteTime.isAfter(localTime)) return 'remote_wins';
    if (localTime.isAfter(remoteTime)) return 'local_wins';
    return 'remote_wins';
  }

  static void _saveData(String boxName, String key, Map<String, dynamic> data) {
    final db = DatabaseService.instance;
    switch (boxName) {
      case 'students':
        final s = _mapToStudent(data);
        if (s != null) db.saveStudent(s);
        break;
      case 'groups':
        db.saveGroup(_mapToGroup(data));
        break;
      case 'attendance':
        db.saveAttendance(data);
        break;
      case 'grades':
        db.saveGrade(data);
        break;
      case 'invoices':
        db.saveInvoice(data);
        break;
      case 'payments':
        db.savePayment(data);
        break;
    }
  }

  static StudentModel? _mapToStudent(Map<String, dynamic> data) {
    try {
      return StudentModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  static GroupModel _mapToGroup(Map<String, dynamic> data) {
    return GroupModel.fromJson(data);
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
      DatabaseService.instance.db.execute(
        'INSERT INTO ${DbConstants.conflictLogsTable} (box, key, winner, resolver, local_device, remote_device, local_data, remote_data, timestamp) VALUES (?,?,?,?,?,?,?,?,?)',
        [
          boxName,
          key,
          winner,
          resolver,
          localDeviceId,
          remoteDeviceId,
          jsonEncode(localData),
          jsonEncode(remoteData),
          DateTime.now().toIso8601String(),
        ],
      );
    } catch (e) {
      AppLogger.instance.error('conflict_log_failed', error: e);
    }
  }

  static DateTime? _parseTimestamp(String? ts) {
    if (ts == null) return null;
    return DateTime.tryParse(ts);
  }
}
