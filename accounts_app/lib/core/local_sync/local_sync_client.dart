import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:web_socket_channel/io.dart';

class LocalSyncClient {
  static const String _defaultIp = '127.0.0.1';
  static const int _defaultPort = 8765;
  final String _deviceId = 'accounts_${DateTime.now().millisecondsSinceEpoch}';

  IOWebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _serverDeviceId;
  StreamSubscription? _channelSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onEvent => _eventController.stream;

  bool get isConnected => _isConnected;
  String? get serverDeviceId => _serverDeviceId;

  Future<bool> connect({String? ip}) async {
    if (_isConnected || _isConnecting) return true;
    _isConnecting = true;

    try {
      final uri = 'ws://${ip ?? _defaultIp}:$_defaultPort/ws';
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
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            _handleMessage(msg);
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
      'device_id': _deviceId,
      'device_type': 'accounts',
    });
  }

  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'handshake_ack':
        _serverDeviceId = msg['device_id'] as String?;
        break;

      case 'event':
        _handleEvent(msg);
        break;

      case 'ack':
      case 'pong':
      case 'error':
        break;
    }
  }

  void _handleEvent(Map<String, dynamic> msg) {
    final event = msg['event'] as Map<String, dynamic>? ?? msg;
    final box = event['box'] as String?;
    final key = event['key'] as String?;
    final data = event['data'] as Map<String, dynamic>?;

    if (box == null || key == null || data == null) return;

    try {
      Hive.box<Map>(box).put(key, data);
      _eventController.add(event);
    } catch (_) {}
  }

  void _onDisconnected() {
    _isConnected = false;
    _serverDeviceId = null;
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = Duration(
      seconds: (2 * (_reconnectAttempts + 1)).clamp(1, 30),
    );
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, () => connect());
  }

  bool send(Map<String, dynamic> msg) {
    if (!_isConnected || _channel == null) return false;
    try {
      _channel!.sink.add(jsonEncode(msg));
      return true;
    } catch (_) {
      return false;
    }
  }

  bool sendPaymentEvent({
    required String studentCode,
    required String month,
    required Map<String, dynamic> paymentData,
  }) {
    return send({
      'type': 'event',
      'event': {
        'box': 'payments',
        'key': '${studentCode}_$month',
        'data': paymentData,
        'timestamp': DateTime.now().toIso8601String(),
      },
      'ack_id': '${DateTime.now().millisecondsSinceEpoch}',
    });
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
  }
}
