import 'dart:async';
import 'dart:io' as io;
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../api/api_service.dart';
import '../database/database_service.dart';
import '../sync/sync_queue_manager.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../services/debug_tracker.dart';
import '../models/student.dart';
import '../models/group.dart';

/// Simplified sync service.
/// Core rule: every flag (_isSyncing, _isOnline) MUST be reset in finally blocks.
final class SyncService {
  final ApiService _api;
  final SyncQueueManager _queue;
  final DatabaseService _db;
  final String _dbPath;
  final Connectivity _connectivity;

  StreamSubscription? _connectivitySubscription;
  Timer? _queueTimer;
  Timer? _reconnectTimer;

  bool _isOnline = false;
  bool _isSyncing = false;
  bool _paused = false;
  DateTime _lastQueueProcess = DateTime(2000);
  DateTime _lastConnectivitySyncAttempt = DateTime(2000);
  DateTime _lastBackupTime = DateTime(2000);
  int _reconnectAttempts = 0;

  String _lastSyncStatus = 'غير متصل';

  final List<void Function(String status, String type)> _listeners = [];
  final List<void Function(dynamic)> _opListenerStubs = []; // kept for backward compat

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  String get lastSyncStatus => _lastSyncStatus;
  int get pendingCount => _queue.getUnsynced().length;
  int get failedCount => 0; // simplified: queue-based, no per-op failure tracking
  DateTime? get lastSyncTime => _db.getLastSyncTime();

  SyncService({
    required ApiService api,
    required SyncQueueManager queue,
    required DatabaseService db,
    String dbPath = '',
    Connectivity? connectivity,
  })  : _api = api,
        _queue = queue,
        _db = db,
        _dbPath = dbPath,
        _connectivity = connectivity ?? Connectivity();

