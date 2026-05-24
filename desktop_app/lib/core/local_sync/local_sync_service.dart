import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../constants.dart';
import '../local_db.dart';
import 'local_sync_server.dart';
import 'local_sync_client.dart';
import 'network_discovery.dart';

enum LocalSyncStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class LocalSyncService {
  final LocalSyncServer _server = LocalSyncServer();
  LocalSyncClient? _client;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  bool _isEnabled = true;

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

    // Start WebSocket server
    await _server.start();
    if (_server.isRunning) {
      _notify(LocalSyncStatus.connected, 'الخادم المحلي يعمل على port ${LocalSyncConfig.port}');
    } else {
      _notify(LocalSyncStatus.error, 'فشل تشغيل الخادم المحلي');
    }

    // Listen for server events
    _server.onEvent.listen((event) {
      final box = event['box'] as String?;
      final key = event['key'] as String?;
      if (box != null && key != null) {
        _notify(
          LocalSyncStatus.connected,
          'تم استلام حدث: $box/$key',
        );
      }
    });

    // Health check
    _healthTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _connectedClients = _server.clientCount;
    });

    // Connectivity monitoring
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (!isOnline && _server.isRunning) {
        _notify(LocalSyncStatus.disconnected, 'الشبكة المحلية غير متاحة');
      }
    });
  }

  /// Send an event directly via server broadcast to all connected clients
  bool broadcastEvent({
    required String box,
    required String key,
    required Map<String, dynamic> data,
    String? excludeDeviceId,
  }) {
    if (!_server.isRunning) return false;
    _server.broadcast(
      {
        'box': box,
        'key': key,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      },
      excludeDeviceId: excludeDeviceId,
    );
    return true;
  }

  /// Try to send an event to a connected local peer.
  /// Falls back to cloud queue if no peers connected.
  Future<bool> trySendToPeer(Map<String, dynamic> item) async {
    if (!_server.isRunning || _server.clientCount == 0) return false;

    final type = item['type'] as String? ?? '';
    final data = item['data'] as Map<String, dynamic>? ?? {};
    final timestamp =
        item['timestamp'] as String? ?? DateTime.now().toIso8601String();

    final box = _boxForType(type);
    final key = data['id'] ?? data['code'] ?? '';

    _server.broadcast({
      'box': box,
      'key': key,
      'data': data,
      'timestamp': timestamp,
    });
    return true;
  }

  String _boxForType(String type) {
    switch (type) {
      case 'student':
        return LocalDB.studentsBox;
      case 'group':
        return LocalDB.groupsBox;
      case 'attendance':
        return LocalDB.attendanceBox;
      case 'grade':
        return LocalDB.gradesBox;
      case 'invoice':
        return LocalDB.invoicesBox;
      case 'payment':
        return LocalDB.paymentsBox;
      default:
        return type;
    }
  }

  Future<void> stop() async {
    _healthTimer?.cancel();
    _connectivitySubscription?.cancel();
    await _server.stop();
    _notify(LocalSyncStatus.disconnected, 'تم إيقاف الخدمة المحلية');
  }

  void dispose() {
    stop();
  }
}
