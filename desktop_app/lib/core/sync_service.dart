import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'api_service.dart';
import 'analytics_service.dart';
import 'structured_logger.dart';
import 'constants.dart';
import 'local_db.dart';
import 'local_sync/local_sync_service.dart';

enum SyncOpStatus { pending, syncing, synced, failed }

class SyncOp {
  final String id;
  final String type;
  final String label;
  SyncOpStatus status;
  final DateTime createdAt;
  DateTime? syncedAt;
  int retryCount;
  String? lastError;
  int latencyMs;

  SyncOp({
    required this.id, required this.type, required this.label,
    this.status = SyncOpStatus.pending, DateTime? createdAt,
    this.syncedAt, this.retryCount = 0, this.lastError, this.latencyMs = 0,
  }) : createdAt = createdAt ?? DateTime.now();
}

class SyncService {
  final ApiService _api = ApiService();
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));
  final Connectivity _connectivity = Connectivity();
  final LocalSyncService? _localSync;
  StreamSubscription? _connectivitySubscription;
  Timer? _reconnectTimer;
  Timer? _retryTimer;
  bool _isOnline = false;
  bool _isSyncing = false;
  String _lastSyncStatus = 'غير متصل';
  final List<Function(String, String)> _listeners = [];
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelay = 120;
  DateTime _lastBackupTime = DateTime(2000);
  static const Duration _backupInterval = Duration(hours: 1);
  bool _paused = false;

  final List<SyncOp> _ops = [];
  final List<Function(SyncOp)> _opListeners = [];

  static const String _cursorBox = 'sync_cursors';
  final Map<String, String> _cursorMap = {};
  bool _cursorsLoaded = false;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  String get lastSyncStatus => _lastSyncStatus;

  int get pendingCount => _ops.where((o) => o.status == SyncOpStatus.pending).length;
  int get syncingCount => _ops.where((o) => o.status == SyncOpStatus.syncing).length;
  int get failedCount => _ops.where((o) => o.status == SyncOpStatus.failed).length;
  DateTime? get lastSyncTime => _ops.where((o) => o.status == SyncOpStatus.synced).map((o) => o.syncedAt).where((t) => t != null).fold<DateTime?>(null, (prev, t) => prev != null && prev.isAfter(t!) ? prev : t);
  List<SyncOp> get recentOps => _ops.reversed.take(50).toList();

  SyncService({LocalSyncService? localSync}) : _localSync = localSync;

  void init() {
    _loadCursors();
    _checkConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });
  }

  void addListener(Function(String, String) listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void removeListener(Function(String, String) listener) {
    _listeners.remove(listener);
  }

  void addOpListener(Function(SyncOp) listener) {
    if (!_opListeners.contains(listener)) _opListeners.add(listener);
  }

  void removeOpListener(Function(SyncOp) listener) {
    _opListeners.remove(listener);
  }

  void _notify(String status, String type) {
    for (final l in _listeners) { l(status, type); }
  }

  void _notifyOp(SyncOp op) {
    for (final l in _opListeners) { l(op); }
  }

  void _addOp(String type, String label, {String? opId}) {
    final op = SyncOp(id: opId ?? const Uuid().v4(), type: type, label: label);
    _ops.add(op);
    _notifyOp(op);
    if (_ops.length > 200) _ops.removeRange(0, _ops.length - 200);
  }

  SyncOp? _findOp(String? opId, String type, String label) {
    if (opId != null) return _ops.cast<SyncOp?>().firstWhere((o) => o?.id == opId, orElse: () => null);
    return _ops.cast<SyncOp?>().firstWhere((o) => o?.type == type && o?.label == label && o?.status == SyncOpStatus.pending, orElse: () => null);
  }

  void _updateOpStatus(String? opId, String type, String label, SyncOpStatus status, {String? error, int? latencyMs}) {
    final op = _findOp(opId, type, label);
    if (op != null) {
      op.status = status;
      if (status == SyncOpStatus.synced) { op.syncedAt = DateTime.now(); op.lastError = null; }
      if (status == SyncOpStatus.failed) { op.lastError = error; }
      if (latencyMs != null) op.latencyMs = latencyMs;
      _notifyOp(op);
    }
  }

  SyncOp? _opByLabel(String type, String label) {
    return _ops.cast<SyncOp?>().firstWhere((o) => o?.type == type && o?.label == label && o?.status != SyncOpStatus.synced, orElse: () => null);
  }

  Future<void> immediatePush(String type, String label, Map<String, dynamic> data, {String? opId}) async {
    final id = opId ?? const Uuid().v4();
    _addOp(type, label, opId: id);

    if (!_isOnline) {
      _addToQueue(type, data, operationId: id);
      return;
    }

    _updateOpStatus(id, type, label, SyncOpStatus.syncing);
    _lastSyncStatus = 'جاري رفع التغييرات...';
    _notify(_lastSyncStatus, 'syncing');

    final start = DateTime.now();
    try {
      await _sendToServer(type, data);
      final ms = DateTime.now().difference(start).inMilliseconds;
      _updateOpStatus(id, type, label, SyncOpStatus.synced, latencyMs: ms);
      _lastSyncStatus = 'تمت المزامنة';
      _notify(_lastSyncStatus, 'synced');
      _setLastSyncTime();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _updateOpStatus(id, type, label, SyncOpStatus.failed, error: 'انتهت الجلسة');
        _lastSyncStatus = 'انتهت الجلسة';
        _notify(_lastSyncStatus, 'error');
        return;
      }
      final ms = DateTime.now().difference(start).inMilliseconds;
      _updateOpStatus(id, type, label, SyncOpStatus.pending, latencyMs: ms, error: e.type.name);
      _addToQueue(type, data, operationId: id);
      _lastSyncStatus = 'فشل الرفع - قيد إعادة المحاولة';
      _notify(_lastSyncStatus, 'pending');
      _scheduleRetry();
    } catch (e) {
      final ms = DateTime.now().difference(start).inMilliseconds;
      _updateOpStatus(id, type, label, SyncOpStatus.pending, latencyMs: ms, error: e.toString());
      _addToQueue(type, data, operationId: id);
      _scheduleRetry();
    }
  }

  Future<void> _sendToServer(String type, Map<String, dynamic> data) async {
    switch (type) {
      case 'student': await _api.createStudent(data); break;
      case 'delete_student': await _api.deleteStudent(data['id']?.toString() ?? ''); break;
      case 'attendance': await _api.markAttendance(data); break;
      case 'grade': await _api.createGrade(data); break;
      case 'invoice': await _api.createInvoice(data); break;
      case 'group': await _api.createGroup(data); break;
      case 'pin':
        await _api.resetStudentPin(data['student_id']?.toString() ?? '', data['pin']?.toString() ?? '');
        break;
    }
  }

  void _addToQueue(String type, Map<String, dynamic> data, {String? operationId}) {
    LocalDB.addToSyncQueue(type, data, operationId: operationId);
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 10), () => _processQueue());
  }

  Future<void> _processQueue() async {
    if (!_isOnline || _isSyncing) return;
    _isSyncing = true;
    final items = LocalDB.getUnsyncedItems();
    if (items.isEmpty) { _isSyncing = false; return; }

    for (final item in items) {
      if (!_isOnline) break;
      final type = item['type'] as String;
      final data = Map<String, dynamic>.from(item['data'] as Map);
      final opId = item['operation_id']?.toString();
      final label = data['full_name']?.toString() ?? data['exam_name']?.toString() ?? data['id']?.toString() ?? type;

      _updateOpStatus(opId, type, label, SyncOpStatus.syncing);
      _lastSyncStatus = 'جاري رفع التغييرات...';
      _notify(_lastSyncStatus, 'syncing');

      final start = DateTime.now();
      try {
        await _sendToServer(type, data);
        final ms = DateTime.now().difference(start).inMilliseconds;
        _updateOpStatus(opId, type, label, SyncOpStatus.synced, latencyMs: ms);
        LocalDB.markSyncItemSynced(data);
      } catch (e) {
        final ms = DateTime.now().difference(start).inMilliseconds;
        final op = _findOp(opId, type, label);
        if (op != null) {
          op.retryCount++;
          if (op.retryCount > 5) {
            _updateOpStatus(opId, type, label, SyncOpStatus.failed, error: 'فشل بعد 5 محاولات', latencyMs: ms);
            LocalDB.addToDeadLetter(item, error: 'Failed after 5 retries');
          } else {
            _updateOpStatus(opId, type, label, SyncOpStatus.pending, latencyMs: ms);
          }
        }
      }
    }

    LocalDB.clearSyncedItems();
    _isSyncing = false;
    if (_ops.any((o) => o.status == SyncOpStatus.failed)) {
      _lastSyncStatus = 'بعض التغييرات فشلت';
      _notify(_lastSyncStatus, 'error');
    } else {
      _lastSyncStatus = 'تمت المزامنة';
      _notify(_lastSyncStatus, 'synced');
    }
  }

  Future<void> syncFromServer() async {
    if (!_isOnline || _isSyncing) return;
    _isSyncing = true;
    _notify('جاري تحميل البيانات...', 'syncing');

    try {
      final now = DateTime.now();
      if (now.difference(_lastBackupTime) > _backupInterval) {
        try { await LocalDB.createBackup(); _lastBackupTime = now; } catch (_) {}
      }

      await _syncTable('students', () => _api.getStudents(), 'code', fallbackField: 'id');
      await _syncTable('groups', () => _api.getGroups(), 'id');
      await _syncTable('grades', () => _api.getGrades(), 'id');
      await _syncTable('invoices', () => _api.getInvoices(), 'id');
      try {
        final attendance = await _api.getAttendance();
        await _processBatch('attendance', attendance, 'id');
      } catch (_) {}

      LocalDB.deduplicateBox(LocalDB.studentsBox, 'code');
      LocalDB.setLastSyncTime(DateTime.now());
      _lastSyncStatus = 'تم تحديث البيانات';
      _notify(_lastSyncStatus, 'synced');
    } catch (e) {
      _lastSyncStatus = 'فشل تحميل البيانات';
      _notify(_lastSyncStatus, 'error');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncTable(String name, Future<List<dynamic>> Function() fetch, String keyField, {String? fallbackField}) async {
    try {
      final data = await fetch();
      await _processBatch(name, data, keyField, fallbackField: fallbackField);
    } catch (_) {}
  }

  Future<void> _processBatch(String name, List<dynamic> items, String keyField, {String? fallbackField}) async {
    if (items.isEmpty) return;
    for (final item in items) {
      final m = item as Map;
      var key = m[keyField]?.toString() ?? '';
      if (key.isEmpty && fallbackField != null) key = m[fallbackField]?.toString() ?? '';
      if (key.isNotEmpty) LocalDB.saveData(name, key, Map<String, dynamic>.from(m));
    }
    final last = items.last as Map;
    _saveCursor(name, last['updated_at']?.toString() ?? last['created_at']?.toString() ?? DateTime.now().toIso8601String());
  }

  void _loadCursors() {
    try {
      final box = LocalDB.getBox(_cursorBox);
      for (final key in box.keys) _cursorMap[key.toString()] = box.get(key).toString();
      _cursorsLoaded = true;
    } catch (_) { _cursorsLoaded = true; }
  }

  void _saveCursor(String table, String cursor) {
    _cursorMap[table] = cursor;
    try { LocalDB.getBox(_cursorBox).put(table, cursor); } catch (_) {}
  }

  void _setLastSyncTime() {
    LocalDB.setLastSyncTime(DateTime.now());
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    await _handleConnectivityChange(results);
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
      _lastSyncStatus = 'تم استعادة الاتصال';
      _notify(_lastSyncStatus, 'connected');
      _processQueue();
      syncFromServer();
    } else if (!_isOnline && wasOnline) {
      _lastSyncStatus = 'وضع عدم الاتصال';
      _notify(_lastSyncStatus, 'disconnected');
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = min(pow(2, _reconnectAttempts).toInt(), _maxReconnectDelay);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: delay), () => _checkConnectivity());
  }

  Future<bool> _pingApi() async {
    try { final r = await _dio.get('/versions/'); return r.statusCode == 200; }
    catch (_) { return false; }
  }

  void pause() { _paused = true; }
  void resume() { _paused = false; if (_isOnline) { _processQueue(); } }

  Future<void> syncNow() async {
    await _processQueue();
    await syncFromServer();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _reconnectTimer?.cancel();
    _retryTimer?.cancel();
  }
}
