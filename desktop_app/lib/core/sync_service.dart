import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
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

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  String get lastSyncStatus => _lastSyncStatus;

  SyncService({LocalSyncService? localSync}) : _localSync = localSync;

  void init() {
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
      _isOnline = true;
      _reconnectAttempts = 0;
    } else {
      _isOnline = await _pingApi();
      if (!_isOnline) {
        _scheduleReconnect();
      }
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
      for (final item in unsynced) {
        final type = item['type'] as String;
        final data = Map<String, dynamic>.from(item['data'] as Map);

        bool synced = false;

        if (_localSync != null) {
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
                  await _api.deleteStudent(id);
                }
                break;
            }
            synced = true;
          } catch (e) {
            synced = false;
          }
        }

        if (synced) {
          LocalDB.markSyncItemSynced(data);
        }
      }
      LocalDB.clearSyncedItems();
      _lastSyncStatus = 'تم رفع التغييرات';
      _notifyListeners(_lastSyncStatus, 'synced');
    } catch (e) {
      AnalyticsService.instance.syncFailed(error: e.toString());
      _lastSyncStatus = 'فشل في المزامنة';
      _notifyListeners(_lastSyncStatus, 'error');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> syncFromServer() async {
    if (!_isOnline || _isSyncing) return;
    _isSyncing = true;
    _notifyListeners('جاري تحميل البيانات...', 'syncing');

    try {
      await LocalDB.createBackup();

      List<dynamic> students = [];
      List<dynamic> groups = [];
      List<dynamic> grades = [];
      List<dynamic> invoices = [];
      List<dynamic> attendance = [];

      try { students = await _api.getStudents(); } catch (_) {}
      try { groups = await _api.getGroups(); } catch (_) {}
      try { grades = await _api.getGrades(); } catch (_) {}
      try { invoices = await _api.getInvoices(); } catch (_) {}

      try {
        final lastSync = LocalDB.getLastSyncTime() ?? DateTime.now().subtract(const Duration(days: 30));
        attendance = await _api.getAttendance(date: lastSync.toIso8601String());
      } catch (_) {}

      // Merge server data: update existing, add new — never delete local-only items
      void mergeData(String boxName, List<dynamic> serverItems, String keyField, {String? fallbackField}) {
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
      }

      mergeData(LocalDB.studentsBox, students, 'code', fallbackField: 'id');
      mergeData(LocalDB.groupsBox, groups, 'id');
      mergeData(LocalDB.gradesBox, grades, 'id');
      mergeData(LocalDB.invoicesBox, invoices, 'id');
      mergeData(LocalDB.attendanceBox, attendance, 'id');

      LocalDB.deduplicateBox(LocalDB.studentsBox, 'code');

      LocalDB.setLastSyncTime(DateTime.now());
      _lastSyncStatus = 'تم المزامنة بنجاح';
      _notifyListeners(_lastSyncStatus, 'synced');
      AnalyticsService.instance.syncSuccess();
      StructuredLogger.instance.info('sync_success', data: { 'new_students': students.length });
    } catch (e) {
      AnalyticsService.instance.syncFailed(error: e.toString());
      StructuredLogger.instance.error('sync_failed', data: { 'error': e.toString() });
      _lastSyncStatus = 'فشل في تحميل البيانات';
      _notifyListeners(_lastSyncStatus, 'error');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> fullSync() async {
    await syncToServer();
    await syncFromServer();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _reconnectTimer?.cancel();
  }
}
