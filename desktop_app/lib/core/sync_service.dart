import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'local_db.dart';
import 'local_sync/local_sync_service.dart';

class SyncService {
  final ApiService _api = ApiService();
  final Connectivity _connectivity = Connectivity();
  final LocalSyncService? _localSync;
  StreamSubscription? _connectivitySubscription;
  Timer? _syncTimer;
  bool _isOnline = false;
  bool _isSyncing = false;
  String _lastSyncStatus = 'غير متصل';
  final List<Function(String, String)> _listeners = [];

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

    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isOnline && !_isSyncing) {
        syncToServer();
      }
    });
  }

  void addListener(Function(String, String) listener) {
    _listeners.add(listener);
  }

  void _notifyListeners(String status, String type) {
    for (final listener in _listeners) {
      listener(status, type);
    }
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _handleConnectivityChange(results);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((r) => r != ConnectivityResult.none);

    if (_isOnline && !wasOnline) {
      _lastSyncStatus = 'تم استعادة الاتصال - جاري المزامنة...';
      _notifyListeners(_lastSyncStatus, 'connected');
      syncToServer();
    } else if (!_isOnline) {
      _lastSyncStatus = 'وضع عدم الاتصال';
      _notifyListeners(_lastSyncStatus, 'disconnected');
    }
  }

  Future<void> syncToServer() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _notifyListeners('جاري رفع التغييرات...', 'syncing');

    try {
      final unsynced = LocalDB.getUnsyncedItems();
      for (int i = 0; i < unsynced.length; i++) {
        final item = unsynced[i];
        final type = item['type'] as String;
        final data = Map<String, dynamic>.from(item['data'] as Map);

        bool synced = false;

        // Try local P2P sync first
        if (_localSync != null) {
          synced = await _localSync.trySendToPeer(item);
        }

        // Fall back to cloud API
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
            }
            synced = true;
          } catch (e) {
            synced = false;
          }
        }

        if (synced) {
          LocalDB.markSynced(i);
        }
      }
      LocalDB.clearSyncedItems();
      _lastSyncStatus = 'تم رفع التغييرات';
      _notifyListeners(_lastSyncStatus, 'synced');
    } catch (e) {
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
      // Backup before sync
      await LocalDB.createBackup();

      // Fetch ALL data first before touching local storage
      final students = await _api.getStudents();
      final groups = await _api.getGroups();
      final grades = await _api.getGrades();
      final invoices = await _api.getInvoices();
      final lastSync = LocalDB.getLastSyncTime() ?? DateTime.now().subtract(const Duration(days: 30));
      final attendance = await _api.getAttendance(date: lastSync.toIso8601String());

      // Only replace local data if API returned data for that box
      // Never delete non-empty local data with empty API response
      if (students.isNotEmpty) {
        final localLen = LocalDB.getAllData(LocalDB.studentsBox).length;
        if (localLen == 0 || students.length >= localLen) {
          LocalDB.clearBox(LocalDB.studentsBox);
          for (final s in students) {
            LocalDB.saveData(LocalDB.studentsBox, s['id'], s);
          }
        }
      }
      if (groups.isNotEmpty) {
        final localLen = LocalDB.getAllData(LocalDB.groupsBox).length;
        if (localLen == 0 || groups.length >= localLen) {
          LocalDB.clearBox(LocalDB.groupsBox);
          for (final g in groups) {
            LocalDB.saveData(LocalDB.groupsBox, g['id'], g);
          }
        }
      }
      if (grades.isNotEmpty) {
        final localLen = LocalDB.getAllData(LocalDB.gradesBox).length;
        if (localLen == 0 || grades.length >= localLen) {
          LocalDB.clearBox(LocalDB.gradesBox);
          for (final g in grades) {
            LocalDB.saveData(LocalDB.gradesBox, g['id'], g);
          }
        }
      }
      if (invoices.isNotEmpty) {
        final localLen = LocalDB.getAllData(LocalDB.invoicesBox).length;
        if (localLen == 0 || invoices.length >= localLen) {
          LocalDB.clearBox(LocalDB.invoicesBox);
          for (final i in invoices) {
            LocalDB.saveData(LocalDB.invoicesBox, i['id'], i);
          }
        }
      }
      if (attendance.isNotEmpty) {
        final localLen = LocalDB.getAllData(LocalDB.attendanceBox).length;
        if (localLen == 0 || attendance.length >= localLen) {
          LocalDB.clearBox(LocalDB.attendanceBox);
          for (final a in attendance) {
            LocalDB.saveData(LocalDB.attendanceBox, a['id'], a);
          }
        }
      }

      LocalDB.setLastSyncTime(DateTime.now());
      _lastSyncStatus = 'تم المزامنة بنجاح';
      _notifyListeners(_lastSyncStatus, 'synced');
    } catch (e) {
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
  }
}
