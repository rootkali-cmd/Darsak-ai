import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../constants.dart';
import '../local_db.dart';
import 'conflict_resolver.dart';
import 'network_discovery.dart';

class LocalSyncClient {
  final NetworkDiscovery _discovery;
  IOWebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _peerDeviceId;
  StreamSubscription? _channelSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  String? _currentPeerIp;

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onEvent => _eventController.stream;

  bool get isConnected => _isConnected;
  String? get peerDeviceId => _peerDeviceId;

  LocalSyncClient({NetworkDiscovery? discovery})
      : _discovery = discovery ?? LocalhostDiscovery();

  Future<bool> connect({String? peerIp}) async {
    if (_isConnected || _isConnecting) return true;
    _isConnecting = true;

    try {
      _currentPeerIp = peerIp ?? await _discovery.discoverPeerIp();
      if (_currentPeerIp == null) {
        _isConnecting = false;
        return false;
      }

      final uri = 'ws://$_currentPeerIp:${LocalSyncConfig.port}/ws';
      _channel = IOWebSocketChannel.connect(
        Uri.parse(uri),
        pingInterval: const Duration(seconds: 15),
      );

      await _channel!.ready;
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;

      _sendHandshake();

      _channelSubscription = _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data as String) as Map<String, dynamic>;
            _handleMessage(message);
          } catch (_) {}
        },
        onDone: () => _onDisconnected(),
        onError: (_) => _onDisconnected(),
      );

      return true;
    } catch (_) {
      _isConnected = false;
      _isConnecting = false;
      _scheduleReconnect();
      return false;
    }
  }

  void _sendHandshake() {
    send({
      'type': 'handshake',
      'device_id': LocalSyncConfig.deviceId,
      'device_type': 'desktop',
    });
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'handshake_ack':
        _peerDeviceId = message['device_id'] as String?;
        _sendPendingEvents();
        break;

      case 'event':
        _handleEvent(message);
        break;

      case 'ack':
        _onAck(message);
        break;

      case 'pong':
        break;

      case 'error':
        break;
    }
  }

  void _handleEvent(Map<String, dynamic> message) {
    final event = message['event'] as Map<String, dynamic>? ?? message;
    final box = event['box'] as String?;
    final key = event['key'] as String?;
    final data = event['data'] as Map<String, dynamic>?;
    final timestamp = event['timestamp'] as String?;

    if (box == null || key == null || data == null) return;

    try {
      final existing = LocalDB.getData(box, key);
      if (existing != null) {
        ConflictResolver.resolve(
          localData: existing,
          remoteData: data,
          boxName: box,
          key: key,
          localDeviceId: LocalSyncConfig.deviceId,
          remoteDeviceId: _peerDeviceId ?? 'unknown',
          localTimestamp: existing['updated_at'] as String?,
          remoteTimestamp: timestamp,
        );
      } else {
        LocalDB.saveData(box, key, data);
      }

      _eventController.add(event);
    } catch (_) {}
  }

  void _sendPendingEvents() {
    try {
      final unsynced = LocalDB.getUnsyncedItems();
      for (final item in unsynced) {
        send({
          'type': 'event',
          'event': {
            'box': _boxForType(item['type'] as String? ?? ''),
            'key': item['data']?['id'] ?? item['data']?['code'] ?? '',
            'data': item['data'],
            'timestamp': item['timestamp'] ?? DateTime.now().toIso8601String(),
          },
          'ack_id': '${DateTime.now().millisecondsSinceEpoch}',
        });
      }
    } catch (_) {}
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

  void _onAck(Map<String, dynamic> message) {
    // mark item as synced
  }

  void _onDisconnected() {
    _isConnected = false;
    _peerDeviceId = null;
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = Duration(
      seconds: (LocalSyncConfig.reconnectDelay.inSeconds *
              (_reconnectAttempts + 1))
          .clamp(1, LocalSyncConfig.maxReconnectDelay.inSeconds),
    );
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, () => connect(peerIp: _currentPeerIp));
  }

  bool send(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) return false;
    try {
      _channel!.sink.add(jsonEncode(message));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendEvent({
    required String box,
    required String key,
    required Map<String, dynamic> data,
  }) async {
    final message = {
      'type': 'event',
      'event': {
        'box': box,
        'key': key,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      },
      'ack_id': '${DateTime.now().millisecondsSinceEpoch}',
    };

    if (isConnected) {
      return send(message);
    }
    // Queue it locally instead
    LocalDB.addToSyncQueue('local_sync', message);
    return false;
  }

  Future<void> stop() async {
    _reconnectTimer?.cancel();
    _channelSubscription?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    _discovery.dispose();
  }
}
