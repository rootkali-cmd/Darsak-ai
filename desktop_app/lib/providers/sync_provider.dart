import 'package:flutter/foundation.dart';
import '../core/sync_service.dart';

class SyncProvider extends ChangeNotifier {
  final SyncService _sync;
  String _status = 'غير متصل';
  bool _isOnline = false;
  bool _isSyncing = false;

  String get status => _status;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  SyncProvider(this._sync) {
    _isOnline = _sync.isOnline;
    _status = _sync.lastSyncStatus;
    _sync.addListener(_onSyncChange);
  }

  void _onSyncChange(String status, String type) {
    _status = status;
    _isOnline = _sync.isOnline;
    _isSyncing = _sync.isSyncing;
    notifyListeners();
  }

  Future<void> syncNow() async {
    await _sync.syncNow();
  }

  @override
  void dispose() {
    _sync.removeListener(_onSyncChange);
    super.dispose();
  }
}
