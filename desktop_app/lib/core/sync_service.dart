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
  Timer? _syncTimer;
  Timer? _reconnectTimer;
  bool _isOnline = false;
  bool _isSyncing = false;
  String _lastSyncStatus = 'غير متصل';
  final List<Function(String, String)> _listeners = [];
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelay = 120;

  static const String _cursorBox = 'sync_cursors';
  static const String _deadLetterBox = 'dead_letter';

  final Map<String, String> _cursorMap = {};
  bool _cursorsLoaded = false;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  String get lastSyncStatus => _lastSyncStatus;

  SyncService({LocalSyncService? localSync}) : _localSync = localSync;

  void init() {
    _loadCursors();
    _checkConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });

    _syncTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      if (_isOnline && !_isSyncing) {
        await fullSync();
      }
    });
  }

  void _loadCursors() {
    try {
      final box = LocalDB.getBox(_cursorBox);
      for (final key in box.keys) {
        _cursorMap[key.toString()] = box.get(key).toString();
      }
      _cursorsLoaded = true;
    } catch (_) {
      _cursorsLoaded = true;
    }
  }

  void _saveCursor(String table, String cursor) {
    _cursorMap[table] = cursor;
    try {
      LocalDB.getBox(_cursorBox).put(table, cursor);
    } catch (_) {}
  }

  String? _getCursor(String table) {
    return _cursorMap[table];
  }

  void addListener(Function(String, String) listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeListener(Function(String, String) listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners(String status, String type) {
    for (final listener in _listeners) {
      listener(status, type);
    }
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    await _handleConnectivityChange(results);
  }

  Future<void> _handleConnectivityChange(List<ConnectivityResult> results) async {
    final wasOnline = _isOnline;
    final hasNetworkInterface = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);

    if (hasNetworkInterface) {
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
      _lastSyncStatus = 'تم استعادة الاتصال - جاري المزامنة...';
      _notifyListeners(_lastSyncStatus, 'connected');
      AnalyticsService.instance.reconnectSuccess();
      StructuredLogger.instance.info('reconnect_success', data: { 'attempts': _reconnectAttempts });
      fullSync();
    } else if (!_isOnline && wasOnline) {
      _lastSyncStatus = 'وضع عدم الاتصال';
      _notifyListeners(_lastSyncStatus, 'disconnected');
      AnalyticsService.instance.offlineModeEnabled();
      StructuredLogger.instance.warning('offline_mode_enabled', data: { 'attempts': _reconnectAttempts });
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = min(pow(2, _reconnectAttempts).toInt(), _maxReconnectDelay);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _checkConnectivity();
    });
  }

  Future<bool> _pingApi() async {
    try {
      final response = await _dio.get('/versions/');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncToServer() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _notifyListeners('جاري رفع التغييرات...', 'syncing');

    try {
      final unsynced = LocalDB.getUnsyncedItems();
      final ackIds = <String>[];

      for (final item in unsynced) {
        final type = item['type'] as String;
        final data = Map<String, dynamic>.from(item['data'] as Map);
        final operationId = item['operation_id'] as String? ?? const Uuid().v4();

        bool synced = false;

        if (_localSync != null) {
          item['operation_id'] = operationId;
          synced = await _localSync.trySendToPeer(item);
        }

        if (!synced && _isOnline) {
          try {
            switch (type) {
              case 'attendance':
                await _api.markAttendance(data);
                break;
              case 'grade':
                await _api.createGrade(data);
                break;
              case 'invoice':
                await _api.createInvoice(data);
                break;
              case 'student':
                final created = await _api.createStudent(data);
                final serverId = created['id']?.toString();
                if (serverId != null && serverId.isNotEmpty) {
                  data['id'] = serverId;
                }
                break;
              case 'delete_student':
                final id = data['id']?.toString() ?? '';
                if (id.isNotEmpty) {
                  try {
                    await _api.deleteStudent(id);
                  } on DioException catch (e) {
                    if (e.response?.statusCode != 404) rethrow;
                  }
                }
                break;
            }
            synced = true;
          } catch (e) {
            synced = false;
          }
        }

        if (synced) {
          ackIds.add(operationId);
          LocalDB.markSyncItemSynced(data);
        }

        if (!synced) {
          LocalDB.addToDeadLetter(item, error: 'Sync failed after retry');
        }
      }

      if (ackIds.isNotEmpty && _isOnline) {
        try {
          await _api.post('/sync/ack', data: {'acked_ids': ackIds});
        } catch (_) {}
      }

      _lastSyncStatus = 'تم رفع التغييرات';
      _notifyListeners(_lastSyncStatus, 'synced');
    } catch (e) {
      AnalyticsService.instance.syncFailed(error: e.toString());
      _lastSyncStatus = 'فشل في المزامنة';
      _notifyListeners(_lastSyncStatus, 'error');
    } finally {
      LocalDB.clearSyncedItems();
      _isSyncing = false;
    }
  }

  Future<void> syncFromServer() async {
    if (!_isOnline || _isSyncing) return;
    _isSyncing = true;
    _notifyListeners('جاري تحميل البيانات...', 'syncing');

    try {
      try { await LocalDB.createBackup(); } catch (_) {}

      await _syncTableIncremental('students', _api.getStudents(), LocalDB.studentsBox, 'code', fallbackField: 'id');
      await _syncTableIncremental('groups', _api.getGroups(), LocalDB.groupsBox, 'id');
      await _syncTableIncremental('grades', _api.getGrades(), LocalDB.gradesBox, 'id');
      await _syncTableIncremental('invoices', _api.getInvoices(), LocalDB.invoicesBox, 'id');

      try {
        final lastSync = _getCursor('attendance') ?? LocalDB.getLastSyncTime()?.toIso8601String() ?? DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
        final attendance = await _api.getAttendance(date: lastSync);
        await _processBatch('attendance', attendance, LocalDB.attendanceBox, 'id');
        _saveCursor('attendance', DateTime.now().toIso8601String());
      } catch (_) {}

      LocalDB.deduplicateBox(LocalDB.studentsBox, 'code');

      LocalDB.setLastSyncTime(DateTime.now());
      _lastSyncStatus = 'تم المزامنة بنجاح';
      _notifyListeners(_lastSyncStatus, 'synced');
      AnalyticsService.instance.syncSuccess();
      StructuredLogger.instance.info('sync_success', data: {});
    } catch (e) {
      AnalyticsService.instance.syncFailed(error: e.toString());
      StructuredLogger.instance.error('sync_failed', data: { 'error': e.toString() });
      _lastSyncStatus = 'فشل في تحميل البيانات';
      _notifyListeners(_lastSyncStatus, 'error');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncTableIncremental(
    String tableName,
    Future<List<dynamic>> Function() fetchAll,
    String boxName,
    String keyField, {
    String? fallbackField,
  }) async {
    try {
      final data = await fetchAll();
      await _processBatch(tableName, data, boxName, keyField, fallbackField: fallbackField);
    } catch (_) {}
  }

  Future<void> _processBatch(
    String tableName,
    List<dynamic> serverItems,
    String boxName,
    String keyField, {
    String? fallbackField,
  }) async {
    if (serverItems.isEmpty) return;

    final localItems = LocalDB.getAllData(boxName);
    final localKeys = localItems.map((e) => e[keyField]?.toString() ?? '').toSet();

    for (final item in serverItems) {
      final itemMap = item as Map;
      var key = itemMap[keyField]?.toString() ?? '';
      if (key.isEmpty && fallbackField != null) {
        key = itemMap[fallbackField]?.toString() ?? '';
      }
      if (key.isNotEmpty) {
        LocalDB.saveData(boxName, key, Map<String, dynamic>.from(itemMap));
        localKeys.remove(key);
      }
    }

    if (serverItems.isNotEmpty) {
      final lastItem = serverItems.last as Map;
      final cursor = lastItem['updated_at']?.toString() ?? lastItem['created_at']?.toString() ?? DateTime.now().toIso8601String();
      _saveCursor(tableName, cursor);
    }
  }

  Future<void> _recoverDeadLetters() async {
    final deadItems = LocalDB.getAllDeadLetters();
    for (final item in deadItems) {
      LocalDB.addToSyncQueue(
        item['type'] as String? ?? 'unknown',
        Map<String, dynamic>.from(item['data'] as Map? ?? {}),
      );
      LocalDB.removeDeadLetter(item);
    }
    if (deadItems.isNotEmpty) {
      StructuredLogger.instance.info('dead_letter_recovered', data: { 'count': deadItems.length });
    }
  }

  Future<void> fullSync() async {
    await _recoverDeadLetters();
    await syncToServer();
    await syncFromServer();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _reconnectTimer?.cancel();
  }
}