  void init() {
    // Clear stale queue on startup (queue is only for current session)
    _queue.clearAllQueue();
    // Delay first check so startup isn't blocked
    Future.delayed(const Duration(seconds: 3), _checkConnectivity);
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    // Periodic queue processor every 15s when online
    _queueTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isOnline && !_paused && !_isSyncing) {
        _processQueue();
      }
    });
    AppLogger.instance.info('sync_service_initialized');
  }

  void addListener(void Function(String, String) listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void removeListener(void Function(String, String) listener) {
    _listeners.remove(listener);
  }

  // Backward compat stubs — op tracking removed for simplicity
  void addOpListener(void Function(dynamic) listener) {
    if (!_opListenerStubs.contains(listener)) _opListenerStubs.add(listener);
  }

  void removeOpListener(void Function(dynamic) listener) {
    _opListenerStubs.remove(listener);
  }

  void _notify(String status, String type) {
    DebugTracker.instance.syncEvent(type, status);
    for (final l in _listeners) {
      try { l(status, type); } catch (_) {}
    }
  }

  // ── Public: queue silently without trying API (for instant UI operations) ──
  void queueOnly(String type, String label, Map<String, dynamic> data,
      {String? opId}) {
    _queue.enqueue(type, data, operationId: opId);
    _lastSyncStatus = 'في قائمة الانتظار';
    _notify(_lastSyncStatus, 'pending');
  }

  // ── Public: push one item immediately ──
  Future<void> immediatePush(
      String type, String label, Map<String, dynamic> data,
      {String? opId}) async {
    final labelStr = label.isEmpty
        ? (data['full_name']?.toString() ??
            data['exam_name']?.toString() ??
            data['code']?.toString() ??
            data['id']?.toString() ??
            type)
        : label;

    if (!_isOnline) {
      _queue.enqueue(type, data, operationId: opId);
      _lastSyncStatus = 'غير متصل - في قائمة الانتظار';
      _notify(_lastSyncStatus, 'pending');
      return;
    }

    try {
      await _sendToServer(type, data).timeout(const Duration(seconds: 10));
      _lastSyncStatus = 'تمت المزامنة';
      _notify(_lastSyncStatus, 'synced');
      _db.setLastSyncTime(DateTime.now());
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _lastSyncStatus = 'انتهت الجلسة';
        _notify(_lastSyncStatus, 'error');
        return;
      }
      _queue.enqueue(type, data, operationId: opId);
      _lastSyncStatus = 'فشل مؤقت - في قائمة الانتظار';
      _notify(_lastSyncStatus, 'pending');
    } catch (e) {
      _queue.enqueue(type, data, operationId: opId);
      _lastSyncStatus = 'فشل مؤقت - في قائمة الانتظار';
      _notify(_lastSyncStatus, 'pending');
    }
  }

  // ── Process the queue ──
  Future<void> _processQueue() async {
    if (!_isOnline || _isSyncing || _paused) return;
    if (DateTime.now().difference(_lastQueueProcess) < const Duration(seconds: 5)) return;

    _isSyncing = true;
    _lastQueueProcess = DateTime.now();
    _notify('جاري رفع التغييرات...', 'syncing');

    try {
      final items = _queue.getUnsynced();
      if (items.isEmpty) {
        _lastSyncStatus = 'كل التغييرات متزامنة';
        _notify(_lastSyncStatus, 'synced');
        return;
      }

      int successCount = 0;
      int failCount = 0;

      for (final item in items) {
        if (!_isOnline || _paused) break;
        final type = item['type'] as String;
        final data = Map<String, dynamic>.from(item['data'] as Map);

        try {
          await _sendToServer(type, data).timeout(const Duration(seconds: 10));
          _queue.markSynced(item);
          if (type == 'delete_student' || type == 'delete_group') {
            _deleteDbRecord(type, data);
          }
          successCount++;
        } catch (e) {
          failCount++;
          // Keep in queue for next retry
        }
      }

      _queue.clearSynced();

      if (failCount > 0) {
        _lastSyncStatus = '$successCount تم رفعها، $failCount باقية في قائمة الانتظار';
        _notify(_lastSyncStatus, 'error');
      } else {
        _lastSyncStatus = 'تمت المزامنة';
        _notify(_lastSyncStatus, 'synced');
      }
    } finally {
      _isSyncing = false;
    }
  }

  // ── Pull from server ──
  Future<void> syncFromServer() async {
    if (!_isOnline || _isSyncing || _paused) return;
    _isSyncing = true;
    _notify('جاري تحميل البيانات...', 'syncing');

    try {
      await _maybeBackup();

      await _syncTable('students', () => _api.getStudents(), 'code');
      await _syncTable('groups', () => _api.getGroups(), 'id');
      await _syncTable('grades', () => _api.getGrades(), 'id');
      await _syncTable('invoices', () => _api.getInvoices(), 'id');
      try {
        final attendance = await _api.getAttendance().timeout(const Duration(seconds: 8));
        for (final item in attendance) {
          final m = item as Map;
          final key = m['id']?.toString() ?? '';
          if (key.isNotEmpty) _db.saveAttendance(Map<String, dynamic>.from(m));
        }
      } catch (_) {}

      _db.setLastSyncTime(DateTime.now());
      _lastSyncStatus = 'تم تحديث البيانات';
      _notify(_lastSyncStatus, 'synced');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _lastSyncStatus = 'انتهت الجلسة';
        _isOnline = false;
      } else {
        _lastSyncStatus = 'فشل تحميل البيانات';
      }
      _notify(_lastSyncStatus, 'error');
    } catch (e) {
      _lastSyncStatus = 'فشل تحميل البيانات';
      _notify(_lastSyncStatus, 'error');
    } finally {
      _isSyncing = false;
    }
  }

  // ── Server helpers ──
  Future<void> _sendToServer(String type, Map<String, dynamic> data) async {
    switch (type) {
      case 'student':
        await _api.createStudent(data);
        break;
      case 'delete_student':
        await _api.deleteStudent(data['id']?.toString() ?? '');
        break;
      case 'delete_group':
        await _api.deleteGroup(data['id']?.toString() ?? '');
        break;
      case 'attendance':
        await _api.markAttendance(data);
        break;
      case 'grade':
        await _api.createGrade(data);
        break;
      case 'invoice':
        await _api.createInvoice(data);
        break;
      case 'group':
        await _api.createGroup(data);
        break;
      case 'pin':
        await _api.resetStudentPin(
          data['student_id']?.toString() ?? '',
          data['pin']?.toString() ?? '',
        );
        break;
    }
  }

  Future<void> _syncTable(String name, Future<List<dynamic>> Function() fetch, String keyField) async {
    try {
      final data = await fetch().timeout(const Duration(seconds: 10));
      for (final item in data) {
        final m = item as Map;
        final key = m[keyField]?.toString() ?? '';
        if (key.isEmpty) continue;
        switch (name) {
          case 'students':
            _db.saveStudent(StudentModel.fromJson(Map<String, dynamic>.from(m)));
            break;
          case 'groups':
            _db.saveGroup(GroupModel.fromJson(Map<String, dynamic>.from(m)));
            break;
          case 'grades':
            _db.saveGrade(Map<String, dynamic>.from(m));
            break;
          case 'invoices':
            _db.saveInvoice(Map<String, dynamic>.from(m));
            break;
        }
      }
    } catch (e) {
      AppLogger.instance.warning('sync_table_failed', data: {'table': name}, error: e);
    }
  }

  void _deleteDbRecord(String type, Map<String, dynamic> data) {
    if (type == 'delete_student') {
      _db.deleteStudent(data['code']?.toString() ?? '');
    } else if (type == 'delete_group') {
      _db.deleteGroup(data['id']?.toString() ?? '');
    }
  }

  // ── Connectivity ──
  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    await _handleConnectivityChange(results);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _handleConnectivityChange(results);
  }

  Future<void> _handleConnectivityChange(List<ConnectivityResult> results) async {
    final wasOnline = _isOnline;
    final hasInterface = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);

    if (hasInterface) {
      _isOnline = await _pingApi();
      if (_isOnline) {
        _reconnectAttempts = 0;
      } else {
        _scheduleReconnect();
      }
    } else {
      _isOnline = false;
      _scheduleReconnect();
    }

    if (_isOnline && !wasOnline) {
      _lastSyncStatus = 'متصل';
      _notify(_lastSyncStatus, 'connected');
      // Throttle: only sync from server once per 60s on connectivity change
      if (DateTime.now().difference(_lastConnectivitySyncAttempt) > const Duration(seconds: 60)) {
        _lastConnectivitySyncAttempt = DateTime.now();
        await _processQueue();
        await syncFromServer();
      } else {
        await _processQueue();
      }
    } else if (!_isOnline && wasOnline) {
      _lastSyncStatus = 'غير متصل';
      _notify(_lastSyncStatus, 'disconnected');
    }
  }

  Future<bool> _pingApi() async {
    try {
      return await _api.ping();
    } catch (_) {
      return false;
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_reconnectAttempts >= 10) return;
    final delay = min(pow(2, _reconnectAttempts).toInt(), 60);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: delay), _checkConnectivity);
  }

  // ── Backup ──
  Future<void> _maybeBackup() async {
    if (_dbPath.isEmpty) return;
    if (DateTime.now().difference(_lastBackupTime) < const Duration(hours: 1)) return;
    try {
      final backupDir = io.Directory('${_dbDir()}/backups');
      if (!await backupDir.exists()) await backupDir.create(recursive: true);
      _db.checkpointWal();
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      final destPath = '${backupDir.path}/backup_$ts';
      await io.Directory(destPath).create(recursive: true);
      await io.File(_dbPath).copy('$destPath/darsak.db');
      _lastBackupTime = DateTime.now();
      await _rotateBackups(backupDir);
    } catch (_) {}
  }

  String _dbDir() => _dbPath.substring(0, _dbPath.lastIndexOf('/'));

  Future<void> _rotateBackups(io.Directory backupDir) async {
    try {
      final entries = await backupDir.list().toList();
      final dirs = entries.whereType<io.Directory>().toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      if (dirs.length > AppConstants.maxBackups) {
        for (int i = AppConstants.maxBackups; i < dirs.length; i++) {
          await dirs[i].delete(recursive: true);
        }
      }
      final cutoff = DateTime.now().subtract(Duration(days: AppConstants.backupRetentionDays));
      for (final d in dirs) {
        final name = d.path.split('_').last;
        final ms = int.tryParse(name);
        if (ms != null) {
          final ts = DateTime.fromMillisecondsSinceEpoch(ms);
          if (ts.isBefore(cutoff)) await d.delete(recursive: true);
        }
      }
    } catch (_) {}
  }

  // ── Public controls ──
  void pause() => _paused = true;

  void resume() {
    _paused = false;
    if (_isOnline) _processQueue();
  }

  Future<void> syncNow() async {
    // If queue is bloated (>1000 items), it's likely corrupt — clear and start fresh
    if (_queue.pendingCount > 1000) {
      _queue.clearAllQueue();
      _lastSyncStatus = 'تم تنظيف قائمة الانتظار';
      _notify(_lastSyncStatus, 'synced');
      return;
    }
    await _processQueue();
    await syncFromServer();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _reconnectTimer?.cancel();
    _queueTimer?.cancel();
    _listeners.clear();
  }
}
