import 'dart:async';
import '../utils/constants.dart';
import 'local_sync_server.dart';

enum LocalSyncStatus { disconnected, connecting, connected, error }

final class LocalSyncService {
  final LocalSyncServer _server = LocalSyncServer();
  final bool _isEnabled = true;
  LocalSyncStatus _status = LocalSyncStatus.disconnected;
  String _lastError = '';
  int _connectedClients = 0;
  Timer? _healthTimer;
  final List<void Function(LocalSyncStatus, String)> _listeners = [];

  LocalSyncStatus get status => _status;
  String get lastError => _lastError;
  bool get isServerRunning => _server.isRunning;
  int get connectedClients => _connectedClients;

  void addListener(void Function(LocalSyncStatus, String) listener) {
    _listeners.add(listener);
  }

  void _notify(LocalSyncStatus s, String msg) {
    _status = s;
    _lastError = msg;
    for (final l in _listeners) {
      l(s, msg);
    }
  }

  Future<void> start() async {
    if (!_isEnabled) return;
    await _server.start();
    if (_server.isRunning) {
      _notify(LocalSyncStatus.connected,
          'الخادم المحلي يعمل على port ${LocalSyncConfig.port}');
    } else {
      _notify(LocalSyncStatus.error, 'فشل تشغيل الخادم المحلي');
    }
    _server.onEvent.listen((event) {
      final box = event['box'] as String?;
      final key = event['key'] as String?;
      if (box != null && key != null) {
        _notify(LocalSyncStatus.connected, 'تم استلام حدث: $box/$key');
      }
    });
    _healthTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _connectedClients = _server.clientCount;
    });
  }

  bool broadcastEvent({
    required String box,
    required String key,
    required Map<String, dynamic> data,
    String? excludeDeviceId,
  }) {
    if (!_server.isRunning) return false;
    _server.broadcast({
      'box': box,
      'key': key,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    }, excludeDeviceId: excludeDeviceId);
    return true;
  }

  Future<bool> trySendToPeer(Map<String, dynamic> item) async {
    if (!_server.isRunning || _server.clientCount == 0) return false;
    final type = item['type'] as String? ?? '';
    final data = item['data'] as Map<String, dynamic>? ?? {};
    final timestamp =
        item['timestamp'] as String? ?? DateTime.now().toIso8601String();
    final box = _boxForType(type);
    final key = data['id'] ?? data['code'] ?? '';
    final sourceDeviceId = item['device_id'] as String?;
    _server.broadcast({
      'box': box,
      'key': key,
      'data': data,
      'timestamp': timestamp,
    }, excludeDeviceId: sourceDeviceId);
    return true;
  }

  String _boxForType(String type) {
    switch (type) {
      case 'student':
        return 'students';
      case 'delete_student':
        return 'students';
      case 'delete_group':
        return 'groups';
      case 'group':
        return 'groups';
      case 'attendance':
        return 'attendance';
      case 'grade':
        return 'grades';
      case 'invoice':
        return 'invoices';
      default:
        return type;
    }
  }

  Future<void> stop() async {
    _healthTimer?.cancel();
    await _server.stop();
    _notify(LocalSyncStatus.disconnected, 'تم إيقاف الخدمة المحلية');
  }

  void dispose() {
    stop();
  }
}
