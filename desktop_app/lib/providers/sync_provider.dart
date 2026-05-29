import 'package:flutter/foundation.dart';
import '../core/sync/sync_service.dart';
import '../core/services/debug_tracker.dart';

final class SyncProvider extends ChangeNotifier {
  final SyncService _sync;
  String _status = 'غير متصل';
  bool _isOnline = false;
  bool _isSyncing = false;
  String? _lastError;
  bool _pendingNotify = false;

  String get status => _status;
  String? get lastError => _lastError;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingCount => _sync.pendingCount;
  int get failedCount => _sync.failedCount;
  DateTime? get lastSyncTime => _sync.lastSyncTime;

  SyncProvider(this._sync) {
    _isOnline = _sync.isOnline;
    _status = _sync.lastSyncStatus;
    _sync.addListener(_onSyncChange);
  }

  void _onSyncChange(String status, String type) {
    _status = status;
    _isOnline = _sync.isOnline;
    _isSyncing = _sync.isSyncing;
    if (!_pendingNotify) {
      _pendingNotify = true;
      Future.microtask(() {
        _pendingNotify = false;
        DebugTracker.instance.notifyListeners('SyncProvider');
        notifyListeners();
      });
    }
  }

  Future<void> syncNow() async {
    try {
      await _sync.syncNow();
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
      _status = 'فشلت المزامنة';
      DebugTracker.instance.notifyListeners('SyncProvider(error)');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sync.removeListener(_onSyncChange);
    super.dispose();
  }
}
